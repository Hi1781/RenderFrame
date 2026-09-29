import UIKit
import SceneKit

/// 主界面：3D 预览 + 设备库 + 关键帧时间轴 + 导入贴图 + 导出视频
final class MainViewController: UIViewController {

    // MARK: - 场景
    private let sceneView = SCNView()
    private let scene = SCNScene()
    private let cameraNode = SCNNode()
    private let rigNode = SCNNode()          // 设备位姿根节点
    private var deviceNode: SCNNode?         // 当前设备
    private var screenMaterial: SCNMaterial? // 屏幕材质（贴图入口）
    private var currentDevice: DeviceType = .iPhone

    // MARK: - 时间轴状态
    private let timeline = Timeline()
    private var currentTime: Double = 0
    private var isPlaying = false
    private var displayLink: CADisplayLink?
    private var lastTick = CACurrentMediaTime()

    // MARK: - UI
    private let deviceControl = UISegmentedControl(items: DeviceType.allCases.map { $0.displayName })
    private let importButton = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)
    private let timeSlider = UISlider()
    private let timeLabel = UILabel()
    private let addKFButton = UIButton(type: .system)
    private let delKFButton = UIButton(type: .system)
    private let kfInfoLabel = UILabel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.08, alpha: 1)
        setupScene()
        setupUI()
        loadDevice(.iPhone)
        applyTimelineFrame(at: 0)
        timeLabel.text = "0.0s"
    }

    deinit { displayLink?.invalidate() }

    // MARK: - Scene 初始化
    private func setupScene() {
        sceneView.scene = scene
        sceneView.allowsCameraControl = true    // 手拖旋转观察
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = UIColor(white: 0.12, alpha: 1)

        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 50
        cameraNode.position = SCNVector3(0, 0.4, 5)
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(rigNode)

        // 灯光
        let ambient = SCNNode()
        ambient.light = SCNLight(); ambient.light?.type = .ambient
        ambient.light?.intensity = 500
        scene.rootNode.addChildNode(ambient)

        let dir = SCNNode()
        dir.light = SCNLight(); dir.light?.type = .directional
        dir.light?.intensity = 800
        dir.position = SCNVector3(3, 4, 5)
        scene.rootNode.addChildNode(dir)
    }

    // MARK: - 设备库
    private func loadDevice(_ type: DeviceType) {
        deviceNode?.removeFromParentNode()
        let d = MockupFactory.makeDevice(type)
        rigNode.addChildNode(d.node)
        deviceNode = d.node
        screenMaterial = d.screenMaterial
        d.node.scale = SCNVector3(d.scale, d.scale, d.scale)
    }

    // MARK: - 时间轴帧应用
    private func applyTimelineFrame(at time: Double) {
        let s = timeline.sample(at: time)
        rigNode.position = s.pos
        rigNode.eulerAngles = s.euler
        rigNode.scale = SCNVector3(s.scale, s.scale, s.scale)
        cameraNode.position = s.cam
        currentTime = time
        timeSlider.value = Float(time / max(timeline.duration, 0.001))
        timeLabel.text = String(format: "%.1fs", time)
        kfInfoLabel.text = "\(timeline.keyframes.count) 关键帧"
    }

    // MARK: - UI 构建
    private func setupUI() {
        deviceControl.selectedSegmentIndex = currentDevice.rawValue
        deviceControl.addTarget(self, action: #selector(deviceChanged(_:)), for: .valueChanged)

        style(importButton, title: "导入图片")
        importButton.addTarget(self, action: #selector(importTapped), for: .touchUpInside)
        style(exportButton, title: "导出MP4")
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)

        style(playButton, title: "▶")
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        style(addKFButton, title: "＋关键帧")
        addKFButton.addTarget(self, action: #selector(addKFTapped), for: .touchUpInside)
        style(delKFButton, title: "－关键帧")
        delKFButton.addTarget(self, action: #selector(delKFTapped), for: .touchUpInside)

        timeSlider.minimumValue = 0
        timeSlider.maximumValue = 1
        timeSlider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        timeLabel.textColor = .white
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        kfInfoLabel.textColor = UIColor(white: 0.8, alpha: 1)
        kfInfoLabel.font = UIFont.systemFont(ofSize: 11)
        kfInfoLabel.textAlignment = .right

        let topBar = UIStackView(arrangedSubviews: [deviceControl, importButton, exportButton])
        topBar.axis = .horizontal; topBar.spacing = 8; topBar.distribution = .fill
        view.addSubview(topBar)

        view.addSubview(sceneView)

        let playRow = UIStackView(arrangedSubviews: [playButton, timeSlider, timeLabel])
        playRow.axis = .horizontal; playRow.spacing = 8; playRow.alignment = .center
        view.addSubview(playRow)

        let kfRow = UIStackView(arrangedSubviews: [addKFButton, delKFButton, kfInfoLabel])
        kfRow.axis = .horizontal; kfRow.spacing = 8; kfRow.alignment = .center
        view.addSubview(kfRow)

        topBar.translatesAutoresizingMaskIntoConstraints = false
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        playRow.translatesAutoresizingMaskIntoConstraints = false
        kfRow.translatesAutoresizingMaskIntoConstraints = false

        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: g.topAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 12),
            topBar.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -12),

            sceneView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 8),
            sceneView.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 12),
            sceneView.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -12),

            playRow.topAnchor.constraint(equalTo: sceneView.bottomAnchor, constant: 10),
            playRow.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 12),
            playRow.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -12),

            kfRow.topAnchor.constraint(equalTo: playRow.bottomAnchor, constant: 10),
            kfRow.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 12),
            kfRow.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -12),
            kfRow.bottomAnchor.constraint(lessThanOrEqualTo: g.bottomAnchor, constant: -12),

            timeSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            timeLabel.widthAnchor.constraint(equalToConstant: 46)
        ])
    }

    private func style(_ btn: UIButton, title: String) {
        btn.setTitle(title, for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor(white: 0.25, alpha: 1)
        btn.layer.cornerRadius = 8
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
    }

    // MARK: - Actions
    @objc private func deviceChanged(_ seg: UISegmentedControl) {
        guard let t = DeviceType(rawValue: seg.selectedSegmentIndex) else { return }
        currentDevice = t
        loadDevice(t)
        applyTimelineFrame(at: currentTime)
    }

    @objc private func playTapped() {
        isPlaying.toggle()
        playButton.setTitle(isPlaying ? "⏸" : "▶", for: .normal)
        if isPlaying {
            lastTick = CACurrentMediaTime()
            let dl = CADisplayLink(target: self, selector: #selector(tick))
            dl.add(to: .main, forMode: .common)
            displayLink = dl
        } else {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = now - lastTick
        lastTick = now
        currentTime += dt
        if currentTime >= timeline.duration {
            currentTime = timeline.duration
            applyTimelineFrame(at: currentTime)
            stopPlayback()
            return
        }
        applyTimelineFrame(at: currentTime)
    }

    private func stopPlayback() {
        isPlaying = false
        playButton.setTitle("▶", for: .normal)
        displayLink?.invalidate(); displayLink = nil
    }

    @objc private func sliderChanged(_ s: UISlider) {
        let t = Double(s.value) * timeline.duration
        applyTimelineFrame(at: t)
    }

    @objc private func addKFTapped() {
        timeline.upsertKeyframe(time: currentTime,
                                rigPosition: rigNode.position,
                                rigEuler: rigNode.eulerAngles,
                                rigScale: rigNode.scale.x,
                                cameraPosition: cameraNode.position)
        applyTimelineFrame(at: currentTime)
    }

    @objc private func delKFTapped() {
        _ = timeline.removeNearest(to: currentTime)
        applyTimelineFrame(at: currentTime)
    }

    @objc private func importTapped() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func exportTapped() {
        guard let mat = screenMaterial else { return }
        _ = mat
        // 存到临时目录
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("RenderFrame_\(Int(Date().timeIntervalSince1970)).mp4")
        let alert = UIAlertController(title: "导出中…", message: "离屏逐帧渲染，请稍候", preferredStyle: .alert)
        present(alert, animated: true)

        let config = VideoExporter.Config(fps: 30, size: CGSize(width: 1080, height: 1080), bitrate: 10_000_000)
        VideoExporter.export(scene: scene, timeline: timeline,
                             rigNode: rigNode, camera: cameraNode.camera!,
                             cameraNode: cameraNode, config: config, to: tmp,
                             progress: { _ in },
                             completion: { [weak self] result in
            alert.dismiss(animated: true) {
                guard let self = self else { return }
                switch result {
                case .success(let url):
                    self.saveToDocuments(url)
                    let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    self.present(av, animated: true)
                case .failure(let e):
                    let err = UIAlertController(title: "导出失败", message: e.localizedDescription,
                                                preferredStyle: .alert)
                    err.addAction(UIAlertAction(title: "好", style: .default))
                    self.present(err, animated: true)
                }
            }
        })
    }

    private func saveToDocuments(_ url: URL) {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dest = docs.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.copyItem(at: url, to: dest)
    }
}

// MARK: - 图片导入（贴到设备屏幕）
extension MainViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        screenMaterial?.diffuse.contents = image
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
