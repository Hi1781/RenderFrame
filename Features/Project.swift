import SceneKit

/// 工程保存/加载（JSON 序列化场景 + 关键帧），复刻 iMockup 的「项目文件」
struct Project: Codable {
    var device: Int = 0
    var keyframes: [KF] = []
    var duration: Double = 4

    struct KF: Codable {
        var time: Double
        var px: Float; var py: Float; var pz: Float
        var rx: Float; var ry: Float; var rz: Float
        var scale: Float
        var cx: Float; var cy: Float; var cz: Float
    }

    init(timeline: Timeline, device: DeviceType) {
        self.device = device.rawValue
        self.duration = timeline.duration
        for k in timeline.keyframes {
            keyframes.append(KF(time: k.time,
                                px: k.rigPosition.x, py: k.rigPosition.y, pz: k.rigPosition.z,
                                rx: k.rigEuler.x, ry: k.rigEuler.y, rz: k.rigEuler.z,
                                scale: k.rigScale,
                                cx: k.cameraPosition.x, cy: k.cameraPosition.y, cz: k.cameraPosition.z))
        }
    }

    /// 生成 JSON 数据
    func jsonData() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(self)
    }

    /// 从 JSON 数据重建时间轴
    func apply(to timeline: Timeline) {
        timeline.keyframes.removeAll()
        timeline.keyframes = keyframes.map { k in
            Keyframe(time: k.time,
                     rigPosition: SCNVector3(k.px, k.py, k.pz),
                     rigEuler: SCNVector3(k.rx, k.ry, k.rz),
                     rigScale: k.scale,
                     cameraPosition: SCNVector3(k.cx, k.cy, k.cz))
        }
        timeline.keyframes.sort { $0.time < $1.time }
    }
}
