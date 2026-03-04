//
//  ObjectRecognitionView.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//

import SwiftUI
import AVFoundation

public struct ObjectRecognitionView: View {
    let onRecognized: (RecognitionResult) -> Void
    let onSkip: () -> Void
    let onCancel: () -> Void
    
    @StateObject private var camera = CameraController()
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
        ZStack {
            CapturableCameraView(controller: camera)
            
            // UI overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                // Instructions
                Text("Take a photo of the item")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.red.opacity(0.8)))
                        .padding(.top, 8)
                }
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 20) {
                    // Capture button
                    Button {
                        capturePhoto()
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
                    .disabled(!camera.isAuthorized)
                    
                    // Skip option
                    if #available(iOS 26.0, *) {
                        Button {
                            onSkip()
                        } label: {
                            Text("Enter Manually")
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
                            Text("Enter Manually")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.white.opacity(0.2)))
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
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
    
    private func capturePhoto() {
        errorMessage = nil
        
        camera.capturePhoto { image in
            guard let image else {
                errorMessage = "Failed to capture photo"
                return
            }
            
            capturedImage = image
            viewState = .selectRegion
        }
    }
    
    private func recognizeItem(_ image: UIImage) {
        viewState = .processing
        isProcessing = true
        
        Task {
            do {
                var result = try await RecognitionAPIService.shared.recognize(image)
                
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
