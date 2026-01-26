//
//  GuidedLabelScanView.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//

import SwiftUI
import AVFoundation
import Vision

public struct GuidedLabelScanView: View {
    let recognition: RecognitionResult
    let onComplete: (LabelScanResult) -> Void
    let onSkip: () -> Void
    
    @EnvironmentObject private var knowledgeBase: ApplianceKnowledgeBase
    @StateObject private var camera = CameraController()
    
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var detectedModel = ""
    @State private var detectedSerial = ""
    @State private var rawOCRText = ""
    @State private var errorMessage: String?
    
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
            manufacturer: recognition.manufacturer
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
                    Text("Reading label...")
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
            Button("No label on this item") {
                onSkip()
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))
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
                self.isProcessing = false
                
                if let error {
                    self.errorMessage = "OCR failed: \(error.localizedDescription)"
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                
                let allText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                self.rawOCRText = allText.joined(separator: "\n")
                self.parseFields(from: allText)
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
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let upper = trimmed.uppercased()
            
            // Check for model number
            if detectedModel.isEmpty {
                if let model = extractField(from: trimmed, upper: upper, fieldName: "model", patterns: patterns, hints: ["MODEL:", "MODEL ", "MOD:", "MOD ", "M/N:", "M/N ", "MODEL NO", "MODEL NUMBER"]) {
                    detectedModel = model
                }
            }
            
            // Check for serial number
            if detectedSerial.isEmpty {
                if let serial = extractField(from: trimmed, upper: upper, fieldName: "serial", patterns: patterns, hints: ["SERIAL:", "SERIAL ", "SER:", "SER ", "S/N:", "S/N ", "SERIAL NO", "SERIAL NUMBER"]) {
                    detectedSerial = serial
                }
            }
        }
    }
    
    private func extractField(from line: String, upper: String, fieldName: String, patterns: [FieldPattern], hints: [String]) -> String? {
        // Check if line contains a hint
        for hint in hints {
            if upper.contains(hint) {
                // Extract value after the hint
                if let hintRange = upper.range(of: hint) {
                    let afterHint = String(line[hintRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    // Clean up common separators at the start
                    let cleaned = afterHint
                        .trimmingCharacters(in: CharacterSet(charactersIn: ":.-# "))
                        .trimmingCharacters(in: .whitespaces)
                    
                    if cleaned.count >= 3 && cleaned.count <= 50 {
                        return cleaned
                    }
                }
            }
        }
        
        // Try regex patterns from knowledge base
        for pattern in patterns where pattern.fieldName == fieldName {
            if let regex = try? NSRegularExpression(pattern: pattern.regex, options: .caseInsensitive) {
                let range = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, options: [], range: range) {
                    if let matchRange = Range(match.range, in: line) {
                        return String(line[matchRange])
                    }
                }
            }
        }
        
        return nil
    }
    
    private func resetCapture() {
        capturedImage = nil
        detectedModel = ""
        detectedSerial = ""
        rawOCRText = ""
        errorMessage = nil
    }
    
    private func submitResult() {
        let ocrFields = OCRFields(
            modelNumber: detectedModel.isEmpty ? nil : OCRField(text: detectedModel),
            serialNumber: detectedSerial.isEmpty ? nil : OCRField(text: detectedSerial),
            rawText: rawOCRText.isEmpty ? nil : rawOCRText
        )
        
        let result = LabelScanResult(
            labelImage: capturedImage ?? UIImage(),
            ocrFields: ocrFields,
            labelLocationSource: .pending
        )
        
        onComplete(result)
    }
}
