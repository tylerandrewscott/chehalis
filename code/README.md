# Code

All pipeline code for the chehalis project, organized by pipeline stage. Most work is in
Jupyter notebooks (Python) with R scripts for data aggregation, measurement, and analysis.

```
code/
├── scraping/              1. Collect contract data from the Indiana state API
├── preprocessing/         2. Classify pages (form vs contract), build embeddings
├── information_extraction/ 3. Extract structured fields from EDS forms
│   └── claude/               → production extraction system (Claude Batch API)
├── measurement/           4. Feature construction from extracted text (SOW embeddings)
├── misc/                     PDF/image utilities, AWS config
└── testing/                 Superseded / evaluated-but-not-adopted extraction engines
                             (Donut, GPT-4o mini, Textract, PaddleOCR, exploratory scraps)
```

> **Note on `testing/`, `scraps/`, `scratch/`:** the extraction stage went through a
> bake-off of several engines before **Claude** was adopted for production. The also-rans
> and exploratory notebooks live under `testing/` so the live pipeline stays easy to read.
> Within any stage, `scraps/`/`scratch/` subfolders likewise hold superseded work kept for
> reference.

---

## 1. Scraping (`scraping/`)

Collects raw contract metadata and PDFs from the Indiana state contract system. Notebooks
are numbered in run order:

- **`01_post_indiana_api.ipynb`** — queries the Indiana state contract API and saves
  results as JSON. Supports incremental updates (`CLOBBER=False`) or full refresh
  (`CLOBBER=True`). Writes `indiana_contracts.json` (all) and
  `indiana_prof_services_contracts.json` (professional services only).
- **`02_download_contract_pdfs.ipynb`** — downloads the PDF for each scraped contract
  into `data/raw/_contracts/`, with batch handling and error recovery.
- **`03_indiana_json_to_csv.ipynb`** — flattens the scraped JSON into CSV for analysis.
- **`scraps/`** — `scrape_indiana.js` (Selenium/JS scraper) and `dockertry.R`
  (Docker-based processing experiment).

## 2. Preprocessing (`preprocessing/`)

Classification and embedding steps that run between scraping and extraction — mainly
deciding **which page of a multi-page contract is the EDS form**.

- **`zero_shot_classifier_clean.ipynb`** — zero-shot classification of pages as
  form vs. contract.
- **`zero_shot_renewal_classifier.ipynb`** — flags renewal/amendment documents.
- **`cached_embeddings/`** — precomputed reference embeddings (`clip_reference_embeddings.pkl`,
  `donut_reference_embeddings.pkl`) used for similarity-based page matching.
- Result CSVs (`zero_shot_results_full_corpus.csv`, `zero_shot_test_results.csv`) and
  `scraps/` with earlier CLIP / parallel classifier experiments.

## 3. Information extraction (`information_extraction/`)

Extracts structured fields from the first-page EDS form of each contract. This stage saw
the most iteration — several engines were evaluated before settling on Claude.

### `claude/` — **production extraction system**

Cost-optimized extraction of the full ~40k-form corpus using the **Claude Batch API** with
prompt caching (~50% batch discount + ~90% cache savings). This is the system that
produced `data/intermediate_products/eds_claude_extraction_results.csv`.

- **`eds_extraction_claude.ipynb`** — main pipeline: renders EDS pages, submits batches,
  retrieves results, writes one JSON per form. Test mode (single-page PDFs) and production
  mode (multi-page contracts + page-number metadata CSV).
- **`eds_json_to_dataframe.ipynb`** — aggregates the per-form JSON into the results CSV.
- **`fix_raw_responses.ipynb`** — repairs/reparses raw model responses that failed to parse.
- **`check_batch_status.py`** — CLI to poll batch job status.
- **`README.md`**, **`QUICKSTART.md`**, **`BATCH_TRACKING_SYSTEM.md`** — setup, cost
  estimates, and the `batch_registry.json` system that prevents re-querying PDFs already
  in a pending batch.

### Aggregation & admin (top level of `information_extraction/`)

- **`aggregate_jsons.R`** — combines per-form JSON into a tabular dataset.
- **`parse_admin_data.R`** — parses administrative contract data; aggregates by EDS number,
  agency, and vendor; computes renewal/amendment statistics.
- **`batch_pdf_files.R`** — batches PDFs for extraction runs.

## 4. Measurement (`measurement/`)

Turns extracted text into analysis features.

- **`sow_transform.R`** — reads `eds_claude_extraction_results.csv`, splits each contract's
  `description_of_work` into sentences, and generates **768-dim sentence embeddings**
  (`sentence-transformers/all-mpnet-base-v2` via `reticulate`). Outputs
  `sow_sentence_embeddings.parquet` + `sow_sentence_metadata.csv`. Sentence-level
  granularity supports downstream mean/variance, pairwise-distance, and clustering analyses.

## Misc (`misc/`)

- **`firstpage_PDF.R`** — extracts the first page of PDFs.
- **`pdf_to_jpeg.R`** — converts PDF pages to JPEG.
- **`aws_config.ipynb`** — AWS credentials/config for Textract.
- **`Textract_PostProcessing.ipynb`**, **`Template_Textract_PostProcessing.ipynb`** —
  Textract OCR post-processing.
- **`scratch_descripives.R`** (in `code/`) — scratch descriptive statistics.

## Testing / superseded extraction (`testing/`)

Extraction engines that were **evaluated but not adopted** for the production run — kept
for reference and reproducibility of the comparison. Claude (in
`information_extraction/claude/`) was the engine ultimately used on the full corpus.

- **`form_processing/`** — the main alternative extractors:
  - `donut_eds_adapter_V1.ipynb` — production-tuned **Donut** adapter (query reduction +
    strict anti-hallucination validation); see `README_donut_adapter.md`.
  - `gpt4o_mini_eds_extractor.ipynb` — **GPT-4o mini** extractor.
  - `textract_eds_adapter.ipynb`, `textract_eds_textblurbs.ipynb` — **AWS Textract** paths.
  - `README_HYBRID_APPROACH.md` — OpenCV (checkboxes) + Donut (text) hybrid design.
  - `scratch/` — earlier Donut adapter versions and the OpenCV hybrid notebook.
- **`paddleocr_form_extractor.ipynb`** — **PaddleOCR** extraction path.
- **`aggregate_textract_results.R`** — aggregates Textract per-form output.
- **`tutorials/`** — reference tutorials for the superseded methods (`donut.ipynb`,
  `Textract_PostProcessing.ipynb`).
- **`scraps/`** — the broad extraction bake-off: GPT, DeepSeek, Textract, Donut, LayoutLM,
  zero-shot form/contract classifiers, and detection-failure debugging notebooks.

---

## Typical data flow

```
scraping/01–03  →  data/raw/indiana_contracts.* + data/raw/_contracts/*.pdf
preprocessing   →  identify EDS page per contract
information_extraction/claude  →  data/intermediate_products/eds_claude_json_production/*.json
                               →  eds_claude_extraction_results.csv
measurement/sow_transform.R    →  sow_sentence_embeddings.parquet (+ metadata)
```

Paths in R scripts are resolved with `here::here()`; run from the RStudio project root.
