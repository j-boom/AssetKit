//
//  BoundingBoxSelector.swift
//  AssetKit
//
//  Allows user to draw and adjust a bounding box on a captured image.
//

import SwiftUI

public struct BoundingBoxSelector: View {
    let image: UIImage
    let onConfirm: (CGRect) -> Void  // Normalized 0-1 coordinates
    let onRetake: () -> Void
    
    @State private var boxRect: CGRect = .zero
    @State private var isDragging = false
    @State private var dragStart: CGPoint = .zero
    @State private var activeHandle: Handle? = nil
    @State private var imageFrame: CGRect = .zero
    
    private let handleSize: CGFloat = 44
    private let minBoxSize: CGFloat = 50
    
    enum Handle {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
        case move
    }
    
    public init(
        image: UIImage,
        onConfirm: @escaping (CGRect) -> Void,
        onRetake: @escaping () -> Void
    ) {
        self.image = image
        self.onConfirm = onConfirm
        self.onRetake = onRetake
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            GeometryReader { geometry in
                let imageSize = calculateImageSize(in: geometry.size)
                let imageOrigin = CGPoint(
                    x: (geometry.size.width - imageSize.width) / 2,
                    y: (geometry.size.height - imageSize.height) / 2
                )
                
                ZStack {
                    // Image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageSize.width, height: imageSize.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    
                    // Dimmed overlay outside selection
                    if boxRect != .zero {
                        DimmedOverlay(
                            boxRect: boxRect,
                            imageFrame: CGRect(origin: imageOrigin, size: imageSize)
                        )
                    }
                    
                    // Selection box
                    if boxRect != .zero {
                        SelectionBox(rect: boxRect, handleSize: handleSize)
                    }
                    
                    // Gesture layer
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleDrag(value, imageOrigin: imageOrigin, imageSize: imageSize)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    activeHandle = nil
                                }
                        )
                }
                .onAppear {
                    imageFrame = CGRect(origin: imageOrigin, size: imageSize)
                    // Start with a default box in the center
                    let defaultSize = min(imageSize.width, imageSize.height) * 0.6
                    boxRect = CGRect(
                        x: imageOrigin.x + (imageSize.width - defaultSize) / 2,
                        y: imageOrigin.y + (imageSize.height - defaultSize) / 2,
                        width: defaultSize,
                        height: defaultSize
                    )
                }
            }
            
            // UI Overlay
            VStack {
                // Instructions
                Text("Drag the corners to select the item")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
                    .padding(.top, 60)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 16) {
                    Button {
                        confirmSelection()
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Capsule().fill(Color.blue))
                    }
                    .padding(.horizontal)
                    .disabled(boxRect == .zero)
                    
                    Button("Retake photo") {
                        onRetake()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
    }
    
    // MARK: - Calculations
    
    private func calculateImageSize(in containerSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height
        
        if imageAspect > containerAspect {
            // Image is wider
            let width = containerSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            // Image is taller
            let height = containerSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }
    
    private func handleDrag(_ value: DragGesture.Value, imageOrigin: CGPoint, imageSize: CGSize) {
        let location = value.location
        
        if !isDragging {
            // Determine what we're dragging
            isDragging = true
            dragStart = value.startLocation
            activeHandle = detectHandle(at: value.startLocation)
        }
        
        guard let handle = activeHandle else { return }
        
        let delta = CGSize(
            width: location.x - dragStart.x,
            height: location.y - dragStart.y
        )
        
        var newRect = boxRect
        
        switch handle {
        case .move:
            newRect.origin.x += delta.width
            newRect.origin.y += delta.height
            
        case .topLeft:
            newRect.origin.x += delta.width
            newRect.origin.y += delta.height
            newRect.size.width -= delta.width
            newRect.size.height -= delta.height
            
        case .topRight:
            newRect.origin.y += delta.height
            newRect.size.width += delta.width
            newRect.size.height -= delta.height
            
        case .bottomLeft:
            newRect.origin.x += delta.width
            newRect.size.width -= delta.width
            newRect.size.height += delta.height
            
        case .bottomRight:
            newRect.size.width += delta.width
            newRect.size.height += delta.height
            
        case .top:
            newRect.origin.y += delta.height
            newRect.size.height -= delta.height
            
        case .bottom:
            newRect.size.height += delta.height
            
        case .left:
            newRect.origin.x += delta.width
            newRect.size.width -= delta.width
            
        case .right:
            newRect.size.width += delta.width
        }
        
        // Enforce minimum size
        if newRect.width < minBoxSize {
            if handle == .topLeft || handle == .bottomLeft || handle == .left {
                newRect.origin.x = boxRect.maxX - minBoxSize
            }
            newRect.size.width = minBoxSize
        }
        if newRect.height < minBoxSize {
            if handle == .topLeft || handle == .topRight || handle == .top {
                newRect.origin.y = boxRect.maxY - minBoxSize
            }
            newRect.size.height = minBoxSize
        }
        
        // Constrain to image bounds
        let imageBounds = CGRect(origin: imageOrigin, size: imageSize)
        newRect = constrainRect(newRect, to: imageBounds)
        
        boxRect = newRect
        dragStart = location
    }
    
    private func detectHandle(at point: CGPoint) -> Handle {
        let cornerRadius = handleSize
        
        // Check corners first
        if distance(from: point, to: CGPoint(x: boxRect.minX, y: boxRect.minY)) < cornerRadius {
            return .topLeft
        }
        if distance(from: point, to: CGPoint(x: boxRect.maxX, y: boxRect.minY)) < cornerRadius {
            return .topRight
        }
        if distance(from: point, to: CGPoint(x: boxRect.minX, y: boxRect.maxY)) < cornerRadius {
            return .bottomLeft
        }
        if distance(from: point, to: CGPoint(x: boxRect.maxX, y: boxRect.maxY)) < cornerRadius {
            return .bottomRight
        }
        
        // Check edges
        let edgeThreshold: CGFloat = 30
        if abs(point.y - boxRect.minY) < edgeThreshold && point.x > boxRect.minX && point.x < boxRect.maxX {
            return .top
        }
        if abs(point.y - boxRect.maxY) < edgeThreshold && point.x > boxRect.minX && point.x < boxRect.maxX {
            return .bottom
        }
        if abs(point.x - boxRect.minX) < edgeThreshold && point.y > boxRect.minY && point.y < boxRect.maxY {
            return .left
        }
        if abs(point.x - boxRect.maxX) < edgeThreshold && point.y > boxRect.minY && point.y < boxRect.maxY {
            return .right
        }
        
        // Inside box = move
        if boxRect.contains(point) {
            return .move
        }
        
        // Outside = draw new box (treat as move for simplicity)
        return .move
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }
    
    private func constrainRect(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        var result = rect
        
        if result.minX < bounds.minX {
            result.origin.x = bounds.minX
        }
        if result.minY < bounds.minY {
            result.origin.y = bounds.minY
        }
        if result.maxX > bounds.maxX {
            result.origin.x = bounds.maxX - result.width
        }
        if result.maxY > bounds.maxY {
            result.origin.y = bounds.maxY - result.height
        }
        
        return result
    }
    
    private func confirmSelection() {
        // Convert box to normalized coordinates relative to image
        let normalizedRect = CGRect(
            x: (boxRect.minX - imageFrame.minX) / imageFrame.width,
            y: (boxRect.minY - imageFrame.minY) / imageFrame.height,
            width: boxRect.width / imageFrame.width,
            height: boxRect.height / imageFrame.height
        )
        
        onConfirm(normalizedRect)
    }
}

// MARK: - Dimmed Overlay

private struct DimmedOverlay: View {
    let boxRect: CGRect
    let imageFrame: CGRect
    
    var body: some View {
        Canvas { context, size in
            // Fill entire area with dim
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.5))
            )
            
            // Cut out the selection box
            context.blendMode = .destinationOut
            context.fill(
                Path(boxRect),
                with: .color(.white)
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Selection Box

private struct SelectionBox: View {
    let rect: CGRect
    let handleSize: CGFloat
    
    var body: some View {
        ZStack {
            // Border
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
            
            // Corner handles
            ForEach(corners, id: \.0) { corner in
                CornerHandle()
                    .position(corner.1)
            }
            
            // Grid lines (rule of thirds)
            GridLines(rect: rect)
        }
    }
    
    private var corners: [(String, CGPoint)] {
        [
            ("tl", CGPoint(x: rect.minX, y: rect.minY)),
            ("tr", CGPoint(x: rect.maxX, y: rect.minY)),
            ("bl", CGPoint(x: rect.minX, y: rect.maxY)),
            ("br", CGPoint(x: rect.maxX, y: rect.maxY))
        ]
    }
}

// MARK: - Corner Handle

private struct CornerHandle: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 20, height: 20)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Grid Lines

private struct GridLines: View {
    let rect: CGRect
    
    var body: some View {
        Canvas { context, size in
            let thirdWidth = rect.width / 3
            let thirdHeight = rect.height / 3
            
            // Vertical lines
            for i in 1...2 {
                let x = rect.minX + thirdWidth * CGFloat(i)
                var path = Path()
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
                context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 1)
            }
            
            // Horizontal lines
            for i in 1...2 {
                let y = rect.minY + thirdHeight * CGFloat(i)
                var path = Path()
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
                context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Image Cropping Extension

public extension UIImage {
    /// Crop image to normalized rect (0-1 coordinates)
    func cropped(to normalizedRect: CGRect) -> UIImage? {
        // First, normalize the image to .up orientation
        guard let normalizedImage = normalizedToUp(),
              let cgImage = normalizedImage.cgImage else {
            return nil
        }
        
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        let cropRect = CGRect(
            x: normalizedRect.minX * imageWidth,
            y: normalizedRect.minY * imageHeight,
            width: normalizedRect.width * imageWidth,
            height: normalizedRect.height * imageHeight
        )
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }
        
        return UIImage(cgImage: croppedCGImage, scale: scale, orientation: .up)
    }
    
    /// Redraw the image with .up orientation
    private func normalizedToUp() -> UIImage? {
        guard imageOrientation != .up else { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
}
