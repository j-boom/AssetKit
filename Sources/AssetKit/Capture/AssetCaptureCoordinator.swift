//
//  AssetCaptureCoordinator.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//

import SwiftUI
import CastleMindrModels

// MARK: - Capture Context

public enum AssetCaptureContext {
    case property(propertyId: String)
    case room(propertyId: String, areaId: String)
    /// Scan label on an existing asset to add model/serial number.
    /// Jumps directly to the GuidedLabelScan flow, skipping object recognition.
    case scanLabel(propertyId: String, existingAsset: Asset)
}

// MARK: - Capture Result

public enum AssetCaptureResult {
    case completed(asset: Asset, trainingData: TrainingSample?, capturedImage: UIImage?)
    case cancelled
}

// MARK: - Premium Environment Key

private struct IsPremiumKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    var isPremium: Bool {
        get { self[IsPremiumKey.self] }
        set { self[IsPremiumKey.self] = newValue }
    }
}

// MARK: - Coordinator

@MainActor
public final class AssetCaptureCoordinator: ObservableObject {

    public let context: AssetCaptureContext
    public let isPremium: Bool
    private var onComplete: ((AssetCaptureResult) -> Void)?

    public init(context: AssetCaptureContext, isPremium: Bool = false) {
        self.context = context
        self.isPremium = isPremium
    }
    
    public func start(onComplete: @escaping (AssetCaptureResult) -> Void) {
        self.onComplete = onComplete
    }
    
    public func complete(with asset: Asset, trainingData: TrainingSample? = nil, capturedImage: UIImage? = nil) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ AssetKit: Asset capture completed")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("   ID: \(asset.id)")
        print("   Name: \(asset.name)")
        print("   Type: \(asset.type.rawValue)")
        print("   Brand: \(asset.brand ?? "nil")")
        print("   Manufacturer: \(asset.manufacturer ?? "nil")")
        print("   Model: \(asset.modelNumber ?? "nil")")
        print("   Serial: \(asset.serialNumber ?? "nil")")
        if let training = trainingData {
            print("   Training data: ✓")
            print("      - AI predicted: \(training.aiPredictedCategory)")
            print("      - AI predicted brand: \(training.aiPredictedBrand ?? "nil")")
            print("      - User corrected category: \(training.userCorrectedCategory)")
            print("      - User corrected brand: \(training.userCorrectedBrand)")
            print("      - Label extraction: \(training.labelExtractionSource ?? "none")")
            print("      - User final model: \(training.userFinalModelNumber ?? "nil")")
            print("      - User final serial: \(training.userFinalSerialNumber ?? "nil")")
        } else {
            print("   Training data: none")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        onComplete?(.completed(asset: asset, trainingData: trainingData, capturedImage: capturedImage))
    }
    
    public func cancel() {
        print("❌ AssetKit: Asset capture cancelled")
        onComplete?(.cancelled)
    }
}
