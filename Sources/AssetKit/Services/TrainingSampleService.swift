import Foundation
import UIKit

/// Service to submit training samples to the backend
public actor TrainingSampleService {
    
    private let endpoint: URL
    private let maxImageDimension: CGFloat
    private let jpegQuality: CGFloat
    private let timeoutInterval: TimeInterval
    
    public static let shared = TrainingSampleService()
    
    public init(
        endpoint: URL = URL(string: "https://us-central1-chateau-3e605.cloudfunctions.net/submit_training_sample")!,
        maxImageDimension: CGFloat = 1024,
        jpegQuality: CGFloat = 0.75,
        timeoutInterval: TimeInterval = 60
    ) {
        self.endpoint = endpoint
        self.maxImageDimension = maxImageDimension
        self.jpegQuality = jpegQuality
        self.timeoutInterval = timeoutInterval
    }
    
    // MARK: - Public API
    
    /// Submit a training sample with images
    public func submit(
        sample: TrainingSample,
        applianceImage: UIImage?,
        labelImage: UIImage?
    ) async throws -> SubmitResult {
        
        // Build request body
        var body: [String: Any] = encodeSample(sample)
        
        if let applianceImage {
            body["applianceImageBase64"] = encodeImage(applianceImage)
        }
        
        if let labelImage {
            body["labelImageBase64"] = encodeImage(labelImage)
        }
        
        // Build request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Send
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TrainingSampleError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorJson["error"] as? String {
                throw TrainingSampleError.serverError(errorMessage)
            }
            throw TrainingSampleError.httpError(httpResponse.statusCode)
        }
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sampleId = json["sampleId"] as? String else {
            throw TrainingSampleError.invalidResponse
        }
        
        return SubmitResult(
            sampleId: sampleId,
            applianceImageUrl: json["applianceImageUrl"] as? String,
            labelImageUrl: json["labelImageUrl"] as? String
        )
    }
    
    // MARK: - Encoding
    
    private func encodeSample(_ sample: TrainingSample) -> [String: Any] {
        var dict: [String: Any] = [
            "id": sample.id,
            "createdAt": ISO8601DateFormatter().string(from: sample.createdAt),
            "category": sample.category,
            "aiPredictedCategory": sample.aiPredictedCategory,
            "aiConfidence": sample.aiConfidence,
            "wasCloudUsed": sample.wasCloudUsed,
            "userCorrectedCategory": sample.userCorrectedCategory,
            "userCorrectedManufacturer": sample.userCorrectedManufacturer,
            "labelLocationSource": sample.labelLocationSource,
            "deviceModel": sample.deviceModel,
            "osVersion": sample.osVersion,
            "appVersion": sample.appVersion
        ]
        
        if let manufacturer = sample.manufacturer {
            dict["manufacturer"] = manufacturer
        }
        if let aiPredictedManufacturer = sample.aiPredictedManufacturer {
            dict["aiPredictedManufacturer"] = aiPredictedManufacturer
        }
        if let itemBoundingBox = sample.itemBoundingBox {
            dict["itemBoundingBox"] = [
                "x": itemBoundingBox.x,
                "y": itemBoundingBox.y,
                "width": itemBoundingBox.width,
                "height": itemBoundingBox.height
            ]
        }
        if let labelLocation = sample.labelLocation {
            dict["labelLocation"] = labelLocation
        }
        if let ocrRawText = sample.ocrRawText {
            dict["ocrRawText"] = ocrRawText
        }
        if let ocrFields = sample.ocrFields {
            dict["ocrFields"] = encodeOCRFields(ocrFields)
        }
        
        return dict
    }
    
    private func encodeOCRFields(_ fields: OCRFieldsDTO) -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let f = fields.modelNumber { dict["modelNumber"] = encodeOCRField(f) }
        if let f = fields.serialNumber { dict["serialNumber"] = encodeOCRField(f) }
        if let f = fields.manufacturer { dict["manufacturer"] = encodeOCRField(f) }
        if let f = fields.manufactureDate { dict["manufactureDate"] = encodeOCRField(f) }
        
        return dict
    }
    
    private func encodeOCRField(_ field: OCRFieldDTO) -> [String: Any] {
        var dict: [String: Any] = [
            "text": field.text,
            "confidence": field.confidence
        ]
        if let box = field.boundingBox {
            dict["boundingBox"] = [
                "x": box.x,
                "y": box.y,
                "width": box.width,
                "height": box.height
            ]
        }
        return dict
    }
    
    private func encodeImage(_ image: UIImage) -> String? {
        let resized = image.resized(toFit: maxImageDimension)
        guard let data = resized.jpegData(compressionQuality: jpegQuality) else {
            return nil
        }
        return data.base64EncodedString()
    }
}

// MARK: - Result

public struct SubmitResult: Sendable {
    public let sampleId: String
    public let applianceImageUrl: String?
    public let labelImageUrl: String?
}

// MARK: - Errors

public enum TrainingSampleError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server returned error code \(code)"
        case .serverError(let message):
            return message
        }
    }
}
