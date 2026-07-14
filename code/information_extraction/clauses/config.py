"""
Shared configuration and helpers for the Key Person(s) clause extraction pipeline.

Every step (01-06) imports from this module so that the run mode, corpus/output
paths, model, and the key-person regexes are defined in exactly one place.

Layout note: this package lives at ``code/information_extraction/clauses/``,
three directories below the repo root (same depth as the sibling
``code/information_extraction/eds_forms`` pipeline). ``JLOC`` is derived from
this file's location so it works regardless of the current working directory.
``data/`` is a symlink into Box and is git-ignored, so nothing here resolves
unless the symlink is live (run ``./setup_symlinks.sh`` on a machine with the
Box mount).
"""

from __future__ import annotations

import os
import re
from pathlib import Path

# --------------------------------------------------------------------------- #
# Run mode
# --------------------------------------------------------------------------- #
# 'production' scans the full ~197k corpus; 'test' runs the whole pipeline on a
# tiny, isolated slice (own manifest / inputs / json / batch registry / results)
# so a test run never pollutes or resumes against production state.
#
# Override from the shell without editing this file, e.g.:
#     KP_MODE=test KP_TEST_LIMIT=200 python 01_scan_text_layer.py
MODE = os.environ.get("KP_MODE", "production")
assert MODE in ("test", "production"), f"KP_MODE must be test|production, got {MODE!r}"

# Test-mode knobs (ignored in production).
TEST_LIMIT = int(os.environ.get("KP_TEST_LIMIT", "500"))
# Optional path to a newline-delimited list of file_ids to use as the test slice
# (spanning present_named / present_unnamed / deleted / intentionally_omitted /
# needs-OCR so every branch is exercised). When present it overrides TEST_LIMIT.
TEST_IDS = os.environ.get("KP_TEST_IDS", str(Path(__file__).parent / "test_ids.txt"))

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #
# Repo root: three levels up from this file (clauses -> information_extraction
# -> code -> repo root). KP_JLOC overrides for nonstandard checkouts.
JLOC = os.environ.get("KP_JLOC") or str(Path(__file__).resolve().parents[3])

CONTRACTS_DIR = Path(JLOC) / "data" / "raw" / "_contracts"
API_KEY_FILE = Path(JLOC) / ".claude_key"

# Base of all derived artifacts; test mode nests everything under test/ .
_BASE = Path(JLOC) / "data" / "intermediate_products" / "key_persons"
OUT_DIR = _BASE / "test" if MODE == "test" else _BASE

MANIFEST_CSV = OUT_DIR / "key_persons_scan_manifest.csv"
OCR_CACHE_DIR = OUT_DIR / "ocr_json"           # {file_id}_ocr.json
INPUTS_DIR = OUT_DIR / "inputs"                # {file_id}.txt payloads
METADATA_CSV = OUT_DIR / "keyperson_metadata.csv"
JSON_DIR = OUT_DIR / "json"                    # {file_id}.json Claude results
RESULTS_CSV = OUT_DIR / "key_persons_extraction_results.csv"

# --------------------------------------------------------------------------- #
# Model / batch
# --------------------------------------------------------------------------- #
MODEL = os.environ.get("KP_MODEL", "claude-haiku-4-5-20251001")
MAX_TOKENS = 1500
CLOBBER = os.environ.get("KP_CLOBBER", "0") == "1"

# --------------------------------------------------------------------------- #
# Scan tuning
# --------------------------------------------------------------------------- #
# A page with fewer than this many non-whitespace chars counts as "low text".
# A file whose pages are (nearly) all low-text is routed to OCR (step 02).
LOW_TEXT_CHARS = 100
# Fraction of pages that must clear LOW_TEXT_CHARS for a file to be considered
# to have a usable text layer.
TEXT_LAYER_MIN_FRACTION = 0.5

# --------------------------------------------------------------------------- #
# Key-person regexes (whitespace-tolerant: fitz get_text() and OCR both inject
# stray spaces, e.g. "Person(s )", "key  personnel", "exc eed").
# --------------------------------------------------------------------------- #
# Broad recall on purpose -- Claude filters false positives downstream.
_KP_VARIANTS = [
    r"key\s*person(?:\s*\(\s*s\s*\)|s)?",   # key person / key persons / key person(s)
    r"key\s*personnel",
    r"key\s*individual(?:\s*\(\s*s\s*\)|s)?",
    r"key\s*staff",
]
KP_REGEX = re.compile("|".join(f"(?:{v})" for v in _KP_VARIANTS), re.IGNORECASE)

def collapse_ws(text: str) -> str:
    """Collapse all runs of whitespace to single spaces (for substring checks)."""
    return re.sub(r"\s+", " ", text or "").strip()


def truthy(v) -> bool:
    """Parse a manifest CSV boolean cell ('True'/'False'/''/bool)."""
    return str(v).strip().lower() in ("true", "1")


def load_test_ids() -> set[str] | None:
    """Return the curated test id set if a readable TEST_IDS file exists, else None."""
    p = Path(TEST_IDS)
    if not p.exists():
        return None
    ids = {line.strip() for line in p.read_text().splitlines() if line.strip()}
    return ids or None


def ensure_dirs() -> None:
    """Create the output directory tree for the current mode."""
    for d in (OUT_DIR, OCR_CACHE_DIR, INPUTS_DIR, JSON_DIR):
        d.mkdir(parents=True, exist_ok=True)


def read_api_key() -> str:
    """Read the Anthropic API key from the git-ignored .claude_key, or env."""
    if API_KEY_FILE.exists():
        return API_KEY_FILE.read_text().strip()
    key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if not key:
        raise RuntimeError(
            f"No API key: create {API_KEY_FILE} or set ANTHROPIC_API_KEY."
        )
    return key
