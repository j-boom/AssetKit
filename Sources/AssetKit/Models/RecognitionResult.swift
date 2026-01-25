//
//  RecognitionResult.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//
import Foundation
import UIKit
import CastleMindrModels

/// Result from appliance recognition (API or on-device)
public struct RecognitionResult: Equatable {
    public let category: ApplianceCategory
    public let manufacturer: String?
    public let confidence: Double
    public let capturedImage: UIImage?
    
    /// Error message if recognition failed (from API)
    public let error: String?
    
    public init(
        category: ApplianceCategory,
        manufacturer: String? = nil,
        confidence: Double,
        capturedImage: UIImage? = nil,
        error: String? = nil
    ) {
        self.category = category
        self.manufacturer = manufacturer
        self.confidence = confidence
        self.capturedImage = capturedImage
        self.error = error
    }
    
    /// Whether this is a successful recognition (not unknown, no error, confidence > 0.5)
    public var isSuccessful: Bool {
        category != .unknown && error == nil && confidence > 0.5
    }
}

// MARK: - API Response (for decoding JSON)

/// Internal struct for decoding API response
struct RecognitionAPIResponse: Codable {
    let category: String
    let manufacturer: String?
    let confidence: Double
    let error: String?
    
    func toResult(with image: UIImage?) -> RecognitionResult {
        RecognitionResult(
            category: ApplianceCategory(rawValue: category) ?? .unknown,
            manufacturer: manufacturer,
            confidence: confidence,
            capturedImage: image,
            error: error
        )
    }
}
