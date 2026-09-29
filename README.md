# RenderFrame — 3D 设备样机动画工作室（iMockup 功能复刻，原生 iOS）

> 纯学习研究项目。用 **Swift + SceneKit** 在 Linux 上交叉编译，产出**未签名裸 IPA**，供个人侧载使用（AltStore / SideStore 本地签名）。
> 全部代码为原创实现，未复制任何商业产品源码。

## 复刻的 iMockup 核心功能

| iMockup（Web/Three.js） | RenderFrame（iOS 原生） | 实现 |
|---|---|---|
| 设备库（iPhone/Mac/iPad） | 程序化 3D 设备模型 | SceneKit 几何构建，自包含无外部资源 |
| 导入截图贴到设备屏幕 | 相册导入贴图 | `UIImagePickerController` → `SCNMaterial.diffuse` |
| 关键帧时间轴动画 | 时间轴 + 关键帧 | `Timeline` 采样 + easeInOut 插值 |
| 运镜动画 | 相机关键帧 | 设备位姿 + 相机位置双轨插值 |
| 播放预览 | 3D 预览 + 播放/拖动 | `SCNView` + CADisplayLink |
| 导出视频 | 离屏逐帧渲染 → MP4 | `SCNRenderer` + `AVAssetWriter`(H.264) |

## 目录结构
```
RenderFrame/
├── App/AppDelegate.swift           入口
├── Features/
│   ├── MockupModel.swift           设备模型工厂（iPhone/MacBook/iPad）
│   ├── AnimationEngine.swift       关键帧时间轴 + 插值引擎
│   ├── VideoExporter.swift         离屏渲染 + AVAssetWriter 导出 MP4
│   └── MainViewController.swift    主界面（设备库/时间轴/贴图/导出）
├── Resources/{Info.plist,entitlements.plist}
├── build.sh                        Linux 交叉编译 → 裸 IPA
└── build-linux/RenderFrame-1.0.0-raw-unsigned.ipa
```

## 构建（复用你已验证的流水线）
前置：Swift 5.8 工具链 + iPhoneOS16.4.sdk + ld64.lld + ldid。
```bash
./build.sh
# 产物：build-linux/RenderFrame-1.0.0-raw-unsigned.ipa
```
关键编译配方（与 PrivacyToolkit 一致）：
```
swiftc -target arm64-apple-ios16.0 -sdk <SDK> -resource-dir <RES> \
       -O -parse-as-library -I <SDK>/usr/lib/swift -emit-executable \
       -Xlinker -adhoc_codesign ...   # → arm64 Mach-O
ldid -S entitlements.plist <exec>      # ad-hoc 签名槽
python3 规范化 zip → Payload/xxx.app → .ipa
```

## 设备端侧载（raw unsigned 裸 IPA）
1. 用 AltStore / SideStore / TrollStore 导入本 IPA（它们会在设备本地完成签名）
2. 打开 App → 顶部切设备 → 「导入图片」贴屏幕 → 时间轴「＋关键帧」摆位 → ▶ 预览 → 「导出MP4」经分享/保存

## 已知限制（学习用途如实说明）
- 程序化设备模型为简化几何，非高精度工业模型
- 导出为 H.264 MP4，未做透明通道 MOV（iMockup 的 Pro 功能）
- 无账号/云端/多人协作（iMockup 的后端能力，纯前端无法替代）
- 需 iOS 16.0+，arm64

## 校验结果
- Mach-O：arm64 / iOS / MH_EXECUTE + ad-hoc 签名槽 ✓
- 框架链接：SceneKit / AVFoundation / Metal / CoreVideo / CoreMedia ✓
- Info.plist：com.renderframe，iOS 16.0，SDK 16.4 ✓
- 规范化 zip：EOCD 末尾，无 zip64，testzip 通过 ✓
