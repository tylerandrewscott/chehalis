#!/usr/bin/env python3
"""
06 - Consolidate per-file Claude JSON into one row per file_id.

Aggregates json/{file_id}.json (adapting eds_forms 05's load-all-json pattern),
then LEFT JOINs onto the FULL scan manifest so EVERY file_id in the corpus gets a
row -- not just the candidates that went to Claude.

Status mapping for the final key_persons_status column:
  - candidate with a Claude result  -> Claude's key_persons_status
  - kp_hit == False (scanned/OCR'd or text, no match) -> "nothing_observed"
  - still needs_ocr / unreadable (kp_hit blank)        -> "undetermined"

Emits key_persons_extraction_results.csv and runs integrity assertions.

Usage:
    python 06_json_to_dataframe.py
    KP_MODE=test python 06_json_to_dataframe.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pandas as pd

import config as C

RESULT_COLS = [
    "file_id", "source_pdf", "n_pages", "has_text_layer", "ocr_used", "kp_scan_hit",
    "kp_pages", "key_persons_status", "clause_section_number", "clause_text",
    "named_individuals", "confidence", "model", "extracted_at",
]

# Statuses Claude may return. Anything else (a JSON-parse failure saved by step
# 04, or an off-schema status) is "parse_error": the file DID go to Claude but
# we have no usable answer, so it must surface as undetermined -- never as a
# confident not_found. Re-run those files with KP_CLOBBER=1.
CLAUDE_STATUSES = {
    "present_named", "present_unnamed", "deleted", "intentionally_omitted", "not_found",
}


def load_claude_json() -> dict[str, dict]:
    """Map file_id -> flattened Claude extraction (skips batch/registry files)."""
    out: dict[str, dict] = {}
    if not C.JSON_DIR.exists():
        return out
    for jf in C.JSON_DIR.glob("*.json"):
        if jf.name.startswith("batch_") or jf.name == "batch_registry.json":
            continue
        try:
            data = json.loads(jf.read_text())
        except Exception:
            continue
        ex = data.get("extracted_data", data)  # tolerate flat or {metadata,extracted_data}
        meta = data.get("metadata", {})
        status = ex.get("key_persons_status")
        if status not in CLAUDE_STATUSES:
            status = "parse_error"
        named = ex.get("named_individuals") or []
        out[jf.stem] = {
            "key_persons_status": status,
            "clause_section_number": ex.get("clause_section_number") or "",
            "clause_text": ex.get("clause_text") or "",
            "named_individuals": ", ".join(named) if isinstance(named, list) else str(named),
            "confidence": ex.get("confidence") or "",
            "model": meta.get("model", C.MODEL),
            "extracted_at": meta.get("extracted_at", ""),
        }
    return out


def main() -> None:
    if not C.MANIFEST_CSV.exists():
        sys.exit(f"ERROR: {C.MANIFEST_CSV} not found -- run the scan first.")

    manifest = pd.read_csv(C.MANIFEST_CSV, dtype=str, keep_default_na=False)
    claude = load_claude_json()
    parse_errors = sum(1 for v in claude.values()
                       if v["key_persons_status"] == "parse_error")
    print(f"Manifest rows: {len(manifest)} | Claude JSON files: {len(claude)}")
    if parse_errors:
        print(f"WARNING: {parse_errors} Claude results unparseable -> undetermined "
              f"(reprocess with KP_CLOBBER=1)")

    records = []
    for _, m in manifest.iterrows():
        fid = m["file_id"]
        kp_hit_raw = str(m.get("kp_hit", "")).strip()
        res = claude.get(fid)

        if res is not None:
            status = res["key_persons_status"]
            if status == "parse_error":        # went to Claude, answer unusable
                status = "undetermined"
        elif kp_hit_raw == "":                 # never classified (needs_ocr / unreadable)
            status = "undetermined"
        elif C.truthy(kp_hit_raw):             # candidate but no Claude result yet
            status = "undetermined"
        else:                                  # scanned/text, definitively no match
            status = "nothing_observed"

        rec = {
            "file_id": fid,
            "source_pdf": m.get("source_pdf", ""),
            "n_pages": m.get("n_pages", ""),
            "has_text_layer": m.get("has_text_layer", ""),
            "ocr_used": m.get("ocr_used", ""),
            "kp_scan_hit": kp_hit_raw,
            "kp_pages": m.get("kp_pages", ""),
            "key_persons_status": status,
            "clause_section_number": "",
            "clause_text": "",
            "named_individuals": "",
            "confidence": "",
            "model": "",
            "extracted_at": "",
        }
        if res is not None:
            rec.update({k: res[k] for k in (
                "clause_section_number", "clause_text", "named_individuals",
                "confidence", "model", "extracted_at")})
        records.append(rec)

    df = pd.DataFrame(records, columns=RESULT_COLS)
    df.to_csv(C.RESULTS_CSV, index=False)
    print(f"Wrote {len(df)} rows to {C.RESULTS_CSV}")

    # ---- integrity checks ------------------------------------------------- #
    assert df["file_id"].is_unique, "duplicate file_id rows"
    assert df["key_persons_status"].notna().all(), "null key_persons_status"
    assert (df["key_persons_status"] != "").all(), "empty key_persons_status"
    bad = df[(df["key_persons_status"] == "nothing_observed") &
             df["kp_scan_hit"].map(C.truthy)]
    assert bad.empty, f"{len(bad)} nothing_observed rows have kp_scan_hit truthy"

    print("\nStatus counts:")
    print(df["key_persons_status"].value_counts().to_string())
    if C.MODE == "production":
        n = len(df)
        print(f"\nProduction row count: {n} "
              f"({'OK' if n == 197339 else 'NOTE: expected 197,339 unique file_ids'})")


if __name__ == "__main__":
    main()
