import SwiftUI
import AVFoundation

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan, onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, ScannerViewControllerDelegate {
        let onScan: (String) -> Void
        let onDismiss: () -> Void
        init(onScan: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
            self.onScan = onScan
            self.onDismiss = onDismiss
        }
        func didScan(barcode: String) { onScan(barcode) }
        func didTapClose() { onDismiss() }
    }
}

// MARK: - ScannerViewController Protocol

protocol ScannerViewControllerDelegate: AnyObject {
    func didScan(barcode: String)
    func didTapClose()
}

// MARK: - UIKit Scanner

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var scanned = false
    private var dimView: ScanDimView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
        dimView?.setNeedsLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    private func setupCamera() {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            showPermissionAlert()
            return
        }

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [
            .ean8, .ean13, .code128, .code39, .qr,
            .upce, .itf14, .dataMatrix
        ]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = view.layer.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        self.previewLayer = layer
    }

    private func setupUI() {
        // Full-screen dim with transparent hole for scan area
        let dim = ScanDimView(holeSize: CGSize(width: 260, height: 160), holeOffsetY: -30)
        dim.translatesAutoresizingMaskIntoConstraints = false
        dim.isUserInteractionEnabled = false
        view.addSubview(dim)
        self.dimView = dim

        // Corner bracket frame
        let frameView = ScanFrameView()
        frameView.translatesAutoresizingMaskIntoConstraints = false
        frameView.backgroundColor = .clear
        frameView.isUserInteractionEnabled = false
        view.addSubview(frameView)

        // Close button
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeBtn.tintColor = .white
        closeBtn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeBtn.layer.cornerRadius = 18
        closeBtn.clipsToBounds = true
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeBtn)

        // Hint label
        let hint = UILabel()
        hint.text = "Наведите на штрихкод товара"
        hint.textColor = .white
        hint.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        hint.textAlignment = .center
        hint.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        hint.layer.cornerRadius = 12
        hint.clipsToBounds = true
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)

        NSLayoutConstraint.activate([
            dim.topAnchor.constraint(equalTo: view.topAnchor),
            dim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dim.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            closeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeBtn.widthAnchor.constraint(equalToConstant: 36),
            closeBtn.heightAnchor.constraint(equalToConstant: 36),

            frameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frameView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            frameView.widthAnchor.constraint(equalToConstant: 260),
            frameView.heightAnchor.constraint(equalToConstant: 160),

            hint.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hint.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            hint.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    @objc private func closeTapped() {
        delegate?.didTapClose()
    }

    private func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Нет доступа к камере",
                message: "Разрешите доступ в Настройках",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Настройки", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            self.present(alert, animated: true)
        }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !scanned,
              let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = obj.stringValue else { return }

        scanned = true
        HapticManager.success()
        session.stopRunning()
        delegate?.didScan(barcode: barcode)
    }
}

// MARK: - Full-screen dim with transparent hole

private final class ScanDimView: UIView {
    private let holeSize: CGSize
    private let holeOffsetY: CGFloat
    private let maskLayer = CAShapeLayer()

    init(holeSize: CGSize, holeOffsetY: CGFloat) {
        self.holeSize = holeSize
        self.holeOffsetY = holeOffsetY
        super.init(frame: .zero)
        backgroundColor = UIColor.black.withAlphaComponent(0.55)
        layer.mask = maskLayer
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let holeRect = CGRect(
            x: (bounds.width - holeSize.width) / 2,
            y: (bounds.height - holeSize.height) / 2 + holeOffsetY,
            width: holeSize.width,
            height: holeSize.height
        )
        let full = UIBezierPath(rect: bounds)
        let hole = UIBezierPath(roundedRect: holeRect, cornerRadius: 6)
        full.append(hole)
        full.usesEvenOddFillRule = true
        maskLayer.fillRule = .evenOdd
        maskLayer.path = full.cgPath
        maskLayer.frame = bounds
    }
}

// MARK: - Scan frame corners

private final class ScanFrameView: UIView {
    override func draw(_ rect: CGRect) {
        let corner: CGFloat = 20
        let len: CGFloat = 32
        let lw: CGFloat = 3
        let color = UIColor(red: 0.07, green: 0.71, blue: 0.84, alpha: 1)
        color.setStroke()

        let path = UIBezierPath()
        path.lineWidth = lw
        path.lineCapStyle = .round

        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: len, y: 0), CGPoint(x: 0, y: 0), CGPoint(x: 0, y: len)),
            (CGPoint(x: rect.width - len, y: 0), CGPoint(x: rect.width, y: 0), CGPoint(x: rect.width, y: len)),
            (CGPoint(x: 0, y: rect.height - len), CGPoint(x: 0, y: rect.height), CGPoint(x: len, y: rect.height)),
            (CGPoint(x: rect.width, y: rect.height - len), CGPoint(x: rect.width, y: rect.height), CGPoint(x: rect.width - len, y: rect.height)),
        ]

        for (a, b, c) in corners {
            path.move(to: a)
            path.addLine(to: b)
            path.addLine(to: c)
        }
        path.stroke()
    }
}
