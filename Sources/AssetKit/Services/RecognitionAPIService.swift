import Foundation
import UIKit
import Foundation
import UIKit

// MARK: - Recognition API Service

/// Service for recognizing appliances via Cloud Function + Gemini Vision
public actor RecognitionAPIService {
    
    // MARK: - Configuration
    
    private let endpoint: URL
    private let maxImageDimension: CGFloat
    private let jpegQuality: CGFloat
    private let timeoutInterval: TimeInterval
    
    // MARK: - Singleton
    
    public static let shared = RecognitionAPIService()
    
    // MARK: - Init
    
    public init(
        endpoint: URL = URL(string: "https://us-central1-chateau-3e605.cloudfunctions.net/recognize_appliance")!,
        maxImageDimension: CGFloat = 1024,
        jpegQuality: CGFloat = 0.75,
        timeoutInterval: TimeInterval = 30
    ) {
        self.endpoint = endpoint
        self.maxImageDimension = maxImageDimension
        self.jpegQuality = jpegQuality
        self.timeoutInterval = timeoutInterval
    }
    
    // MARK: - Public API
    
    /// Recognize an appliance from an image
    /// - Parameter image: The UIImage to analyze
    /// - Returns: RecognitionResult with category, manufacturer, confidence, and the original image
    public func recognize(_ image: UIImage) async throws -> RecognitionResult {
        // 1. Prepare image (resize + compress)
        guard let imageData = prepareImage(image) else {
            throw RecognitionError.imageProcessingFailed
        }
        
        // 2. Encode to base64
        let base64String = imageData.base64EncodedString()
        
        // 3. Build request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval
        
        let body = ["image_base64": base64String]
        request.httpBody = try JSONEncoder().encode(body)
        
        // 4. Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 5. Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RecognitionError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(RecognitionAPIResponse.self, from: data),
               let errorMessage = errorResponse.error {
                throw RecognitionError.serverError(errorMessage)
            }
            throw RecognitionError.httpError(httpResponse.statusCode)
        }
        
        // 6. Parse result and attach original image
        let apiResponse = try JSONDecoder().decode(RecognitionAPIResponse.self, from: data)
        return apiResponse.toResult(with: image)
    }
    
    // MARK: - Image Processing
    
    private func prepareImage(_ image: UIImage) -> Data? {
        // Resize if needed
        let resized = image.resized(toFit: maxImageDimension)
        
        // Convert to JPEG
        return resized.jpegData(compressionQuality: jpegQuality)
    }
}

// MARK: - Errors

public enum RecognitionError: LocalizedError {
    case imageProcessingFailed
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    
    public var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process image for upload"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server returned error code \(code)"
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /// Resize image to fit within maxDimension, preserving aspect ratio
    func resized(toFit maxDimension: CGFloat) -> UIImage {
        let currentMax = max(size.width, size.height)
        
        // No resize needed
        guard currentMax > maxDimension else { return self }
        
        let scale = maxDimension / currentMax
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
