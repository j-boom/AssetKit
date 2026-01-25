//
//  LabelScanResult.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/24/26.
//

import Foundation
import UIKit

/// Field extracted from OCR with optional bounding box for training
public struct OCRField: Codable, Sendable, Equatable {
    public let text: String
    public let confidence: Double
    public let boundingBox: CGRect?  // Normalized 0-1 coordinates for training
    
    public init(text: String, confidence: Double = 1.0, boundingBox: CGRect? = nil) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
    
    // Custom Codable for CGRect
    enum CodingKeys: String, CodingKey {
        case text, confidence, boundingBox
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        confidence = try container.decode(Double.self, forKey: .confidence)
        if let boxDict = try container.decodeIfPresent([String: Double].self, forKey: .boundingBox) {
            boundingBox = CGRect(
                x: boxDict["x"] ?? 0,
                y: boxDict["y"] ?? 0,
                width: boxDict["width"] ?? 0,
                height: boxDict["height"] ?? 0
            )
        } else {
            boundingBox = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(confidence, forKey: .confidence)
        if let box = boundingBox {
            let boxDict: [String: Double] = [
                "x": box.origin.x,
                "y": box.origin.y,
                "width": box.size.width,
                "height": box.size.height
            ]
            try container.encode(boxDict, forKey: .boundingBox)
        }
    }
}

/// Collection of OCR-extracted fields from a label scan
public struct OCRFields: Codable, Sendable, Equatable {
    public var modelNumber: OCRField?
    public var serialNumber: OCRField?
    public var manufacturer: OCRField?
    public var manufactureDate: OCRField?
    public var voltage: OCRField?
    public var wattage: OCRField?
    
    /// Raw OCR text for training/debugging
    public var rawText: String?
    
    public init(
        modelNumber: OCRField? = nil,
        serialNumber: OCRField? = nil,
        manufacturer: OCRField? = nil,
        manufactureDate: OCRField? = nil,
        voltage: OCRField? = nil,
        wattage: OCRField? = nil,
        rawText: String? = nil
    ) {
        self.modelNumber = modelNumber
        self.serialNumber = serialNumber
        self.manufacturer = manufacturer
        self.manufactureDate = manufactureDate
        self.voltage = voltage
        self.wattage = wattage
        self.rawText = rawText
    }
    
    /// Check if minimum required fields are captured
    public var hasMinimumData: Bool {
        modelNumber != nil || serialNumber != nil
    }
}

/// Result from the guided label scan flow
public struct LabelScanResult: Equatable {
    public let labelImage: UIImage
    public let ocrFields: OCRFields
    public var labelLocation: LabelLocation?
    public let labelLocationSource: LabelLocationSource
    
    public init(
        labelImage: UIImage,
        ocrFields: OCRFields,
        labelLocation: LabelLocation? = nil,
        labelLocationSource: LabelLocationSource = .pending
    ) {
        self.labelImage = labelImage
        self.ocrFields = ocrFields
        self.labelLocation = labelLocation
        self.labelLocationSource = labelLocationSource
    }
}

/// How the label location was determined
public enum LabelLocationSource: String, Codable, Sendable {
    case userSelected = "user_selected"   // User picked from list
    case inferred = "inferred"             // AI/heuristics guessed
    case skipped = "skipped"               // User skipped, enough data exists
    case pending = "pending"               // Not yet determined
}
