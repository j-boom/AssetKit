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
}

// MARK: - Capture Result

public enum AssetCaptureResult {
    case completed(asset: Asset, trainingData: TrainingSample?)
    case cancelled
}

// MARK: - Coordinator

@MainActor
public final class AssetCaptureCoordinator: ObservableObject {
    
    public let context: AssetCaptureContext
    private var onComplete: ((AssetCaptureResult) -> Void)?
    
    public init(context: AssetCaptureContext) {
        self.context = context
    }
    
    public func start(onComplete: @escaping (AssetCaptureResult) -> Void) {
        self.onComplete = onComplete
    }
    
    public func complete(with asset: Asset, trainingData: TrainingSample? = nil) {
        onComplete?(.completed(asset: asset, trainingData: trainingData))
    }
    
    public func cancel() {
        onComplete?(.cancelled)
    }
}
