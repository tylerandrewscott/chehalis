# Code

Pipeline code, organized by stage. Mostly Python notebooks with R scripts for
aggregation, measurement, and analysis. Paths in R resolve with `here::here()` — run from
the project root.

```
scraping/               1. Collect contract metadata + PDFs from the Indiana API
preprocessing/          2. Classify pages (form vs contract), build embeddings
information_extraction/ 3. Extract structured fields from documents
  eds_forms/               → EDS form extraction (Claude Batch API, production)
measurement/            4. Feature construction from extracted text (SOW embeddings)
misc/                     PDF/image utilities, AWS config
testing/                  Evaluated-but-not-adopted extractors (Donut, GPT-4o, Textract, PaddleOCR)
```

`scraps/`/`scratch/` subfolders hold superseded work kept for reference.

## 1. Scraping (`scraping/`) — notebooks numbered in run order

- `01_post_indiana_api.ipynb` — query the API → `indiana_contracts.json` (+ professional
  services subset). `CLOBBER` toggles incremental vs full refresh.
- `02_download_contract_pdfs.ipynb` — download each PDF into `data/raw/_contracts/`.
- `03_indiana_json_to_csv.ipynb` — flatten JSON → CSV.

## 2. Preprocessing (`preprocessing/`)

Decides **which page of a multi-page contract is the EDS form**.

- `zero_shot_classifier_clean.ipynb` — classify pages as form vs. contract.
- `zero_shot_renewal_classifier.ipynb` — flag renewal/amendment documents.
- `cached_embeddings/` — precomputed reference embeddings for similarity matching.

## 3. Information extraction (`information_extraction/`)

### `eds_forms/` — **production system**

Extracts the full ~40k-form corpus via the Claude Batch API with prompt caching. Produced
`eds_claude_extraction_results.csv`. Notebooks/scripts numbered in run order; see
`eds_forms/README.md`.

- `01_batch_pdf_files.R` — batch PDFs for extraction runs.
- `02_eds_extraction_claude.ipynb` — main pipeline (render → submit batch → retrieve → JSON).
- `03_check_batch_status.py` — poll batch status.
- `04_fix_raw_responses.ipynb` — reparse responses that failed to parse.
- `05_eds_json_to_dataframe.ipynb` — aggregate per-form JSON → results CSV.
- `06_aggregate_jsons.R` — combine per-form JSON → tabular dataset.
- `07_parse_admin_data.R` — parse admin data; aggregate by EDS number, agency, vendor.

## 4. Measurement (`measurement/`)

- `sow_transform.R` — split each contract's `description_of_work` into sentences and
  generate 768-dim embeddings (`all-mpnet-base-v2` via `reticulate`) →
  `sow_sentence_embeddings.parquet` + metadata.

## Misc (`misc/`)

`firstpage_PDF.R`, `pdf_to_jpeg.R` (PDF utilities); `aws_config.ipynb`,
`Textract_PostProcessing.ipynb` (Textract).

## Testing / superseded (`testing/`)

Extractors evaluated but not adopted, kept for reproducibility of the comparison.

- `form_processing/` — Donut (`donut_eds_adapter_V1.ipynb`), GPT-4o mini, Textract paths,
  and an OpenCV+Donut hybrid design (see the two `README_*.md`).
- `paddleocr_form_extractor.ipynb`, `aggregate_textract_results.R`, `tutorials/`,
  `scraps/` (the broad bake-off: GPT, DeepSeek, LayoutLM, classifiers).

## Data flow

```
scraping/01–03  →  data/raw/indiana_contracts.* + _contracts/*.pdf
preprocessing   →  EDS page per contract
information_extraction/eds_forms →  eds_claude_json_production/*.json → eds_claude_extraction_results.csv
measurement/sow_transform.R    →  sow_sentence_embeddings.parquet
```
