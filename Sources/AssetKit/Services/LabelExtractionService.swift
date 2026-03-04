//
//  LabelExtractionService.swift
//  AssetKit
//
//  Created by Jim Bergren on 2/15/26.
//

import Foundation
import UIKit
import CastleMindrModels

// MARK: - Label Extraction Service

/// Service for extracting structured fields from appliance label images
/// via Cloud Function + Gemini Vision. Falls back to heuristic parsing on failure.
public actor LabelExtractionService {

    // MARK: - Configuration

    private let endpoint: URL
    private let maxImageDimension: CGFloat
    private let jpegQuality: CGFloat
    private let timeoutInterval: TimeInterval

    // MARK: - Singleton

    public static let shared = LabelExtractionService()

    // MARK: - Init

    public init(
        endpoint: URL = URL(string: "https://us-central1-chateau-3e605.cloudfunctions.net/extract_label_fields")!,
        maxImageDimension: CGFloat = 1024,
        jpegQuality: CGFloat = 0.80,
        timeoutInterval: TimeInterval = 30
    ) {
        self.endpoint = endpoint
        self.maxImageDimension = maxImageDimension
        self.jpegQuality = jpegQuality
        self.timeoutInterval = timeoutInterval
    }

    // MARK: - Public API

    /// Extract structured fields from a label image using Gemini
    /// - Parameters:
    ///   - image: The label photo (UIImage)
    ///   - ocrText: Raw OCR text from Vision framework (provides additional context)
    ///   - category: The appliance category (helps Gemini understand field formats)
    ///   - brand: The brand detected during recognition (helps disambiguate manufacturer vs brand)
    /// - Returns: LabelExtractionResult with parsed fields and confidence
    public func extractFields(
        image: UIImage,
        ocrText: String?,
        category: ApplianceCategory,
        brand: String?
    ) async throws -> LabelExtractionResult {
        // 1. Prepare image
        guard let imageData = prepareImage(image) else {
            throw LabelExtractionError.imageProcessingFailed
        }

        let base64String = imageData.base64EncodedString()

        // 2. Build request body
        var body: [String: Any] = [
            "image_base64": base64String,
            "appliance_category": category.rawValue
        ]

        if let ocrText, !ocrText.isEmpty {
            body["ocr_text"] = ocrText
        }

        if let brand, !brand.isEmpty {
            body["brand"] = brand
        }

        // 3. Build HTTP request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // 4. Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        // 5. Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LabelExtractionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorJson["error"] as? String {
                throw LabelExtractionError.serverError(errorMessage)
            }
            throw LabelExtractionError.httpError(httpResponse.statusCode)
        }

        // 6. Parse response
        let apiResponse = try JSONDecoder().decode(LabelExtractionAPIResponse.self, from: data)
        return apiResponse.toResult()
    }

    // MARK: - Image Processing

    private func prepareImage(_ image: UIImage) -> Data? {
        let resized = image.resized(toFit: maxImageDimension)
        return resized.jpegData(compressionQuality: jpegQuality)
    }
}

// MARK: - Extraction Result

/// Structured result from Gemini label extraction
public struct LabelExtractionResult {
    public let modelNumber: String?
    public let serialNumber: String?
    public let manufacturer: String?
    public let brand: String?
    public let manufactureDate: String?
    public let voltage: String?
    public let wattage: String?
    public let typeCode: String?
    public let additionalNotes: String?
    public let confidence: Double

    /// Convert to OCRFields for downstream consumption (zero changes needed in the rest of the pipeline)
    public func toOCRFields(rawText: String?) -> OCRFields {
        OCRFields(
            modelNumber: modelNumber.map { OCRField(text: $0, confidence: confidence) },
            serialNumber: serialNumber.map { OCRField(text: $0, confidence: confidence) },
            brand: brand.map { OCRField(text: $0, confidence: confidence) },
            manufacturer: manufacturer.map { OCRField(text: $0, confidence: confidence) },
            manufactureDate: manufactureDate.map { OCRField(text: $0, confidence: confidence) },
            voltage: voltage.map { OCRField(text: $0, confidence: confidence) },
            wattage: wattage.map { OCRField(text: $0, confidence: confidence) },
            rawText: rawText
        )
    }
}

// MARK: - API Response (for decoding JSON)

/// Internal struct for decoding the Cloud Function response
struct LabelExtractionAPIResponse: Codable {
    let modelNumber: String?
    let serialNumber: String?
    let manufacturer: String?
    let brand: String?
    let manufactureDate: String?
    let voltage: String?
    let wattage: String?
    let typeCode: String?
    let additionalNotes: String?
    let confidence: Double?

    enum CodingKeys: String, CodingKey {
        case modelNumber = "model_number"
        case serialNumber = "serial_number"
        case manufacturer
        case brand
        case manufactureDate = "manufacture_date"
        case voltage
        case wattage
        case typeCode = "type_code"
        case additionalNotes = "additional_notes"
        case confidence
    }

    func toResult() -> LabelExtractionResult {
        LabelExtractionResult(
            modelNumber: modelNumber,
            serialNumber: serialNumber,
            manufacturer: manufacturer,
            brand: brand,
            manufactureDate: manufactureDate,
            voltage: voltage,
            wattage: wattage,
            typeCode: typeCode,
            additionalNotes: additionalNotes,
            confidence: confidence ?? 0.8
        )
    }
}

// MARK: - Errors

public enum LabelExtractionError: LocalizedError {
    case imageProcessingFailed
    case invalidResponse
    case httpError(Int)
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process label image for upload"
        case .invalidResponse:
            return "Invalid response from label extraction service"
        case .httpError(let code):
            return "Label extraction server returned error code \(code)"
        case .serverError(let message):
            return message
        }
    }
}
