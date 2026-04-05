//
//  ObjectRecognitionView.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//

import SwiftUI
import AVFoundation
import os.log
import CMCameraKit

private let recognitionLog = Logger(subsystem: "com.castlemindr.AssetKit", category: "Recognition")

public struct ObjectRecognitionView: View {
    let onRecognized: (RecognitionResult) -> Void
    let onSkip: () -> Void
    let onCancel: () -> Void

    @Environment(\.isPremium) private var isPremium
    @State private var viewState: ViewState = .camera
    @State private var capturedImage: UIImage?
    @State private var croppedImage: UIImage?
    @State private var boundingBox: CGRect?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    enum ViewState {
        case camera
        case selectRegion
        case processing
    }
    
    public init(
        onRecognized: @escaping (RecognitionResult) -> Void,
        onSkip: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onRecognized = onRecognized
        self.onSkip = onSkip
        self.onCancel = onCancel
    }
    
    public var body: some View {
        ZStack {
            switch viewState {
            case .camera:
                cameraView
                
            case .selectRegion:
                if let image = capturedImage {
                    BoundingBoxSelector(
                        image: image,
                        onConfirm: { normalizedRect in
                            boundingBox = normalizedRect
                            if let cropped = image.cropped(to: normalizedRect) {
                                croppedImage = cropped
                                recognizeItem(cropped)
                            } else {
                                // Fallback to full image
                                recognizeItem(image)
                            }
                        },
                        onRetake: {
                            capturedImage = nil
                            viewState = .camera
                        }
                    )
                }
                
            case .processing:
                processingView
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
    }
    
    // MARK: - Camera View

    private var cameraView: some View {
        CMCameraView(
            configuration: CMCameraConfiguration(
                instructionMessage: "Take a photo of the item",
                alternateAction: .init(label: "Enter Manually") { onSkip() }
            ),
            errorMessage: $errorMessage,
            onCapture: { image in
                capturedImage = image
                viewState = .selectRegion
            },
            onCancel: { onCancel() }
        )
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        ZStack {
            // Show the full captured image during processing
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Identifying...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
    }
    
    // MARK: - Actions

    private func recognizeItem(_ image: UIImage) {
        // Check daily Gemini cap before calling the API
        guard GeminiUsageTracker.shared.canUseGemini(isPremium: isPremium) else {
            recognitionLog.info("⛔ Gemini daily cap reached — skipping recognition, user will select category manually")
            // Pass through with the captured image but no AI prediction.
            // ConfirmRecognitionView's category picker lets the user choose.
            let manual = RecognitionResult(
                category: "unknown",
                brand: nil,
                confidence: 0,
                capturedImage: capturedImage,
                boundingBox: boundingBox
            )
            onRecognized(manual)
            return
        }

        viewState = .processing
        isProcessing = true

        Task {
            do {
                var result = try await RecognitionAPIService.shared.recognize(image)

                // Record usage only after a successful Gemini call
                GeminiUsageTracker.shared.recordUsage()
                recognitionLog.info("✅ Gemini recognition used — remaining: \(GeminiUsageTracker.shared.remainingCount.map(String.init) ?? "unlimited")")

                // Attach the full captured image (not cropped) for the asset
                // but store bounding box info for training
                result = RecognitionResult(
                    category: result.category,
                    brand: result.brand,
                    manufacturer: result.manufacturer,
                    confidence: result.confidence,
                    capturedImage: capturedImage,  // Full image
                    boundingBox: boundingBox       // Where the item is
                )

                await MainActor.run {
                    isProcessing = false
                    onRecognized(result)
                }
            } catch RecognitionError.capReached {
                // Cap hit server-side — fall through to manual selection
                GeminiUsageTracker.shared.syncFromProfile(limit: 0, remaining: 0)
                await MainActor.run {
                    isProcessing = false
                    let manual = RecognitionResult(
                        category: "unknown",
                        brand: nil,
                        confidence: 0,
                        capturedImage: capturedImage,
                        boundingBox: boundingBox
                    )
                    onRecognized(manual)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    viewState = .camera
                    capturedImage = nil
                    croppedImage = nil
                    boundingBox = nil
                }
            }
        }
    }
}
