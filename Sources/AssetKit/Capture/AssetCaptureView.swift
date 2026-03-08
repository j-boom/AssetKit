//
//  AssetCaptureView.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//

import SwiftUI
import CastleMindrModels

// Disambiguate TrainingSample type
typealias LocalTrainingSample = TrainingSample

// MARK: - Flow State

public enum AssetCaptureFlowState {
    case entrySelection
    case objectRecognition
    case confirmRecognition(RecognitionResult)
    case guidedLabelScan(RecognitionResult)
    case labelLocationPicker(RecognitionResult, LabelScanResult)
    case form(AssetFormData)
}

// MARK: - Form Data

public struct AssetFormData {
    public var name: String
    public var category: String
    public var brand: String
    public var manufacturer: String
    public var modelNumber: String
    public var serialNumber: String
    public var purchaseDate: Date?
    public var warrantyExpires: Date?
    public var notes: String
    public var applianceImage: UIImage?
    public var labelImage: UIImage?

    // For training data
    public var originalRecognition: RecognitionResult?
    public var labelScan: LabelScanResult?

    public init(
        name: String = "",
        category: String = "unknown",
        brand: String = "",
        manufacturer: String = "",
        modelNumber: String = "",
        serialNumber: String = "",
        purchaseDate: Date? = nil,
        warrantyExpires: Date? = nil,
        notes: String = "",
        applianceImage: UIImage? = nil,
        labelImage: UIImage? = nil,
        originalRecognition: RecognitionResult? = nil,
        labelScan: LabelScanResult? = nil
    ) {
        self.name = name
        self.category = category
        self.brand = brand
        self.manufacturer = manufacturer
        self.modelNumber = modelNumber
        self.serialNumber = serialNumber
        self.purchaseDate = purchaseDate
        self.warrantyExpires = warrantyExpires
        self.notes = notes
        self.applianceImage = applianceImage
        self.labelImage = labelImage
        self.originalRecognition = originalRecognition
        self.labelScan = labelScan
    }

    public static func from(recognition: RecognitionResult) -> AssetFormData {
        AssetFormData(
            category: recognition.category,
            brand: recognition.brand ?? "",
            applianceImage: recognition.capturedImage,
            originalRecognition: recognition
        )
    }

    public static func from(recognition: RecognitionResult, labelScan: LabelScanResult?) -> AssetFormData {
        AssetFormData(
            category: recognition.category,
            brand: recognition.brand ?? "",
            manufacturer: labelScan?.ocrFields.manufacturer?.text ?? "",
            modelNumber: labelScan?.ocrFields.modelNumber?.text ?? "",
            serialNumber: labelScan?.ocrFields.serialNumber?.text ?? "",
            applianceImage: recognition.capturedImage,
            labelImage: labelScan?.labelImage,
            originalRecognition: recognition,
            labelScan: labelScan
        )
    }
}

// MARK: - Capture View

public struct AssetCaptureView: View {
    @ObservedObject var coordinator: AssetCaptureCoordinator
    @StateObject private var knowledgeBase: ApplianceKnowledgeBase
    
    @State private var flowState: AssetCaptureFlowState = .entrySelection
    @State private var navigationPath = NavigationPath()
    
    public init(
        coordinator: AssetCaptureCoordinator,
        knowledgeProvider: KnowledgeProvider = BundledKnowledgeProvider()
    ) {
        self.coordinator = coordinator
        self._knowledgeBase = StateObject(wrappedValue: ApplianceKnowledgeBase(provider: knowledgeProvider))
    }
    
    public var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if case .scanLabel(_, let asset) = coordinator.context {
                    // Jump directly to label scan for existing assets
                    GuidedLabelScanView(
                        recognition: RecognitionResult(
                            category: asset.type,
                            brand: asset.brand,
                            confidence: 1.0,
                            capturedImage: nil
                        ),
                        skipEntrySelection: true,
                        onComplete: { labelScanResult in
                            var formData = AssetFormData(
                                name: asset.name,
                                category: asset.type,
                                brand: asset.brand ?? "",
                                manufacturer: labelScanResult.ocrFields.manufacturer?.text ?? asset.manufacturer ?? "",
                                modelNumber: labelScanResult.ocrFields.modelNumber?.text ?? "",
                                serialNumber: labelScanResult.ocrFields.serialNumber?.text ?? "",
                                labelImage: labelScanResult.labelImage,
                                labelScan: labelScanResult
                            )
                            formData.originalRecognition = nil
                            navigationPath.append(AssetCaptureFlowState.form(formData))
                        },
                        onSkip: {
                            coordinator.cancel()
                        }
                    )
                } else {
                    EntryPointSelectionView(
                        onScanAppliance: { startObjectRecognition() },
                        onScanReceipt: { /* CAS-91 */ },
                        onEnterManually: { startManualEntry() },
                        onCancel: { coordinator.cancel() }
                    )
                }
            }
            .navigationDestination(for: AssetCaptureFlowState.self) { state in
                destinationView(for: state)
            }
        }
        .task {
            await knowledgeBase.loadIfNeeded()
        }
        .environment(\.isPremium, coordinator.isPremium)
        .environmentObject(knowledgeBase)
    }
    
    // MARK: - Navigation
    
    @ViewBuilder
    private func destinationView(for state: AssetCaptureFlowState) -> some View {
        switch state {
        case .entrySelection:
            EmptyView()
            
        case .objectRecognition:
            ObjectRecognitionView(
                onRecognized: { result in
                    navigationPath.append(AssetCaptureFlowState.confirmRecognition(result))
                },
                onSkip: { startManualEntry() },
                onCancel: { coordinator.cancel() }
            )
            
        case .confirmRecognition(let result):
            ConfirmRecognitionView(
                result: result,
                onConfirm: { confirmedResult in
                    navigationPath.append(AssetCaptureFlowState.guidedLabelScan(confirmedResult))
                },
                onRetry: {
                    navigationPath.removeLast()
                },
                onSkipToForm: {
                    let formData = AssetFormData.from(recognition: result)
                    navigationPath.append(AssetCaptureFlowState.form(formData))
                }
            )
            
        case .guidedLabelScan(let recognition):
            GuidedLabelScanView(
                recognition: recognition,
                onComplete: { labelScanResult in
                    // Go to label location picker if we got OCR data
                    if labelScanResult.ocrFields.hasMinimumData {
                        navigationPath.append(AssetCaptureFlowState.labelLocationPicker(recognition, labelScanResult))
                    } else {
                        // No OCR data, skip picker
                        let formData = AssetFormData.from(recognition: recognition, labelScan: labelScanResult)
                        navigationPath.append(AssetCaptureFlowState.form(formData))
                    }
                },
                onSkip: {
                    let formData = AssetFormData.from(recognition: recognition, labelScan: nil)
                    navigationPath.append(AssetCaptureFlowState.form(formData))
                }
            )
        
        case .labelLocationPicker(let recognition, let labelScanResult):
            LabelLocationPickerView(
                category: recognition.category,
                onSelect: { location, customDescription in
                    let formData = AssetFormData.from(
                        recognition: recognition,
                        labelScan: LabelScanResult(
                            labelImage: labelScanResult.labelImage,
                            ocrFields: labelScanResult.ocrFields,
                            labelLocation: location,
                            labelLocationSource: .userSelected,
                            extractionSource: labelScanResult.extractionSource,
                            customLocationDescription: customDescription
                        )
                    )
                    navigationPath.append(AssetCaptureFlowState.form(formData))
                },
                onSkip: {
                    let formData = AssetFormData.from(
                        recognition: recognition,
                        labelScan: LabelScanResult(
                            labelImage: labelScanResult.labelImage,
                            ocrFields: labelScanResult.ocrFields,
                            labelLocation: nil,
                            labelLocationSource: .skipped,
                            extractionSource: labelScanResult.extractionSource
                        )
                    )
                    navigationPath.append(AssetCaptureFlowState.form(formData))
                }
            )
            
        case .form(let formData):
            AssetFormView(
                initialData: formData,
                context: coordinator.context,
                onSave: { [coordinator] (asset: Asset, trainingData: LocalTrainingSample?, capturedImage: UIImage?) in
                    coordinator.complete(with: asset, trainingData: trainingData, capturedImage: capturedImage)
                },
                onCancel: { [coordinator] in
                    coordinator.cancel()
                }
            )
        }
    }
    
    // MARK: - Actions
    
    private func startObjectRecognition() {
        navigationPath.append(AssetCaptureFlowState.objectRecognition)
    }
    
    private func startManualEntry() {
        navigationPath.append(AssetCaptureFlowState.form(AssetFormData()))
    }
}

// MARK: - Flow State Hashable

extension AssetCaptureFlowState: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .entrySelection:
            hasher.combine(0)
        case .objectRecognition:
            hasher.combine(1)
        case .confirmRecognition(let result):
            hasher.combine(2)
            hasher.combine(result.category)
        case .guidedLabelScan(let result):
            hasher.combine(3)
            hasher.combine(result.category)
        case .labelLocationPicker(let result, _):
            hasher.combine(4)
            hasher.combine(result.category)
        case .form(let data):
            hasher.combine(5)
            hasher.combine(data.modelNumber)
        }
    }
    
    public static func == (lhs: AssetCaptureFlowState, rhs: AssetCaptureFlowState) -> Bool {
        switch (lhs, rhs) {
        case (.entrySelection, .entrySelection): return true
        case (.objectRecognition, .objectRecognition): return true
        case (.confirmRecognition(let l), .confirmRecognition(let r)): return l.category == r.category
        case (.guidedLabelScan(let l), .guidedLabelScan(let r)): return l.category == r.category
        case (.labelLocationPicker(let l, _), .labelLocationPicker(let r, _)): return l.category == r.category
        case (.form(let l), .form(let r)): return l.modelNumber == r.modelNumber
        default: return false
        }
    }
}
