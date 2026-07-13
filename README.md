# chehalis

**Applying computational social science to government contracting.**

This project builds an end-to-end pipeline over **Indiana state contracting data**: it
scrapes the state's contract API, downloads the underlying contract PDFs, extracts
structured fields from the standardized **EDS forms** (Executive Document Summary — the
cover page attached to every state contract), and produces analysis-ready datasets for
downstream computational social science research.

## Pipeline overview

```
  Indiana API                 Contract PDFs              EDS form extraction            Measurement / analysis
 ┌─────────────┐   scrape    ┌──────────────┐  download ┌────────────────────┐  embed  ┌──────────────────────┐
 │ post API,   │ ─────────▶  │ _contracts/  │ ────────▶ │ Claude Batch API   │ ──────▶ │ SOW sentence         │
 │ JSON → CSV  │             │  *.pdf        │           │ → structured JSON  │         │ embeddings, clusters │
 └─────────────┘             └──────────────┘           └────────────────────┘         └──────────────────────┘
   code/scraping              data/raw/_contracts         code/information_extraction     code/measurement
```

1. **Scrape** — pull contract metadata from the Indiana state API, save as JSON/CSV.
2. **Download** — fetch the contract PDF for each record.
3. **Extract** — read structured fields off the first-page EDS form of each contract.
   Several extraction engines were evaluated (GPT-4o, AWS Textract, PaddleOCR,
   LayoutLMv3, Donut); the **Claude Batch API** approach is the production system and
   produced the full-corpus results.
4. **Measure / analyze** — transform extracted text (e.g. sentence-level embeddings of
   the scope-of-work description) into features for statistical and ML analysis.

## Repository layout

```
chehalis/
├── README.md                   # this file
├── LICENSE
├── chehalis.Rproj              # RStudio project
├── setup_symlinks.sh           # recreates the data/ symlink into Box (see below)
├── .gitignore
├── code/                       # all pipeline code — see code/README.md
│   ├── scraping/               #   1. collect data from the Indiana API
│   ├── preprocessing/          #      form/contract classification, embeddings
│   ├── information_extraction/ #   3. EDS form field extraction (Claude — production)
│   ├── measurement/            #   4. feature construction (SOW embeddings)
│   ├── misc/                   #      PDF/image utilities, AWS config
│   └── testing/                #      superseded extractors (Donut, Textract, PaddleOCR, GPT-4o)
├── data -> Box/chehalis/data   # symlink; NOT in git — see data/README.md
└── output/                     # small committed sample extraction outputs
    ├── donut_testing/          #   Donut adapter sample JSON
    └── gpt4o_testing/          #   GPT-4o sample JSON
```

## Data

`data/` is a **symlink into Box** (`~/Library/CloudStorage/Box-Box/chehalis/data`) and is
**not tracked in git** — the corpus is tens of GB of PDFs and derived files. See
[`data/README.md`](data/README.md) for the layout of `raw/`, `intermediate_products/`,
and the schema of the extraction results.

If the `data/` symlink is missing (fresh clone, or a machine where Box lives elsewhere),
recreate it:

```bash
./setup_symlinks.sh
# or, with an explicit path:
./setup_symlinks.sh /path/to/box/chehalis/data
```

## Setup

- **R** — open `chehalis.Rproj` in RStudio. R scripts use `here::here()` for
  project-relative paths, so run them with the project as the working directory.
- **Python** — extraction notebooks need `anthropic`, `pandas`, `pdf2image`/`pymupdf`,
  and `poppler-utils`. The Claude extraction system has its own `requirements.txt` in
  `code/information_extraction/claude/`.
- **Credentials** — set `ANTHROPIC_API_KEY` for Claude extraction; configure AWS
  credentials for the Textract path (`code/misc/aws_config.ipynb`).

## Status

The EDS extraction problem is **solved and run end-to-end**: the full-corpus results live
in `data/intermediate_products/eds_claude_extraction_results.csv`. The current frontier is
**measurement/analysis** on top of those results — see `code/measurement/sow_transform.R`,
which produces sentence-level embeddings of each contract's scope-of-work text for
downstream clustering and similarity analysis.
