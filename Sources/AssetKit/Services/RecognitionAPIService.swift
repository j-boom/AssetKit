import Foundation
import UIKit

// MARK: - Recognition API Service

/// Service for recognizing appliances via the FastAPI backend,
/// which proxies to the Gemini Vision Cloud Function and enforces caps.
public actor RecognitionAPIService {

    // MARK: - Configuration

    private var baseURL: URL?
    private var authToken: String?
    private let maxImageDimension: CGFloat
    private let jpegQuality: CGFloat
    private let timeoutInterval: TimeInterval

    /// Called on the main actor when a 429 (cap reached) response is received.
    /// The host app sets this to present the upgrade paywall.
    private var onCapReached: (@MainActor @Sendable () -> Void)?

    /// Set the callback that fires when asset ingestion cap is reached (429).
    public func setCapReachedCallback(_ callback: @escaping @MainActor @Sendable () -> Void) {
        self.onCapReached = callback
    }

    // MARK: - Singleton

    public static let shared = RecognitionAPIService()

    // MARK: - Init

    public init(
        maxImageDimension: CGFloat = 1024,
        jpegQuality: CGFloat = 0.75,
        timeoutInterval: TimeInterval = 30
    ) {
        self.maxImageDimension = maxImageDimension
        self.jpegQuality = jpegQuality
        self.timeoutInterval = timeoutInterval
    }

    /// Configure the service with the backend base URL and auth token.
    /// Call this after auth state changes (e.g., from AuthViewModel).
    ///
    /// - Parameters:
    ///   - baseURL: The FastAPI base URL (e.g., "http://localhost:8000/api").
    ///   - authToken: Firebase ID token for authorization.
    public func configure(baseURL: URL, authToken: String) {
        self.baseURL = baseURL
        self.authToken = authToken
    }

    // MARK: - Public API

    /// Recognize an appliance from an image via the backend proxy.
    /// - Parameter image: The UIImage to analyze
    /// - Returns: RecognitionResult with category, manufacturer, confidence, and the original image
    public func recognize(_ image: UIImage) async throws -> RecognitionResult {
        guard let baseURL = baseURL, let authToken = authToken else {
            throw RecognitionError.serverError("Recognition service not configured. Please sign in.")
        }

        // 1. Prepare image (resize + compress)
        guard let imageData = prepareImage(image) else {
            throw RecognitionError.imageProcessingFailed
        }

        // 2. Encode to base64
        let base64String = imageData.base64EncodedString()

        // 3. Build request to FastAPI proxy
        let endpoint = baseURL.appendingPathComponent("cf/recognize")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
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
            if httpResponse.statusCode == 429 {
                if let callback = onCapReached {
                    await callback()
                }
                throw RecognitionError.capReached
            }
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(RecognitionAPIResponse.self, from: data),
               let errorMessage = errorResponse.error {
                throw RecognitionError.serverError(errorMessage)
            }
            throw RecognitionError.httpError(httpResponse.statusCode)
        }

        // 6. Parse result and attach original image
        let apiResponse = try JSONDecoder().decode(RecognitionAPIResponse.self, from: data)
        print("API Response: category=\(apiResponse.category), manufacturer=\(String(describing: apiResponse.manufacturer)), confidence=\(apiResponse.confidence)")
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
    case capReached

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
        case .capReached:
            return "You've reached your AI recognition limit. Upgrade your plan for more access."
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
