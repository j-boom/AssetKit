//
//  BundledKnowledgeProvider.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//

import Foundation
import CastleMindrModels

/// Provides bundled seed data for offline use
public struct BundledKnowledgeProvider: KnowledgeProvider {
    
    public init() {}
    
    public func fetchCategories() async throws -> [CategoryKnowledge] {
        [
            CategoryKnowledge(
                category: .refrigerator,
                displayName: "Refrigerator",
                icon: "refrigerator.fill",
                commonManufacturers: ["samsung", "lg", "whirlpool", "ge", "frigidaire", "kitchenaid"],
                labelLocations: [
                    LabelLocationHint(position: LabelLocation.insideLeftDoor.rawValue, instructions: "Open the refrigerator door and look on the inside wall, usually on the left side near the top.", probability: 0.55),
                    LabelLocationHint(position: LabelLocation.insideRightDoor.rawValue, instructions: "Open the refrigerator door and look on the inside wall on the right side.", probability: 0.20),
                    LabelLocationHint(position: LabelLocation.backPanel.rawValue, instructions: "Check the back of the refrigerator near the bottom.", probability: 0.10),
                    LabelLocationHint(position: LabelLocation.sideLeft.rawValue, instructions: "Check the left side panel of the refrigerator.", probability: 0.05),
                    LabelLocationHint(position: LabelLocation.onCompressor.rawValue, instructions: "Look on or near the compressor at the back bottom of the unit.", probability: 0.10)
                ],
                fieldPatterns: [
                    FieldPattern(fieldName: "model", regex: "^[A-Z]{2,4}[0-9]{2,5}[A-Z0-9]*$", labelHints: ["Model", "Model No", "MOD"]),
                    FieldPattern(fieldName: "serial", regex: "^[A-Z0-9]{10,20}$", labelHints: ["Serial", "S/N", "SER"])
                ]
            ),
            CategoryKnowledge(
                category: .washer,
                displayName: "Washing Machine",
                icon: "washer.fill",
                commonManufacturers: ["samsung", "lg", "whirlpool", "ge", "maytag", "speed queen"],
                labelLocations: [
                    LabelLocationHint(position: LabelLocation.insideFrame.rawValue, instructions: "Open the washer door and look around the door frame opening.", probability: 0.50),
                    LabelLocationHint(position: LabelLocation.backPanel.rawValue, instructions: "Check the back panel of the washer.", probability: 0.20),
                    LabelLocationHint(position: LabelLocation.underLid.rawValue, instructions: "For top-loaders, lift the lid and check underneath.", probability: 0.15),
                    LabelLocationHint(position: LabelLocation.topEdge.rawValue, instructions: "Check the top edge of the washer opening.", probability: 0.10),
                    LabelLocationHint(position: LabelLocation.sideLeft.rawValue, instructions: "Check the left side panel.", probability: 0.05)
                ],
                fieldPatterns: [
                    FieldPattern(fieldName: "model", regex: "^[A-Z]{2,4}[0-9]{3,5}[A-Z0-9]*$", labelHints: ["Model", "Model No", "MOD"]),
                    FieldPattern(fieldName: "serial", regex: "^[A-Z0-9]{8,16}$", labelHints: ["Serial", "S/N", "SER"])
                ]
            ),
            CategoryKnowledge(
                category: .dryer,
                displayName: "Dryer",
                icon: "dryer.fill",
                commonManufacturers: ["samsung", "lg", "whirlpool", "ge", "maytag", "speed queen"],
                labelLocations: [
                    LabelLocationHint(position: LabelLocation.insideFrame.rawValue, instructions: "Open the door and look on the inside of the door frame.", probability: 0.45),
                    LabelLocationHint(position: LabelLocation.insideDoor.rawValue, instructions: "Look on the inside of the door itself.", probability: 0.15),
                    LabelLocationHint(position: LabelLocation.backPanel.rawValue, instructions: "Check the back panel of the unit.", probability: 0.25),
                    LabelLocationHint(position: LabelLocation.topEdge.rawValue, instructions: "Check the top edge near the lint filter area.", probability: 0.10),
                    LabelLocationHint(position: LabelLocation.sideLeft.rawValue, instructions: "Check the left side panel.", probability: 0.05)
                ],
                fieldPatterns: [
                    FieldPattern(fieldName: "model", regex: "^[A-Z]{2,4}[0-9]{3,5}[A-Z0-9]*$", labelHints: ["Model", "Model No", "MOD"]),
                    FieldPattern(fieldName: "serial", regex: "^[A-Z0-9]{8,16}$", labelHints: ["Serial", "S/N", "SER"])
                ]
            ),
            CategoryKnowledge(
                category: .hvac,
                displayName: "HVAC System",
                icon: "air.conditioner.horizontal.fill",
                commonManufacturers: ["carrier", "trane", "lennox", "rheem", "goodman", "american standard"],
                labelLocations: [
                    LabelLocationHint(position: LabelLocation.behindAccessPanel.rawValue, instructions: "Open the access panel on the unit.", probability: 0.50),
                    LabelLocationHint(position: LabelLocation.sideLeft.rawValue, instructions: "Check the side panel near the electrical connections.", probability: 0.15),
                    LabelLocationHint(position: LabelLocation.sideRight.rawValue, instructions: "Check the right side panel.", probability: 0.15),
                    LabelLocationHint(position: LabelLocation.nearFilter.rawValue, instructions: "Look near the filter slot area.", probability: 0.10),
                    LabelLocationHint(position: LabelLocation.frontPanel.rawValue, instructions: "Check the front panel near the controls.", probability: 0.10)
                ],
                fieldPatterns: [
                    FieldPattern(fieldName: "model", regex: "^[A-Z0-9]{6,15}$", labelHints: ["Model", "M/N", "MOD"]),
                    FieldPattern(fieldName: "serial", regex: "^[A-Z0-9]{8,20}$", labelHints: ["Serial", "S/N", "SER"])
                ]
            ),
            CategoryKnowledge(
                category: .waterHeater,
                displayName: "Water Heater",
                icon: "flame.fill",
                commonManufacturers: ["rheem", "ao smith", "bradford white", "state", "whirlpool"],
                labelLocations: [
                    LabelLocationHint(position: LabelLocation.frontPanel.rawValue, instructions: "Look on the front of the unit near the controls.", probability: 0.60),
                    LabelLocationHint(position: LabelLocation.sideLeft.rawValue, instructions: "Check the left side of the tank.", probability: 0.15),
                    LabelLocationHint(position: LabelLocation.sideRight.rawValue, instructions: "Check the right side of the tank.", probability: 0.10),
                    LabelLocationHint(position: LabelLocation.nearPipes.rawValue, instructions: "Look near where the pipes connect at the top.", probability: 0.10),
                    LabelLocationHint(position: LabelLocation.backPanel.rawValue, instructions: "Check the back of the unit.", probability: 0.05)
                ],
                fieldPatterns: [
                    FieldPattern(fieldName: "model", regex: "^[A-Z0-9\\-]{6,20}$", labelHints: ["Model", "M/N", "MOD"]),
                    FieldPattern(fieldName: "serial", regex: "^[A-Z0-9]{8,16}$", labelHints: ["Serial", "S/N", "SER"]),
                    FieldPattern(fieldName: "capacity", regex: "^[0-9]{2,3}\\s*(gal|GAL|gallon)?$", labelHints: ["Capacity", "Gallons", "GAL"])
                ]
            )
        ]
    }
    
    public func fetchManufacturers() async throws -> [ManufacturerKnowledge] {
        [
            ManufacturerKnowledge(
                name: "Samsung",
                categories: [
                    "refrigerator": ManufacturerCategoryOverride(
                        modelPattern: "^RF[0-9]{2}[A-Z][0-9]{4}[A-Z]{2,3}$",
                        serialPattern: "^[A-Z0-9]{11,15}$"
                    ),
                    "washer": ManufacturerCategoryOverride(
                        modelPattern: "^WF[0-9]{2}[A-Z][0-9]{4}[A-Z]{2}$"
                    )
                ]
            ),
            ManufacturerKnowledge(
                name: "LG",
                categories: [
                    "refrigerator": ManufacturerCategoryOverride(
                        modelPattern: "^L[A-Z]{2,3}[0-9]{4,5}[A-Z]{1,2}$"
                    )
                ]
            ),
            ManufacturerKnowledge(
                name: "Whirlpool",
                categories: [
                    "refrigerator": ManufacturerCategoryOverride(
                        modelPattern: "^W[A-Z]{2}[0-9]{5}[A-Z]{2,3}$"
                    ),
                    "washer": ManufacturerCategoryOverride(
                        modelPattern: "^W[A-Z]{2}[0-9]{4,5}[A-Z]{2}$"
                    )
                ]
            )
        ]
    }
}
