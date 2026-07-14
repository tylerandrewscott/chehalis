#!/usr/bin/env python3
"""
Batch Status Checker for Key Person(s) clause extraction.

Copy of code/information_extraction/eds_forms/03_check_batch_status.py.

Usage:
    python 05_check_batch_status.py <batch_id>

Displays a Claude Batch API job's status, request counts, and completion %.
Reads the API key from <repo-root>/.claude_key or ANTHROPIC_API_KEY (config.py).
"""

import sys
import anthropic

import config as C


def check_batch_status(batch_id: str):
    """Check and display batch status."""
    try:
        api_key = C.read_api_key()
    except RuntimeError as e:
        print(f"ERROR: {e}")
        sys.exit(1)

    client = anthropic.Anthropic(api_key=api_key)

    try:
        batch = client.messages.batches.retrieve(batch_id)

        print("=" * 60)
        print(f"BATCH STATUS: {batch_id}")
        print("=" * 60)
        print(f"\nStatus: {batch.processing_status}")
        print(f"Created: {batch.created_at}")

        if batch.ended_at:
            print(f"Ended: {batch.ended_at}")

        print("\nRequest Counts:")
        print(f"  Succeeded:  {batch.request_counts.succeeded}")
        print(f"  Processing: {batch.request_counts.processing}")
        print(f"  Errored:    {batch.request_counts.errored}")
        print(f"  Canceled:   {batch.request_counts.canceled}")
        print(f"  Expired:    {batch.request_counts.expired}")

        total = (batch.request_counts.succeeded +
                 batch.request_counts.processing +
                 batch.request_counts.errored +
                 batch.request_counts.canceled +
                 batch.request_counts.expired)

        if total > 0:
            completion_pct = (batch.request_counts.succeeded / total) * 100
            print(f"\nCompletion: {completion_pct:.1f}%")

        if batch.processing_status == 'in_progress':
            print("\nBatch is still processing. Check back later!")
            print("Batch processing typically completes within 24 hours.")
        elif batch.processing_status == 'ended':
            print("\nBatch complete! You can now retrieve results.")
        elif batch.processing_status == 'canceling':
            print("\nBatch is being canceled.")
        elif batch.processing_status == 'expired':
            print("\nBatch has expired. You may need to resubmit.")

        print("=" * 60)

    except anthropic.NotFoundError:
        print(f"ERROR: Batch {batch_id} not found.")
        print("Check that you have the correct batch ID.")
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)


def main():
    if len(sys.argv) != 2:
        print("Usage: python 05_check_batch_status.py <batch_id>")
        print("\nExample:")
        print("  python 05_check_batch_status.py msgbatch_01ABC123XYZ")
        sys.exit(1)

    check_batch_status(sys.argv[1])


if __name__ == '__main__':
    main()
