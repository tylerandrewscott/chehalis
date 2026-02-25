# EDS Form Data Extraction System

A cost-optimized system for extracting structured data from ~40,000 Executive Document Summary (EDS) forms using Claude's Batch API with prompt caching.

## Features

- ✅ **Batch API Processing**: 50% cost savings with 24-hour processing
- ✅ **Prompt Caching**: 90% savings on repeated system prompts
- ✅ **Hybrid Extraction**: Main text extraction + targeted checkbox detection
- ✅ **Dual Modes**: Test mode (single PDFs) and Production mode (multi-page PDFs with metadata)
- ✅ **Clobber Toggle**: Skip already-processed files or reprocess everything
- ✅ **Individual JSON Output**: One JSON file per form for fault tolerance

## Cost Estimate

For 40,000 forms using Claude Haiku 4.5:
- **Estimated total cost: ~$72** (with batch discount + prompt caching)
- **Cost per form: ~$0.0018**

Compare to without optimizations: ~$288

## Setup

### 1. Install Dependencies

```bash
pip install anthropic pandas pdf2image pillow
```

You'll also need `poppler-utils` for PDF processing:
- **Ubuntu/Debian**: `sudo apt-get install poppler-utils`
- **macOS**: `brew install poppler`
- **Windows**: Download from https://github.com/oschwartz10612/poppler-windows

### 2. Set Your API Key

Get your API key from https://console.anthropic.com/

In the notebook, set:
```python
import os
os.environ['ANTHROPIC_API_KEY'] = 'your-api-key-here'
```

Or set as environment variable:
```bash
export ANTHROPIC_API_KEY='your-api-key-here'
```

### 3. Organize Your Files

#### For Testing (single-page PDFs):
```
project/
├── eds_extraction.ipynb
├── test_forms/
│   ├── 83501-000.pdf
│   ├── 83502-000.pdf
│   └── ...
└── output_json/
```

#### For Production (multi-page PDFs):
```
project/
├── eds_extraction.ipynb
├── production_contracts/
│   ├── contract_001.pdf
│   ├── contract_002.pdf
│   └── ...
├── eds_metadata.csv
└── output_json/
```

The `eds_metadata.csv` should have columns:
```csv
filename,page_number
contract_001.pdf,5
contract_002.pdf,12
contract_003.pdf,3
...
```

## Usage

### Quick Start

1. Open `eds_extraction.ipynb` in Jupyter
2. Update the `CONFIG` section (cell 1):
   ```python
   CONFIG = {
       'api_key': os.environ.get('ANTHROPIC_API_KEY', ''),
       'mode': 'test',  # or 'production'
       'clobber': False,  # Set True to reprocess existing
       'test_dir': './test_forms',
       'production_dir': './production_contracts',
       'metadata_csv': './eds_metadata.csv',
       'output_dir': './output_json',
   }
   ```
3. Run all cells (or use "Run All")
4. Wait for batch to complete (~24 hours)

### Configuration Options

| Option | Description | Values |
|--------|-------------|--------|
| `mode` | Processing mode | `'test'` or `'production'` |
| `clobber` | Overwrite existing results | `True` or `False` |
| `model` | Claude model to use | `'claude-haiku-4-5-20251001'` or `'claude-sonnet-4-5-20250929'` |
| `test_dir` | Directory with single-page test PDFs | Path string |
| `production_dir` | Directory with multi-page contract PDFs | Path string |
| `metadata_csv` | CSV mapping files to EDS page numbers | Path string |
| `output_dir` | Where to save JSON results | Path string |

### Monitoring Progress

The notebook will display:
- Number of forms found
- Batch ID (save this!)
- Processing status updates every 5 minutes

You can close the notebook and check back later using:
```python
batch_id = "YOUR_BATCH_ID"
status = check_batch_status(client, batch_id)
print(status)
```

## Output Format

Each form produces a JSON file like:

```json
{
  "metadata": {
    "source_file": "/path/to/contract_001.pdf",
    "page_number": 5,
    "extracted_at": "2025-11-26T10:30:00",
    "model": "claude-haiku-4-5-20251001"
  },
  "extracted_data": {
    "EDS_Number": "A70-5-008060",
    "Date_prepared": "12/9/2014",
    "Agency_name": "Department of Health",
    "Vendor_name": "Indiana Minority Health Coalition",
    "Contract_amount": "$65,000.00",
    "contract_type_info": {
      "contract_type": "Grant",
      "confidence": "high"
    },
    "checkbox_fields": {
      "vendor_registered": "yes",
      "renewal_language": "yes",
      "termination_clause": "yes",
      "vendor_status": {
        "minority": "yes",
        "minority_percentage": "100.0",
        "women": "no",
        "in_veteran": "no"
      }
    }
  }
}
```

## How It Works

### Hybrid Extraction Approach

Each form is processed with 3 targeted queries:

1. **Main Extraction**: Text-based fields (names, dates, amounts, descriptions)
2. **Contract Type Detection**: Identifies which contract type checkbox is marked
3. **Yes/No Fields**: Extracts all binary selections and vendor status percentages

This targeted approach improves accuracy on the problematic checkbox fields while keeping costs low.

### Batch API Processing

- All requests are submitted as a single batch
- Processing happens asynchronously over ~24 hours
- Automatic 50% discount on all tokens
- Results are retrieved when complete

### Prompt Caching

- System prompts are cached after first use
- 90% cost reduction on cached tokens
- Especially effective for processing many similar forms
- Cache persists for 5 minutes (long enough for batch processing)

## Troubleshooting

### "No forms to process"
- Check that your directories exist and contain PDF files
- Verify `mode` is set correctly ('test' or 'production')
- If `clobber=False`, check if output files already exist

### "ANTHROPIC_API_KEY not set"
- Make sure you've set the API key in the notebook or as environment variable
- Verify the key is valid at https://console.anthropic.com/

### PDF conversion errors
- Ensure `poppler-utils` is installed
- Check that PDF files are not corrupted
- Verify page numbers in metadata CSV are correct

### Batch taking too long
- Batches process within 24 hours (usually much faster)
- Check status with `check_batch_status(client, batch_id)`
- Results appear in output directory as batch completes

### Poor extraction quality
- Try upgrading to Claude Sonnet 4.5 (change `model` in config)
- Review prompt templates and adjust for your specific forms
- Check that image quality is sufficient (DPI=200 is used by default)

## Cost Optimization Tips

1. **Start with Haiku**: Test with Claude Haiku 4.5 first (~$72 for 40k forms)
2. **Use Batch API**: Always use batch processing for 50% savings
3. **Enable Caching**: System prompts are automatically cached
4. **Process in Bulk**: Larger batches maximize caching benefits
5. **Upgrade Selectively**: If Haiku struggles, upgrade specific query types to Sonnet

## Scaling Beyond 40k Forms

The system is designed to handle much larger datasets:
- Batch API has no hard size limits
- Individual JSON files prevent data loss
- Resume processing with `clobber=False`
- Process in chunks if needed (update metadata CSV)

## Next Steps

After extraction, you can:
1. **Aggregate to Database**: Load all JSON files into SQL/MongoDB
2. **Quality Analysis**: Check confidence scores and review unclear results
3. **Iterate on Prompts**: Refine extraction for specific problematic fields
4. **Scale Up**: Process full 40k dataset once satisfied with test results

## Support

For issues with:
- **Claude API**: https://docs.anthropic.com/
- **Batch Processing**: https://docs.anthropic.com/en/docs/build-with-claude/message-batches
- **This Notebook**: Review the inline comments and documentation

## License

This notebook is provided as-is for processing EDS forms. Adjust as needed for your specific use case.
