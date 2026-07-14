#!/usr/bin/env python3
"""
02 - OCR the scanned / low-text subset (~7% of the corpus, needs_ocr==True).

Renders each page with PyMuPDF (fitz.get_pixmap, ~200 DPI) and OCRs it with
Tesseract via pytesseract. This is CPU-only by design (the no-GPU constraint);
the repo's existing ocr_contracts.ipynb uses TrOCR/GPU -- we deliberately do not,
because this subset is small and bounded.

Re-runs the SAME key-person / omission regexes (config.py) on the OCR text and
UPDATES those rows in the manifest in place: kp_hit, kp_pages, kp_snippets,
has_text_layer(-> stays False), ocr_used=True.

Resumable: OCR text is cached to {file_id}_ocr.json, so a re-run reuses it.

Usage:
    python 02_ocr_scanned_subset.py
    KP_MODE=test python 02_ocr_scanned_subset.py
"""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

import fitz  # PyMuPDF

try:
    import pytesseract
    from PIL import Image
except ImportError:
    sys.exit("ERROR: pip install pytesseract pillow  (and: apt-get install tesseract-ocr)")

import config as C

OCR_DPI = 200
SNIPPET_PAD = 120
# ocr_used is added to the manifest here; keep column order stable.
# Values: "" (not attempted), "True" (OCR'd), "missing" (PDF not found),
# "failed" (unreadable/OCR error). Any non-empty value means "don't retry";
# only "True" rows have usable OCR text, so kp_hit stays blank (undetermined)
# for missing/failed.
EXTRA_FIELDS = ["ocr_used"]


def ocr_pdf(pdf_path: Path) -> dict[int, str]:
    """OCR every page; return {page_no: text}. Cached to {file_id}_ocr.json."""
    cache = C.OCR_CACHE_DIR / f"{pdf_path.stem}_ocr.json"
    if cache.exists():
        return {int(k): v for k, v in json.loads(cache.read_text()).items()}

    pages: dict[int, str] = {}
    doc = fitz.open(pdf_path)
    zoom = OCR_DPI / 72.0
    mat = fitz.Matrix(zoom, zoom)
    for i in range(doc.page_count):
        try:
            pix = doc[i].get_pixmap(matrix=mat)
            img = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
            pages[i + 1] = pytesseract.image_to_string(img)
        except Exception as e:
            pages[i + 1] = ""
            print(f"    page {i + 1} OCR error: {str(e)[:80]}")
    doc.close()

    cache.write_text(json.dumps(pages))
    return pages


def scan_ocr_text(pages: dict[int, str]) -> tuple[list[int], list[str]]:
    """Apply the key-person regex to OCR text; return (hit_pages, snippets)."""
    hit_pages, snippets = [], []
    for page_no in sorted(pages):
        text = pages[page_no]
        for m in C.KP_REGEX.finditer(text):
            if page_no not in hit_pages:
                hit_pages.append(page_no)
            start = max(0, m.start() - SNIPPET_PAD)
            end = min(len(text), m.end() + SNIPPET_PAD)
            snippets.append(C.collapse_ws(text[start:end]))
    return hit_pages, snippets


def main() -> None:
    if not C.MANIFEST_CSV.exists():
        sys.exit(f"ERROR: {C.MANIFEST_CSV} not found -- run 01_scan_text_layer.py first.")
    C.ensure_dirs()

    with open(C.MANIFEST_CSV, newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = list(reader.fieldnames)
        rows = list(reader)
    for extra in EXTRA_FIELDS:
        if extra not in fieldnames:
            fieldnames.append(extra)

    todo = [r for r in rows if C.truthy(r.get("needs_ocr", ""))
            and not str(r.get("ocr_used", "")).strip()]
    print(f"{len(todo)} files need OCR ({len(rows)} total in manifest)")

    missing = failed = 0
    for n, r in enumerate(todo, 1):
        pdf_path = C.CONTRACTS_DIR / r["source_pdf"]
        if not pdf_path.exists():
            r["ocr_used"] = "missing"       # never read -> stays undetermined
            missing += 1
            continue
        try:
            pages = ocr_pdf(pdf_path)
        except Exception as e:
            print(f"  {r['file_id']}: OCR failed: {str(e)[:80]}")
            r["ocr_used"] = "failed"        # don't retry on re-run
            failed += 1
            continue

        hit_pages, snippets = scan_ocr_text(pages)
        r["n_pages"] = str(len(pages)) if pages else r.get("n_pages", "0")
        r["ocr_used"] = "True"
        r["kp_hit"] = str(bool(hit_pages))
        r["kp_pages"] = ",".join(str(p) for p in hit_pages)
        r["kp_snippets"] = " || ".join(snippets[:5])
        if n % 200 == 0:
            print(f"  OCR'd {n}/{len(todo)}")

    # Rewrite the manifest atomically (temp -> replace).
    tmp = C.MANIFEST_CSV.with_suffix(".csv.tmp")
    with open(tmp, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for r in rows:
            writer.writerow({k: r.get(k, "") for k in fieldnames})
    tmp.replace(C.MANIFEST_CSV)
    print(f"Updated {len(todo)} rows in {C.MANIFEST_CSV} "
          f"(missing PDFs: {missing}, OCR failures: {failed})")


if __name__ == "__main__":
    main()
