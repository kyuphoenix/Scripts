# ---------- 根路径全自动交互引导编排器 ----------
ui_banner "sing-box 自动化多协议节点部署向导"

printf "${C_BOLD}📝 请选择部署协议与配置参数：${C_RESET}\n\n"

# 1. 协议选择
printf " ${C_BOLD}请选择要部署的节点协议：${C_RESET}\n"
printf "  ${C_CYAN}1)${C_RESET} Hysteria 2 ${C_GRAY}(推荐，超高速 UDP 代理)${C_RESET}\n"
printf "  ${C_CYAN}2)${C_RESET} TUIC v5    ${C_GRAY}(基于 QUIC 协议的高性能代理)${C_RESET}\n"
while true; do
    printf " ${C_CYAN}?${C_RESET} 请输入选项 [1-2] ${C_GRAY}[默认: 1]${C_RESET}: "
    ui_read PROTO_CHOICE
    PROTO_CHOICE=$(echo "$PROTO_CHOICE" | tr -d '[:space:]')
    PROTO_CHOICE="${PROTO_CHOICE:-1}"
    if [ "$PROTO_CHOICE" = "1" ]; then
        PROTO_NAME="hy2"
        PROTO_TITLE="Hysteria 2"
        break
    elif [ "$PROTO_CHOICE" = "2" ]; then
        PROTO_NAME="tuic"
        PROTO_TITLE="TUIC v5"
        break
    fi
    ui_warn "选项无效，请输入 1 或 2！"
done

# 2. 域名输入
while true; do
    printf "\n ${C_CYAN}?${C_RESET} 请输入你要绑定的域名 ${C_GRAY}(例如: node.example.com)${C_RESET}: "
    ui_read USER_DOMAIN
    USER_DOMAIN=$(echo "$USER_DOMAIN" | tr -d '[:space:]')
    if [ -n "$USER_DOMAIN" ]; then
        break
    fi
    ui_warn "域名不能为空，请重新输入！"
done

# 3. Cloudflare API 认证方式选择与输入
printf "\n ${C_BOLD}请选择 Cloudflare API 认证方式：${C_RESET}\n"
printf "  ${C_CYAN}1)${C_RESET} API Token ${C_GRAY}(推荐，仅需 DNS:Edit 权限)${C_RESET}\n"
printf "  ${C_CYAN}2)${C_RESET} Global API Key ${C_GRAY}(全局 API 密钥，需配合 CF 账号邮箱)${C_RESET}\n"
while true; do
    printf " ${C_CYAN}?${C_RESET} 请输入选项 [1-2] ${C_GRAY}[默认: 1]${C_RESET}: "
    ui_read CF_AUTH_TYPE
    CF_AUTH_TYPE=$(echo "$CF_AUTH_TYPE" | tr -d '[:space:]')
    CF_AUTH_TYPE="${CF_AUTH_TYPE:-1}"
    if [ "$CF_AUTH_TYPE" = "1" ] || [ "$CF_AUTH_TYPE" = "2" ]; then
        break
    fi
    ui_warn "选项无效，请输入 1 或 2！"
done

if [ "$CF_AUTH_TYPE" = "2" ]; then
    while true; do
        printf " ${C_CYAN}?${C_RESET} 请输入 Cloudflare 账号邮箱 (CF_Email): "
        ui_read CF_Email
        CF_Email=$(echo "$CF_Email" | tr -d '[:space:]')
        if [ -n "$CF_Email" ]; then
            break
        fi
        ui_warn "邮箱不能为空，请重新输入！"
    done

    while true; do
        printf " ${C_CYAN}?${C_RESET} 请输入 Cloudflare Global API Key: "
        ui_read CF_Key
        CF_Key=$(echo "$CF_Key" | tr -d '[:space:]')
        if [ -n "$CF_Key" ]; then
            break
        fi
        ui_warn "Global API Key 不能为空，请重新输入！"
    done
    export CF_Email="$CF_Email"
    export CF_Key="$CF_Key"
else
    while true; do
        printf " ${C_CYAN}?${C_RESET} 请输入 Cloudflare API Token (CF_Token): "
        ui_read CF_Token
        CF_Token=$(echo "$CF_Token" | tr -d '[:space:]')
        if [ -n "$CF_Token" ]; then
            break
        fi
        ui_warn "API Token 不能为空，请重新输入！"
    done
    export CF_Token="$CF_Token"
fi

# 4. 端口输入与校验
while true; do
    printf " ${C_CYAN}?${C_RESET} 请输入监听端口 ${C_GRAY}[默认: 20000]${C_RESET}: "
    ui_read INPUT_PORT
    INPUT_PORT=$(echo "$INPUT_PORT" | tr -d '[:space:]')
    PORT="${INPUT_PORT:-20000}"
    case "$PORT" in
        ''|*[!0-9]*)
            ui_warn "端口必须为纯数字，请重新输入！"
            continue
            ;;
        *)
            if [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then
                break
            else
                ui_warn "端口超出合法范围 (1-65535)，请重新输入！"
                continue
            fi
            ;;
    esac
done

# 5. TUIC 协议专属 UUID
if [ "$PROTO_NAME" = "tuic" ]; then
    if [ -r /proc/sys/kernel/random/uuid ]; then
        GEN_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
    fi
    if [ -z "$GEN_UUID" ] && command -v uuidgen >/dev/null 2>&1; then
        GEN_UUID=$(uuidgen | tr 'A-Z' 'a-z')
    fi
    if [ -z "$GEN_UUID" ]; then
        GEN_UUID=$(od -x /dev/urandom 2>/dev/null | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}')
    fi
    if [ -z "$GEN_UUID" ]; then
        GEN_UUID="12345678-1234-1234-1234-123456789abc"
    fi

    printf " ${C_CYAN}?${C_RESET} 请输入用户 UUID ${C_GRAY}[回车使用随机: %s]${C_RESET}: " "$GEN_UUID"
    ui_read INPUT_UUID
    INPUT_UUID=$(echo "$INPUT_UUID" | tr -d '[:space:]')
    USER_UUID="${INPUT_UUID:-$GEN_UUID}"
fi

# 6. 连接密码输入
GEN_PASS=$(tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c 16 || echo "Pass$(date +%s)")
printf " ${C_CYAN}?${C_RESET} 请输入连接密码 ${C_GRAY}[回车使用随机: %s]${C_RESET}: " "$GEN_PASS"
ui_read INPUT_PASS
INPUT_PASS=$(echo "$INPUT_PASS" | tr -d '[:space:]')
PASSWORD="${INPUT_PASS:-$GEN_PASS}"

# 7. 架构与操作系统检测
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)   SB_ARCH="amd64" ;;
    aarch64|arm64)  SB_ARCH="arm64" ;;
    armv7l|armhf)   SB_ARCH="armv7" ;;
    *) ui_error "不支持的 CPU 架构: $ARCH"; exit 1 ;;
esac

if [ -f /etc/alpine-release ] || command -v apk >/dev/null 2>&1; then
    OS_TYPE="alpine"
    OS_DESC="Alpine Linux (musl + OpenRC)"
    SB_TARGET="musl"
    RELOAD_CMD="rc-service sing-box restart 2>/dev/null || true"
elif [ -f /etc/debian_version ] || grep -qi "debian\|ubuntu" /etc/os-release 2>/dev/null || command -v apt-get >/dev/null 2>&1; then
    OS_TYPE="debian"
    OS_DESC="Debian / Ubuntu (glibc + Systemd)"
    SB_TARGET="glibc"
    RELOAD_CMD="systemctl restart sing-box 2>/dev/null || true"
else
    ui_error "未能识别的 Linux 发行版，当前脚本仅支持 Alpine 和 Debian/Ubuntu 系统！"
    exit 1
fi

# 8. 确认面板展示
printf "\n${C_BOLD}${C_CYAN}------------------- 配置信息确认 -------------------${C_RESET}\n"
printf "  ${C_BOLD}节 点 协 议${C_RESET} : ${C_GREEN}%s${C_RESET}\n" "$PROTO_TITLE"
printf "  ${C_BOLD}检 测 系 统${C_RESET} : ${C_GREEN}%s${C_RESET}\n" "$OS_DESC"
printf "  ${C_BOLD}硬 件 架 构${C_RESET} : ${C_GREEN}%s (%s)${C_RESET}\n" "$ARCH" "$SB_ARCH"
printf "  ${C_BOLD}绑 定 域 名${C_RESET} : ${C_GREEN}%s${C_RESET}\n" "$USER_DOMAIN"
if [ "$CF_AUTH_TYPE" = "2" ]; then
    printf "  ${C_BOLD}CF 认证方式${C_RESET} : ${C_GREEN}Global API Key (${CF_Email})${C_RESET}\n"
else
    printf "  ${C_BOLD}CF 认证方式${C_RESET} : ${C_GREEN}API Token${C_RESET}\n"
fi
printf "  ${C_BOLD}监 听 端 口${C_RESET} : ${C_GREEN}%s${C_RESET}\n" "$PORT"
if [ "$PROTO_NAME" = "tuic" ]; then
    printf "  ${C_BOLD}用 户 UUID${C_RESET}  : ${C_GREEN}%s${C_RESET}\n" "$USER_UUID"
fi
printf "  ${C_BOLD}认 证 密 码${C_RESET} : ${C_GREEN}%s${C_RESET}\n" "$PASSWORD"
printf "${C_BOLD}${C_CYAN}----------------------------------------------------${C_RESET}\n"
printf "按 ${C_BOLD}[Enter]${C_RESET} 开始自动化部署，或按 ${C_BOLD}[Ctrl+C]${C_RESET} 取消退出..."
ui_read CONFIRM_CONTINUE || true

# 9. 执行系统依赖与服务环境准备
if [ "$OS_TYPE" = "alpine" ]; then
    ui_step "1/6" "安装最小核心系统依赖 (Alpine)..."
    apk update
    apk add --no-cache curl openssl ca-certificates cronie openrc
    [ -d /run/openrc ] || mkdir -p /run/openrc
    touch /run/openrc/softlevel 2>/dev/null || true
    CRON_SVC="cronie"
    if [ ! -f /etc/init.d/cronie ] && [ -f /etc/init.d/crond ]; then
        CRON_SVC="crond"
    fi
    rc-update add "$CRON_SVC" default 2>/dev/null || true
    rc-service "$CRON_SVC" restart 2>/dev/null || rc-service "$CRON_SVC" start 2>/dev/null || true
    ui_success "Alpine 核心系统依赖与定时服务就绪"
else
    ui_step "1/6" "安装最小核心系统依赖 (Debian / Ubuntu)..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y --no-install-recommends curl openssl ca-certificates cron systemd tar procps
    systemctl enable cron 2>/dev/null || systemctl enable crond 2>/dev/null || true
    systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null || systemctl start cron 2>/dev/null || true
    ui_success "Debian/Ubuntu 核心系统依赖与定时服务就绪"
fi
