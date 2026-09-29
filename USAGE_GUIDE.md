# RenderFrame 使用引导

RenderFrame 是一款原生 iOS 侧载应用，复刻 3D 设备样机动画工具（iMockup）的核心工作流，在设备本地完成建模、动画与视频导出。以下是从安装到使用的完整步骤。

## 一、安装（侧载）

IPA 为**未签名裸包**，需要在设备端侧载签名后运行。推荐任选其一：

| 工具 | 说明 |
| --- | --- |
| AltStore / AltServer | 经典侧载，需在电脑安装 AltServer，Wi-Fi 同步签名 |
| SideStore | 类 AltStore，可无线签名，无需电脑常驻 |
| Sideloadly | 图形化侧载工具，拖入 IPA 即可 |
| LiveContainer | 沙盒容器，直接加载未签名 App 进行测试 |

> 侧载包通常每 7 天需重新签名一次（取决于 Apple ID 免费额度）。

## 二、制作样机动画

1. 打开 RenderFrame，顶部切换**设备库**（iPhone / MacBook / iPad）。
2. 点 **「导入图片」**，从相册选择 UI 截图，自动贴到设备屏幕。
3. 在时间轴上点 **「＋关键帧」**，把设备摆到想要的位置/角度，重复添加多帧。
4. 点 **「▶」** 播放预览；可拖动时间滑块、用 **「－关键帧」** 删除多余帧。
5. 点 **「导出MP4」**，离屏逐帧渲染后经系统分享/保存到文件。

## 三、构建与校验（Linux 交叉编译）

```bash
./build.sh        # 产出 build-linux/RenderFrame-<ver>-raw-unsigned.ipa
python3 verify.py build-linux/Payload/RenderFrame.app/RenderFrame \
         build-linux/Payload/RenderFrame.app/Info.plist \
         build-linux/RenderFrame-<ver>-raw-unsigned.ipa
```

## 四、免责声明

本项目**仅用于合法的应用开发学习与研究**。设备模型为原创程序化几何，未使用任何受版权保护的商业模型或第三方素材。
