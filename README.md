# chehalis

**Applying computational social science to government contracting.**

An end-to-end pipeline over **Indiana state contracting data**: scrape the state's
contract API, download contract PDFs, extract structured fields from the standardized
**EDS forms** (Executive Document Summary — the cover page on every state contract), and
produce analysis-ready datasets.

## Pipeline

1. **Scrape** — pull contract metadata from the Indiana API → JSON/CSV (`code/scraping`).
2. **Download** — fetch each contract PDF into `data/raw/_contracts/`.
3. **Extract** — read structured fields off the first-page EDS form. The **Claude Batch
   API** system (`code/information_extraction/eds_forms`) is production and produced the
   full-corpus results; GPT-4o, Textract, PaddleOCR, LayoutLMv3, and Donut were evaluated
   but not adopted (`code/testing`).
4. **Measure** — turn extracted text into features, e.g. SOW sentence embeddings
   (`code/measurement`).

## Layout

```
code/                       # all pipeline code — see code/README.md
data -> Box/chehalis/data   # symlink, NOT in git — see data/README.md
output/                     # small committed sample extraction outputs
```

## Data

`data/` is a **symlink into Box** (`~/Library/CloudStorage/Box-Box/chehalis/data`), not
tracked in git — the corpus is tens of GB. Recreate it on a fresh clone with:

```bash
./setup_symlinks.sh                 # or: ./setup_symlinks.sh /path/to/box/chehalis/data
```

## Setup

- **R** — open `chehalis.Rproj`; scripts use `here::here()` for paths.
- **Python** — extraction needs `anthropic`, `pandas`, `pdf2image`/`pymupdf`, and
  `poppler-utils`; see `code/information_extraction/eds_forms/requirements.txt`.
- **Credentials** — `ANTHROPIC_API_KEY` for Claude; AWS credentials for Textract.

## Status

EDS extraction is solved and run end-to-end
(`data/intermediate_products/eds_claude_extraction_results.csv`). Current work is
measurement/analysis on top of those results (`code/measurement/sow_transform.R`).
