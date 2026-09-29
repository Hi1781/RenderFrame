import SceneKit
import UIKit

/// 设备类型：复刻 iMockup 的「设备库」概念（v1.1 扩充机型）
enum DeviceType: Int, CaseIterable {
    case iPhone = 0
    case iPhonePro = 1
    case macBook = 2
    case iPad = 3
    case watch = 4

    var displayName: String {
        switch self {
        case .iPhone:     return "iPhone 15"
        case .iPhonePro:  return "iPhone 15 Pro"
        case .macBook:    return "MacBook Pro"
        case .iPad:       return "iPad Pro"
        case .watch:      return "Apple Watch"
        }
    }
}

/// 返回一个设备节点与其「屏幕材质」（可替换贴图）
struct MockupDevice {
    let node: SCNNode
    let screenMaterial: SCNMaterial
    let scale: Float
}

enum MockupFactory {
    /// 生成本地库 3D 设备模型（程序化原创几何，自包含，无外部资源依赖）
    static func makeDevice(_ type: DeviceType) -> MockupDevice {
        switch type {
        case .iPhone:    return makePhone(bodyW: 0.40, bodyH: 0.80, screenW: 0.365, screenH: 0.71,
                                          bodyColor: 0.98, metalness: 0.75)
        case .iPhonePro: return makePhone(bodyW: 0.40, bodyH: 0.80, screenW: 0.368, screenH: 0.712,
                                          bodyColor: 0.70, metalness: 0.95) // 钛金属灰
        case .iPad:      return makePhone(bodyW: 0.70, bodyH: 0.94, screenW: 0.645, screenH: 0.87,
                                          bodyColor: 0.92, metalness: 0.80)
        case .macBook:   return makeMacBook()
        case .watch:     return makeWatch()
        }
    }

    // MARK: - 手机 / 平板（高保真：金属机身 + 摄像头岛 + 侧键 + 屏幕玻璃）
    private static func makePhone(bodyW: CGFloat, bodyH: CGFloat,
                                  screenW: CGFloat, screenH: CGFloat,
                                  bodyColor: CGFloat, metalness: CGFloat) -> MockupDevice {
        let root = SCNNode()
        let bw = Float(bodyW), bh = Float(bodyH)
        let depth: Float = 0.115

        // 机身（金属边框）
        let body = SCNBox(width: bodyW, height: bodyH, length: CGFloat(depth), chamferRadius: bodyW * 0.14)
        body.firstMaterial?.diffuse.contents = UIColor(white: bodyColor, alpha: 1)
        body.firstMaterial?.metalness.contents = metalness
        body.firstMaterial?.roughness.contents = 0.32
        let bodyNode = SCNNode(geometry: body)
        root.addChildNode(bodyNode)

        // 屏幕玻璃（半透 + 镜面）
        let screenMat = SCNMaterial()
        screenMat.diffuse.contents = defaultScreenImage
        screenMat.metalness.contents = 0.05
        screenMat.roughness.contents = 0.15
        screenMat.lightingModel = .physicallyBased
        screenMat.isDoubleSided = false
        let screen = SCNPlane(width: screenW, height: screenH)
        screen.firstMaterial = screenMat
        let screenNode = SCNNode(geometry: screen)
        screenNode.position = SCNVector3(0, 0, depth / 2 + 0.004)
        root.addChildNode(screenNode)

        // 灵动岛（胶囊）
        let island = SCNBox(width: 0.10, height: 0.022, length: 0.004, chamferRadius: 0.010)
        island.firstMaterial?.diffuse.contents = UIColor.black
        island.firstMaterial?.roughness.contents = 0.4
        let islandNode = SCNNode(geometry: island)
        islandNode.position = SCNVector3(0, bh / 2 - 0.035, depth / 2 + 0.009)
        root.addChildNode(islandNode)

        // 后置摄像头模组
        let camRing = SCNBox(width: 0.05, height: 0.05, length: 0.006, chamferRadius: 0.012)
        camRing.firstMaterial?.diffuse.contents = UIColor(white: 0.05, alpha: 1)
        camRing.firstMaterial?.metalness.contents = 0.9
        camRing.firstMaterial?.roughness.contents = 0.25
        let camNode = SCNNode(geometry: camRing)
        camNode.position = SCNVector3(0, bh / 2 - 0.09, depth / 2 + 0.008)
        root.addChildNode(camNode)

        // 侧键（音量/电源）
        let btn = SCNBox(width: 0.013, height: 0.07, length: 0.032, chamferRadius: 0.003)
        btn.firstMaterial?.diffuse.contents = UIColor(white: 0.30, alpha: 1)
        btn.firstMaterial?.metalness.contents = 0.7
        btn.firstMaterial?.roughness.contents = 0.4
        let btnNode = SCNNode(geometry: btn)
        btnNode.position = SCNVector3(bw / 2 + 0.004, 0.12, 0)
        root.addChildNode(btnNode)

        return MockupDevice(node: root, screenMaterial: screenMat, scale: 1.0)
    }

    // MARK: - MacBook Pro
    private static func makeMacBook() -> MockupDevice {
        let root = SCNNode()
        let baseW: CGFloat = 0.82, baseD: CGFloat = 0.55, baseH: CGFloat = 0.036
        let lidW: CGFloat = 0.82, lidH: CGFloat = 0.53, lidT: CGFloat = 0.016

        let base = SCNBox(width: baseW, height: baseH, length: baseD, chamferRadius: 0.006)
        base.firstMaterial?.diffuse.contents = UIColor(white: 0.62, alpha: 1) // 银色
        base.firstMaterial?.metalness.contents = 0.9
        base.firstMaterial?.roughness.contents = 0.3
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, -0.02, 0)
        root.addChildNode(baseNode)

        let screenMat = SCNMaterial()
        screenMat.diffuse.contents = defaultScreenImage
        screenMat.metalness.contents = 0.05
        screenMat.roughness.contents = 0.2
        let screen = SCNPlane(width: lidW, height: lidH)
        screen.firstMaterial = screenMat
        let lidScreen = SCNNode(geometry: screen)
        lidScreen.position = SCNVector3(0, lidH / 2, 0)

        let lidBack = SCNBox(width: lidW, height: lidH, length: lidT, chamferRadius: 0.008)
        lidBack.firstMaterial?.diffuse.contents = UIColor(white: 0.60, alpha: 1)
        lidBack.firstMaterial?.metalness.contents = 0.9
        lidBack.firstMaterial?.roughness.contents = 0.3
        let lidNode = SCNNode(geometry: lidBack)
        lidNode.position = SCNVector3(0, lidH / 2, -lidT / 2 - 0.002)
        lidNode.addChildNode(lidScreen)
        lidNode.eulerAngles = SCNVector3(0.35, 0, 0)
        root.addChildNode(lidNode)

        return MockupDevice(node: root, screenMaterial: screenMat, scale: 0.92)
    }

    // MARK: - Apple Watch
    private static func makeWatch() -> MockupDevice {
        let root = SCNNode()
        let w: Float = 0.24, h: Float = 0.30, d: Float = 0.035

        // 表体（圆角方形，钛金属）
        let body = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: 0.055)
        body.firstMaterial?.diffuse.contents = UIColor(white: 0.62, alpha: 1)
        body.firstMaterial?.metalness.contents = 0.9
        body.firstMaterial?.roughness.contents = 0.32
        let bodyNode = SCNNode(geometry: body)
        root.addChildNode(bodyNode)

        // 屏幕
        let screenMat = SCNMaterial()
        screenMat.diffuse.contents = defaultScreenImage
        screenMat.metalness.contents = 0.05
        screenMat.roughness.contents = 0.18
        let screen = SCNPlane(width: CGFloat(w) - 0.02, height: CGFloat(h) - 0.02)
        screen.firstMaterial = screenMat
        let screenNode = SCNNode(geometry: screen)
        screenNode.position = SCNVector3(0, 0, d / 2 + 0.002)
        root.addChildNode(screenNode)

        // 表冠
        let crown = SCNBox(width: 0.012, height: 0.03, length: 0.02, chamferRadius: 0.004)
        crown.firstMaterial?.diffuse.contents = UIColor(white: 0.35, alpha: 1)
        crown.firstMaterial?.metalness.contents = 0.7
        let crownNode = SCNNode(geometry: crown)
        crownNode.position = SCNVector3(w / 2 + 0.004, h / 2 - 0.03, 0)
        root.addChildNode(crownNode)

        // 表带（上下两条软带）
        for sign: Float in [-1, 1] {
            let band = SCNBox(width: CGFloat(w * 0.7), height: 0.12, length: 0.012, chamferRadius: 0.008)
            band.firstMaterial?.diffuse.contents = UIColor(white: 0.25, alpha: 1)
            band.firstMaterial?.roughness.contents = 0.9
            let bandNode = SCNNode(geometry: band)
            bandNode.position = SCNVector3(0, sign * (h / 2 + 0.06), 0)
            root.addChildNode(bandNode)
        }
        return MockupDevice(node: root, screenMaterial: screenMat, scale: 1.35)
    }

    /// 默认屏幕画面（无用户贴图时显示的渐变网格）
    static var defaultScreenImage: UIImage {
        let size = CGSize(width: 640, height: 1280)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        defer { UIGraphicsEndImageContext() }
        UIColor(white: 0.9, alpha: 1).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        UIColor(white: 0.72, alpha: 1).setStroke()
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.setLineWidth(1)
        for x in stride(from: 0, to: 640, by: 80) {
            ctx?.move(to: CGPoint(x: x, y: 0)); ctx?.addLine(to: CGPoint(x: x, y: 1280))
        }
        for y in stride(from: 0, to: 1280, by: 160) {
            ctx?.move(to: CGPoint(x: 0, y: y)); ctx?.addLine(to: CGPoint(x: 640, y: y))
        }
        ctx?.strokePath()
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}
