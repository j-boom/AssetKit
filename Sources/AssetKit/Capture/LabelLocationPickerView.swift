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
    let category: String
    let onSelect: (LabelLocation, String?) -> Void   // (location, customDescription)
    let onSkip: () -> Void

    @State private var selectedLocation: LabelLocation?
    @State private var showAllLocations = false
    @State private var customDescription = ""
    @FocusState private var isCustomFieldFocused: Bool

    public init(
        category: String,
        onSelect: @escaping (LabelLocation, String?) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.category = category
        self.onSelect = onSelect
        self.onSkip = onSkip
    }

    private var commonLocations: [LabelLocation] {
        LabelLocation.commonLocations(for: category)
    }

    private var additionalLocations: [LabelLocation] {
        LabelLocation.additionalLocations(for: category)
    }

    public var body: some View {
        ScrollView {
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

                // Common locations grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(commonLocations, id: \.self) { location in
                        LocationButton(
                            location: location,
                            isSelected: selectedLocation == location
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedLocation = location
                                isCustomFieldFocused = false
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Show More / Additional Locations
                if !additionalLocations.isEmpty {
                    if showAllLocations {
                        VStack(spacing: 8) {
                            HStack {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(.quaternary)
                                Text("More locations")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(.quaternary)
                            }
                            .padding(.horizontal)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(additionalLocations, id: \.self) { location in
                                    LocationButton(
                                        location: location,
                                        isSelected: selectedLocation == location
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedLocation = location
                                            isCustomFieldFocused = false
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showAllLocations = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Show more locations")
                                Image(systemName: "chevron.down")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                    }
                }

                // "Other" with free-text input
                VStack(spacing: 12) {
                    LocationButton(
                        location: .other,
                        isSelected: selectedLocation == .other
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedLocation = .other
                            isCustomFieldFocused = true
                        }
                    }
                    .padding(.horizontal)

                    if selectedLocation == .other {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Describe where you found the label:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("e.g. behind the kick plate, inside the freezer compartment", text: $customDescription)
                                .textFieldStyle(.roundedBorder)
                                .focused($isCustomFieldFocused)
                                .submitLabel(.done)
                        }
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer(minLength: 20)

                // Actions
                VStack(spacing: 12) {
                    Button {
                        if let location = selectedLocation {
                            let description = location == .other ? customDescription.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                            onSelect(location, description?.isEmpty == true ? nil : description)
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
        category: "refrigerator",
        onSelect: { location, description in
            print("Selected: \(location), description: \(description ?? "nil")")
        },
        onSkip: {
            print("Skipped")
        }
    )
}
