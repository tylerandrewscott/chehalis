# Key Person(s) Clause Extraction

Extracts the **Key Person(s) clause** from the ~197k unstructured contract PDFs in
`data/raw/_contracts/` — including the common struck-out case (`- Deleted.`,
`(deleted)`, `intentionally omitted`, `intentionally left blank`).

The deliverable is `key_persons_extraction_results.csv` with **one row per file ID**,
carrying an explicit `nothing_observed` value for files with no key-person language.

The hard constraint that shapes the design: **scan all 197k PDFs cheaply on CPU**
(no LLM/GPU on the full corpus), then send only the small candidate set — and only the
relevant pages — to Claude. This mirrors the sibling `code/information_extraction/eds_forms/`
pipeline (Claude **Batch API** + per-file JSON + a `batch_registry.json`
tracker), but sends extracted **text** (not page images) and issues **one request per file**.

## Pipeline

Files are numbered by run order. All read shared settings from `config.py`.

| # | File | Purpose |
|---|------|---------|
| — | `config.py` | Shared mode/paths/model/regexes. Single source of truth. |
| 01 | `01_scan_text_layer.py` | CPU full-corpus scan: PyMuPDF `get_text()` per page + whitespace-tolerant key-person regex → `key_persons_scan_manifest.csv`. Parallel, resumable. |
| 02 | `02_ocr_scanned_subset.py` | OCR only the low-text ~7% (`needs_ocr==True`) with Tesseract; re-run the regex and update those manifest rows. |
| 03 | `03_build_extraction_inputs.py` | For `kp_hit==True` candidates, pull matched page(s) ±1 context → `inputs/{file_id}.txt` + `keyperson_metadata.csv`. |
| 04 | `04_keyperson_extraction_claude.ipynb` | Claude Batch API: one text request per file → `json/{file_id}.json`. Resumable via registry + `clobber`. |
| 05 | `05_check_batch_status.py` | Poll a batch: `python 05_check_batch_status.py <batch_id>`. |
| 06 | `06_json_to_dataframe.py` | Aggregate per-file JSON, LEFT JOIN onto the full manifest → results CSV (one row per file ID). |

```
_contracts/ ──01──▶ scan_manifest.csv ──02(OCR ~7%)──▶ (updated manifest)
                          │
                 kp_hit==True (~27k) ──03──▶ inputs/*.txt + metadata.csv
                          │
                         04 (Claude Batch, text, cached) ──▶ json/*.json
                          │
                         06 (LEFT JOIN onto full manifest) ──▶ results.csv (197,339 rows)
```

## Setup

```bash
pip install -r requirements.txt
apt-get install tesseract-ocr        # or: brew install tesseract
./setup_symlinks.sh                  # from repo root — makes data/ resolve to Box
# API key: put it in <repo-root>/.claude_key  (git-ignored) or export ANTHROPIC_API_KEY
```

> **Runs where Box is mounted.** `data/` is a git-ignored symlink into Box; the pipeline
> does nothing useful in a container where that symlink is dangling.

## Usage

```bash
cd code/information_extraction/clauses

# --- test run first (cheap, isolated under .../key_persons/test/) ---
KP_MODE=test python 01_scan_text_layer.py
KP_MODE=test python 02_ocr_scanned_subset.py
KP_MODE=test python 03_build_extraction_inputs.py
KP_MODE=test jupyter nbconvert --to notebook --execute 04_keyperson_extraction_claude.ipynb  # or run interactively
KP_MODE=test python 06_json_to_dataframe.py

# --- production ---
python 01_scan_text_layer.py            # hours; resumable — safe to re-run
python 02_ocr_scanned_subset.py
python 03_build_extraction_inputs.py
# open 04_...ipynb, run cells (KP_MODE defaults to production)
python 06_json_to_dataframe.py
```

### Config knobs (env vars, read by `config.py`)

| Var | Default | Meaning |
|---|---|---|
| `KP_MODE` | `production` | `test` isolates all outputs under `key_persons/test/`. |
| `KP_TEST_LIMIT` | `500` | Max files in a test run (unless `test_ids.txt` is used). |
| `KP_TEST_IDS` | `./test_ids.txt` | Optional curated file-id list for the test slice. |
| `KP_MODEL` | `claude-haiku-4-5-20251001` | Escalate to Sonnet if validation is weak. |
| `KP_CLOBBER` | `0` | `1` reprocesses existing outputs. |

## `key_persons_status` dictionary

| Value | Meaning |
|---|---|
| `present_named` | Clause in force and names specific individual(s). |
| `present_unnamed` | Clause in force but designates key persons by reference (e.g. "listed in Section 33"). |
| `deleted` | Clause struck out / marked deleted. |
| `intentionally_omitted` | Marked intentionally omitted / left blank / not applicable. |
| `not_found` | Sent to Claude but no key-person language actually present (false-positive match). |
| `nothing_observed` | Scan found no key-person language (never sent to Claude). |
| `undetermined` | Still `needs_ocr`/unreadable/missing, a candidate whose Claude result isn't in yet, or a Claude response that failed to parse (rerun 04 with `KP_CLOBBER=1`). |

`clause_text` is **verbatim** — the prompt forbids paraphrasing; Claude may only normalize
extraction/OCR whitespace artifacts. To QA this, check that `clause_text` (whitespace-collapsed)
is a substring of the corresponding `inputs/{file_id}.txt` payload **after stripping the
`----- PAGE N -----` separators** and collapsing whitespace — those markers can fall inside a
clause that straddles a page break, so a naive substring test yields false negatives.

## Outputs (Box, git-ignored)

Under `data/intermediate_products/key_persons/` (production) or `.../key_persons/test/` (test):

- `key_persons_scan_manifest.csv` — one row per scanned file (steps 01/02)
- `ocr_json/{file_id}_ocr.json` — cached OCR text (step 02)
- `inputs/{file_id}.txt`, `keyperson_metadata.csv` — LLM inputs (step 03)
- `json/{file_id}.json`, `batch_registry.json` — Claude results + batch tracking (step 04)
- `key_persons_extraction_results.csv` — final deliverable (step 06)

## Cost

Text-only + the 50% Batch API discount keeps this well under the eds_forms figure
(~$72 for 40k image forms with Haiku): only ~27k text candidates reach Claude, one
request each. (Prompt caching is not used — the system prompt is far below Haiku 4.5's
4096-token minimum cacheable prefix, so it would be a silent no-op.) A test batch of a
few hundred files costs cents.

## Follow-ups (not blocking)

- Join results to EDS/admin identifiers via
  `data/intermediate_products/eds_claude_extraction_results.csv` in a later measurement step.
