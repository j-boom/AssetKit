//
//  GuidedLabelScanView.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//


import SwiftUI

public struct GuidedLabelScanView: View {
    let recognition: RecognitionResult
    let onComplete: (AssetFormData) -> Void
    let onSkip: () -> Void
    
    @EnvironmentObject private var knowledgeBase: ApplianceKnowledgeBase
    
    @State private var detectedModel = ""
    @State private var detectedSerial = ""
    @State private var detectedBrand = ""
    
    public init(
        recognition: RecognitionResult,
        onComplete: @escaping (AssetFormData) -> Void,
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
        VStack(spacing: 16) {
            // Camera feed placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black)
                .aspectRatio(3/4, contentMode: .fit)
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Label Scanner")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal)
            
            // Guidance prompt
            Text(guidancePrompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Detected fields status
            VStack(spacing: 8) {
                FieldStatusRow(label: "Model", value: detectedModel)
                FieldStatusRow(label: "Serial", value: detectedSerial)
                FieldStatusRow(label: "Brand", value: detectedBrand.isEmpty ? recognition.manufacturer ?? "" : detectedBrand)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            Spacer()
            
            // Temp: simulate OCR detection
            Button("Simulate OCR Detection") {
                detectedModel = "RF28R7351SR"
                detectedSerial = "ABC123456789"
                detectedBrand = recognition.manufacturer ?? "Samsung"
            }
            .buttonStyle(.bordered)
            
            // Actions
            VStack(spacing: 12) {
                Button {
                    var formData = AssetFormData.from(recognition: recognition)
                    formData.modelNumber = detectedModel
                    formData.serialNumber = detectedSerial
                    formData.manufacturer = detectedBrand.isEmpty ? recognition.manufacturer ?? "" : detectedBrand
                    onComplete(formData)
                } label: {
                    Text("Looks good!")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!hasMinimumData)
                
                Button("Enter manually", action: onSkip)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            Spacer().frame(height: 20)
        }
        .navigationTitle("Scan Label")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Field Status Row

private struct FieldStatusRow: View {
    let label: String
    let value: String
    
    private var isDetected: Bool { !value.isEmpty }
    
    var body: some View {
        HStack {
            Image(systemName: isDetected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDetected ? Color.green : Color.secondary)
            
            Text(label)
                .foregroundStyle(Color.secondary)
            
            Spacer()
            
            Text(isDetected ? value : "—")
                .fontWeight(isDetected ? .medium : .regular)
                .foregroundStyle(isDetected ? Color.primary : Color.secondary)
        }
    }
}
