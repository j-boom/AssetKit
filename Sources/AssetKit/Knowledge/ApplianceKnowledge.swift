//
//  ApplianceKnowledge.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//
//

import Foundation
import CastleMindrModels

// MARK: - Label Location Hint (guidance for where to look)

public struct LabelLocationHint: Codable, Sendable {
    public let position: String
    public let instructions: String
    public let probability: Double
    
    public init(position: String, instructions: String, probability: Double) {
        self.position = position
        self.instructions = instructions
        self.probability = probability
    }
}

// MARK: - Field Pattern

public struct FieldPattern: Codable, Sendable {
    public let fieldName: String
    public let regex: String
    public let labelHints: [String]
    
    public init(fieldName: String, regex: String, labelHints: [String]) {
        self.fieldName = fieldName
        self.regex = regex
        self.labelHints = labelHints
    }
}

// MARK: - Category Knowledge

public struct CategoryKnowledge: Codable, Identifiable, Sendable {
    public var id: String { category.rawValue }
    public let category: ApplianceCategory
    public let displayName: String
    public let icon: String?
    public let commonManufacturers: [String]
    public let labelLocations: [LabelLocationHint]
    public let fieldPatterns: [FieldPattern]
    
    public init(
        category: ApplianceCategory,
        displayName: String,
        icon: String? = nil,
        commonManufacturers: [String] = [],
        labelLocations: [LabelLocationHint] = [],
        fieldPatterns: [FieldPattern] = []
    ) {
        self.category = category
        self.displayName = displayName
        self.icon = icon
        self.commonManufacturers = commonManufacturers
        self.labelLocations = labelLocations
        self.fieldPatterns = fieldPatterns
    }
}

// MARK: - Manufacturer Knowledge

public struct ManufacturerKnowledge: Codable, Identifiable, Sendable {
    public var id: String { name.lowercased() }
    public let name: String
    public let categories: [String: ManufacturerCategoryOverride]
    
    public init(name: String, categories: [String: ManufacturerCategoryOverride] = [:]) {
        self.name = name
        self.categories = categories
    }
    
    public func override(for category: ApplianceCategory) -> ManufacturerCategoryOverride? {
        categories[category.rawValue]
    }
}

public struct ManufacturerCategoryOverride: Codable, Sendable {
    public let labelLocations: [LabelLocationHint]?
    public let modelPattern: String?
    public let serialPattern: String?
    
    public init(
        labelLocations: [LabelLocationHint]? = nil,
        modelPattern: String? = nil,
        serialPattern: String? = nil
    ) {
        self.labelLocations = labelLocations
        self.modelPattern = modelPattern
        self.serialPattern = serialPattern
    }
}

// MARK: - Knowledge Provider Protocol

public protocol KnowledgeProvider: Sendable {
    func fetchCategories() async throws -> [CategoryKnowledge]
    func fetchManufacturers() async throws -> [ManufacturerKnowledge]
}

// MARK: - Knowledge Base

@MainActor
public final class ApplianceKnowledgeBase: ObservableObject {
    
    @Published public private(set) var categories: [ApplianceCategory: CategoryKnowledge] = [:]
    @Published public private(set) var manufacturers: [String: ManufacturerKnowledge] = [:]
    @Published public private(set) var isLoaded = false
    
    private let provider: KnowledgeProvider
    
    public init(provider: KnowledgeProvider) {
        self.provider = provider
    }
    
    // MARK: - Loading
    
    public func loadIfNeeded() async {
        guard !isLoaded else { return }
        
        do {
            let fetchedCategories = try await provider.fetchCategories()
            let fetchedManufacturers = try await provider.fetchManufacturers()
            
            self.categories = Dictionary(uniqueKeysWithValues: fetchedCategories.map { ($0.category, $0) })
            self.manufacturers = Dictionary(uniqueKeysWithValues: fetchedManufacturers.map { ($0.id, $0) })
            self.isLoaded = true
        } catch {
            print("Failed to load appliance knowledge: \(error)")
        }
    }
    
    // MARK: - Lookup
    
    public func knowledge(for category: ApplianceCategory) -> CategoryKnowledge? {
        categories[category]
    }
    
    public func knowledge(for manufacturerName: String) -> ManufacturerKnowledge? {
        manufacturers[manufacturerName.lowercased()]
    }
    
    public func allCategories() -> [CategoryKnowledge] {
        Array(categories.values)
    }
    
    public func labelLocationHints(for category: ApplianceCategory, manufacturer: String? = nil) -> [LabelLocationHint] {
        // Check for manufacturer-specific override first
        if let mfr = manufacturer,
           let mfrKnowledge = knowledge(for: mfr),
           let override = mfrKnowledge.override(for: category),
           let locations = override.labelLocations {
            return locations
        }
        
        // Fall back to category default
        return knowledge(for: category)?.labelLocations ?? []
    }
    
    public func guidancePrompt(for category: ApplianceCategory, manufacturer: String? = nil) -> String {
        let hints = labelLocationHints(for: category, manufacturer: manufacturer)
        guard let topHint = hints.first else {
            return "Look for a label with model and serial number information."
        }
        return topHint.instructions
    }
}

