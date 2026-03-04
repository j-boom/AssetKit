//
//  EntryPointSelectionView.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/23/26.
//

import SwiftUI

public struct EntryPointSelectionView: View {
    let onScanAppliance: () -> Void
    let onScanReceipt: () -> Void
    let onEnterManually: () -> Void
    let onCancel: () -> Void
    
    public init(
        onScanAppliance: @escaping () -> Void,
        onScanReceipt: @escaping () -> Void,
        onEnterManually: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onScanAppliance = onScanAppliance
        self.onScanReceipt = onScanReceipt
        self.onEnterManually = onEnterManually
        self.onCancel = onCancel
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Add an Asset")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("How would you like to add this item?")
                .foregroundStyle(.secondary)
            
            Spacer()
            
            VStack(spacing: 16) {
                EntryOptionButton(
                    icon: "camera.fill",
                    title: "Scan Asset",
                    subtitle: "Point camera at the item",
                    action: onScanAppliance
                )
                
                EntryOptionButton(
                    icon: "doc.text.fill",
                    title: "Scan Receipt",
                    subtitle: "Capture purchase info",
                    isEnabled: false, // CAS-91
                    action: onScanReceipt
                )
                
                EntryOptionButton(
                    icon: "pencil",
                    title: "Enter Manually",
                    subtitle: "Type in the details",
                    action: onEnterManually
                )
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
        }
    }
}

// MARK: - Entry Option Button

private struct EntryOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    var isEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(isEnabled ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
                    .foregroundStyle(isEnabled ? Color.accentColor : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isEnabled ? .primary : .secondary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!isEnabled)
    }
}
