import AVFoundation
import CoreVideo
import CoreMedia
import SceneKit
import UIKit

/// 离屏渲染 + AVAssetWriter 导出 MP4（复刻 iMockup 的「逐帧渲染导出」）
final class VideoExporter {

    struct Config {
        var fps: Int = 30
        var size: CGSize = CGSize(width: 1080, height: 1080)
        var bitrate: Int = 10_000_000
    }

    /// 导出整个时间轴为 MP4
    /// - Parameters:
    ///   - scene: 待渲染的场景
    ///   - timeline: 关键帧时间轴
    ///   - rigNode: 承载设备位姿的根节点（设备挂在其下）
    ///   - camera: 场景相机
    ///   - config: 导出配置
    ///   - url: 输出文件 URL
    ///   - progress: 0.0 ~ 1.0 进度回调（主线程）
    ///   - completion: 结果
    static func export(scene: SCNScene,
                       timeline: Timeline,
                       rigNode: SCNNode,
                       camera: SCNCamera,
                       cameraNode: SCNNode,
                       config: Config,
                       to url: URL,
                       progress: @escaping (Float) -> Void,
                       completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try writeMP4(scene: scene, timeline: timeline, rigNode: rigNode,
                             cameraNode: cameraNode, config: config, to: url,
                             progress: progress)
                DispatchQueue.main.async { completion(.success(url)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    // MARK: - 核心写 MP4
    private static func writeMP4(scene: SCNScene,
                                 timeline: Timeline,
                                 rigNode: SCNNode,
                                 cameraNode: SCNNode,
                                 config: Config,
                                 to url: URL,
                                 progress: @escaping (Float) -> Void) throws {
        try FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: config.size.width,
            AVVideoHeightKey: config.size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: config.bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: config.size.width,
                kCVPixelBufferHeightKey as String: config.size.height
            ])
        guard writer.canAdd(input) else {
            throw ExportError.cannotAddInput
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? ExportError.startFailed
        }
        writer.startSession(atSourceTime: .zero)

        // 离屏渲染器：整帧渲染（复刻 iMockup 的离屏逐帧渲染）
        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode

        let totalFrames = max(1, Int(Double(config.fps) * timeline.duration))
        var pool: CVPixelBufferPool?

        CVPixelBufferPoolCreate(nil, nil, [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: config.size.width,
            kCVPixelBufferHeightKey as String: config.size.height
        ] as CFDictionary, &pool)

        var frameIndex = 0
        while input.isReadyForMoreMediaData, frameIndex < totalFrames {
            let time = Double(frameIndex) / Double(config.fps)
            let s = timeline.sample(at: time)

            // 更新设备位姿
            rigNode.position = s.pos
            rigNode.eulerAngles = s.euler
            rigNode.scale = SCNVector3(s.scale, s.scale, s.scale)
            // 更新相机
            cameraNode.position = s.cam

            // 离屏渲染当前帧 → UIImage
            autoreleasepool {
                let image = renderer.snapshot(atTime: time, with: config.size,
                                              antialiasingMode: .multisampling4X)
                if let buffer = makePixelBuffer(from: image, pool: pool) {
                    let pts = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(config.fps))
                    _ = adaptor.append(buffer, withPresentationTime: pts)
                }
                frameIndex += 1
                if frameIndex % 3 == 0 || frameIndex == totalFrames {
                    let p = Float(frameIndex) / Float(totalFrames)
                    DispatchQueue.main.async { progress(p) }
                }
            }
        }

        input.markAsFinished()
        let sema = DispatchSemaphore(value: 0)
        writer.finishWriting { sema.signal() }
        _ = sema.wait(timeout: .now() + 60)

        if let err = writer.error { throw err }
        guard writer.status == .completed else { throw ExportError.writeIncomplete }
    }

    /// UIImage → CVPixelBuffer (BGRA)
    private static func makePixelBuffer(from image: UIImage, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        let w = Int(image.size.width), h = Int(image.size.height)
        var buffer: CVPixelBuffer?
        if let pool = pool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        } else {
            CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, nil, &buffer)
        }
        guard let buf = buffer else { return nil }

        CVPixelBufferLockBaseAddress(buf, [])
        defer { CVPixelBufferUnlockBaseAddress(buf, []) }

        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf),
                                  width: w, height: h,
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue |
                                              CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        ctx.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: w, height: h))
        return buf
    }

    enum ExportError: LocalizedError {
        case cannotAddInput, startFailed, writeIncomplete
        var errorDescription: String? {
            switch self {
            case .cannotAddInput: return "无法添加视频输入"
            case .startFailed:    return "写入器启动失败"
            case .writeIncomplete: return "视频写出未完成"
            }
        }
    }
}
