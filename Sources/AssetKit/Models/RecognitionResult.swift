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
    public let category: String
    public let brand: String?
    public let manufacturer: String?
    public let confidence: Double
    public let capturedImage: UIImage?

    /// Normalized bounding box (0-1) of the item within the captured image
    /// Used for training data to identify exactly what the user selected
    public let boundingBox: CGRect?

    /// Error message if recognition failed (from API)
    public let error: String?

    /// Anonymous training-sample identifier returned by the FastAPI
    /// `/assets/recognize/appliance` endpoint. Echo this back when saving
    /// the resulting asset so the backend can write the human-correction
    /// row in the training corpus. Nil when recognition was on-device or
    /// the user has training-data contribution turned off.
    public let sampleId: String?

    public init(
        category: String,
        brand: String? = nil,
        manufacturer: String? = nil,
        confidence: Double,
        capturedImage: UIImage? = nil,
        boundingBox: CGRect? = nil,
        error: String? = nil,
        sampleId: String? = nil
    ) {
        self.category = category
        self.brand = brand
        self.manufacturer = manufacturer
        self.confidence = confidence
        self.capturedImage = capturedImage
        self.boundingBox = boundingBox
        self.error = error
        self.sampleId = sampleId
    }

    /// Whether this is a successful recognition (not unknown, no error, confidence > 0.5)
    public var isSuccessful: Bool {
        category != "unknown" && error == nil && confidence > 0.5
    }

    /// Backward-compatible lookup for category icon, display name, etc.
    public var categoryInfo: ApplianceCategory {
        ApplianceCategory(rawValue: category)
    }

    // Equatable - ignore images for comparison
    public static func == (lhs: RecognitionResult, rhs: RecognitionResult) -> Bool {
        lhs.category == rhs.category &&
        lhs.brand == rhs.brand &&
        lhs.manufacturer == rhs.manufacturer &&
        lhs.confidence == rhs.confidence &&
        lhs.boundingBox == rhs.boundingBox &&
        lhs.error == rhs.error &&
        lhs.sampleId == rhs.sampleId
    }
}

// MARK: - API Response (for decoding JSON)

/// Decodes the FastAPI `/assets/recognize/appliance` response shape.
///
///     {
///       "sample_id": "uuid",
///       "result": {"category": "...", "manufacturer": "...", "confidence": 0.87}
///     }
struct ApplianceRecognitionAPIResponse: Codable {
    let sampleId: String
    let result: Body

    struct Body: Codable {
        let category: String
        let manufacturer: String?
        let confidence: Double
    }

    enum CodingKeys: String, CodingKey {
        case sampleId = "sample_id"
        case result
    }

    func toResult(with image: UIImage?) -> RecognitionResult {
        RecognitionResult(
            category: result.category,
            brand: result.manufacturer,
            confidence: result.confidence,
            capturedImage: image,
            sampleId: sampleId
        )
    }
}
