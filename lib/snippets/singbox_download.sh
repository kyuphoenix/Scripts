# ---------- 4. 下载并部署 sing-box 二进制 ----------
ui_step "3/6" "下载并部署 sing-box 官方发布版本..."

ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)   SB_ARCH="amd64" ;;
    aarch64|arm64)  SB_ARCH="arm64" ;;
    armv7l|armhf)   SB_ARCH="armv7" ;;
    *) ui_error "不支持的 CPU 架构: $ARCH"; exit 1 ;;
esac

# 自动判断目标二进制类型 (musl vs glibc)
if [ -z "$SB_TARGET" ]; then
    if [ -f /etc/alpine-release ]; then
        SB_TARGET="musl"
    else
        SB_TARGET="glibc"
    fi
fi

ui_info "检测到硬件架构: $ARCH (sing-box 目标架构: $SB_ARCH, 类型: $SB_TARGET)"

ui_info "正在查询 sing-box 最新发布版本..."
LATEST_JSON=$(curl -sSL "https://api.github.com/repos/SagerNet/sing-box/releases/latest" 2>/dev/null || true)
LATEST_TAG=$(echo "$LATEST_JSON" | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)

if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "null" ]; then
    ui_info "轻量解析未获取到版本，正在按需安装 jq 重试..."
    if command -v apk >/dev/null 2>&1; then
        apk add --no-cache jq >/dev/null 2>&1 || true
    elif command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y --no-install-recommends jq >/dev/null 2>&1 || true
    fi
    LATEST_TAG=$(echo "$LATEST_JSON" | jq -r .tag_name 2>/dev/null || true)
fi

VERSION="${LATEST_TAG#v}"
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
    VERSION="1.11.4"
    ui_warn "未获取到最新版本，降级使用默认稳定版本: v${VERSION}"
else
    ui_success "成功匹配到版本: v${VERSION}"
fi

if [ "$SB_TARGET" = "musl" ]; then
    DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${SB_ARCH}-musl.tar.gz"
else
    DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${SB_ARCH}.tar.gz"
fi

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$INSTALL_DIR"

ui_info "正在下载: $DOWNLOAD_URL"
if ! curl -fSL "$DOWNLOAD_URL" -o "$WORK_DIR/sing-box.tar.gz"; then
    ui_warn "curl 下载失败，正在按需安装 wget 重试下载..."
    if command -v apk >/dev/null 2>&1; then
        apk add --no-cache wget >/dev/null 2>&1 || true
    elif command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y --no-install-recommends wget >/dev/null 2>&1 || true
    fi
    wget -qO "$WORK_DIR/sing-box.tar.gz" "$DOWNLOAD_URL"
fi

ui_info "解压并安装二进制文件..."
tar -zxvf "$WORK_DIR/sing-box.tar.gz" -C "$WORK_DIR/" >/dev/null
find "$WORK_DIR" -type f -name "sing-box" -exec mv -f {} "$INSTALL_DIR/sing-box" \;
chmod +x "$INSTALL_DIR/sing-box"
rm -rf "$WORK_DIR"
ui_success "sing-box 已成功安装至 $INSTALL_DIR/sing-box"
