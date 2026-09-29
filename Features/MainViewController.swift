import UIKit
import SceneKit

/// 主界面（工作分区布局，仿 iMockup 编辑器）：
///   顶栏：设备库 + 设置 + 保存/加载 + 导入/导出
///   中央：3D 预览区（最大）
///   底部：时间轴（播放/拖动/关键帧）
final class MainViewController: UIViewController {

    // MARK: - 场景
    private let sceneView = SCNView()
    private let scene = SCNScene()
    private let cameraNode = SCNNode()
    private let rigNode = SCNNode()          // 设备位姿根节点
    private var screenMaterial: SCNMaterial?
    private var currentDevice: DeviceType = .iPhone

    // MARK: - 时间轴状态
    private let timeline = Timeline()
    private var currentTime: Double = 0
    private var isPlaying = false
    private var displayLink: CADisplayLink?
    private var lastTick = CACurrentMediaTime()

    // MARK: - 导出设置
    private var exportResolution: Int = 1080
    private var exportFPS: Int = 30

    // MARK: - UI 控件
    private let deviceControl = UISegmentedControl(items: DeviceType.allCases.map { $0.displayName })
    private let importButton = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let loadButton = UIButton(type: .system)
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
    }

    deinit { displayLink?.invalidate() }

    // MARK: - Scene
    private func setupScene() {
        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = UIColor(white: 0.10, alpha: 1)

        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 50
        cameraNode.position = SCNVector3(0, 0.4, 5)
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(rigNode)

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
        rigNode.childNodes.forEach { $0.removeFromParentNode() }
        let d = MockupFactory.makeDevice(type)
        rigNode.addChildNode(d.node)
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
        kfInfoLabel.text = "\(timeline.keyframes.count) KF"
    }

    // MARK: - UI 构建（工作分区）
    private func setupUI() {
        deviceControl.selectedSegmentIndex = currentDevice.rawValue
        deviceControl.addTarget(self, action: #selector(deviceChanged(_:)), for: .valueChanged)

        style(settingsButton, title: "⚙")
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        style(saveButton, title: "保存")
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        style(loadButton, title: "加载")
        loadButton.addTarget(self, action: #selector(loadTapped), for: .touchUpInside)
        style(importButton, title: "图片")
        importButton.addTarget(self, action: #selector(importTapped), for: .touchUpInside)
        style(exportButton, title: "导出")
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)

        style(playButton, title: "▶")
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        style(addKFButton, title: "＋KF")
        addKFButton.addTarget(self, action: #selector(addKFTapped), for: .touchUpInside)
        style(delKFButton, title: "－KF")
        delKFButton.addTarget(self, action: #selector(delKFTapped), for: .touchUpInside)

        timeSlider.minimumValue = 0
        timeSlider.maximumValue = 1
        timeSlider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        timeLabel.textColor = .white
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        kfInfoLabel.textColor = UIColor(white: 0.8, alpha: 1)
        kfInfoLabel.font = UIFont.systemFont(ofSize: 11)
        kfInfoLabel.textAlignment = .right

        // 顶栏：设备库 + 操作
        let topBar = UIStackView(arrangedSubviews: [deviceControl, settingsButton, saveButton, loadButton,
                                                    importButton, exportButton])
        topBar.axis = .horizontal; topBar.spacing = 6; topBar.alignment = .center
        view.addSubview(topBar)

        // 中央：3D 预览
        view.addSubview(sceneView)

        // 底部：时间轴
        let playRow = UIStackView(arrangedSubviews: [playButton, timeSlider, timeLabel, addKFButton, delKFButton, kfInfoLabel])
        playRow.axis = .horizontal; playRow.spacing = 6; playRow.alignment = .center
        view.addSubview(playRow)

        for v in [topBar, sceneView, playRow] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: g.topAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 10),
            topBar.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -10),

            sceneView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 8),
            sceneView.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 10),
            sceneView.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -10),

            playRow.topAnchor.constraint(equalTo: sceneView.bottomAnchor, constant: 10),
            playRow.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 10),
            playRow.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -10),
            playRow.bottomAnchor.constraint(lessThanOrEqualTo: g.bottomAnchor, constant: -10),

            timeSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            timeLabel.widthAnchor.constraint(equalToConstant: 44),
            deviceControl.widthAnchor.constraint(lessThanOrEqualToConstant: 220)
        ])
    }

    private func style(_ btn: UIButton, title: String) {
        btn.setTitle(title, for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor(white: 0.25, alpha: 1)
        btn.layer.cornerRadius = 8
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
            displayLink?.invalidate(); displayLink = nil
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

    // MARK: - 导出设置
    @objc private func settingsTapped() {
        let a = UIAlertController(title: "导出设置", message: "分辨率 \(exportResolution)P · 帧率 \(exportFPS)fps",
                                  preferredStyle: .alert)
        a.addTextField { $0.placeholder = "分辨率 (720/1080/2160)" }
        a.addTextField { $0.placeholder = "帧率 (24/30/60)" }
        a.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            guard let self = self else { return }
            if let r = Int(a.textFields?[0].text ?? ""), r >= 720 { self.exportResolution = r }
            if let f = Int(a.textFields?[1].text ?? ""), (24...60).contains(f) { self.exportFPS = f }
        })
        a.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(a, animated: true)
    }

    // MARK: - 导出视频
    @objc private func exportTapped() {
        let size = CGSize(width: exportResolution, height: exportResolution)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("RenderFrame_\(Int(Date().timeIntervalSince1970)).mp4")
        let alert = UIAlertController(title: "导出中…",
                                      message: "离屏逐帧渲染 (\(exportResolution)P/\(exportFPS)fps)",
                                      preferredStyle: .alert)
        present(alert, animated: true)

        let config = VideoExporter.Config(fps: exportFPS, size: size,
                                          bitrate: exportResolution > 1500 ? 18_000_000 : 10_000_000)
        VideoExporter.export(scene: scene, timeline: timeline, rigNode: rigNode,
                             camera: cameraNode.camera!, cameraNode: cameraNode,
                             config: config, to: tmp,
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

    // MARK: - 保存 / 加载工程
    @objc private func saveTapped() {
        do {
            let project = Project(timeline: timeline, device: currentDevice)
            let data = try project.jsonData()
            let dir = projectDir()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let name = "RenderFrame_\(Int(Date().timeIntervalSince1970)).json"
            try data.write(to: dir.appendingPathComponent(name))
            toast("已保存: \(name)")
        } catch {
            toast("保存失败: \(error.localizedDescription)")
        }
    }

    @objc private func loadTapped() {
        let dir = projectDir()
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()) ?? []
        guard !files.isEmpty else { toast("无已保存工程"); return }
        let a = UIAlertController(title: "选择工程", message: nil, preferredStyle: .actionSheet)
        for f in files {
            a.addAction(UIAlertAction(title: f, style: .default) { [weak self] _ in
                self?.applyProject(at: dir.appendingPathComponent(f))
            })
        }
        a.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(a, animated: true)
    }

    private func applyProject(at url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let p = try JSONDecoder().decode(Project.self, from: data)
            p.apply(to: timeline)
            if let d = DeviceType(rawValue: p.device) {
                currentDevice = d
                deviceControl.selectedSegmentIndex = d.rawValue
                loadDevice(d)
            }
            applyTimelineFrame(at: 0)
            toast("已加载工程")
        } catch {
            toast("加载失败: \(error.localizedDescription)")
        }
    }

    private func projectDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MockupProjects", isDirectory: true)
    }

    private func saveToDocuments(_ url: URL) {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        try? FileManager.default.copyItem(at: url, to: docs.appendingPathComponent(url.lastPathComponent))
    }

    private func toast(_ text: String) {
        let a = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "好", style: .default))
        present(a, animated: true)
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
