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
    @State private var selectedManufacturer: String
    @State private var showCategoryPicker = false
    @State private var showManufacturerPicker = false
    
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
        self._selectedManufacturer = State(initialValue: result.manufacturer ?? "")
    }
    
    private var categoryDisplayName: String {
        knowledgeBase.knowledge(for: selectedCategory)?.displayName ?? selectedCategory.rawValue.capitalized
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
            
            Text("This looks like a:")
                .font(.headline)
            
            // Category selection
            VStack(spacing: 12) {
                Button {
                    showCategoryPicker = true
                } label: {
                    HStack {
                        Text(categoryDisplayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(.primary)
                }
                
                // Manufacturer if detected
                if !selectedManufacturer.isEmpty {
                    Button {
                        showManufacturerPicker = true
                    } label: {
                        HStack {
                            Text("by \(selectedManufacturer)")
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
                        manufacturer: selectedManufacturer.isEmpty ? nil : selectedManufacturer,
                        confidence: result.confidence,
                        capturedImage: result.capturedImage
                    )
                    onConfirm(confirmed)
                } label: {
                    Text("Yes, continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                HStack(spacing: 24) {
                    Button("Try again", action: onRetry)
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
        .sheet(isPresented: $showManufacturerPicker) {
            ManufacturerPickerSheet(
                selectedManufacturer: $selectedManufacturer,
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
            .navigationTitle("Select Category")
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

// MARK: - Manufacturer Picker

private struct ManufacturerPickerSheet: View {
    @Binding var selectedManufacturer: String
    let category: ApplianceCategory
    @EnvironmentObject private var knowledgeBase: ApplianceKnowledgeBase
    @Environment(\.dismiss) private var dismiss
    @State private var customManufacturer = ""
    
    private var manufacturers: [String] {
        knowledgeBase.knowledge(for: category)?.commonManufacturers ?? []
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(manufacturers, id: \.self) { (manufacturer: String) in
                        Button {
                            selectedManufacturer = manufacturer.capitalized
                            dismiss()
                        } label: {
                            HStack {
                                Text(manufacturer.capitalized)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if manufacturer.lowercased() == selectedManufacturer.lowercased() {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
                
                Section("Other") {
                    HStack {
                        TextField("Enter manufacturer", text: $customManufacturer)
                        Button("Add") {
                            selectedManufacturer = customManufacturer
                            dismiss()
                        }
                        .disabled(customManufacturer.isEmpty)
                    }
                }
            }
            .navigationTitle("Select Manufacturer")
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
