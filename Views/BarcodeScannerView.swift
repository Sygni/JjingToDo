//
//  BarcodeScannerView.swift
//  JjingToDo
//

import SwiftUI
import AVFoundation

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onDetected: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onDetected = onDetected
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}
}

class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var onDetected: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              captureSession.canAddInput(videoInput)
        else { return }

        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8]
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        if let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let code = object.stringValue {
            captureSession.stopRunning()
            onDetected?(code)
            DispatchQueue.main.async { [weak self] in self?.dismiss(animated: true) }
        }
    }
}
