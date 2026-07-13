# EDS Form Data Extraction System

Extracts structured data from ~40,000 EDS forms using Claude's Batch API with prompt
caching. **~$72 total for 40k forms** with Haiku 4.5 (batch discount + caching), vs ~$288
without.

## Pipeline

Files are numbered by run order. Steps `01`, `06`, and `07` are R scripts; the rest are
Python (notebooks + a helper script).

| # | File | Purpose |
|---|------|---------|
| 01 | `01_batch_pdf_files.R` | Prep — split the first page out of each contract PDF (`qpdf`) into single-page forms |
| 02 | `02_eds_extraction_claude.ipynb` | Submit the forms to Claude's Batch API and retrieve results as per-form JSON |
| 03 | `03_check_batch_status.py` | Poll a batch's status while it processes (`python 03_check_batch_status.py <batch_id>`) |
| 04 | `04_fix_raw_responses.ipynb` | Repair malformed / truncated raw JSON responses |
| 05 | `05_eds_json_to_dataframe.ipynb` | Consolidate the per-form JSON into a tabular dataframe |
| 06 | `06_aggregate_jsons.R` | Aggregate the extracted JSON forms in R |
| 07 | `07_parse_admin_data.R` | Parse and join the administrative contract records (by EDS number) |

## Setup

```bash
pip install anthropic pandas pdf2image pillow
brew install poppler          # or: apt-get install poppler-utils
export ANTHROPIC_API_KEY='...'
```

## Usage

1. Open `02_eds_extraction_claude.ipynb` and edit the `CONFIG` cell:

   ```python
   CONFIG = {
       'mode': 'test',        # 'test' (single-page PDFs) or 'production' (multi-page + metadata CSV)
       'clobber': False,      # True reprocesses existing output
       'model': 'claude-haiku-4-5-20251001',   # or 'claude-sonnet-4-5-20250929'
       'test_dir': './test_forms',
       'production_dir': './production_contracts',
       'metadata_csv': './eds_metadata.csv',    # columns: filename,page_number
       'output_dir': './output_json',
   }
   ```

2. Run all cells. Batches complete within 24h (usually faster). Save the printed batch ID;
   check later with `check_batch_status(client, batch_id)` or `03_check_batch_status.py`.

One JSON file is written per form (fault-tolerant; resume with `clobber=False`).

## How it works

Each form is processed with 3 targeted queries — main text fields, contract-type
checkbox, and yes/no + vendor-status fields — which improves checkbox accuracy. All
requests go out as one batch (50% discount); system prompts are cached (90% savings on
cached tokens).

## Output

```json
{
  "metadata": { "source_file": "...", "page_number": 5, "model": "..." },
  "extracted_data": {
    "EDS_Number": "A70-5-008060",
    "Agency_name": "Department of Health",
    "Vendor_name": "Indiana Minority Health Coalition",
    "Contract_amount": "$65,000.00",
    "contract_type_info": { "contract_type": "Grant", "confidence": "high" },
    "checkbox_fields": {
      "vendor_registered": "yes",
      "renewal_language": "yes",
      "vendor_status": { "minority": "yes", "minority_percentage": "100.0", "women": "no" }
    }
  }
}
```

## Troubleshooting

- **"No forms to process"** — check `mode`, that dirs contain PDFs, and (if `clobber=False`)
  whether output already exists.
- **PDF conversion errors** — ensure `poppler-utils` is installed and page numbers in the
  metadata CSV are correct.
- **Poor extraction** — upgrade `model` to Sonnet; default render DPI is 200.

See `BATCH_TRACKING_SYSTEM.md` for the `batch_registry.json` system that prevents
re-querying PDFs already in a pending batch.
