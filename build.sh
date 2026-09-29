#!/bin/bash
# ============================================================================
# RenderFrame —— Ubuntu/Linux 交叉编译，产出「未签名裸 raw.ipa」
# 复用已验证流水线：swiftc 交叉编译 + ld64.lld + ldid
# 复刻 iMockup 核心功能：SceneKit 3D 设备库 + 关键帧时间轴 + 离屏渲染导出 MP4
# 用法：SWIFT_TOOLCHAIN=... IOS_SDK=... ./build.sh
# ============================================================================
set -euo pipefail

APP_NAME="RenderFrame"
DEPLOY="16.0"; SDK_VER="16.4"
TARGET="arm64-apple-ios${DEPLOY}"
MARK_VER="1.1.0"; CUR_VER="2"
BUNDLE_ID="com.renderframe"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="${ROOT}/build-linux"
APP="${BUILD}/Payload/${APP_NAME}.app"
OUT_IPA="${BUILD}/${APP_NAME}-${MARK_VER}-raw-unsigned.ipa"

SWIFT_TOOLCHAIN="${SWIFT_TOOLCHAIN:-}"
IOS_SDK="${IOS_SDK:-}"
for c in "$SWIFT_TOOLCHAIN" \
         /home/user/.doubao/agent_mode/workspace/toolchain/swift-5.8-RELEASE-ubuntu22.04/usr; do
    [[ -z "$c" ]] && continue
    if [[ -x "$c/bin/swiftc" ]]; then SWIFT_TOOLCHAIN="$c"; break; fi
done
for s in "$IOS_SDK" /home/user/.doubao/agent_mode/workspace/toolchain/iPhoneOS16.4.sdk; do
    [[ -z "$s" ]] && continue
    if [[ -d "$s/usr/include" ]]; then IOS_SDK="$s"; break; fi
done
[[ -x "${SWIFT_TOOLCHAIN}/bin/swiftc" ]] || { echo "❌ 未找到 swiftc"; exit 1; }
[[ -d "${IOS_SDK}" ]] || { echo "❌ 未找到 iOS SDK"; exit 1; }
SWIFTC="${SWIFT_TOOLCHAIN}/bin/swiftc"

LDID="${LDID:-}"
for c in "$LDID" /home/user/.doubao/agent_mode/workspace/toolchain/bin/ldid "$(command -v ldid)"; do
    [[ -z "$c" ]] && continue
    if [[ -x "$c" ]]; then LDID="$c"; break; fi
done
[[ -n "$LDID" && -x "$LDID" ]] || { echo "❌ 未找到 ldid"; exit 1; }

LINKBIN="${BUILD}/linkbin"; mkdir -p "$LINKBIN"
cat > "$LINKBIN/ld" <<EOF
#!/bin/bash
exec "${SWIFT_TOOLCHAIN}/bin/ld64.lld" "\$@"
EOF
chmod +x "$LINKBIN/ld"
export PATH="${LINKBIN}:${SWIFT_TOOLCHAIN}/bin:$PATH"

RES="$(mkdir -p "${BUILD}/resource-dir" && cd "${BUILD}/resource-dir" && pwd)"
if [[ ! -f "${RES}/.prepared" ]]; then
  rm -rf "${RES:?}"/*
  cp -R "${SWIFT_TOOLCHAIN}/lib/swift/"*.swift "${RES}/" 2>/dev/null || true
  cp -R "${SWIFT_TOOLCHAIN}/lib/swift/linux" "${RES}/" 2>/dev/null || true
  rm -rf "${RES}/dispatch" "${RES}/os" "${RES}/CoreFoundation" "${RES}/Block" "${RES}/linux" 2>/dev/null || true
  CLANG_VER="$(ls "${SWIFT_TOOLCHAIN}/lib/clang" | head -1)"
  mkdir -p "${RES}/clang"
  cp -R "${SWIFT_TOOLCHAIN}/lib/clang/${CLANG_VER}/include" "${RES}/clang/" 2>/dev/null || true
  mkdir -p "${RES}/apinotes"
  for ap in Dispatch.apinotes os.apinotes; do
    for cand in /home/user/.doubao/agent_mode/workspace/toolchain/swift-apinotes/apinotes/$ap; do
      [[ -f "$cand" ]] && cp "$cand" "${RES}/apinotes/" && break
    done
  done
  touch "${RES}/.prepared"
fi

COMMON=(-target "$TARGET" -sdk "$IOS_SDK" -resource-dir "$RES" -O -parse-as-library \
        -I "${IOS_SDK}/usr/lib/swift" -Xcc -fmodules-cache-path="${BUILD}/mcapp")
LINKV=(-Xlinker -adhoc_codesign \
       -Xlinker -platform_version -Xlinker ios -Xlinker "${DEPLOY}.0" -Xlinker "$SDK_VER")

mkdir -p "${APP}"

echo "==> [1/3] 编译主 App（全部 Swift 源）"
mapfile -t SRC < <(find "${ROOT}/App" "${ROOT}/Features" -name '*.swift' | sort)
"$SWIFTC" "${COMMON[@]}" -module-name RenderFrame -emit-executable "${LINKV[@]}" \
  -o "${APP}/RenderFrame" "${SRC[@]}"

echo "==> [2/3] ldid 嵌入 entitlements"
"$LDID" -S"${ROOT}/Resources/entitlements.plist" "${APP}/RenderFrame"

# ---- 组装 Bundle ----
subst(){ # $1=exec  $2=bundleid
  sed -e "s/\\\$(EXECUTABLE_NAME)/$1/g" -e "s/\\\$(PRODUCT_MODULE_NAME)/$1/g" \
      -e "s/\\\$(PRODUCT_NAME)/$1/g" -e "s/\\\$(PRODUCT_BUNDLE_IDENTIFIER)/$2/g" \
      -e "s/\\\$(MARKETING_VERSION)/${MARK_VER}/g" -e "s/\\\$(CURRENT_PROJECT_VERSION)/${CUR_VER}/g" \
      "${ROOT}/Resources/Info.plist"
}
subst "$APP_NAME" "$BUNDLE_ID" > "${APP}/Info.plist"
printf 'APPL????' > "${APP}/PkgInfo"

# ---- 生成并缩放图标 ----
echo "==> 生成图标"
python3 - "$APP" <<'PY'
import sys, os
from PIL import Image, ImageDraw
app=sys.argv[1]
S=1024
im=Image.new("RGB",(S,S))
px=im.load()
# 深色渐变背景
for y in range(S):
    t=y/S
    r=int(30+25*t); g=int(34+20*t); b=int(60+10*t)
    for x in range(S):
        px[x,y]=(r,g,b)
d=ImageDraw.Draw(im)
# 圆角设备轮廓（模拟 iPhone 机身）
x0,y0,x1,y1=312,190,712,834
d.rounded_rectangle([x0,y0,x1,y1],radius=96,fill=(16,17,20))
# 屏幕
d.rounded_rectangle([x0+34,y0+36,x1-34,y1-40],radius=46,fill=(235,235,240))
# 渐变屏幕点缀
grd=Image.new("L",(x1-x0-68, y1-y0-76),0)
gg=ImageDraw.Draw(grd)
for y in range(grd.size[1]):
    gg.line([(0,y),(grd.size[0],y)],fill=int(150-120*y/grd.size[1]))
im.paste((40,120,220), box=(x0+34,y0+36), mask=grd)
# 摄像头
d.ellipse([x0+34+ (x1-x0-68)//2 -12, y0+36+20, x0+34+(x1-x0-68)//2+12, y0+36+44], fill=(20,22,26))
im.save(os.path.join(app,"Icon-1024.png"),"PNG",optimize=True)
specs=[("Icon-20","@2x",40),("Icon-20","@3x",60),("Icon-20~ipad","",20),("Icon-20@2x~ipad","",40),
("Icon-29","@2x",58),("Icon-29","@3x",87),("Icon-29~ipad","",29),("Icon-29@2x~ipad","",58),
("Icon-40","@2x",80),("Icon-40","@3x",120),("Icon-40~ipad","",40),("Icon-40@2x~ipad","",80),
("Icon-60","@2x",120),("Icon-60","@3x",180),("Icon-76~ipad","",76),("Icon-76@2x~ipad","",152),
("Icon-83.5@2x~ipad","",167),("Icon-1024","",1024)]
for base,suf,size in specs:
    im.resize((size,size),Image.LANCZOS).save(f"{app}/{base}{suf}.png","PNG",optimize=True)
print("图标生成完成")
PY

# ---- 补齐 installd 校验所需标准键 ----
python3 - "${DEPLOY}" "${SDK_VER}" "${APP}/Info.plist" <<'PY'
import sys, plistlib
minos, sdkver, path = sys.argv[1], sys.argv[2], sys.argv[3]
std = {
    "MinimumOSVersion": minos,
    "CFBundleSupportedPlatforms": ["iPhoneOS"],
    "DTPlatformName": "iphoneos",
    "DTPlatformVersion": sdkver,
    "DTSDKName": f"iphoneos{sdkver}",
    "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
}
with open(path,"rb") as f: pl=plistlib.load(f)
for k,v in std.items(): pl.setdefault(k,v)
with open(path,"wb") as f: plistlib.dump(pl,f,fmt=plistlib.FMT_XML)
PY

# ---- Mach-O 校验 ----
echo "==> [3/3] Mach-O 校验"
python3 - "$APP" <<'PY'
import struct,sys,os
app=sys.argv[1]
d=open(os.path.join(app,"RenderFrame"),'rb').read()
magic,cput,sub,ft,n=struct.unpack('<IiiII',d[:20])
assert magic==0xfeedfacf and cput==0x0100000c, "非 arm64 Mach-O64"
assert ft==2, f"filetype={ft} 期望 MH_EXECUTE"
off=32;plat=None;sig=None
for _ in range(n):
    cmd,cs=struct.unpack('<II',d[off:off+8])
    if cmd==0x32: plat=struct.unpack('<I',d[off+8:off+12])[0]
    if cmd==0x1d: sig=struct.unpack('<II',d[off+8:off+16])
    off+=cs
assert plat==2, "平台非 iOS"
assert sig and sig[1]>0, "缺少 LC_CODE_SIGNATURE 签名槽"
so,ss=sig
sm=struct.unpack('>I',d[so:so+4])[0]
assert sm==0xfade0cc0, "签名 SuperBlob magic 异常"
print(f"  ✓ RenderFrame arm64/iOS/MH_EXECUTE + ad-hoc签名槽({ss}B)")
PY

# ---- 规范化打包 IPA ----
echo "==> 规范化打包 IPA"
rm -f "$OUT_IPA"
python3 - "$BUILD" "$OUT_IPA" <<'PY'
import sys, os, zipfile
build, out = sys.argv[1], sys.argv[2]
root=os.path.join(build,"Payload")
exec_names={"RenderFrame"}
fixed=(2024,1,1,0,0,0)
def add_dir(zf,arc):
    zi=zipfile.ZipInfo(arc+"/",fixed); zi.create_system=3
    zi.external_attr=(0o40755<<16)|0o040000; zi.compress_type=zipfile.ZIP_STORED
    zf.writestr(zi,b"")
entries=[]
for dirpath,dirnames,filenames in os.walk(root):
    dirnames.sort(); filenames.sort()
    rel=os.path.relpath(dirpath,build)
    if rel!=".": entries.append(("dir",rel,None))
    for fn in filenames:
        full=os.path.join(dirpath,fn); arc=os.path.relpath(full,build)
        entries.append(("file",arc,full))
entries.sort(key=lambda e:(e[1].count("/"),e[1]))
with zipfile.ZipFile(out,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=9,allowZip64=False) as zf:
    seen=set()
    for kind,arc,full in entries:
        parts=arc.split("/")[:-1]
        for i in range(len(parts)):
            d="/".join(parts[:i+1])
            if d not in seen: add_dir(zf,d); seen.add(d)
        if kind=="dir":
            if arc not in seen: add_dir(zf,arc); seen.add(arc)
            continue
        zi=zipfile.ZipInfo(arc,fixed); zi.create_system=3
        base=os.path.basename(arc)
        mode=0o755 if base in exec_names else 0o644
        zi.external_attr=(mode<<16)|0o100000
        zi.compress_type=zipfile.ZIP_DEFLATED
        with open(full,"rb") as f: zf.writestr(zi,f.read(),compress_type=zipfile.ZIP_DEFLATED)
with zipfile.ZipFile(out) as z:
    bad=z.testzip(); assert bad is None, f"坏条目 {bad}"
    n=len(z.namelist())
raw=open(out,"rb").read()
assert raw.rfind(b"PK\x05\x06")==len(raw)-22, "EOCD 不在末尾"
print(f"  规范化 zip 完成：{n} 条目，EOCD 位于末尾，无 zip64")
PY
echo "✅ 完成: ${OUT_IPA}"
ls -lh "$OUT_IPA"
shasum -a 256 "$OUT_IPA" | awk '{print "SHA256:",$1}'
