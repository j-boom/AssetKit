//
//  CameraView.swift
//  AssetKit
//
//  Created by Jim Bergren on 1/25/26.
//


//
//  CameraView.swift
//  AssetKit
//
//  Full-featured camera with pinch to zoom, tap to focus, orientation support.
//

import SwiftUI
import AVFoundation

// MARK: - Camera View

public struct CameraView: View {
    @StateObject private var camera: CameraController
    let onCapture: (UIImage) -> Void
    
    @State private var focusPoint: CGPoint?
    @State private var showFocusIndicator = false
    
    public init(onCapture: @escaping (UIImage) -> Void) {
        self._camera = StateObject(wrappedValue: CameraController())
        self.onCapture = onCapture
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview - full screen
                CameraPreviewLayer(
                    session: camera.session,
                    videoGravity: .resizeAspectFill,
                    orientation: camera.videoOrientation
                )
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            camera.zoom(scale)
                        }
                        .onEnded { _ in
                            camera.zoomEnded()
                        }
                )
                .gesture(
                    SpatialTapGesture()
                        .onEnded { event in
                            let point = event.location
                            let size = geometry.size
                            
                            // Convert to normalized coordinates (0-1)
                            let normalizedPoint = CGPoint(
                                x: point.x / size.width,
                                y: point.y / size.height
                            )
                            
                            camera.focus(at: normalizedPoint)
                            
                            // Show focus indicator
                            focusPoint = point
                            showFocusIndicator = true
                            
                            // Hide after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showFocusIndicator = false
                            }
                        }
                )
                
                // Focus indicator
                if showFocusIndicator, let point = focusPoint {
                    FocusIndicator()
                        .position(point)
                }
                
                // Permission denied overlay
                if !camera.isAuthorized && !camera.isCheckingPermission {
                    PermissionDeniedOverlay()
                }
            }
        }
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }
    
    // MARK: - Public Methods
    
    public func capture() {
        camera.capturePhoto { image in
            if let image = image {
                onCapture(image)
            }
        }
    }
}

// MARK: - Camera Controller

@MainActor
public final class CameraController: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isCheckingPermission = true
    @Published var videoOrientation: AVCaptureVideoOrientation = .portrait
    
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var completion: ((UIImage?) -> Void)?
    
    // Zoom state
    private var baseZoomFactor: CGFloat = 1.0
    private var currentZoomFactor: CGFloat = 1.0
    
    override init() {
        super.init()
        setupOrientationObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    func start() {
        checkAuthorization()
    }
    
    func stop() {
        guard session.isRunning else { return }
        Task.detached { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    private func checkAuthorization() {
        isCheckingPermission = true
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            isCheckingPermission = false
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.isAuthorized = granted
                    self?.isCheckingPermission = false
                    if granted {
                        self?.setupSession()
                    }
                }
            }
        default:
            isAuthorized = false
            isCheckingPermission = false
        }
    }
    
    private func setupSession() {
        guard !session.isRunning else { return }
        
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        
        self.device = device
        session.addInput(input)
        
        // Output
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.isHighResolutionCaptureEnabled = true
        }
        
        session.commitConfiguration()
        
        // Update orientation
        updateVideoOrientation()
        
        Task.detached { [weak self] in
            self?.session.startRunning()
        }
    }
    
    // MARK: - Orientation
    
    private func setupOrientationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func orientationChanged() {
        Task { @MainActor in
            updateVideoOrientation()
        }
    }
    
    private func updateVideoOrientation() {
        let deviceOrientation = UIDevice.current.orientation
        
        switch deviceOrientation {
        case .portrait:
            videoOrientation = .portrait
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        case .landscapeLeft:
            videoOrientation = .landscapeRight // Inverted
        case .landscapeRight:
            videoOrientation = .landscapeLeft // Inverted
        default:
            // Keep current
            break
        }
    }
    
    // MARK: - Zoom
    
    func zoom(_ scale: CGFloat) {
        guard let device = device else { return }
        
        let newZoom = baseZoomFactor * scale
        let clampedZoom = min(max(newZoom, 1.0), device.activeFormat.videoMaxZoomFactor)
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedZoom
            device.unlockForConfiguration()
            currentZoomFactor = clampedZoom
        } catch {
            print("Failed to set zoom: \(error)")
        }
    }
    
    func zoomEnded() {
        baseZoomFactor = currentZoomFactor
    }
    
    // MARK: - Focus
    
    func focus(at point: CGPoint) {
        guard let device = device else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to set focus: \(error)")
        }
    }
    
    // MARK: - Capture
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        
        let settings = AVCapturePhotoSettings()
        
        // Set orientation for capture
        if let connection = output.connection(with: .video) {
            connection.videoOrientation = videoOrientation
        }
        
        output.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - Photo Capture Delegate

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor in
                self.completion?(nil)
            }
            return
        }
        
        Task { @MainActor in
            self.completion?(image)
        }
    }
}

// MARK: - Camera Preview Layer

struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession
    let videoGravity: AVLayerVideoGravity
    let orientation: AVCaptureVideoOrientation
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = videoGravity
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.connection?.videoOrientation = orientation
    }
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }
    }
}

// MARK: - Focus Indicator

struct FocusIndicator: View {
    @State private var scale: CGFloat = 1.5
    @State private var opacity: Double = 1.0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 80, height: 80)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                }
                withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
                    opacity = 0.0
                }
            }
    }
}

// MARK: - Permission Denied Overlay

struct PermissionDeniedOverlay: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.5))
                
                Text("Camera access required")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                
                Text("Enable camera access in Settings to scan items")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Capturable Camera View

/// A camera view with external capture control
public struct CapturableCameraView: View {
    @ObservedObject var controller: CameraController
    
    @State private var focusPoint: CGPoint?
    @State private var showFocusIndicator = false
    
    public init(controller: CameraController) {
        self.controller = controller
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreviewLayer(
                    session: controller.session,
                    videoGravity: .resizeAspectFill,
                    orientation: controller.videoOrientation
                )
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            controller.zoom(scale)
                        }
                        .onEnded { _ in
                            controller.zoomEnded()
                        }
                )
                .gesture(
                    SpatialTapGesture()
                        .onEnded { event in
                            let point = event.location
                            let size = geometry.size
                            
                            let normalizedPoint = CGPoint(
                                x: point.x / size.width,
                                y: point.y / size.height
                            )
                            
                            controller.focus(at: normalizedPoint)
                            
                            focusPoint = point
                            showFocusIndicator = true
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showFocusIndicator = false
                            }
                        }
                )
                
                if showFocusIndicator, let point = focusPoint {
                    FocusIndicator()
                        .position(point)
                }
                
                if !controller.isAuthorized && !controller.isCheckingPermission {
                    PermissionDeniedOverlay()
                }
            }
        }
        .onAppear {
            controller.start()
        }
        .onDisappear {
            controller.stop()
        }
    }
}