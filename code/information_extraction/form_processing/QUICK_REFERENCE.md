# Quick Reference: Old vs New Implementation

## At a Glance

### Old Approach
```
┌─────────────────────────────────┐
│   Load PDF Page as Image        │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│   Run 31 Queries in Sequence    │
│   - All queries mixed together  │
│   - No organization             │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│   Save Raw Q&A Pairs            │
│   {                             │
│     "query": "...",             │
│     "answer": "..."             │
│   }                             │
└─────────────────────────────────┘
```

### New Approach
```
┌─────────────────────────────────┐
│   Load PDF Page as Image        │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│   Pass 1: Basic ID (3 queries)  │
└────────────┬────────────────────┘
             ▼
┌─────────────────────────────────┐
│   Pass 2: Agency (3 queries)    │
└────────────┬────────────────────┘
             ▼
┌─────────────────────────────────┐
│   Pass 3: Contracts (12 queries)│
└────────────┬────────────────────┘
             ▼
         ... (8 passes total)
             │
             ▼
┌─────────────────────────────────┐
│   Post-Process & Normalize      │
│   - Parse currency              │
│   - Normalize dates             │
│   - Convert booleans            │
│   - Validate consistency        │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│   Save Structured Data          │
│   {                             │
│     "structured_data": {        │
│       "eds_number": "...",      │
│       "agency": {...},          │
│       "vendor": {...},          │
│       "fiscal": {...}           │
│     }                           │
│   }                             │
└─────────────────────────────────┘
```

---

## Key Changes Summary

| Aspect | Old | New |
|--------|-----|-----|
| **Query Organization** | 31 flat queries | 8 organized passes |
| **Query Style** | "EDS Number" | "What is the EDS Number?" |
| **Section References** | Sometimes | Always (e.g., "section 14") |
| **Output Format** | Raw Q&A pairs | Structured schema |
| **Data Types** | All strings | Typed (float, bool, date) |
| **Boolean Handling** | Raw text | Normalized True/False/None |
| **Currency** | String with $, commas | Clean float |
| **Dates** | Various formats | ISO format (YYYY-MM-DD) |
| **Validation** | None | Fiscal consistency checks |
| **Database Ready** | No | Yes |

---

## Example: Vendor Information Extraction

### Old Way
```json
{
  "queries_and_answers": [
    {
      "query": "Vendor ID #",
      "answer": "0000199605"
    },
    {
      "query": "Vendor Name",
      "answer": "<yes/>"  // ← Error!
    },
    {
      "query": "Is \"Yes\" checked for Primary Vendor: Minority:'?",
      "answer": "no"
    }
  ]
}
```

**Problems:**
- Vendor name extraction failed
- Need to parse boolean strings manually
- No structure for database insertion

### New Way
```json
{
  "structured_data": {
    "vendor": {
      "id": "0000199605",
      "name": "VALARI A KOZIEL",
      "telephone": "815-353-1168",
      "email": "valari.koziel@ssfhs.org",
      "address": "2408 BRUSH HILL CTR, JOLIET, IL 60432",
      "registered_with_sos": true,
      "minority_owned": false,
      "minority_percentage": null,
      "women_owned": false,
      "women_percentage": null
    }
  },
  "extraction_passes": {
    "pass4_vendor_info": {
      "What is the Vendor ID number from section 23?": "0000199605",
      "What is the Vendor Name from section 24?": "VALARI A KOZIEL",
      "Is Yes checked for Primary Vendor Minority in section 29?": "no"
    }
  }
}
```

**Benefits:**
- ✅ Structured vendor object
- ✅ All fields extracted in one pass
- ✅ Booleans normalized
- ✅ Ready for database INSERT
- ✅ Raw responses preserved for debugging

---

## Example: Fiscal Information

### Old Way
```json
{
  "queries_and_answers": [
    {
      "query": "Total amount this action:",
      "answer": "$24,578.00"  // ← String
    },
    {
      "query": "New contract total",
      "answer": "24,578.00"  // ← Different format
    }
  ]
}
```

### New Way
```json
{
  "structured_data": {
    "fiscal": {
      "account_number": "3610-15060",
      "account_name": "UNIVERSAL NEWBORN HEARING",
      "amount_this_action": 24578.0,  // ← Clean float
      "new_contract_total": 24578.0,
      "revenue_generated_this_action": 0.0,
      "revenue_generated_total": 0.0,
      "amounts_by_year": [],
      "validation_warnings": []  // ← Automatic validation
    }
  }
}
```

**Benefits:**
- ✅ Currency parsed to float
- ✅ Consistent data types
- ✅ Validation built-in
- ✅ Mathematical operations possible

---

## Query Formulation Best Practices

### ❌ Bad Queries (Old Style)
```python
"Vendor Name"
"Total amount this action:"
"Is 'Grant' checked in section 3?"
```

**Problems:**
- Too terse
- Inconsistent with section references
- Quotes make parsing harder

### ✅ Good Queries (New Style)
```python
"What is the Vendor Name from section 24?"
"What is the Total amount this action from section 6?"
"In section 3, is Grant checked?"
```

**Benefits:**
- Complete questions
- Section numbers for context
- Natural language
- Easier for model to understand

---

## Post-Processing Functions

### Boolean Normalization
```python
normalize_boolean_response("yes") → True
normalize_boolean_response("x") → True
normalize_boolean_response("checked") → True
normalize_boolean_response("no") → False
normalize_boolean_response("unchecked") → False
normalize_boolean_response("maybe") → None
```

### Currency Parsing
```python
parse_currency("$24,578.00") → 24578.0
parse_currency("24,578.00") → 24578.0
parse_currency("24578") → 24578.0
parse_currency("invalid") → None
```

### Date Normalization
```python
normalize_date("6/1/2006") → "2006-06-01"
normalize_date("June 1, 2006") → "2006-06-01"
normalize_date("6/1/06") → "2006-06-01"
normalize_date("invalid") → None
```

---

## Migration Path

If you have existing results from the old system:

1. **Keep old results** for comparison
2. **Run new system** on same documents
3. **Compare outputs** to measure improvement
4. **Spot check** high-value contracts manually
5. **Switch to new system** once validated

You can run both in parallel:
- Old output: `eds_forms_donut/`
- New output: `eds_forms_donut_improved/`

---

## When to Use Each Approach

### Use Old Approach If:
- ❌ You need quick prototyping
- ❌ Data quality isn't critical
- ❌ You won't integrate with a database

### Use New Approach If:
- ✅ You need production-quality data
- ✅ You're building a database
- ✅ You need data validation
- ✅ You want maintainable code
- ✅ You care about accuracy

**Recommendation:** Use the new approach. The small increase in complexity pays off dramatically in data quality.

---

## Quick Start

1. **Copy the improved notebook** to your environment
2. **Update configuration** (paths, filters)
3. **Run all cells**
4. **Check sample outputs** in OUTPUT_DIR
5. **Review summary statistics**

That's it! The new system handles all the complexity internally.
