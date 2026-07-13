# Donut EDS Adapter

> **Superseded.** Evaluated but not adopted; production uses the Claude Batch API
> (`code/information_extraction/eds_forms`). Kept for reference.

Donut-based extractor (`donut_eds_adapter_V1.ipynb`) tuned for speed and against
hallucination. ~30 queries/form (down from ~45), ~55 s/form on GPU (2–3 min CPU).

## Anti-hallucination

Every query ends with "if not found, answer 'not found'", and responses pass strict
validation (`is_not_found()`, `is_likely_hallucinated()`, field-specific validators for
dates/amounts/EDS numbers). Rejected: generic phrasing ("approximately", "estimated"),
overly long or descriptive responses, and out-of-range values (dates before 1990,
negative amounts). Fields that fail validation become `null`; rejections are recorded in
`validation_flags`.

## Configuration

```python
TESTING_MODE = True   # test on a few examples first; set False for production
VERBOSE = False
DPI = 300             # 200 for speed
ENABLE_STRICT_VALIDATION = True
CHECKBOX_CONFIDENCE_THRESHOLD = 0.7
```

## Usage

1. Add PDFs to `../../data/raw/_exampleforms/`
2. Run all cells
3. Results in `../../data/intermediate_products/eds_forms_donut_testing_optimized/`
4. Review `validation_flags`; if satisfied, set `TESTING_MODE = False`

## Output

```json
{
  "structured_data": {
    "eds_number": "01-DGP-TP1",         // or null
    "date_prepared": "2021-07-23",
    "contract_info": { "grant": true, "professional_personal_services": false },
    "fiscal": {
      "amount_this_action": 195000.0,
      "amounts_by_year": [ { "year": 2021, "amount": 195000.0 } ]
    },
    "vendor": {}, "time_period": {}, "source_selection": {}
  },
  "validation_flags": []                // empty = clean; non-empty lists rejected responses
}
```

Fields are `null` when not found, rejected as hallucinated, or out of range.

## Troubleshooting

- **Too many nulls** — inspect `raw_qa_pairs` for actual responses; raise DPI or loosen
  validation patterns.
- **Bad data slipping through** — check `validation_flags`, add patterns to
  `is_likely_hallucinated()`, raise `CHECKBOX_CONFIDENCE_THRESHOLD`.
- **Too slow** — lower DPI to 200, smaller batches, use GPU.
