//
//  ConfirmRecognitionView.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//

import SwiftUI
import CastleMindrModels

public struct ConfirmRecognitionView: View {
    let result: RecognitionResult
    let onConfirm: (RecognitionResult) -> Void
    let onRetry: () -> Void
    let onSkipToForm: () -> Void
    
    @EnvironmentObject private var knowledgeBase: ApplianceKnowledgeBase
    @State private var selectedCategory: ApplianceCategory
    @State private var selectedBrand: String
    @State private var showCategoryPicker = false
    @State private var showBrandPicker = false
    
    public init(
        result: RecognitionResult,
        onConfirm: @escaping (RecognitionResult) -> Void,
        onRetry: @escaping () -> Void,
        onSkipToForm: @escaping () -> Void
    ) {
        self.result = result
        self.onConfirm = onConfirm
        self.onRetry = onRetry
        self.onSkipToForm = onSkipToForm
        self._selectedCategory = State(initialValue: result.category)
        self._selectedBrand = State(initialValue: result.brand ?? "")
    }
    
    /// True when AI recognition was skipped (e.g. daily cap reached)
    private var isManualSelection: Bool {
        result.confidence == 0 && result.category == .unknown
    }

    private var categoryDisplayName: String {
        // First check knowledge base for known display name
        if let knowledge = knowledgeBase.knowledge(for: selectedCategory) {
            return knowledge.displayName
        }
        // Otherwise format the raw value nicely: "patio_chair" -> "Patio Chair"
        return selectedCategory.rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Captured image or placeholder
            Group {
                if let image = result.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                        .aspectRatio(4/3, contentMode: .fit)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(maxHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            Text(isManualSelection ? "What is this item?" : "This looks like a:")
                .font(.headline)

            // Category selection
            VStack(spacing: 12) {
                Button {
                    showCategoryPicker = true
                } label: {
                    HStack {
                        Text(isManualSelection ? "Select Type" : categoryDisplayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(isManualSelection ? .secondary : .primary)
                }

                // Brand if detected
                if !selectedBrand.isEmpty {
                    Button {
                        showBrandPicker = true
                    } label: {
                        HStack {
                            Text("by \(selectedBrand)")
                                .font(.title3)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                // Confidence indicator
                if result.confidence > 0 {
                    Text("\(Int(result.confidence * 100))% confident")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // Actions
            VStack(spacing: 12) {
                Button {
                    let confirmed = RecognitionResult(
                        category: selectedCategory,
                        brand: selectedBrand.isEmpty ? nil : selectedBrand,
                        manufacturer: result.manufacturer,
                        confidence: result.confidence,
                        capturedImage: result.capturedImage,
                        boundingBox: result.boundingBox
                    )
                    onConfirm(confirmed)
                } label: {
                    Text("Yes, continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isManualSelection && selectedCategory == .unknown)

                HStack(spacing: 24) {
                    if !isManualSelection {
                        Button("Try again", action: onRetry)
                    }
                    Button("Skip to form", action: onSkipToForm)
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            Spacer().frame(height: 20)
        }
        .navigationTitle("Confirm")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(
                selectedCategory: $selectedCategory,
                categories: knowledgeBase.allCategories()
            )
        }
        .sheet(isPresented: $showBrandPicker) {
            BrandPickerSheet(
                selectedBrand: $selectedBrand,
                category: selectedCategory
            )
        }
    }
}

// MARK: - Category Picker

private struct CategoryPickerSheet: View {
    @Binding var selectedCategory: ApplianceCategory
    let categories: [CategoryKnowledge]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(categories, id: \.id) { (cat: CategoryKnowledge) in
                Button {
                    selectedCategory = cat.category
                    dismiss()
                } label: {
                    HStack {
                        Text(cat.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if cat.category == selectedCategory {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Select Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Brand Picker

private struct BrandPickerSheet: View {
    @Binding var selectedBrand: String
    let category: ApplianceCategory
    @EnvironmentObject private var knowledgeBase: ApplianceKnowledgeBase
    @Environment(\.dismiss) private var dismiss
    @State private var customBrand = ""

    private var brands: [String] {
        knowledgeBase.knowledge(for: category)?.commonManufacturers ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(brands, id: \.self) { (brand: String) in
                        Button {
                            selectedBrand = brand.capitalized
                            dismiss()
                        } label: {
                            HStack {
                                Text(brand.capitalized)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if brand.lowercased() == selectedBrand.lowercased() {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }

                Section("Other") {
                    HStack {
                        TextField("Enter brand", text: $customBrand)
                        Button("Add") {
                            selectedBrand = customBrand
                            dismiss()
                        }
                        .disabled(customBrand.isEmpty)
                    }
                }
            }
            .navigationTitle("Select Brand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
