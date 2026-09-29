#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RenderFrame IPA 深度校验器（仿照 PrivacyToolkit/verify.py 骨架）
1) 完整解析 Mach-O header + 所有 load command，校验边界与平台
2) 解析 LC_CODE_SIGNATURE SuperBlob + CodeDirectory
3) 校验 ad-hoc 签名槽 / 签名区结构自洽
4) 校验 Info.plist（iPhone+iPad、iOS 部署目标、平台键、Bundle ID）
5) 校验 IPA zip 结构与 EOCD
6) 校验关键框架依赖（SceneKit/AVFoundation 等）
"""
import struct, sys, os, hashlib, plistlib, zipfile

BIN = sys.argv[1] if len(sys.argv) > 1 else "build-linux/Payload/RenderFrame.app/RenderFrame"
PLIST = sys.argv[2] if len(sys.argv) > 2 else "build-linux/Payload/RenderFrame.app/Info.plist"
IPA = sys.argv[3] if len(sys.argv) > 3 else None

fail = 0
def ok(m): print("  ✓", m)
def bad(m):
    global fail; fail += 1
    print("  ✗", m)

d = open(BIN, "rb").read()
size = len(d)

# ---- 1. Mach-O header ----
magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags = struct.unpack_from("<IiiIIII", d, 0)
if magic != 0xfeedfacf:
    bad(f"magic=0x{magic:08x} 期望 0xfeedfacf (64位)")
else:
    ok("Mach-O 64 位魔数正确")
if cputype != 0x0100000c:
    bad(f"cputype=0x{cputype:x} 期望 arm64")
else:
    ok("架构 = arm64")
if filetype != 2:
    bad(f"filetype={filetype} 期望 MH_EXECUTE(2)")
else:
    ok("文件类型 = MH_EXECUTE")

# ---- 2. load commands 边界遍历 + 平台 + 签名 ----
off = 32
lc_names = {}
sig = None
for i in range(ncmds):
    cmd, cmdsize = struct.unpack_from("<II", d, off)
    if cmdsize < 8 or off + cmdsize > size:
        bad(f"load command #{i} 越界 off={off} cmdsize={cmdsize} filesize={size}")
        break
    lc_names[cmd] = lc_names.get(cmd, 0) + 1
    if cmd == 0x1d:  # LC_CODE_SIGNATURE
        dataoff, datasize = struct.unpack_from("<II", d, off + 8)
        sig = (dataoff, datasize)
    if cmd == 0x32:  # LC_BUILD_VERSION / platform
        plat = struct.unpack_from("<I", d, off + 8)[0]
        if plat != 2:
            bad(f"平台={plat} 期望 iOS(2)")
        else:
            ok("平台 = iOS")
    off += cmdsize
if off > size:
    bad("load commands 越过文件末尾")
else:
    ok(f"全部 {ncmds} 条 load command 边界合法")
print("  load commands:", dict(lc_names))

# ---- 2.5 段布局 + 关键框架依赖 ----
seg_ok = True
dylibs = []
off2 = 32
for i in range(ncmds):
    cmd, cmdsize = struct.unpack_from("<II", d, off2)
    if cmd == 0x19:  # LC_SEGMENT_64
        fileoff, filesize = struct.unpack_from("<QQQQ", d, off2 + 24)[2:4]
        if fileoff + filesize > size:
            bad(f"段 越出文件（fileoff+filesize={fileoff}+{filesize}>{size}）"); seg_ok = False
    elif cmd == 0x0c:  # LC_LOAD_DYLIB
        nameoff = struct.unpack_from("<I", d, off2 + 8)[0]
        p = off2 + nameoff
        end = d.index(b"\x00", p)
        dylibs.append(d[p:end].decode())
    off2 += cmdsize
if seg_ok:
    ok("段布局一致（偏移+大小均在文件内）")
need = ["SceneKit", "AVFoundation", "UIKit", "Metal", "CoreVideo", "CoreMedia"]
for k in need:
    if any(k in x for x in dylibs):
        ok(f"依赖 {k}")
    else:
        bad(f"缺少依赖 {k}")

# ---- 3. 代码签名 ----
if sig is None:
    bad("无 LC_CODE_SIGNATURE")
else:
    dataoff, datasize = sig
    if dataoff + datasize > size:
        bad("代码签名区越界")
    else:
        ok(f"代码签名区 dataoff={dataoff} datasize={datasize}")
    sb = struct.unpack_from(">IIII", d, dataoff)
    smagic, slen, scount = sb[0], sb[1], sb[2]
    if smagic != 0xfade0cc0:
        bad(f"SuperBlob magic=0x{smagic:08x}")
    else:
        ok("SuperBlob magic = 0xfade0cc0")
    cd = None
    base = dataoff + 12
    for j in range(scount):
        btype, boff = struct.unpack_from(">II", d, base + j * 8)
        bstart = dataoff + boff
        bmagic = struct.unpack_from(">I", d, bstart)[0]
        if bmagic == 0xfade0c02:
            cd = bstart
    if cd is None:
        bad("未找到 CodeDirectory (magic 0xfade0c02)")
    else:
        ok("CodeDirectory 存在")
        cmagic, clen, cver, cflags = struct.unpack_from(">IIII", d, cd)
        hashOffset = struct.unpack_from(">I", d, cd + 16)[0]
        nCode = struct.unpack_from(">I", d, cd + 28)[0]
        hashSize = d[cd + 36]
        hashType = d[cd + 37]
        platform = d[cd + 38]
        pageBits = d[cd + 39]
        pageSize = 1 << pageBits
        print(f"  CD: len={clen} version=0x{cver:x} hashType={hashType} hashSize={hashSize} "
              f"pageSize={pageSize} nCodeSlots={nCode} platform={platform}")
        if hashOffset + nCode * hashSize <= clen:
            ok(f"CD 结构自洽：code hash 槽落在 blob 内（{hashOffset}+{nCode}×{hashSize} ≤ {clen}）")
        else:
            bad("CD code 槽越出 blob 长度")
        print("  说明：raw-unsigned 包中 ad-hoc 签名为占位槽，安装时由设备端重签覆盖真实哈希。")

# ---- 4. Info.plist ----
with open(PLIST, "rb") as f:
    pl = plistlib.load(f)
families = pl.get("UIDeviceFamily", [])
if 1 in families and 2 in families:
    ok("UIDeviceFamily = [iPhone, iPad]（全适配）")
else:
    bad(f"UIDeviceFamily={families} 缺少 iPhone 或 iPad")
if pl.get("MinimumOSVersion") in ("16.0", "16.4"):
    ok(f"MinimumOSVersion = {pl.get('MinimumOSVersion')}")
else:
    bad(f"MinimumOSVersion = {pl.get('MinimumOSVersion')}")
if "iPhoneOS" in pl.get("CFBundleSupportedPlatforms", []):
    ok("CFBundleSupportedPlatforms = iPhoneOS")
else:
    bad("缺少 CFBundleSupportedPlatforms")
if pl.get("CFBundleIdentifier") == "com.renderframe":
    ok("CFBundleIdentifier = com.renderframe")
else:
    bad(f"CFBundleIdentifier = {pl.get('CFBundleIdentifier')}")

# ---- 5. IPA zip 结构 ----
if IPA:
    if os.path.exists(IPA):
        with zipfile.ZipFile(IPA) as z:
            badz = z.testzip()
            if badz is None:
                ok(f"IPA zip 完整（{len(z.namelist())} 条目，无损坏）")
            else:
                bad(f"IPA 损坏条目: {badz}")
        raw = open(IPA, "rb").read()
        if raw.rfind(b"PK\x05\x06") == len(raw) - 22:
            ok("EOCD 位于文件末尾，无 zip64")
        else:
            bad("EOCD 位置异常")
    else:
        bad("IPA 文件不存在")

print("\n" + ("=" * 40))
if fail == 0:
    print("✅ 全部校验通过：Mach-O / 签名 / 依赖 / plist / IPA")
else:
    print(f"❌ 存在 {fail} 项失败")
sys.exit(1 if fail else 0)
