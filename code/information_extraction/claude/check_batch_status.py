#!/usr/bin/env python3
"""
Batch Status Checker for EDS Form Extraction

Usage:
    python check_batch_status.py <batch_id>

This script checks the status of a Claude Batch API job and displays:
- Current processing status
- Request counts (succeeded, processing, errored)
- Estimated completion time

Set your ANTHROPIC_API_KEY environment variable before running.
"""

import sys
import os
from datetime import datetime
import anthropic


def check_batch_status(batch_id: str):
    """Check and display batch status."""
    
    # Get API key
    api_key = os.environ.get('ANTHROPIC_API_KEY')
    if not api_key:
        print("ERROR: ANTHROPIC_API_KEY environment variable not set!")
        print("Set it with: export ANTHROPIC_API_KEY='your-key-here'")
        sys.exit(1)
    
    # Initialize client
    client = anthropic.Anthropic(api_key=api_key)
    
    try:
        # Get batch info
        batch = client.messages.batches.retrieve(batch_id)
        
        # Display status
        print("=" * 60)
        print(f"BATCH STATUS: {batch_id}")
        print("=" * 60)
        print(f"\nStatus: {batch.processing_status}")
        print(f"Created: {batch.created_at}")
        
        if batch.ended_at:
            print(f"Ended: {batch.ended_at}")
        
        print("\nRequest Counts:")
        print(f"  ✓ Succeeded:  {batch.request_counts.succeeded}")
        print(f"  ⏳ Processing: {batch.request_counts.processing}")
        print(f"  ✗ Errored:    {batch.request_counts.errored}")
        print(f"  ⊗ Canceled:   {batch.request_counts.canceled}")
        print(f"  ⌛ Expired:    {batch.request_counts.expired}")
        
        total = (batch.request_counts.succeeded + 
                 batch.request_counts.processing + 
                 batch.request_counts.errored + 
                 batch.request_counts.canceled + 
                 batch.request_counts.expired)
        
        if total > 0:
            completion_pct = (batch.request_counts.succeeded / total) * 100
            print(f"\nCompletion: {completion_pct:.1f}%")
        
        # Status-specific messages
        if batch.processing_status == 'in_progress':
            print("\n⏳ Batch is still processing. Check back later!")
            print("Batch processing typically completes within 24 hours.")
        elif batch.processing_status == 'ended':
            print("\n✓ Batch complete! You can now retrieve results.")
            print("Use the retrieve_batch_results() function in the notebook.")
        elif batch.processing_status == 'canceling':
            print("\n⚠️  Batch is being canceled.")
        elif batch.processing_status == 'expired':
            print("\n⌛ Batch has expired. You may need to resubmit.")
        
        print("=" * 60)
        
    except anthropic.NotFoundError:
        print(f"ERROR: Batch {batch_id} not found.")
        print("Check that you have the correct batch ID.")
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)


def main():
    """Main entry point."""
    if len(sys.argv) != 2:
        print("Usage: python check_batch_status.py <batch_id>")
        print("\nExample:")
        print("  python check_batch_status.py msgbatch_01ABC123XYZ")
        sys.exit(1)
    
    batch_id = sys.argv[1]
    check_batch_status(batch_id)


if __name__ == '__main__':
    main()
