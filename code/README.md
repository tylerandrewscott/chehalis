# Code Directory Documentation

This directory contains scripts for the Chehalis project, focusing on contract data scraping, information extraction, and analysis.

## Directory Structure

```
code/
├── information_extraction/     # Scripts for extracting information from contracts
│   ├── loc/                   # Location-related processing
│   └── tutorials/             # Tutorial notebooks and examples
├── misc/                      # Miscellaneous utilities and tools
└── scraping/                  # Web scraping and data collection scripts
    └── scraps/               # Temporary/experimental scraping code
```

## Scripts Overview

### Scraping (`/scraping`)

#### **post_indiana_api.ipynb**
- Scrapes contract data from Indiana state government API
- Supports incremental updates (CLOBBER=False) or complete refresh (CLOBBER=True)
- Saves data to JSON files:
  - `indiana_contracts.json` - All contracts
  - `indiana_prof_services_contracts.json` - Professional services contracts only

#### **download_contract_pdfs.ipynb**
- Downloads PDF files for contracts scraped by `post_indiana_api.ipynb`
- Handles batch downloading with error recovery

#### **indiana_json_to_csv.ipynb**
- Converts scraped JSON contract data to CSV format for analysis

#### **dockertry.R**
- R script for Docker-based processing experiments

### Information Extraction (`/information_extraction`)

#### **parse_admin_data.R**
- Parses and analyzes administrative contract data
- Aggregates contracts by EDS number, agency, and vendor
- Calculates renewal and amendment statistics

#### **aggregate_jsons.R**
- Aggregates multiple JSON files containing extracted contract information

#### **batch_pdf_files.R**
- Batch processes PDF files for information extraction

#### **gpt_on_contracts.ipynb**
- Uses GPT models to extract structured information from contract PDFs

#### **gpt_on_forms.ipynb**
- Uses GPT models to extract structured information from form PDFs

#### **ocr_contract_docs.ipynb**
- OCR processing for contract documents

#### **zeroshot_form_or_contract.ipynb**
- Zero-shot classification to determine if a document is a form or contract

#### **zeroshot_profservices.ipynb**
- Zero-shot classification for professional services contracts

#### **donut.ipynb**
- Document understanding transformer (Donut) model experiments

#### **read_jsons.ipynb**
- Utilities for reading and exploring extracted JSON data

### Miscellaneous (`/misc`)

#### **pdf_to_jpeg.R**
- Converts PDF pages to JPEG images for processing

#### **firstpage_PDF.R**
- Extracts the first page of PDF documents

#### **aws_config.ipynb**
- AWS configuration for cloud-based processing

#### **Textract_PostProcessing.ipynb**
- Post-processing for AWS Textract OCR results

#### **Template_Textract_PostProcessing.ipynb**
- Template for Textract post-processing workflows

### Tutorials (`/information_extraction/tutorials`)

#### **donut.ipynb**
- Tutorial for using the Donut model

#### **Textract_PostProcessing.ipynb**
- Tutorial for AWS Textract post-processing

## Data Flow

1. **Scraping**: Use `post_indiana_api.ipynb` to collect contract metadata
2. **Download**: Use `download_contract_pdfs.ipynb` to fetch PDF files
3. **Extract**: Use scripts in `/information_extraction` to extract structured data
4. **Analyze**: Use `parse_admin_data.R` for statistical analysis

## Key Features

- **Incremental Updates**: The scraping system supports updating existing data without re-downloading everything
- **Multiple Formats**: Data can be processed as JSON, CSV, or directly from PDFs
- **Cloud Integration**: AWS Textract integration for scalable OCR processing
- **ML Models**: Zero-shot classification and document understanding models

## Usage Notes

- Set `CLOBBER = False` in `post_indiana_api.ipynb` for incremental updates
- Check `.ipynb_checkpoints` directories are excluded from version control
- Ensure proper AWS credentials are configured before using Textract features