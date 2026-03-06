//
//  AssetFormView.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//

import SwiftUI
import CastleMindrModels

public struct AssetFormView: View {
    let initialData: AssetFormData
    let context: AssetCaptureContext
    let onSave: (Asset, TrainingSample?, UIImage?) -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject private var knowledgeBase: ApplianceKnowledgeBase
    
    @State private var name: String
    @State private var category: ApplianceCategory
    @State private var brand: String
    @State private var manufacturer: String
    @State private var modelNumber: String
    @State private var serialNumber: String
    @State private var purchaseDate: Date?
    @State private var warrantyExpires: Date?
    @State private var notes: String
    @State private var isSaving = false
    
    @State private var showPurchaseDatePicker = false
    @State private var showWarrantyDatePicker = false
    @State private var showCategoryPicker = false
    
    public init(
        initialData: AssetFormData,
        context: AssetCaptureContext,
        onSave: @escaping (Asset, TrainingSample?, UIImage?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialData = initialData
        self.context = context
        self.onSave = onSave
        self.onCancel = onCancel
        
        _name = State(initialValue: initialData.name)
        _category = State(initialValue: initialData.category)
        _brand = State(initialValue: initialData.brand)
        _manufacturer = State(initialValue: initialData.manufacturer)
        _modelNumber = State(initialValue: initialData.modelNumber)
        _serialNumber = State(initialValue: initialData.serialNumber)
        _purchaseDate = State(initialValue: initialData.purchaseDate)
        _warrantyExpires = State(initialValue: initialData.warrantyExpires)
        _notes = State(initialValue: initialData.notes)
    }
    
    private var categoryDisplayName: String {
        knowledgeBase.knowledge(for: category)?.displayName
            ?? category.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    private var generatedName: String {
        if !name.isEmpty { return name }
        let brandPrefix = brand.isEmpty ? "" : "\(brand) "
        return "\(brandPrefix)\(categoryDisplayName)"
    }
    
    private var canSave: Bool {
        category != .unknown && !isSaving
    }
    
    public var body: some View {
        Form {
            Section {
                // Name
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("Auto-generated", text: $name)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(name.isEmpty ? .secondary : .primary)
                }
                
                // Category
                Button {
                    showCategoryPicker = true
                } label: {
                    HStack {
                        Text("Type")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(category == .unknown ? "Select" : categoryDisplayName)
                            .foregroundStyle(category == .unknown ? .secondary : .primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                // Brand
                HStack {
                    Text("Brand")
                    Spacer()
                    TextField("Optional", text: $brand)
                        .multilineTextAlignment(.trailing)
                }
                if !initialData.brand.isEmpty && initialData.brand == brand {
                    ScannedIndicator()
                }

                // Manufacturer
                HStack {
                    Text("Manufacturer")
                    Spacer()
                    TextField("Optional", text: $manufacturer)
                        .multilineTextAlignment(.trailing)
                }
                if !initialData.manufacturer.isEmpty && initialData.manufacturer == manufacturer {
                    ScannedIndicator()
                }
                
                // Model
                HStack {
                    Text("Model")
                    Spacer()
                    TextField("Optional", text: $modelNumber)
                        .multilineTextAlignment(.trailing)
                }
                if !initialData.modelNumber.isEmpty && initialData.modelNumber == modelNumber {
                    ScannedIndicator()
                }
                
                // Serial
                HStack {
                    Text("Serial")
                    Spacer()
                    TextField("Optional", text: $serialNumber)
                        .multilineTextAlignment(.trailing)
                }
                if !initialData.serialNumber.isEmpty && initialData.serialNumber == serialNumber {
                    ScannedIndicator()
                }
            } header: {
                Text("Details")
            }
            
            Section {
                // Purchase date
                Button {
                    showPurchaseDatePicker.toggle()
                } label: {
                    HStack {
                        Text("Purchase Date")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(purchaseDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not set")
                            .foregroundStyle(purchaseDate == nil ? .secondary : .primary)
                    }
                }
                if showPurchaseDatePicker {
                    DatePicker(
                        "Purchase Date",
                        selection: Binding(
                            get: { purchaseDate ?? Date() },
                            set: { purchaseDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    
                    Button("Clear") {
                        purchaseDate = nil
                        showPurchaseDatePicker = false
                    }
                    .foregroundStyle(.red)
                }
                
                // Warranty expiration
                Button {
                    showWarrantyDatePicker.toggle()
                } label: {
                    HStack {
                        Text("Warranty Expires")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(warrantyExpires?.formatted(date: .abbreviated, time: .omitted) ?? "Not set")
                            .foregroundStyle(warrantyExpires == nil ? .secondary : .primary)
                    }
                }
                if showWarrantyDatePicker {
                    DatePicker(
                        "Warranty Expires",
                        selection: Binding(
                            get: { warrantyExpires ?? Date() },
                            set: { warrantyExpires = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    
                    Button("Clear") {
                        warrantyExpires = nil
                        showWarrantyDatePicker = false
                    }
                    .foregroundStyle(.red)
                }
            } header: {
                Text("Optional")
            }
            
            Section {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("Notes")
            }
        }
        .navigationTitle("Asset Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveAsset()
                }
                .fontWeight(.semibold)
                .disabled(!canSave)
            }
        }
        .sheet(isPresented: $showCategoryPicker) {
            FormCategoryPicker(
                selectedCategory: $category,
                categories: knowledgeBase.allCategories()
            )
        }
    }
    
    private func saveAsset() {
        isSaving = true
        
        let (propertyId, areaId): (String, String?) = {
            switch context {
            case .property(let id):
                return (id, nil)
            case .room(let propId, let roomId):
                return (propId, roomId)
            case .scanLabel(let propId, let existingAsset):
                return (propId, existingAsset.areaId)
            }
        }()
        
        let asset = Asset(
            id: UUID().uuidString,
            name: generatedName,
            propertyId: propertyId,
            type: category,
            areaId: areaId,
            brand: brand.isEmpty ? nil : brand,
            manufacturer: manufacturer.isEmpty ? nil : manufacturer,
            modelNumber: modelNumber.isEmpty ? nil : modelNumber,
            serialNumber: serialNumber.isEmpty ? nil : serialNumber,
            purchaseDate: purchaseDate,
            warrantyExpires: warrantyExpires,
            notes: notes.isEmpty ? nil : notes
        )

        // Build training sample if we have recognition data
        var trainingSample: TrainingSample? = nil

        if let recognition = initialData.originalRecognition {
            trainingSample = TrainingSample.build(
                recognition: recognition,
                confirmedCategory: category,
                confirmedBrand: brand.isEmpty ? nil : brand,
                confirmedManufacturer: manufacturer.isEmpty ? nil : manufacturer,
                labelScan: initialData.labelScan,
                userFinalModelNumber: modelNumber.isEmpty ? nil : modelNumber,
                userFinalSerialNumber: serialNumber.isEmpty ? nil : serialNumber,
                userFinalManufacturer: manufacturer.isEmpty ? nil : manufacturer,
                userFinalBrand: brand.isEmpty ? nil : brand,
                labelExtractionSource: initialData.labelScan?.extractionSource
            )
            
            // Crop the image to bounding box for training
            var trainingImage: UIImage? = recognition.capturedImage
            if let fullImage = recognition.capturedImage,
               let boundingBox = recognition.boundingBox {
                trainingImage = fullImage.cropped(to: boundingBox) ?? fullImage
            }
            
            // Submit training sample to cloud (fire and forget)
            Task {
                do {
                    let result = try await TrainingSampleService.shared.submit(
                        sample: trainingSample!,
                        applianceImage: trainingImage,
                        labelImage: initialData.labelScan?.labelImage
                    )
                    print("📊 Training sample submitted: \(result.sampleId)")
                } catch {
                    print("⚠️ Failed to submit training sample: \(error.localizedDescription)")
                }
            }
        }
        
        // Crop to bounding box for the stored asset photo (not full scene)
        var assetImage = initialData.applianceImage
        if let fullImage = initialData.applianceImage,
           let boundingBox = initialData.originalRecognition?.boundingBox {
            assetImage = fullImage.cropped(to: boundingBox) ?? fullImage
        }

        onSave(asset, trainingSample, assetImage)
    }
}

// MARK: - Scanned Indicator

private struct ScannedIndicator: View {
    var body: some View {
        HStack {
            Spacer()
            Label("Scanned", systemImage: "viewfinder")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .listRowInsets(EdgeInsets(top: -8, leading: 0, bottom: 0, trailing: 16))
        .listRowBackground(Color.clear)
    }
}

// MARK: - Category Picker

private struct FormCategoryPicker: View {
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
