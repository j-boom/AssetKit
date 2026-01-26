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
    
    /// Normalized bounding box (0-1) of the item within the captured image
    /// Used for training data to identify exactly what the user selected
    public let boundingBox: CGRect?
    
    /// Error message if recognition failed (from API)
    public let error: String?
    
    public init(
        category: ApplianceCategory,
        manufacturer: String? = nil,
        confidence: Double,
        capturedImage: UIImage? = nil,
        boundingBox: CGRect? = nil,
        error: String? = nil
    ) {
        self.category = category
        self.manufacturer = manufacturer
        self.confidence = confidence
        self.capturedImage = capturedImage
        self.boundingBox = boundingBox
        self.error = error
    }
    
    /// Whether this is a successful recognition (not unknown, no error, confidence > 0.5)
    public var isSuccessful: Bool {
        category != .unknown && error == nil && confidence > 0.5
    }
    
    // Equatable - ignore images for comparison
    public static func == (lhs: RecognitionResult, rhs: RecognitionResult) -> Bool {
        lhs.category == rhs.category &&
        lhs.manufacturer == rhs.manufacturer &&
        lhs.confidence == rhs.confidence &&
        lhs.boundingBox == rhs.boundingBox &&
        lhs.error == rhs.error
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
            category: ApplianceCategory(rawValue: category),
            manufacturer: manufacturer,
            confidence: confidence,
            capturedImage: image,
            error: error
        )
    }
}
