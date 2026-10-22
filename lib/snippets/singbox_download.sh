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

# 检查本地是否已经安装了有效的 sing-box 内核 (支持重跑跳过重复下载)
SKIP_SB_DOWNLOAD=0
if [ -x "$INSTALL_DIR/sing-box" ]; then
    CURRENT_SB_VER=$("$INSTALL_DIR/sing-box" version 2>/dev/null | head -n 1 | awk '{print $3}' || true)
    if [ -n "$CURRENT_SB_VER" ]; then
        ui_success "检测到已安装有效 sing-box 内核 (v${CURRENT_SB_VER})，直接复用跳过下载！"
        SKIP_SB_DOWNLOAD=1
    fi
fi

if [ "$SKIP_SB_DOWNLOAD" -ne 1 ]; then
    ui_info "正在查询 sing-box 最新发布版本..."
    LATEST_TAG=""

    # 方式 1: 跟踪 GitHub releases 302 重定向 (免 API 限额，速度最快且最稳定)
    LATEST_TAG=$(curl -sI "https://github.com/SagerNet/sing-box/releases/latest" 2>/dev/null | grep -i '^location:' | head -n 1 | tr -d '\r\n' | awk -F'/' '{print $NF}' || true)

    # 方式 2: 若重定向未取到，安全解析 GitHub API (使用严格的精准字段匹配，避免误匹配 reactions)
    if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "latest" ]; then
        LATEST_JSON=$(curl -sSL "https://api.github.com/repos/SagerNet/sing-box/releases/latest" 2>/dev/null || true)
        LATEST_TAG=$(echo "$LATEST_JSON" | grep -oE '"tag_name": *"[^"]+"' | head -n 1 | cut -d'"' -f4 || true)
    fi

    # 版本格式严格校验 (必须是形如 x.y.z 的纯数字语义化版本，杜绝误匹配到 eyes 等字符串)
    VERSION="${LATEST_TAG#v}"
    case "$VERSION" in
        [0-9]*.[0-9]*.[0-9]*)
            ui_success "成功匹配到版本: v${VERSION}"
            ;;
        *)
            VERSION="1.14.3"
            ui_warn "未解析到有效数字版本号，自动降级启用已验证稳定版: v${VERSION}"
            ;;
    esac

    # 定义通用健壮下载函数 (防 set -e 导致脚本提前退出)
    try_download() {
        dl_url="$1"
        dl_out="$2"

        # 优先使用 curl 下载
        if curl -fSL --connect-timeout 10 --max-time 180 "$dl_url" -o "$dl_out"; then
            return 0
        fi

        # curl 失败时按需安装 wget
        ui_warn "curl 下载失败，尝试检查并安装 wget 进行备用下载..."
        if ! command -v wget >/dev/null 2>&1; then
            if command -v apk >/dev/null 2>&1; then
                apk add --no-cache wget || true
            elif command -v apt-get >/dev/null 2>&1; then
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -y && apt-get install -y --no-install-recommends wget || true
            fi
        fi

        # 使用 wget 重试
        if command -v wget >/dev/null 2>&1; then
            if wget -T 15 -t 3 -O "$dl_out" "$dl_url"; then
                return 0
            fi
        fi

        return 1
    }

    # 构造真实的 Release 二进制下载地址
    if [ "$SB_TARGET" = "musl" ]; then
        DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${SB_ARCH}-musl.tar.gz"
    else
        DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${SB_ARCH}.tar.gz"
    fi

    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR" "$INSTALL_DIR"

    ui_info "正在下载: $DOWNLOAD_URL"
    if ! try_download "$DOWNLOAD_URL" "$WORK_DIR/sing-box.tar.gz"; then
        # 如果最新版下载失败，尝试降级稳定版 1.14.3
        ui_warn "当前版本下载失败，尝试降级稳定基准版本 v1.14.3 重试..."
        if [ "$SB_TARGET" = "musl" ]; then
            DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v1.14.3/sing-box-1.14.3-linux-${SB_ARCH}-musl.tar.gz"
        else
            DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v1.14.3/sing-box-1.14.3-linux-${SB_ARCH}.tar.gz"
        fi

        if ! try_download "$DOWNLOAD_URL" "$WORK_DIR/sing-box.tar.gz"; then
            ui_error "sing-box 内核下载失败，请检查网络是否能连接 GitHub Release！"
            exit 1
        fi
    fi

    # 校验下载包非空
    if [ ! -s "$WORK_DIR/sing-box.tar.gz" ]; then
        ui_error "下载的文件损坏或大小为 0，安装中止！"
        exit 1
    fi

    ui_info "解压并安装二进制文件..."
    tar -zxvf "$WORK_DIR/sing-box.tar.gz" -C "$WORK_DIR/" >/dev/null
    find "$WORK_DIR" -type f -name "sing-box" -exec mv -f {} "$INSTALL_DIR/sing-box" \;
    chmod +x "$INSTALL_DIR/sing-box"
    rm -rf "$WORK_DIR"
    ui_success "sing-box 已成功安装至 $INSTALL_DIR/sing-box"
fi
