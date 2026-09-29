import SceneKit
import UIKit

/// 设备类型：复刻 iMockup 的「设备库」概念
enum DeviceType: Int, CaseIterable {
    case iPhone = 0
    case macBook = 1
    case iPad = 2

    var displayName: String {
        switch self {
        case .iPhone:  return "iPhone"
        case .macBook: return "MacBook"
        case .iPad:    return "iPad"
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
    /// 生成本地库 3D 设备模型（程序化几何，自包含，无外部资源依赖）
    static func makeDevice(_ type: DeviceType) -> MockupDevice {
        switch type {
        case .iPhone:  return makePhone(bodyW: 0.40, bodyH: 0.80, screenW: 0.36, screenH: 0.70)
        case .iPad:    return makePhone(bodyW: 0.70, bodyH: 0.94, screenW: 0.64, screenH: 0.86)
        case .macBook: return makeMacBook()
        }
    }

    // MARK: - 手机 / 平板
    private static func makePhone(bodyW: CGFloat, bodyH: CGFloat,
                                  screenW: CGFloat, screenH: CGFloat) -> MockupDevice {
        let root = SCNNode()
        let bodyWf = Float(bodyW), bodyHf = Float(bodyH)
        let depth: Float = 0.10

        // 机身
        let body = SCNBox(width: CGFloat(bodyWf), height: CGFloat(bodyHf), length: CGFloat(depth), chamferRadius: CGFloat(bodyWf) * 0.12)
        body.firstMaterial?.diffuse.contents = UIColor(white: 0.045, alpha: 1)
        body.firstMaterial?.metalness.contents = 0.85
        body.firstMaterial?.roughness.contents = 0.35
        let bodyNode = SCNNode(geometry: body)
        root.addChildNode(bodyNode)

        // 屏幕（可换贴图的材质）
        let screenMat = SCNMaterial()
        screenMat.diffuse.contents = defaultScreenImage
        screenMat.metalness.contents = 0.1
        screenMat.roughness.contents = 0.25
        screenMat.lightingModel = .physicallyBased
        let screen = SCNPlane(width: screenW, height: screenH)
        screen.firstMaterial = screenMat
        let screenNode = SCNNode(geometry: screen)
        screenNode.position = SCNVector3(0, 0, Float(depth) / 2 + 0.004)
        root.addChildNode(screenNode)

        // 摄像头模组
        let cam = SCNBox(width: 0.05, height: 0.05, length: 0.004, chamferRadius: 0.008)
        cam.firstMaterial?.diffuse.contents = UIColor.black
        cam.firstMaterial?.metalness.contents = 0.5
        cam.firstMaterial?.roughness.contents = 0.6
        let camNode = SCNNode(geometry: cam)
        camNode.position = SCNVector3(0, bodyHf / 2 - 0.06, Float(depth) / 2 + 0.008)
        root.addChildNode(camNode)

        // 侧面按钮（音量 / 电源）
        let btn = SCNBox(width: 0.012, height: 0.07, length: 0.03, chamferRadius: 0.003)
        btn.firstMaterial?.diffuse.contents = UIColor(white: 0.25, alpha: 1)
        btn.firstMaterial?.metalness.contents = 0.6
        btn.firstMaterial?.roughness.contents = 0.5
        let btnNode = SCNNode(geometry: btn)
        btnNode.position = SCNVector3(bodyWf / 2 + 0.004, 0.12, 0)
        root.addChildNode(btnNode)

        return MockupDevice(node: root, screenMaterial: screenMat, scale: 1.0)
    }

    // MARK: - MacBook
    private static func makeMacBook() -> MockupDevice {
        let root = SCNNode()
        let baseW: CGFloat = 0.80, baseD: CGFloat = 0.52, baseH: CGFloat = 0.035
        let lidW: CGFloat = 0.80, lidH: CGFloat = 0.50, lidT: CGFloat = 0.018

        // 底座
        let base = SCNBox(width: baseW, height: baseH, length: baseD, chamferRadius: 0.006)
        base.firstMaterial?.diffuse.contents = UIColor(white: 0.16, alpha: 1)
        base.firstMaterial?.metalness.contents = 0.95
        base.firstMaterial?.roughness.contents = 0.35
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, -0.02, 0)
        root.addChildNode(baseNode)

        // 屏幕（可换贴图材质）
        let screenMat = SCNMaterial()
        screenMat.diffuse.contents = defaultScreenImage
        screenMat.metalness.contents = 0.1
        screenMat.roughness.contents = 0.3
        let screen = SCNPlane(width: CGFloat(lidW), height: CGFloat(lidH))
        screen.firstMaterial = screenMat
        let lidScreen = SCNNode(geometry: screen)
        lidScreen.position = SCNVector3(0, lidH / 2, 0)

        // 屏幕背壳
        let lidBack = SCNBox(width: lidW, height: lidH, length: lidT, chamferRadius: 0.008)
        lidBack.firstMaterial?.diffuse.contents = UIColor(white: 0.20, alpha: 1)
        lidBack.firstMaterial?.metalness.contents = 0.9
        lidBack.firstMaterial?.roughness.contents = 0.4
        let lidNode = SCNNode(geometry: lidBack)
        lidNode.position = SCNVector3(0, lidH / 2, -lidT / 2 - 0.002)
        lidNode.addChildNode(lidScreen)
        // 略微后仰打开
        lidNode.eulerAngles = SCNVector3(0.35, 0, 0)
        root.addChildNode(lidNode)

        return MockupDevice(node: root, screenMaterial: screenMat, scale: 0.9)
    }

    /// 默认屏幕画面（无用户贴图时显示的渐变网格）
    static var defaultScreenImage: UIImage {
        let size = CGSize(width: 640, height: 1280)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        defer { UIGraphicsEndImageContext() }
        UIColor(white: 0.9, alpha: 1).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        // 简单网格示意
        UIColor(white: 0.75, alpha: 1).setStroke()
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
