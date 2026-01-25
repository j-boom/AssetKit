//
//  ObjectRecognitionView.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//


import SwiftUI

public struct ObjectRecognitionView: View {
    let onRecognized: (RecognitionResult) -> Void
    let onSkip: () -> Void
    let onCancel: () -> Void
    
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
        VStack(spacing: 24) {
            Spacer()
            
            // Placeholder for camera feed
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black)
                .aspectRatio(3/4, contentMode: .fit)
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Camera Preview")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal)
            
            Text("Point at an appliance")
                .font(.headline)
            
            Spacer()
            
            // Temp: simulate recognition
            Button("Simulate Recognition") {
                let result = RecognitionResult(
                    category: .refrigerator,
                    manufacturer: "Samsung",
                    confidence: 0.92
                )
                onRecognized(result)
            }
            .buttonStyle(.borderedProminent)
            
            Button("Skip, enter manually", action: onSkip)
                .foregroundStyle(.secondary)
            
            Spacer().frame(height: 20)
        }
        .navigationTitle("Scan Appliance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
        }
    }
}
