# Quick Start Guide - EDS Form Extraction

Get started in 5 minutes!

## Step 1: Install Dependencies

```bash
pip install -r requirements.txt
```

Install poppler (for PDF processing):
- **Mac**: `brew install poppler`
- **Ubuntu**: `sudo apt-get install poppler-utils`
- **Windows**: Download from https://github.com/oschwartz10612/poppler-windows

## Step 2: Set API Key

```bash
export ANTHROPIC_API_KEY='your-api-key-here'
```

Get your key from: https://console.anthropic.com/

## Step 3: Organize Your Files

### For Testing:
```
project/
├── eds_extraction.ipynb
├── test_forms/          ← Put single-page PDF forms here
└── output_json/         ← Results will appear here
```

### For Production:
```
project/
├── eds_extraction.ipynb
├── production_contracts/       ← Multi-page contract PDFs
├── eds_metadata.csv           ← Maps files to page numbers
└── output_json/               ← Results will appear here
```

Create `eds_metadata.csv`:
```csv
filename,page_number
contract_001.pdf,5
contract_002.pdf,12
...
```

## Step 4: Configure and Run

Open `eds_extraction.ipynb` and update:

```python
CONFIG = {
    'mode': 'test',        # or 'production'
    'clobber': False,      # True to reprocess all
    'test_dir': './test_forms',
    'output_dir': './output_json',
}
```

Click "Run All" in Jupyter!

## Step 5: Wait for Results

- Batch processes in ~24 hours (usually faster)
- Check status: `python check_batch_status.py <batch_id>`
- Results save to `output_json/` as individual JSON files

## Cost for 40k Forms

- **Claude Haiku 4.5**: ~$72 total (~$0.0018 per form)
- Includes 50% batch discount + 90% prompt caching

## Troubleshooting

**No forms found?**
- Check directory paths in CONFIG
- Verify PDFs exist in correct location

**API key error?**
- Set: `export ANTHROPIC_API_KEY='key'`
- Or set in notebook: `os.environ['ANTHROPIC_API_KEY'] = 'key'`

**PDF errors?**
- Install poppler-utils
- Check PDF files aren't corrupted

## Output Format

Each form creates a JSON file:

```json
{
  "metadata": {
    "source_file": "contract.pdf",
    "page_number": 5
  },
  "extracted_data": {
    "EDS_Number": "A70-5-008060",
    "Vendor_name": "...",
    "Contract_amount": "$65,000.00",
    "contract_type_info": {
      "contract_type": "Grant"
    },
    "checkbox_fields": {
      "vendor_registered": "yes",
      ...
    }
  }
}
```

## What's Happening Behind the Scenes?

1. **Batch Submission**: All forms submitted as one batch
2. **Async Processing**: Claude processes over ~24 hours
3. **Smart Caching**: System prompts cached for 90% savings
4. **Targeted Extraction**: 3 queries per form (main + 2 checkbox queries)
5. **Individual Results**: Each form saved separately for fault tolerance

## Next Steps

1. Test with small batch (~10-100 forms)
2. Review output quality
3. Adjust prompts if needed
4. Scale to full 40k dataset

---

**Need more details?** See the full README.md
**Having issues?** Check batch status with `check_batch_status.py`
