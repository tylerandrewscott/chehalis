#!/usr/bin/env python3
"""
03 - Select the relevant pages for each candidate and build the LLM text inputs.

Filters the manifest to kp_hit==True (~27k candidates), then for each pulls the
matched page(s) +/- 1 page of context (the clause can straddle a page break).
Text comes from the fitz text layer, or from the {file_id}_ocr.json cache for
files that were OCR'd in step 02.

Writes one payload per file to inputs/{file_id}.txt (what step 04 sends to Claude,
verbatim) plus keyperson_metadata.csv (file_id, source_pdf, page_numbers).

Usage:
    python 03_build_extraction_inputs.py
    KP_MODE=test python 03_build_extraction_inputs.py
"""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

import fitz  # PyMuPDF

import config as C

CONTEXT = 1  # pages of context on each side of a matched page
PAGE_SEP = "\n\n----- PAGE {n} -----\n\n"


def context_pages(kp_pages: list[int], n_pages: int) -> list[int]:
    """Matched pages expanded by +/- CONTEXT, clamped to [1, n_pages], sorted/unique."""
    wanted: set[int] = set()
    for p in kp_pages:
        for q in range(p - CONTEXT, p + CONTEXT + 1):
            if 1 <= q <= (n_pages or q):
                wanted.add(q)
    return sorted(wanted)


def page_text_from_fitz(pdf_path: Path, pages: list[int]) -> dict[int, str]:
    out: dict[int, str] = {}
    doc = fitz.open(pdf_path)
    for p in pages:
        if 1 <= p <= doc.page_count:
            out[p] = doc[p - 1].get_text() or ""
    doc.close()
    return out


def page_text_from_ocr(file_id: str, pages: list[int]) -> dict[int, str]:
    cache = C.OCR_CACHE_DIR / f"{file_id}_ocr.json"
    if not cache.exists():
        return {}
    allpages = {int(k): v for k, v in json.loads(cache.read_text()).items()}
    return {p: allpages.get(p, "") for p in pages}


def main() -> None:
    if not C.MANIFEST_CSV.exists():
        sys.exit(f"ERROR: {C.MANIFEST_CSV} not found -- run steps 01/02 first.")
    C.ensure_dirs()

    with open(C.MANIFEST_CSV, newline="") as f:
        rows = list(csv.DictReader(f))

    candidates = [r for r in rows if C.truthy(r.get("kp_hit", ""))]
    print(f"{len(candidates)} candidates (kp_hit==True) of {len(rows)} files")

    meta_rows = []
    built = skipped = dropped = 0
    for r in candidates:
        file_id = r["file_id"]
        kp_pages = [int(p) for p in str(r.get("kp_pages", "")).split(",") if p.strip()]
        n_pages = int(r.get("n_pages") or 0)
        pages = context_pages(kp_pages, n_pages)

        payload_path = C.INPUTS_DIR / f"{file_id}.txt"
        if payload_path.exists() and not C.CLOBBER:
            # Still record metadata so step 04 can find it.
            meta_rows.append({"file_id": file_id, "source_pdf": r["source_pdf"],
                              "page_numbers": ",".join(str(p) for p in pages)})
            skipped += 1
            continue

        if not pages:
            dropped += 1
            continue

        pdf_path = C.CONTRACTS_DIR / r["source_pdf"]
        if C.truthy(r.get("ocr_used", "")):
            texts = page_text_from_ocr(file_id, pages)
        else:
            texts = page_text_from_fitz(pdf_path, pages) if pdf_path.exists() else {}

        if not any(texts.values()):
            dropped += 1
            continue

        payload = "".join(PAGE_SEP.format(n=p) + texts.get(p, "") for p in pages).strip()
        payload_path.write_text(payload)
        meta_rows.append({"file_id": file_id, "source_pdf": r["source_pdf"],
                          "page_numbers": ",".join(str(p) for p in pages)})
        built += 1
        if built % 1000 == 0:
            print(f"  built {built} payloads")

    with open(C.METADATA_CSV, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["file_id", "source_pdf", "page_numbers"])
        writer.writeheader()
        writer.writerows(meta_rows)

    print(f"Done. Built {built} new payloads ({skipped} already existed, "
          f"{dropped} dropped: no pages or no extractable text -> stay undetermined). "
          f"Metadata: {C.METADATA_CSV} ({len(meta_rows)} rows)")


if __name__ == "__main__":
    main()
