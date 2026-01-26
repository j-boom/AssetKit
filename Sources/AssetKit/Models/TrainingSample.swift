//
//  TrainingSample.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/24/26.
//

import Foundation
import UIKit
import CastleMindrModels

/// Training sample captured during asset creation flow
/// Submitted to backend for ML model training
public struct TrainingSample: Codable {
    
    // MARK: - Identification
    
    /// Unique ID for this sample
    public let id: String
    
    /// Timestamp of capture
    public let createdAt: Date
    
    // MARK: - Recognition Data
    
    /// Confirmed category (user-verified)
    public let category: String
    
    /// Confirmed manufacturer (user-verified, optional)
    public let manufacturer: String?
    
    // MARK: - AI Interaction
    
    /// What the AI predicted
    public let aiPredictedCategory: String
    
    /// AI's manufacturer prediction
    public let aiPredictedManufacturer: String?
    
    /// AI confidence score (0-1)
    public let aiConfidence: Double
    
    /// Whether cloud API was used (vs on-device)
    public let wasCloudUsed: Bool
    
    /// User corrected the AI's category prediction
    public let userCorrectedCategory: Bool
    
    /// User corrected the AI's manufacturer prediction
    public let userCorrectedManufacturer: Bool
    
    // MARK: - Item Bounding Box
    
    /// Normalized bounding box (0-1) of the item within the captured image
    /// This is where the user drew the selection box
    public let itemBoundingBox: BoundingBoxDTO?
    
    // MARK: - Label Data
    
    /// Where the label was located
    public let labelLocation: String?
    
    /// How location was determined
    public let labelLocationSource: String  // user_selected, inferred, skipped
    
    /// OCR-extracted fields with bounding boxes
    public let ocrFields: OCRFieldsDTO?
    
    /// Raw OCR text
    public let ocrRawText: String?
    
    // MARK: - Device Context
    
    /// Device model (e.g., "iPhone 15 Pro")
    public let deviceModel: String
    
    /// iOS version
    public let osVersion: String
    
    /// App version
    public let appVersion: String
    
    // MARK: - Init
    
    public init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        category: String,
        manufacturer: String?,
        aiPredictedCategory: String,
        aiPredictedManufacturer: String?,
        aiConfidence: Double,
        wasCloudUsed: Bool,
        userCorrectedCategory: Bool,
        userCorrectedManufacturer: Bool,
        itemBoundingBox: BoundingBoxDTO?,
        labelLocation: String?,
        labelLocationSource: String,
        ocrFields: OCRFieldsDTO?,
        ocrRawText: String?,
        deviceModel: String,
        osVersion: String,
        appVersion: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.category = category
        self.manufacturer = manufacturer
        self.aiPredictedCategory = aiPredictedCategory
        self.aiPredictedManufacturer = aiPredictedManufacturer
        self.aiConfidence = aiConfidence
        self.wasCloudUsed = wasCloudUsed
        self.userCorrectedCategory = userCorrectedCategory
        self.userCorrectedManufacturer = userCorrectedManufacturer
        self.itemBoundingBox = itemBoundingBox
        self.labelLocation = labelLocation
        self.labelLocationSource = labelLocationSource
        self.ocrFields = ocrFields
        self.ocrRawText = ocrRawText
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appVersion = appVersion
    }
}

// MARK: - OCR Fields DTO (for JSON encoding)

public struct OCRFieldsDTO: Codable {
    public let modelNumber: OCRFieldDTO?
    public let serialNumber: OCRFieldDTO?
    public let manufacturer: OCRFieldDTO?
    public let manufactureDate: OCRFieldDTO?
    
    public init(from ocrFields: OCRFields) {
        self.modelNumber = ocrFields.modelNumber.map { OCRFieldDTO(from: $0) }
        self.serialNumber = ocrFields.serialNumber.map { OCRFieldDTO(from: $0) }
        self.manufacturer = ocrFields.manufacturer.map { OCRFieldDTO(from: $0) }
        self.manufactureDate = ocrFields.manufactureDate.map { OCRFieldDTO(from: $0) }
    }
}

public struct OCRFieldDTO: Codable {
    public let text: String
    public let confidence: Double
    public let boundingBox: BoundingBoxDTO?
    
    public init(from field: OCRField) {
        self.text = field.text
        self.confidence = field.confidence
        self.boundingBox = field.boundingBox.map { BoundingBoxDTO(from: $0) }
    }
}

public struct BoundingBoxDTO: Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    
    public init(from rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }
    
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

// MARK: - Builder

extension TrainingSample {
    
    /// Build training sample from capture flow data
    public static func build(
        recognition: RecognitionResult,
        confirmedCategory: ApplianceCategory,
        confirmedManufacturer: String?,
        labelScan: LabelScanResult?
    ) -> TrainingSample {
        
        let deviceInfo = DeviceInfo.current
        
        return TrainingSample(
            category: confirmedCategory.rawValue,
            manufacturer: confirmedManufacturer,
            aiPredictedCategory: recognition.category.rawValue,
            aiPredictedManufacturer: recognition.manufacturer,
            aiConfidence: recognition.confidence,
            wasCloudUsed: true,  // For now, always cloud
            userCorrectedCategory: recognition.category != confirmedCategory,
            userCorrectedManufacturer: recognition.manufacturer != confirmedManufacturer,
            itemBoundingBox: recognition.boundingBox.map { BoundingBoxDTO(from: $0) },
            labelLocation: labelScan?.labelLocation?.rawValue,
            labelLocationSource: labelScan?.labelLocationSource.rawValue ?? "skipped",
            ocrFields: labelScan.map { OCRFieldsDTO(from: $0.ocrFields) },
            ocrRawText: labelScan?.ocrFields.rawText,
            deviceModel: deviceInfo.model,
            osVersion: deviceInfo.osVersion,
            appVersion: deviceInfo.appVersion
        )
    }
}

// MARK: - Device Info Helper

private struct DeviceInfo {
    let model: String
    let osVersion: String
    let appVersion: String
    
    static var current: DeviceInfo {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let model = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        
        return DeviceInfo(model: model, osVersion: osVersion, appVersion: appVersion)
    }
}
