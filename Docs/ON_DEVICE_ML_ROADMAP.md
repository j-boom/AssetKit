# On-Device ML Roadmap: Label Field Extraction

## Overview

This document outlines the path from heuristic-based label field extraction to a trained on-device ML model. The strategy uses three tiers of extraction, progressively falling back:

1. **Gemini Cloud Function** (current primary) -- highest accuracy, requires network
2. **On-Device ML Model** (future) -- fast, offline-capable, trained on our data
3. **Heuristic Parser** (current fallback) -- regex/hint-based, fragile with unfamiliar layouts

## 1. Data Collection Pipeline (Phase A -- Implemented)

Every time a user saves an asset through the capture flow, a `TrainingSample` is submitted to the backend. This captures:

### Recognition Ground Truth
- AI-predicted category, brand, manufacturer vs. user-confirmed values
- `userCorrectedCategory`, `userCorrectedBrand`, `userCorrectedManufacturer` booleans

### Label Extraction Ground Truth
- Raw OCR text from Apple Vision (`ocrRawText`)
- Structured OCR fields with bounding boxes (`ocrFields`)
- What the user actually typed/confirmed in the form:
  - `userFinalModelNumber`, `userFinalSerialNumber`
  - `userFinalManufacturer`, `userFinalBrand`
- Whether the user changed the extracted values:
  - `userCorrectedModelNumber`, `userCorrectedSerialNumber`, `userCorrectedOCRManufacturer`
- Which extraction method was used: `labelExtractionSource` (`"gemini"`, `"heuristic"`)

### Images
- Appliance image (cropped to bounding box for recognition training)
- Label image (full label photo for extraction training)

### Device Context
- Device model, iOS version, app version (for debugging data quality)

## 2. Volume Targets

| Milestone | Sample Count | Action |
|-----------|-------------|--------|
| Launch | 0 | Begin collecting via TrainingSampleService |
| Minimum viable | 500 | Begin training experiments |
| Target | 1,000 | Train production-quality model |
| Growth | 5,000+ | Per-category specialist models |

### Priority: User-Corrected Samples

Samples where the user changed an extracted value are the most valuable -- they represent cases where the current system failed. These should be weighted higher during training.

A sample where `userCorrectedModelNumber == true` tells us: "the OCR/Gemini extracted X, but the correct value was Y." This is exactly the supervision signal a model needs.

## 3. Model Architecture Recommendation

### Create ML Text Classification

**Approach:** Train a text classifier that takes individual OCR lines (with context) and predicts which field type each line represents.

**Input features per line:**
- The OCR text content
- Line position (first, middle, last)
- Surrounding lines (1 above, 1 below)
- Appliance category
- Whether line contains common hints (MOD, SER, etc.)
- Character composition (% digits, % alpha, % special)

**Output classes:**
- `model_number`
- `serial_number`
- `manufacturer`
- `brand`
- `manufacture_date`
- `voltage`
- `wattage`
- `other` (non-field text)

**Why Create ML?**
- Native iOS integration via CoreML
- Small model footprint (< 5MB typical)
- Fast inference (< 50ms)
- Can train with tabular data (CSV) -- no PyTorch/TensorFlow setup needed
- Apple's `MLTextClassifier` handles tokenization automatically

### Alternative: CoreML + NER

For more complex extraction (e.g., finding the value within a line that contains both a hint and a value), consider a Named Entity Recognition approach:

- Token-level classification: each token tagged as B-MODEL, I-MODEL, B-SERIAL, I-SERIAL, O
- Requires more training data (~2,000+ samples)
- More accurate for lines like "MODEL: ABC123 SERIAL: XYZ789"

**Recommendation:** Start with line-level classification. Graduate to NER if accuracy plateaus.

## 4. Training Pipeline

### Step 1: Export from Firestore

```
Firestore collection: training_samples
  -> Filter: labelExtractionSource != nil (has label data)
  -> Filter: ocrRawText != nil (has OCR text)
  -> Export to CSV/JSON
```

### Step 2: Transform to Training Format

For each sample, generate labeled rows:

```csv
text,context_above,context_below,category,label
"MED5630HW2","MOD","120V 60Hz",dryer,model_number
"MA0503434","SER","MANUFACTURED BY",dryer,serial_number
"Whirlpool Corporation","MANUFACTURED BY","Benton Harbor",dryer,manufacturer
"120V 60Hz","MA0503434","5.4 kW",dryer,voltage
```

Use `userFinalModelNumber` as ground truth to identify which line contains the model, etc.

### Step 3: Train with Create ML

```swift
// Xcode Create ML App or Swift script
let data = try MLDataTable(contentsOf: trainingCSV)
let model = try MLTextClassifier(
    trainingData: data,
    textColumn: "text",
    labelColumn: "label"
)
try model.write(to: outputURL)
```

### Step 4: Validate

- Hold out 20% of data for validation
- Key metric: **field-level accuracy** (did we correctly identify model, serial, manufacturer?)
- Track per-category accuracy (dryers may differ from refrigerators)
- Compare against Gemini and heuristic baselines

## 5. Deployment: On-Device Extraction

### New Component: `OnDeviceLabelExtractor`

```swift
actor OnDeviceLabelExtractor {
    private let classifier: MLTextClassifier

    func extractFields(from ocrLines: [String], category: ApplianceCategory) -> OCRFields {
        // Classify each line
        // Build OCRFields from predictions
        // Return structured result
    }
}
```

### Three-Tier Fallback Chain

```
GuidedLabelScanView
  |
  +--> [1] LabelExtractionService (Gemini Cloud Function)
  |         Success? -> Use Gemini fields, source = "gemini"
  |         Failure? -> Try tier 2
  |
  +--> [2] OnDeviceLabelExtractor (CoreML model)
  |         Success? -> Use ML fields, source = "on_device_ml"
  |         Failure? -> Try tier 3
  |
  +--> [3] parseFields() (Heuristic regex/hints)
                Use heuristic fields, source = "heuristic"
```

### Offline Mode

When no network is available, skip tier 1 entirely:
- Tier 2 (ML) works offline -- this is the primary offline extractor
- Tier 3 (heuristic) is the offline fallback

## 6. Evaluation & A/B Testing

### Metrics to Track

For each extraction source, track:
- **Correction rate per field**: % of times user changes each field
- **Correction rate per category**: Some categories may be harder
- **Empty field rate**: How often we fail to extract anything
- **Latency**: Time from capture to fields displayed

### A/B Framework

Use `labelExtractionSource` to segment:
```
correction_rate = samples_where(userCorrectedModelNumber) / total_samples
```

Compare:
| Source | Model Correction Rate | Serial Correction Rate | Manufacturer Correction Rate |
|--------|----------------------|----------------------|----------------------------|
| gemini | ? | ? | ? |
| on_device_ml | ? | ? | ? |
| heuristic | ? | ? | ? |

### Dashboard Query (Firestore)

```javascript
// Correction rate by extraction source
db.collection('training_samples')
  .where('labelExtractionSource', '==', 'gemini')
  .aggregate({
    total: count(),
    modelCorrected: count('userCorrectedModelNumber', '==', true),
    serialCorrected: count('userCorrectedSerialNumber', '==', true)
  })
```

## 7. Timeline

| Phase | When | What |
|-------|------|------|
| Now | Feb 2026 | Collecting training data via TrainingSampleService |
| Now | Feb 2026 | Gemini extraction as primary, heuristic as fallback |
| +2 months | Apr 2026 | Review collected data quality, begin cleanup |
| +3 months | May 2026 | At ~500 samples: first training experiments |
| +4 months | Jun 2026 | At ~1,000 samples: train production model |
| +5 months | Jul 2026 | Deploy on-device model as tier 2 |
| +6 months | Aug 2026 | Evaluate: if ML matches Gemini accuracy, make ML tier 1 |
| +9 months | Nov 2026 | At ~5,000: per-category specialist models |
| +12 months | Feb 2027 | Retire Gemini dependency if ML is sufficient |

## 8. Open Questions

1. **Per-category vs. universal model?** A single model may struggle across categories. Per-category models are more accurate but require more data per category.

2. **Image features?** The text classifier only uses OCR text. Adding image features (label layout, font size, spatial relationships) could improve accuracy but requires a more complex model (Vision + NLP).

3. **Bounding box extraction?** Current OCR fields include bounding boxes from Vision. The ML model could learn spatial relationships (e.g., "the value below the MOD hint is the model number").

4. **Active learning?** Prioritize requesting label scans for categories with low training data. Show users prompts like "We're still learning about [category] labels -- your corrections help improve accuracy!"
