# Batch Tracking System

## Overview

The notebook now has a **centralized batch registry** that tracks all batch submissions and prevents redundant API calls. This system ensures you never re-query PDFs that are already in pending batches.

## How It Works

### 1. Central Registry (`batch_registry.json`)

Located in your output directory, this file tracks:
- **All batches**: Batch IDs, status, creation time, and which PDFs they contain
- **PDF-to-batch mapping**: Quick lookup to check if a PDF is in any batch

**Structure:**
```json
{
  "batches": {
    "msgbatch_ABC123": {
      "batch_file": "batch_20251205_120000_part1.jsonl",
      "timestamp": "20251205_120000",
      "status": "ended",
      "created_at": "2025-12-05T12:00:00",
      "num_requests": 489,
      "num_forms": 163,
      "pdfs": [
        {
          "pdf_path": "/path/to/file.pdf",
          "page_num": 1,
          "form_id": "file_p1"
        }
      ]
    }
  },
  "pdf_to_batch": {
    "/path/to/file.pdf:1": "msgbatch_ABC123"
  }
}
```

### 2. Automatic PDF Tracking

When you submit a batch:
1. ✅ Batch ID and PDF list are **immediately saved** to registry
2. ✅ Individual `.meta.json` files are created (legacy compatibility)
3. ✅ PDFs are marked as "in-batch"

When you scan for new PDFs to process:
1. ✅ Checks if PDF already has output JSON (respects `clobber` setting)
2. ✅ Checks if PDF is in a **pending batch** (not yet retrieved)
3. ✅ Only processes PDFs that meet neither condition

When you retrieve batch results:
- PDFs automatically become "processed" (output JSON exists)
- Registry stays intact for historical tracking

### 3. Key Functions

**Registry Management:**
- `load_batch_registry()` - Load the central registry
- `save_batch_registry(registry)` - Save registry to disk
- `register_batch(...)` - Register new batch with all metadata
- `is_pdf_in_pending_batch(pdf_path, page_num)` - Check if PDF is in unretrieved batch
- `get_pending_batches()` - Get list of batch IDs with unretrieved results

**Processing:**
- `get_forms_to_process()` - Now checks registry to skip PDFs in pending batches
- `submit_batch(...)` - Automatically registers batch in registry
- `submit_batches_chunked(...)` - Handles multi-batch submissions with registry tracking

## Workflow

### Normal Operation (Going Forward)

1. **Run pipeline** - Submits batch and registers it
2. **Wait for completion** - Batch processes on Anthropic servers
3. **Retrieve results** (cell-19) - Downloads and saves outputs
4. **Run pipeline again** - Automatically skips all processed and pending PDFs

### Handling Clobber

**`clobber = False` (default):**
- Skips PDFs with existing output JSON files
- Skips PDFs in pending batches
- Only processes truly new PDFs

**`clobber = True`:**
- Re-processes PDFs **even if output exists**
- Still skips PDFs in pending batches (avoids redundant API calls)
- Useful for re-running with different prompts/models

## Migration from Old Batches

For your 37 old batches (now matched with cell-17):
- They're **not in the registry** (created before registry existed)
- Cell-19 will still retrieve them using `.meta.json` files
- Once retrieved, their PDFs become "processed" via output JSONs
- Future runs automatically skip them

**Optional:** You can manually add them to the registry for complete tracking:
```python
# After retrieving old batch, optionally register it
register_batch(
    batch_id="msgbatch_...",
    batch_file="batch_20251205_010818_part1.jsonl",
    # ... other metadata
)
```

But this is **not necessary** - the system works fine without it.

## Benefits

✅ **No redundant API calls** - Never re-query PDFs already in batches
✅ **Resume-safe** - Can stop/start notebook without losing track
✅ **Clobber-aware** - Only affects final outputs, not batch tracking
✅ **Historical record** - Complete audit trail of all batches
✅ **Fast lookups** - O(1) check if PDF is in pending batch
✅ **Backwards compatible** - Still creates `.meta.json` files for old code

## Files Created

For each batch:
1. `batch_TIMESTAMP_partN.jsonl` - The batch request file
2. `batch_TIMESTAMP_partN.meta.json` - Individual batch metadata (legacy)
3. `batch_registry.json` - Central registry (shared across all batches)

For each form:
- `formname_pN.json` - Final output (created on retrieval)

## Summary

You now have a **robust, production-ready** batch tracking system that:
- Prevents wasting money on duplicate API calls
- Tracks everything centrally
- Works seamlessly with `clobber` settings
- Maintains backwards compatibility

Just run your pipeline normally - the registry handles everything automatically!
