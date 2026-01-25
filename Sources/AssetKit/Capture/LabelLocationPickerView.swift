//
//  LabelLocationPickerView.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/24/26.
//


import SwiftUI
import CastleMindrModels


/// Quick picker for label location - shown after successful OCR scan
public struct LabelLocationPickerView: View {
    let category: ApplianceCategory
    let onSelect: (LabelLocation) -> Void
    let onSkip: () -> Void
    
    @State private var selectedLocation: LabelLocation?
    
    public init(
        category: ApplianceCategory,
        onSelect: @escaping (LabelLocation) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.category = category
        self.onSelect = onSelect
        self.onSkip = onSkip
    }
    
    private var commonLocations: [LabelLocation] {
        LabelLocation.commonLocations(for: category)
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text("Where was the label?")
                    .font(.title2.bold())
                
                Text("This helps us guide future users")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top)
            
            // Location grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(commonLocations, id: \.self) { location in
                    LocationButton(
                        location: location,
                        isSelected: selectedLocation == location
                    ) {
                        selectedLocation = location
                    }
                }
                
                // "Other" option if not in common
                if !commonLocations.contains(.other) {
                    LocationButton(
                        location: .other,
                        isSelected: selectedLocation == .other
                    ) {
                        selectedLocation = .other
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Actions
            VStack(spacing: 12) {
                Button {
                    if let location = selectedLocation {
                        onSelect(location)
                    }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedLocation != nil ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedLocation == nil)
                
                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}

// MARK: - Location Button

private struct LocationButton: View {
    let location: LabelLocation
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: location.iconName)
                    .font(.title2)
                
                Text(location.displayName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
            .foregroundStyle(isSelected ? .blue : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    LabelLocationPickerView(
        category: .refrigerator,
        onSelect: { location in
            print("Selected: \(location)")
        },
        onSkip: {
            print("Skipped")
        }
    )
}
