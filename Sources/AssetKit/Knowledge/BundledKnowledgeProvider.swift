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
            ),

            // --- Categories with display names (label locations added as data grows) ---

            // Kitchen
            CategoryKnowledge(category: .freezer, displayName: "Freezer",
                              commonManufacturers: ["samsung", "lg", "ge", "frigidaire", "whirlpool"]),
            CategoryKnowledge(category: .dishwasher, displayName: "Dishwasher", icon: "dishwasher.fill",
                              commonManufacturers: ["bosch", "samsung", "lg", "whirlpool", "kitchenaid", "ge"]),
            CategoryKnowledge(category: .oven, displayName: "Oven",
                              commonManufacturers: ["ge", "samsung", "lg", "whirlpool", "kitchenaid", "bosch"]),
            CategoryKnowledge(category: .stove, displayName: "Stove",
                              commonManufacturers: ["ge", "samsung", "lg", "whirlpool", "kitchenaid"]),
            CategoryKnowledge(category: .cooktop, displayName: "Cooktop",
                              commonManufacturers: ["ge", "bosch", "samsung", "kitchenaid", "frigidaire"]),
            CategoryKnowledge(category: .range, displayName: "Range",
                              commonManufacturers: ["ge", "samsung", "lg", "whirlpool", "kitchenaid"]),
            CategoryKnowledge(category: .microwave, displayName: "Microwave",
                              commonManufacturers: ["samsung", "lg", "ge", "whirlpool", "panasonic"]),
            CategoryKnowledge(category: .rangeHood, displayName: "Range Hood",
                              commonManufacturers: ["broan", "zephyr", "ge", "whirlpool", "kitchenaid"]),
            CategoryKnowledge(category: .garbageDisposal, displayName: "Garbage Disposal",
                              commonManufacturers: ["insinkerator", "waste king", "ge", "moen"]),
            CategoryKnowledge(category: .trashCompactor, displayName: "Trash Compactor",
                              commonManufacturers: ["ge", "kitchenaid", "whirlpool"]),
            CategoryKnowledge(category: .iceMaker, displayName: "Ice Maker",
                              commonManufacturers: ["ge", "samsung", "scotsman", "whirlpool"]),
            CategoryKnowledge(category: .wineCooler, displayName: "Wine Cooler",
                              commonManufacturers: ["newair", "wine enthusiast", "avallon", "kalamera"]),

            // Climate
            CategoryKnowledge(category: .furnace, displayName: "Furnace",
                              commonManufacturers: ["carrier", "trane", "lennox", "rheem", "goodman"]),
            CategoryKnowledge(category: .airConditioner, displayName: "Air Conditioner",
                              commonManufacturers: ["carrier", "trane", "lennox", "goodman", "rheem"]),
            CategoryKnowledge(category: .waterSoftener, displayName: "Water Softener",
                              commonManufacturers: ["ge", "culligan", "whirlpool", "fleck"]),
            CategoryKnowledge(category: .sumpPump, displayName: "Sump Pump",
                              commonManufacturers: ["wayne", "zoeller", "liberty", "superior"]),
            CategoryKnowledge(category: .dehumidifier, displayName: "Dehumidifier",
                              commonManufacturers: ["frigidaire", "ge", "hisense", "honeywell"]),
            CategoryKnowledge(category: .humidifier, displayName: "Humidifier",
                              commonManufacturers: ["honeywell", "aprilaire", "levoit", "vicks"]),
            CategoryKnowledge(category: .thermostat, displayName: "Thermostat",
                              commonManufacturers: ["nest", "ecobee", "honeywell", "emerson"]),

            // Fixtures
            CategoryKnowledge(category: .toilet, displayName: "Toilet",
                              commonManufacturers: ["toto", "kohler", "american standard"]),
            CategoryKnowledge(category: .sink, displayName: "Sink",
                              commonManufacturers: ["kohler", "moen", "delta", "american standard"]),
            CategoryKnowledge(category: .tub, displayName: "Bathtub",
                              commonManufacturers: ["kohler", "american standard", "jacuzzi"]),
            CategoryKnowledge(category: .shower, displayName: "Shower",
                              commonManufacturers: ["kohler", "moen", "delta"]),
            CategoryKnowledge(category: .faucet, displayName: "Faucet",
                              commonManufacturers: ["moen", "delta", "kohler", "pfister"]),

            // Lighting & Electrical
            CategoryKnowledge(category: .ceilingFan, displayName: "Ceiling Fan",
                              commonManufacturers: ["hunter", "hampton bay", "casablanca", "minka aire"]),
            CategoryKnowledge(category: .lightFixture, displayName: "Light Fixture",
                              commonManufacturers: ["progress", "sea gull", "kichler", "hampton bay"]),
            CategoryKnowledge(category: .chandelier, displayName: "Chandelier",
                              commonManufacturers: ["kichler", "progress", "sea gull", "quoizel"]),

            // Electronics
            CategoryKnowledge(category: .television, displayName: "Television",
                              commonManufacturers: ["samsung", "lg", "sony", "tcl", "vizio", "hisense"]),
            CategoryKnowledge(category: .soundbar, displayName: "Soundbar",
                              commonManufacturers: ["sonos", "samsung", "bose", "lg", "vizio"]),
            CategoryKnowledge(category: .projector, displayName: "Projector",
                              commonManufacturers: ["epson", "benq", "optoma", "sony"]),

            // Outdoor
            CategoryKnowledge(category: .garageDoor, displayName: "Garage Door Opener",
                              commonManufacturers: ["chamberlain", "liftmaster", "genie", "craftsman"]),
            CategoryKnowledge(category: .grill, displayName: "Grill",
                              commonManufacturers: ["weber", "traeger", "char-broil", "napoleon"]),
            CategoryKnowledge(category: .poolPump, displayName: "Pool Pump",
                              commonManufacturers: ["hayward", "pentair", "intex", "jandy"]),
            CategoryKnowledge(category: .lawnMower, displayName: "Lawn Mower",
                              commonManufacturers: ["john deere", "husqvarna", "honda", "toro"]),
            CategoryKnowledge(category: .sprinklerSystem, displayName: "Sprinkler System",
                              commonManufacturers: ["rain bird", "hunter", "orbit", "rachio"]),
            CategoryKnowledge(category: .hotTub, displayName: "Hot Tub",
                              commonManufacturers: ["jacuzzi", "hot spring", "sundance", "bullfrog"]),

            // Safety
            CategoryKnowledge(category: .smokeDetector, displayName: "Smoke Detector",
                              commonManufacturers: ["first alert", "kidde", "nest", "google"]),
            CategoryKnowledge(category: .securityCamera, displayName: "Security Camera",
                              commonManufacturers: ["ring", "arlo", "nest", "wyze", "blink"]),
            CategoryKnowledge(category: .doorbell, displayName: "Doorbell",
                              commonManufacturers: ["ring", "nest", "arlo", "eufy"]),
            CategoryKnowledge(category: .fireplace, displayName: "Fireplace",
                              commonManufacturers: ["napoleon", "heat & glo", "lennox", "regency"]),

            // Furniture
            CategoryKnowledge(category: .bed, displayName: "Bed"),
            CategoryKnowledge(category: .couch, displayName: "Couch"),
            CategoryKnowledge(category: .table, displayName: "Table"),
            CategoryKnowledge(category: .diningTable, displayName: "Dining Table"),
            CategoryKnowledge(category: .desk, displayName: "Desk"),
            CategoryKnowledge(category: .chair, displayName: "Chair"),
            CategoryKnowledge(category: .dresser, displayName: "Dresser"),
            CategoryKnowledge(category: .bookshelf, displayName: "Bookshelf"),
            CategoryKnowledge(category: .nightstand, displayName: "Nightstand"),
            CategoryKnowledge(category: .cabinet, displayName: "Cabinet"),
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
