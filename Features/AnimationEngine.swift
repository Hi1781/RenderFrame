import SceneKit
import simd

/// 关键帧：记录某一时刻设备(rig)位姿与相机位置
struct Keyframe {
    var time: Double
    var rigPosition: SCNVector3
    var rigEuler: SCNVector3      // 欧拉角，弧度
    var rigScale: Float
    var cameraPosition: SCNVector3
}

/// 插值缓动
enum Easing {
    case linear
    case easeInOut
}

/// 时间轴引擎：复刻 iMockup 的关键帧时间轴
final class Timeline {
    var keyframes: [Keyframe] = []     // 按 time 升序
    var easing: Easing = .easeInOut

    init() {
        // 默认两个关键帧：起点(静止) + 终点(旋转)
        keyframes = [
            Keyframe(time: 0,
                     rigPosition: SCNVector3(0, 0, 0),
                     rigEuler: SCNVector3(0, 0, 0),
                     rigScale: 1.0,
                     cameraPosition: SCNVector3(0, 0, 5)),
            Keyframe(time: 4,
                     rigPosition: SCNVector3(0, 0.3, 0),
                     rigEuler: SCNVector3(0, 1.6, 0),
                     rigScale: 1.0,
                     cameraPosition: SCNVector3(0, 0.4, 5))
        ]
    }

    var duration: Double {
        return keyframes.map { $0.time }.max() ?? 4
    }

    func addKeyframe(_ kf: Keyframe) {
        keyframes.append(kf)
        keyframes.sort { $0.time < $1.time }
    }

    func removeKeyframe(at index: Int) {
        guard index >= 0 && index < keyframes.count else { return }
        keyframes.remove(at: index)
    }

    /// 删除最靠近 time 的关键帧（时间轴上的「删除」交互）
    func removeNearest(to time: Double) -> Int? {
        guard let idx = keyframes.indices.min(by: {
            abs(keyframes[$0].time - time) < abs(keyframes[$1].time - time)
        }) else { return nil }
        keyframes.remove(at: idx)
        return idx
    }

    /// 采样：给定时刻返回该帧的设备位姿与相机位置
    func sample(at time: Double) -> (pos: SCNVector3, euler: SCNVector3, scale: Float, cam: SCNVector3) {
        let t = max(0, min(time, duration))
        guard keyframes.count > 1 else {
            let k = keyframes.first
            return (k?.rigPosition ?? SCNVector3(0,0,0), k?.rigEuler ?? SCNVector3(0,0,0), k?.rigScale ?? 1, k?.cameraPosition ?? SCNVector3(0,0,5))
        }
        // 定位前后关键帧
        var lower = keyframes[0]
        var upper = keyframes[keyframes.count - 1]
        for kf in keyframes {
            if kf.time <= t { lower = kf } else { upper = kf; break }
        }
        if upper.time <= lower.time { upper = keyframes[keyframes.count - 1] }
        guard upper.time != lower.time else {
            return (lower.rigPosition, lower.rigEuler, lower.rigScale, lower.cameraPosition)
        }
        let p = CGFloat((t - lower.time) / (upper.time - lower.time))
        let e = ease(p)
        return (
            pos: lerp(lower.rigPosition, upper.rigPosition, Float(e)),
            euler: lerp(lower.rigEuler, upper.rigEuler, Float(e)),
            scale: lower.rigScale + (upper.rigScale - lower.rigScale) * Float(e),
            cam: lerp(lower.cameraPosition, upper.cameraPosition, Float(e))
        )
    }

    /// 在给定时刻写入/更新一个关键帧（时间轴「添加关键帧」）
    func upsertKeyframe(time: Double, rigPosition: SCNVector3, rigEuler: SCNVector3,
                        rigScale: Float, cameraPosition: SCNVector3) {
        if let idx = keyframes.firstIndex(where: { abs($0.time - time) < 0.001 }) {
            var k = keyframes[idx]
            k.rigPosition = rigPosition; k.rigEuler = rigEuler
            k.rigScale = rigScale; k.cameraPosition = cameraPosition
            keyframes[idx] = k
        } else {
            addKeyframe(Keyframe(time: time, rigPosition: rigPosition, rigEuler: rigEuler,
                                 rigScale: rigScale, cameraPosition: cameraPosition))
        }
    }

    private func ease(_ p: CGFloat) -> CGFloat {
        switch easing {
        case .linear: return p
        case .easeInOut:
            let p2 = min(max(p, 0), 1)
            return p2 < 0.5 ? 4 * p2 * p2 * p2 : 1 - pow(-2 * p2 + 2, 3) / 2
        }
    }
}

// MARK: - 数学工具
func lerp(_ a: SCNVector3, _ b: SCNVector3, _ t: Float) -> SCNVector3 {
    return SCNVector3(a.x + (b.x - a.x) * t,
                      a.y + (b.y - a.y) * t,
                      a.z + (b.z - a.z) * t)
}
