# EDS Form Extractor — Hybrid OpenCV + Donut

> **Superseded.** Evaluated but not adopted; production uses the Claude Batch API
> (`code/information_extraction/eds_forms`). Kept for reference.

OpenCV for checkbox detection (deterministic, ~95%) + Donut for text fields (~85%).
Notebook: `scratch/donut_opencv_hybrid_complete.ipynb`.

```
PDF → OpenCV (checkboxes) ─┐
                           ├→ structured JSON
PDF → Donut (text fields) ─┘
```

## Setup

```bash
pip install transformers torch pillow pymupdf opencv-python numpy pandas tqdm
```

Set `INPUT_DIR`/`OUTPUT_DIR` in Section 1 and run all cells. GPU ~50 s/form; CPU ~10 min.

## Checkbox calibration

Coordinates in `CHECKBOX_COORDINATES` are calibrated for **300 DPI** (scale
proportionally if you change `DPI`). To align:

1. Set `DEBUG_VISUALIZE_CHECKBOXES = True` and run one form (Section 10, single-file test).
2. Open `{filename}_checkbox_viz.png` — green = checked, red = unchecked.
3. Adjust the `(x, y)` coordinates until boxes are centered, then re-run.

Tune `CHECKBOX_DARK_THRESHOLD` (default 0.15): raise it for false positives, lower it for
false negatives. `CHECKBOX_SIZE` is the region checked around each point.

Detection logic: extract the region around each coordinate, count dark pixels
(intensity < 127); if the dark fraction exceeds the threshold, the box is checked.

## Output

Per PDF: `{filename}.json` (+ `_checkbox_viz.png` if debug). Combined:
`extracted_data.csv` / `.json`. Checkbox fields are booleans; text fields include
`raw_text_qa_pairs` for debugging Donut responses.

## Common failure modes

- All boxes unmarked → coordinates misaligned, or threshold too high.
- All boxes marked → threshold too low, or noisy scan; try a different DPI.
- Text errors → inspect `raw_text_qa_pairs`; adjust query phrasing/validation.
- OOM → process one file at a time or lower DPI; confirm GPU with `torch.cuda.is_available()`.
