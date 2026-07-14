#!/usr/bin/env python3
"""
01 - Cheap full-corpus scan for Key Person(s) language (no LLM, no rendering).

Opens every contract PDF with PyMuPDF (fitz), pulls each page's text layer with
``page.get_text()`` (CPU only, the repo standard -- see
``code/preprocessing/scraps/ocr_contracts.ipynb``), and applies the
whitespace-tolerant key-person / omission regexes from ``config.py``.

Emits one manifest row per file_id. Files with (nearly) no text layer are flagged
``needs_ocr=True`` and left for step 02; their ``kp_hit`` is blank until then.

The scan is parallel (multiprocessing.Pool) and resumable: already-scanned
file_ids are skipped on re-run. In test mode it scans only TEST_IDS (if present)
or the first TEST_LIMIT PDFs, writing to the isolated test/ manifest.

Usage:
    python 01_scan_text_layer.py [--workers N]
    KP_MODE=test python 01_scan_text_layer.py
"""

from __future__ import annotations

import argparse
import csv
import sys
from multiprocessing import Pool
from pathlib import Path

import fitz  # PyMuPDF

import config as C

MANIFEST_FIELDS = [
    "file_id", "source_pdf", "n_pages", "has_text_layer", "max_text_density",
    "kp_hit", "kp_pages", "kp_snippets", "needs_ocr",
]

# Chars of context captured around each regex match for the snippet column.
SNIPPET_PAD = 120


def scan_pdf(pdf_path_str: str) -> dict:
    """Scan a single PDF's text layer. Returns one manifest row (pure, picklable)."""
    pdf_path = Path(pdf_path_str)
    row = {
        "file_id": pdf_path.stem,
        "source_pdf": pdf_path.name,
        "n_pages": 0,
        "has_text_layer": False,
        "max_text_density": 0,
        "kp_hit": "",          # blank => undetermined (needs_ocr); True/False once known
        "kp_pages": "",
        "kp_snippets": "",
        "needs_ocr": False,
    }

    try:
        doc = fitz.open(pdf_path)
    except Exception as e:  # corrupt / unreadable
        row["kp_snippets"] = f"OPEN_ERROR: {str(e)[:80]}"
        row["needs_ocr"] = True
        return row

    n_pages = doc.page_count
    row["n_pages"] = n_pages

    hit_pages: list[int] = []
    snippets: list[str] = []
    densities: list[int] = []

    for i in range(n_pages):
        try:
            text = doc[i].get_text() or ""
        except Exception:
            text = ""
        densities.append(len(text.strip()))

        for m in C.KP_REGEX.finditer(text):
            page_no = i + 1
            if page_no not in hit_pages:
                hit_pages.append(page_no)
            start = max(0, m.start() - SNIPPET_PAD)
            end = min(len(text), m.end() + SNIPPET_PAD)
            snippets.append(C.collapse_ws(text[start:end]))
    doc.close()

    row["max_text_density"] = max(densities) if densities else 0
    good_pages = sum(1 for d in densities if d >= C.LOW_TEXT_CHARS)
    has_text_layer = bool(n_pages) and (good_pages / n_pages) >= C.TEXT_LAYER_MIN_FRACTION
    row["has_text_layer"] = has_text_layer

    # kp_hit is decoupled from the text-density gate: a regex hit in whatever text
    # the file *did* expose is a definite hit and must never be discarded. Only a
    # file with NO hit AND a poor text layer is deferred to OCR (kp_hit left blank).
    row["kp_pages"] = ",".join(str(p) for p in hit_pages)
    row["kp_snippets"] = " || ".join(snippets[:5])  # cap snippet volume

    if hit_pages:
        row["kp_hit"] = True                 # found it in the text layer -> trust it
    elif has_text_layer:
        row["kp_hit"] = False                # good text, no match -> confident negative
    else:
        row["needs_ocr"] = True              # no match, poor text -> OCR in step 02
    return row


def already_scanned() -> set[str]:
    """file_ids present in an existing manifest (for resumability)."""
    if not C.MANIFEST_CSV.exists():
        return set()
    with open(C.MANIFEST_CSV, newline="") as f:
        return {r["file_id"] for r in csv.DictReader(f)}


def select_pdfs() -> list[Path]:
    """Choose which PDFs to scan, honoring mode and resumability."""
    if not C.CONTRACTS_DIR.exists():
        sys.exit(
            f"ERROR: {C.CONTRACTS_DIR} not found. Is the Box data symlink live? "
            "Run ./setup_symlinks.sh on a machine with the Box mount."
        )

    all_pdfs = sorted(C.CONTRACTS_DIR.glob("*.pdf"))

    if C.MODE == "test":
        test_ids = C.load_test_ids()
        if test_ids:
            all_pdfs = [p for p in all_pdfs if p.stem in test_ids]
            print(f"[test] curated slice: {len(all_pdfs)} of {len(test_ids)} ids found")
        else:
            all_pdfs = all_pdfs[: C.TEST_LIMIT]
            print(f"[test] no TEST_IDS file; using first {len(all_pdfs)} PDFs")

    done = already_scanned()
    todo = [p for p in all_pdfs if p.stem not in done]
    if done:
        print(f"Resuming: {len(done)} already scanned, {len(todo)} remaining")
    return todo


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--workers", type=int, default=0, help="pool size (0 = os cpu count)")
    args = ap.parse_args()

    C.ensure_dirs()
    todo = select_pdfs()
    if not todo:
        print("Nothing to scan.")
        return

    workers = args.workers or None  # None => Pool uses os.cpu_count()
    new_file = not C.MANIFEST_CSV.exists()

    written = 0
    # Append incrementally so a crash mid-run loses nothing.
    with open(C.MANIFEST_CSV, "a", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=MANIFEST_FIELDS)
        if new_file:
            writer.writeheader()

        with Pool(processes=workers) as pool:
            for row in pool.imap_unordered(scan_pdf, [str(p) for p in todo], chunksize=16):
                writer.writerow(row)
                written += 1
                if written % 1000 == 0:
                    f.flush()
                    print(f"  scanned {written}/{len(todo)}")

    print(f"Done. Wrote {written} rows to {C.MANIFEST_CSV}")


if __name__ == "__main__":
    main()
