//
//  GuidedLabelScanView.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//

import SwiftUI
import AVFoundation
import Vision
import os.log

private let ocrLog = Logger(subsystem: "com.castlemindr.AssetKit", category: "OCR")

public struct GuidedLabelScanView: View {
    let recognition: RecognitionResult
    let onComplete: (LabelScanResult) -> Void
    let onSkip: () -> Void
    
    @EnvironmentObject private var knowledgeBase: ApplianceKnowledgeBase
    @Environment(\.isPremium) private var isPremium
    @StateObject private var camera = CameraController()
    
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var processingStage = "Reading label..."
    @State private var detectedModel = ""
    @State private var detectedSerial = ""
    @State private var detectedManufacturer = ""
    @State private var rawOCRText = ""
    @State private var errorMessage: String?
    @State private var extractionSource = "heuristic"
    @State private var geminiFields: OCRFields?
    
    public init(
        recognition: RecognitionResult,
        onComplete: @escaping (LabelScanResult) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.recognition = recognition
        self.onComplete = onComplete
        self.onSkip = onSkip
    }
    
    private var guidancePrompt: String {
        knowledgeBase.guidancePrompt(
            for: recognition.category,
            manufacturer: recognition.brand
        )
    }
    
    private var hasMinimumData: Bool {
        !detectedModel.isEmpty || !detectedSerial.isEmpty
    }
    
    public var body: some View {
        ZStack {
            // Background: camera when capturing, black after capture
            if capturedImage == nil {
                CapturableCameraView(controller: camera)
            } else {
                Color.black.ignoresSafeArea()
            }
            
            // Processing overlay
            if isProcessing {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text(processingStage)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            
            // UI overlay
            VStack(spacing: 0) {
                // Top bar with guidance
                if capturedImage == nil && !isProcessing {
                    Text(guidancePrompt)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.7)))
                        .padding(.horizontal)
                        .padding(.top, 60)
                }
                
                Spacer()
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.red.opacity(0.8)))
                        .padding(.bottom, 8)
                }
                
                // Detected fields card (shown after scan)
                if capturedImage != nil && !isProcessing {
                    detectedFieldsCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                
                // Bottom controls
                bottomControls
                    .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
    }
    
    // MARK: - Detected Fields Card
    
    private var detectedFieldsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Info")
                .font(.headline)
                .foregroundStyle(.white)
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Model
            fieldRow(
                icon: detectedModel.isEmpty ? "circle" : "checkmark.circle.fill",
                iconColor: detectedModel.isEmpty ? .white.opacity(0.5) : .green,
                label: "Model",
                value: $detectedModel,
                placeholder: "Not detected"
            )
            
            // Serial
            fieldRow(
                icon: detectedSerial.isEmpty ? "circle" : "checkmark.circle.fill",
                iconColor: detectedSerial.isEmpty ? .white.opacity(0.5) : .green,
                label: "Serial",
                value: $detectedSerial,
                placeholder: "Not detected"
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.85)))
        .clipped()
    }
    
    private func fieldRow(
        icon: String,
        iconColor: Color,
        label: String,
        value: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            TextField(placeholder, text: value)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.leading, 28)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            if capturedImage == nil {
                // Capture button
                Button {
                    captureAndScan()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 72, height: 72)
                        
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 84, height: 84)
                    }
                }
                .disabled(isProcessing || !camera.isAuthorized)
                .opacity(isProcessing ? 0.5 : 1)
            } else {
                // Post-capture buttons
                Button {
                    submitResult()
                } label: {
                    Text(hasMinimumData ? "Use this info" : "Continue anyway")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Color.blue))
                }
                .padding(.horizontal, 24)
                
                Button("Retake") {
                    resetCapture()
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            }
            
            // Skip option
            if #available(iOS 26.0, *) {
                Button {
                    onSkip()
                } label: {
                    Text("No Label on This Item")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                }
                .glassEffect(.regular.interactive(), in: .capsule)
            } else {
                Button {
                    onSkip()
                } label: {
                    Text("No Label on This Item")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func captureAndScan() {
        isProcessing = true
        errorMessage = nil
        
        camera.capturePhoto { image in
            guard let image else {
                isProcessing = false
                errorMessage = "Failed to capture photo"
                return
            }
            
            capturedImage = image
            performOCR(on: image)
        }
    }
    
    private func performOCR(on image: UIImage) {
        guard let cgImage = image.cgImage else {
            isProcessing = false
            errorMessage = "Failed to process image"
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            DispatchQueue.main.async {
                if let error {
                    self.isProcessing = false
                    self.errorMessage = "OCR failed: \(error.localizedDescription)"
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    self.isProcessing = false
                    ocrLog.warning("⚠️ No text observations returned from Vision")
                    return
                }

                ocrLog.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                ocrLog.info("📷 OCR SCAN — \(observations.count) text observation(s)")
                ocrLog.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                var allText: [String] = []
                for (i, observation) in observations.enumerated() {
                    let candidates = observation.topCandidates(3)
                    let topText = candidates.first?.string ?? "(empty)"
                    let topConf = candidates.first?.confidence ?? 0

                    allText.append(topText)

                    let altCandidates = candidates.dropFirst().map { "\"\($0.string)\" (\(String(format: "%.0f%%", $0.confidence * 100)))" }.joined(separator: ", ")
                    let altStr = altCandidates.isEmpty ? "none" : altCandidates

                    ocrLog.info("  [\(i)] \"\(topText)\" — confidence: \(String(format: "%.0f%%", topConf * 100)) | alts: \(altStr)")
                }

                ocrLog.info("──────────────────────────────────────────")
                ocrLog.info("📝 RAW TEXT DUMP:")
                ocrLog.info("\(allText.joined(separator: "\n"))")
                ocrLog.info("──────────────────────────────────────────")

                self.rawOCRText = allText.joined(separator: "\n")

                // Run heuristic first (free), then Gemini only if needed
                self.extractFieldsFromLabel(ocrLines: allText)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = "OCR failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func parseFields(from lines: [String]) {
        let knowledge = knowledgeBase.knowledge(for: recognition.category)
        let patterns = knowledge?.fieldPatterns ?? []

        let modelHints = ["MODEL:", "MODEL ", "MOD:", "MOD ", "M/N:", "M/N ", "MODEL NO", "MODEL NUMBER"]
        let serialHints = ["SERIAL:", "SERIAL ", "SER:", "SER ", "S/N:", "S/N ", "SERIAL NO", "SERIAL NUMBER"]

        ocrLog.info("🔍 PARSING — category: \(self.recognition.category.rawValue), \(patterns.count) pattern(s) loaded")

        // Track which lines have been claimed by hint-based extraction
        var claimedLines: Set<Int> = []

        // Pending hint: a hint was found on a line but no value followed on the same line.
        // The value is likely on the next line.
        var pendingField: String? = nil  // "model" or "serial"

        // ── Pass 1: Hint-based extraction (with multi-line lookahead) ──

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let upper = trimmed.uppercased()

            ocrLog.info("  LINE[\(i)]: \"\(trimmed)\"")

            // If previous line left a pending hint, this line is the value
            if let pending = pendingField {
                let cleaned = trimmed
                    .trimmingCharacters(in: CharacterSet(charactersIn: ":.-# "))
                    .trimmingCharacters(in: .whitespaces)

                if cleaned.count >= 3 && cleaned.count <= 50 {
                    if pending == "model" && detectedModel.isEmpty {
                        detectedModel = cleaned
                        claimedLines.insert(i)
                        ocrLog.info("  ✅ MODEL from pending hint (next line[\(i)]): \"\(cleaned)\"")
                    } else if pending == "serial" && detectedSerial.isEmpty {
                        detectedSerial = cleaned
                        claimedLines.insert(i)
                        ocrLog.info("  ✅ SERIAL from pending hint (next line[\(i)]): \"\(cleaned)\"")
                    }
                } else {
                    ocrLog.info("  ⏭️ Pending \(pending) — next line too short/long (\(cleaned.count) chars), skipping")
                }
                pendingField = nil
            }

            // Check for model hint
            if detectedModel.isEmpty {
                if let result = extractHintValue(from: trimmed, upper: upper, hints: modelHints) {
                    switch result {
                    case .value(let v):
                        detectedModel = v
                        claimedLines.insert(i)
                        ocrLog.info("  ✅ MODEL extracted from line[\(i)]: \"\(v)\"")
                    case .hintOnly:
                        pendingField = "model"
                        claimedLines.insert(i)
                        ocrLog.info("  ⏳ MODEL hint found on line[\(i)] but no value — checking next line")
                    }
                }
            }

            // Check for serial hint
            if detectedSerial.isEmpty {
                if let result = extractHintValue(from: trimmed, upper: upper, hints: serialHints) {
                    switch result {
                    case .value(let v):
                        detectedSerial = v
                        claimedLines.insert(i)
                        ocrLog.info("  ✅ SERIAL extracted from line[\(i)]: \"\(v)\"")
                    case .hintOnly:
                        pendingField = "serial"
                        claimedLines.insert(i)
                        ocrLog.info("  ⏳ SERIAL hint found on line[\(i)] but no value — checking next line")
                    }
                }
            }
        }

        // ── Pass 2: Regex-based extraction on unclaimed lines ──

        if !patterns.isEmpty && (detectedModel.isEmpty || detectedSerial.isEmpty) {
            ocrLog.info("  📐 Pass 2: regex patterns on unclaimed lines...")

            for (i, line) in lines.enumerated() {
                guard !claimedLines.contains(i) else { continue }

                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if detectedModel.isEmpty {
                    if let model = extractRegex(from: trimmed, fieldName: "model", patterns: patterns) {
                        detectedModel = model
                        claimedLines.insert(i)
                        ocrLog.info("  ✅ MODEL (regex) from line[\(i)]: \"\(model)\"")
                    }
                }

                if detectedSerial.isEmpty {
                    if let serial = extractRegex(from: trimmed, fieldName: "serial", patterns: patterns) {
                        // Dedup guard: don't let serial be the same as model
                        if serial == detectedModel {
                            ocrLog.info("  ⛔ SERIAL (regex) from line[\(i)]: \"\(serial)\" — REJECTED (same as model)")
                        } else {
                            detectedSerial = serial
                            claimedLines.insert(i)
                            ocrLog.info("  ✅ SERIAL (regex) from line[\(i)]: \"\(serial)\"")
                        }
                    }
                }
            }
        }

        ocrLog.info("──────────────────────────────────────────")
        ocrLog.info("📋 PARSE RESULT — model: \"\(self.detectedModel.isEmpty ? "(none)" : self.detectedModel)\" | serial: \"\(self.detectedSerial.isEmpty ? "(none)" : self.detectedSerial)\"")
        ocrLog.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    // MARK: - Hint Extraction

    private enum HintResult {
        case value(String)  // Hint found and value extracted on same line
        case hintOnly       // Hint found but no value — check next line
    }

    private func extractHintValue(from line: String, upper: String, hints: [String]) -> HintResult? {
        for hint in hints {
            if upper.contains(hint) {
                if let hintRange = upper.range(of: hint) {
                    let afterHint = String(line[hintRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    let cleaned = afterHint
                        .trimmingCharacters(in: CharacterSet(charactersIn: ":.-# "))
                        .trimmingCharacters(in: .whitespaces)

                    if cleaned.count >= 3 && cleaned.count <= 50 {
                        ocrLog.info("    🏷️ hint \"\(hint)\" → value: \"\(cleaned)\" ✅")
                        return .value(cleaned)
                    } else {
                        ocrLog.info("    🏷️ hint \"\(hint)\" → afterHint: \"\(cleaned)\" (len \(cleaned.count)) — hint only")
                        return .hintOnly
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Regex Extraction

    private func extractRegex(from line: String, fieldName: String, patterns: [FieldPattern]) -> String? {
        for pattern in patterns where pattern.fieldName == fieldName {
            if let regex = try? NSRegularExpression(pattern: pattern.regex, options: .caseInsensitive) {
                let range = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, options: [], range: range) {
                    if let matchRange = Range(match.range, in: line) {
                        let matched = String(line[matchRange])
                        ocrLog.info("    🔣 [\(fieldName)] regex /\(pattern.regex)/ matched: \"\(matched)\"")
                        return matched
                    }
                }
            }
        }
        return nil
    }
    
    // MARK: - Extraction Orchestration

    /// Heuristic-first extraction: run free OCR parsing first, only call Gemini
    /// if the heuristic is missing model or serial number.
    private func extractFieldsFromLabel(ocrLines: [String]) {
        // Step 1: Run heuristic parsing first (free, instant)
        processingStage = "Reading label..."
        parseFields(from: ocrLines)

        let heuristicFoundModel = !detectedModel.isEmpty
        let heuristicFoundSerial = !detectedSerial.isEmpty

        ocrLog.info("🔀 Heuristic result — model: \(heuristicFoundModel) | serial: \(heuristicFoundSerial)")

        // Step 2: If heuristic found BOTH model and serial, we're done
        if heuristicFoundModel && heuristicFoundSerial {
            ocrLog.info("✅ Heuristic found both fields — skipping Gemini")
            extractionSource = "heuristic"
            isProcessing = false
            return
        }

        // Step 3: Check usage cap before calling Gemini
        guard GeminiUsageTracker.shared.canUseGemini(isPremium: isPremium) else {
            ocrLog.info("⛔ Gemini daily cap reached — using heuristic-only")
            extractionSource = "heuristic"
            isProcessing = false
            return
        }

        // Step 4: Heuristic is missing at least one field — try Gemini for enhancement
        ocrLog.info("🤖 Heuristic incomplete — calling Gemini for enhancement...")
        enhanceWithGemini(
            ocrLines: ocrLines,
            heuristicModel: heuristicFoundModel ? detectedModel : nil,
            heuristicSerial: heuristicFoundSerial ? detectedSerial : nil
        )
    }

    /// Call Gemini to fill in fields the heuristic missed. Does not overwrite
    /// what the heuristic already found.
    private func enhanceWithGemini(
        ocrLines: [String],
        heuristicModel: String?,
        heuristicSerial: String?
    ) {
        guard let image = capturedImage else {
            // No image — keep heuristic results as-is
            extractionSource = "heuristic"
            isProcessing = false
            return
        }

        processingStage = "Enhancing with AI..."

        Task {
            do {
                let result = try await LabelExtractionService.shared.extractFields(
                    image: image,
                    ocrText: rawOCRText,
                    category: recognition.category,
                    brand: recognition.brand
                )

                await MainActor.run {
                    ocrLog.info("🤖 Gemini enhancement succeeded:")
                    ocrLog.info("   model: \(result.modelNumber ?? "(nil)")")
                    ocrLog.info("   serial: \(result.serialNumber ?? "(nil)")")
                    ocrLog.info("   manufacturer: \(result.manufacturer ?? "(nil)")")
                    ocrLog.info("   brand: \(result.brand ?? "(nil)")")
                    ocrLog.info("   confidence: \(String(format: "%.0f%%", result.confidence * 100))")

                    // Merge: only fill in what heuristic missed
                    var usedGemini = false

                    if heuristicModel == nil, let model = result.modelNumber, !model.isEmpty {
                        detectedModel = model
                        usedGemini = true
                        ocrLog.info("   📥 model (from Gemini): \(model)")
                    }

                    if heuristicSerial == nil, let serial = result.serialNumber, !serial.isEmpty {
                        detectedSerial = serial
                        usedGemini = true
                        ocrLog.info("   📥 serial (from Gemini): \(serial)")
                    }

                    // Always accept manufacturer from Gemini if we don't have one
                    if detectedManufacturer.isEmpty, let mfr = result.manufacturer, !mfr.isEmpty {
                        detectedManufacturer = mfr
                        usedGemini = true
                        ocrLog.info("   📥 manufacturer (from Gemini): \(mfr)")
                    }

                    // Track extraction source for training data
                    if usedGemini {
                        extractionSource = "heuristic+gemini"
                        geminiFields = result.toOCRFields(rawText: rawOCRText)
                    } else {
                        // Gemini returned nothing new — pure heuristic
                        extractionSource = "heuristic"
                    }

                    // Record the Gemini usage (only on success)
                    GeminiUsageTracker.shared.recordUsage()

                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    ocrLog.warning("🤖 Gemini enhancement failed: \(error.localizedDescription)")
                    // Keep heuristic results — don't overwrite anything
                    extractionSource = "heuristic"
                    geminiFields = nil
                    isProcessing = false
                }
            }
        }
    }

    private func resetCapture() {
        capturedImage = nil
        detectedModel = ""
        detectedSerial = ""
        detectedManufacturer = ""
        rawOCRText = ""
        errorMessage = nil
        extractionSource = "heuristic"
        geminiFields = nil
        processingStage = "Reading label..."
    }
    
    private func submitResult() {
        // Use Gemini-extracted fields if available, otherwise build from detected values
        let ocrFields: OCRFields
        if let geminiFields {
            // Gemini fields already have full structure; override with any user edits
            var fields = geminiFields
            if !detectedModel.isEmpty {
                fields.modelNumber = OCRField(text: detectedModel, confidence: geminiFields.modelNumber?.confidence ?? 0.8)
            }
            if !detectedSerial.isEmpty {
                fields.serialNumber = OCRField(text: detectedSerial, confidence: geminiFields.serialNumber?.confidence ?? 0.8)
            }
            ocrFields = fields
        } else {
            ocrFields = OCRFields(
                modelNumber: detectedModel.isEmpty ? nil : OCRField(text: detectedModel),
                serialNumber: detectedSerial.isEmpty ? nil : OCRField(text: detectedSerial),
                manufacturer: detectedManufacturer.isEmpty ? nil : OCRField(text: detectedManufacturer),
                rawText: rawOCRText.isEmpty ? nil : rawOCRText
            )
        }

        let result = LabelScanResult(
            labelImage: capturedImage ?? UIImage(),
            ocrFields: ocrFields,
            labelLocationSource: .pending,
            extractionSource: extractionSource
        )

        onComplete(result)
    }
}
