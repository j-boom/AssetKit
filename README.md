# AssetKit

Swift package for AI-powered asset ingestion on iOS. Point your camera at an appliance, and AssetKit identifies it, reads its label, and creates a tracked asset — collecting training data along the way to get smarter over time.

**Platform:** iOS 17+
**Language:** Swift 5.9
**Dependency:** [CastleMindrModels](../CastleMindr/CastleMindrModels/) (shared domain types)

---

## What It Does

1. **Recognize** — Camera capture + Google Gemini Vision identifies the appliance category and manufacturer
2. **Confirm** — User verifies or corrects the AI prediction
3. **Scan Label** — Guided OCR reads model number, serial number, and specs from the appliance label
4. **Save** — Pre-populated form creates an `Asset` for the property management system
5. **Learn** — Training sample captures AI vs. user corrections for model retraining

---

## Architecture

```
AssetKit
├── Capture/         ← 10-step UI flow (views + coordinator)
├── Models/          ← Data types for the pipeline
├── Services/        ← Cloud API clients (recognition + training)
└── Knowledge/       ← Appliance domain knowledge (offline)
```

### Dependency Graph

```
┌──────────────────────────────┐
│       Consumer App           │
│   (CastleMindr iOS app)     │
└──────────┬───────────────────┘
           │ presents
           ▼
┌──────────────────────────────┐
│  AssetCaptureCoordinator     │ ← entry point
│  AssetCaptureView            │ ← NavigationStack flow
└──────────┬───────────────────┘
           │ uses
     ┌─────┼──────────┐
     ▼     ▼          ▼
  Models  Services  Knowledge
     │     │          │
     │     │          └── BundledKnowledgeProvider (offline data)
     │     ├── RecognitionAPIService → Cloud Function (Gemini)
     │     └── TrainingSampleService → Cloud Function (storage)
     │
     └── CastleMindrModels (Asset, ApplianceCategory)
```

---

## Capture Flow

The capture flow is a `NavigationStack` state machine with 6 screens:

```
┌───────────────────┐
│ EntryPointSelection│  "Scan Appliance" or "Enter Manually"
└────────┬──────────┘
         │ scan
         ▼
┌───────────────────┐
│ ObjectRecognition │  Camera → capture photo → draw bounding box
│                   │  → send to Gemini Vision → get prediction
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ ConfirmRecognition│  Show AI result with confidence %
│                   │  User confirms, corrects, or retries
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ GuidedLabelScan   │  Knowledge-driven guidance:
│                   │  "Check inside the left door (65% likely)"
│                   │  Camera → capture label → on-device OCR
│                   │  Extract: model, serial, manufacturer, etc.
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│LabelLocationPicker│  Where was the label? (inside door, back panel, etc.)
│                   │  Category-filtered location options
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ AssetFormView     │  Pre-populated from recognition + OCR
│                   │  Name, type, manufacturer, model, serial,
│                   │  purchase date, warranty, notes
│                   │  → Creates Asset + TrainingSample
└───────────────────┘
```

**Skip paths:** Users can skip from any screen to the form. "Enter Manually" skips straight to the form with no recognition data.

### Flow States

```swift
public enum AssetCaptureFlowState {
    case entrySelection
    case objectRecognition
    case confirmRecognition(RecognitionResult)
    case guidedLabelScan(RecognitionResult)
    case labelLocationPicker(RecognitionResult, LabelScanResult)
    case form(AssetFormData)
}
```

---

## Models

### RecognitionResult

What the AI saw:

| Field | Type | Description |
|-------|------|-------------|
| `category` | `ApplianceCategory` | Detected appliance type |
| `manufacturer` | `String?` | Detected brand |
| `confidence` | `Double` | 0.0–1.0 confidence score |
| `capturedImage` | `UIImage?` | Full photo from camera |
| `boundingBox` | `CGRect?` | Normalized (0-1) region user selected |
| `isSuccessful` | `Bool` | `category != .unknown && confidence > 0.5` |

### LabelScanResult

What OCR extracted from the label:

| Field | Type | Description |
|-------|------|-------------|
| `labelImage` | `UIImage` | Photo of the label |
| `ocrFields.modelNumber` | `OCRField?` | Model with text + confidence + bounding box |
| `ocrFields.serialNumber` | `OCRField?` | Serial number |
| `ocrFields.manufacturer` | `OCRField?` | Brand name from label |
| `ocrFields.manufactureDate` | `OCRField?` | Date of manufacture |
| `ocrFields.voltage` | `OCRField?` | Electrical specs |
| `ocrFields.wattage` | `OCRField?` | Power consumption |
| `ocrFields.rawText` | `String?` | Full OCR text dump |
| `labelLocation` | `LabelLocation?` | Where on the appliance |

### TrainingSample

Everything needed to improve the AI model:

| Field | Description |
|-------|-------------|
| AI prediction | Category, manufacturer, confidence |
| User correction | What the user changed (category? manufacturer?) |
| Item bounding box | What region the user selected |
| Label data | OCR fields, label location, raw text |
| Device context | iPhone model, iOS version, app version |

Built via:
```swift
TrainingSample.build(
    recognition: result,
    confirmedCategory: .refrigerator,
    confirmedManufacturer: "Samsung",
    labelScan: scanResult
)
```

### LabelLocation

Where appliance labels are typically found (11 locations):

`insideLeftDoor`, `insideRightDoor`, `backPanel`, `sideLeft`, `sideRight`, `topEdge`, `bottomEdge`, `behindAccessPanel`, `drawerFront`, `insideFrame`, `other`

Filtered by category — `LabelLocation.commonLocations(for: .refrigerator)` returns relevant subset.

---

## Services

### RecognitionAPIService

Singleton `Actor`. Sends appliance photo to Google Cloud Function running Gemini Vision.

```swift
let result = try await RecognitionAPIService.shared.recognize(image)
// result.category == .refrigerator
// result.manufacturer == "Samsung"
// result.confidence == 0.87
```

**Pipeline:** Resize to 1024px max → JPEG 75% → Base64 → POST to Cloud Function → parse response.

### TrainingSampleService

Singleton `Actor`. Submits training data (JSON + images) to Cloud Function for storage.

```swift
let result = try await TrainingSampleService.shared.submit(
    sample: trainingSample,
    applianceImage: photo,
    labelImage: labelPhoto
)
// result.sampleId, result.applianceImageUrl, result.labelImageUrl
```

**Pipeline:** Encode sample JSON + Base64 images → POST with 60s timeout → get storage URLs back.

---

## Knowledge Base

Domain knowledge that makes the capture flow smart.

### ApplianceKnowledgeBase

Observable cache that loads on first use. Provides:

- **Label location hints** — Where to find the label on each appliance type, with probability
- **Field patterns** — Regex patterns for extracting model/serial from OCR text
- **Common manufacturers** — Per-category manufacturer lists for picker UI
- **Guidance prompts** — Natural language instructions for label scanning

```swift
let kb = ApplianceKnowledgeBase(provider: BundledKnowledgeProvider())
await kb.loadIfNeeded()

let hints = kb.labelLocationHints(for: .refrigerator, manufacturer: "Samsung")
// → [LabelLocationHint(position: "Inside left door", probability: 0.65, ...)]

let prompt = kb.guidancePrompt(for: .refrigerator, manufacturer: "Samsung")
// → "Look inside the left door of the refrigerator..."
```

### BundledKnowledgeProvider

Offline seed data for 5 appliance categories:

| Category | Manufacturers | Label Locations |
|----------|--------------|-----------------|
| Refrigerator | Samsung, LG, Whirlpool, GE, Frigidaire, KitchenAid | Inside left door (65%), inside right door (25%), back panel (10%) |
| Washing Machine | Samsung, LG, Whirlpool, GE, Maytag, Speed Queen | Inside door frame (60%), back panel (25%), top edge (15%) |
| Dryer | Samsung, LG, Whirlpool, GE, Maytag, Speed Queen | Inside door frame (55%), back panel (30%), side panel (15%) |
| HVAC System | Carrier, Trane, Lennox, Rheem, Goodman, American Standard | Access panel (50%), side panel (30%), top (20%) |
| Water Heater | Rheem, AO Smith, Bradford White, State, Whirlpool | Front panel (60%), side (25%), top edge (15%) |

Each includes regex patterns for model/serial extraction (e.g., Samsung model: `[A-Z]{2}\d{2}[A-Z]\d{4}[A-Z]{2,3}`).

---

## Camera & Bounding Box

### CameraView

Full `AVCaptureSession` wrapper with:
- Permission checking with fallback UI
- Device orientation tracking
- Pinch-to-zoom (1.0 → device max)
- Tap-to-focus with visual indicator
- High-resolution photo capture
- Back wide-angle camera, portrait default

### BoundingBoxSelector

Interactive overlay for selecting a region on a captured photo:
- Default box at center (60% of image)
- Drag corners/edges to resize, center to move
- Dimmed overlay outside selection
- Rule-of-thirds grid lines
- Minimum 50pt size enforcement
- Outputs normalized `CGRect` (0-1) for training data
- `UIImage.cropped(to:)` extension for extracting the region

---

## Usage

### Full capture flow

```swift
import AssetKit
import CastleMindrModels

let coordinator = AssetCaptureCoordinator(
    context: .room(propertyId: "prop-123", areaId: "area-456")
)

// Present the capture flow
AssetCaptureView(coordinator: coordinator)

// Handle result
coordinator.start { result in
    switch result {
    case .completed(let asset, let trainingData):
        // asset is CastleMindrModels.Asset — save to backend
        // trainingData is optional TrainingSample — already submitted to cloud
        await saveAsset(asset)
    case .cancelled:
        dismiss()
    }
}
```

### Recognition only (no UI)

```swift
import AssetKit

let result = try await RecognitionAPIService.shared.recognize(photo)
if result.isSuccessful {
    print("\(result.category) by \(result.manufacturer ?? "unknown")")
    print("Confidence: \(Int(result.confidence * 100))%")
}
```

### Knowledge lookup only

```swift
import AssetKit

let kb = ApplianceKnowledgeBase(provider: BundledKnowledgeProvider())
await kb.loadIfNeeded()

// Where should I look for the label?
let hints = kb.labelLocationHints(for: .waterHeater)
for hint in hints {
    print("\(hint.position): \(Int(hint.probability * 100))% likely")
}
```

---

## File Inventory

| Directory | Files | Description |
|-----------|-------|-------------|
| `Capture/` | 10 | Capture flow views + coordinator |
| `Models/` | 4 | RecognitionResult, LabelScanResult, LabelLocation, TrainingSample |
| `Services/` | 2 | Recognition API, training sample submission |
| `Knowledge/` | 2 | Knowledge base protocol + bundled provider |
| **Total** | **18** | |

---

## Cloud Functions

AssetKit talks to two Google Cloud Functions (deployed separately from `castlemindr-api/functions/`):

| Function | Trigger | Purpose |
|----------|---------|---------|
| `recognize_appliance` | HTTP POST | Receives Base64 image, runs Gemini Vision, returns category + manufacturer + confidence |
| `submit_training_sample` | HTTP POST | Receives JSON sample + Base64 images, stores in Cloud Storage for retraining |

---

## Training Data Loop

AssetKit is designed to get smarter over time:

```
User scans appliance
       │
       ▼
AI predicts: "Samsung Refrigerator (87%)"
       │
       ├── User confirms → positive training signal
       │
       └── User corrects → "LG Washing Machine"
                │
                ▼
         TrainingSample captures:
         - What AI predicted vs. what was correct
         - Bounding box of the appliance
         - OCR data from label (model, serial, etc.)
         - Label location on the appliance
         - Device model, OS version
                │
                ▼
         Submitted to Cloud Function
         Stored for periodic model retraining
```

Every user interaction improves the model. Corrections are weighted higher than confirmations.
