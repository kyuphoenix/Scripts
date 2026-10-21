# ---------- 1. 用户交互输入 (TUIC v5) ----------
ui_banner "sing-box (TUIC v5) 安装脚本"

printf "${C_BOLD}📝 请填写部署配置参数：${C_RESET}\n\n"

# 1.1 域名输入
while true; do
    printf " ${C_CYAN}?${C_RESET} 请输入你要绑定的域名 ${C_GRAY}(例如: node.example.com)${C_RESET}: "
    read USER_DOMAIN
    USER_DOMAIN=$(echo "$USER_DOMAIN" | tr -d '[:space:]')
    if [ -n "$USER_DOMAIN" ]; then
        break
    fi
    ui_warn "域名不能为空，请重新输入！"
done

# 1.2 Cloudflare API 认证方式选择与输入
printf "\n ${C_BOLD}请选择 Cloudflare API 认证方式：${C_RESET}\n"
printf "  ${C_CYAN}1)${C_RESET} API Token ${C_GRAY}(推荐，仅需 DNS:Edit 权限)${C_RESET}\n"
printf "  ${C_CYAN}2)${C_RESET} Global API Key ${C_GRAY}(全局 API 密钥，需配合 CF 账号邮箱)${C_RESET}\n"
while true; do
    printf " ${C_CYAN}?${C_RESET} 请输入选项 [1-2] ${C_GRAY}[默认: 1]${C_RESET}: "
    read CF_AUTH_TYPE
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
        read CF_Email
        CF_Email=$(echo "$CF_Email" | tr -d '[:space:]')
        if [ -n "$CF_Email" ]; then
            break
        fi
        ui_warn "邮箱不能为空，请重新输入！"
    done

    while true; do
        printf " ${C_CYAN}?${C_RESET} 请输入 Cloudflare Global API Key: "
        read CF_Key
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
        read CF_Token
        CF_Token=$(echo "$CF_Token" | tr -d '[:space:]')
        if [ -n "$CF_Token" ]; then
            break
        fi
        ui_warn "API Token 不能为空，请重新输入！"
    done
    export CF_Token="$CF_Token"
fi

# 1.3 端口输入与校验
while true; do
    printf " ${C_CYAN}?${C_RESET} 请输入 TUIC 监听端口 ${C_GRAY}[默认: 20000]${C_RESET}: "
    read INPUT_PORT
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

# 1.4 UUID 生成与输入 (纯 sh/内核随机数适配，无需额外装 uuidgen)
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
read INPUT_UUID
INPUT_UUID=$(echo "$INPUT_UUID" | tr -d '[:space:]')
USER_UUID="${INPUT_UUID:-$GEN_UUID}"

# 1.5 连接密码输入 (支持回车默认)
GEN_PASS=$(tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c 16 || echo "Pass$(date +%s)")
printf " ${C_CYAN}?${C_RESET} 请输入连接密码 ${C_GRAY}[回车使用随机: %s]${C_RESET}: " "$GEN_PASS"
read INPUT_PASS
INPUT_PASS=$(echo "$INPUT_PASS" | tr -d '[:space:]')
PASSWORD="${INPUT_PASS:-$GEN_PASS}"

# 1.6 输入确认面板
printf "\n${C_BOLD}${C_CYAN}------------------- 配置信息确认 -------------------${C_RESET}\n"
printf "  ${C_BOLD}节 点 协 议${C_RESET} : ${C_GREEN}TUIC v5${C_RESET}\n"
printf "  ${C_BOLD}绑 定 域 名${C_RESET} : ${C_GREEN}%s${C_RESET}\n" "$USER_DOMAIN"
if [ "$CF_AUTH_TYPE" = "2" ]; then
    printf "  ${C_BOLD}CF 认证方式${C_RESET} : ${C_GREEN}Global API Key (${CF_Email})${C_RESET}\n"
else
    printf "  ${C_BOLD}CF 认证方式${C_RESET} : ${C_GREEN}API Token${C_RESET}\n"
fi
printf "  ${C_BOLD}监 听 端 口${C_RESET} : ${C_GREEN}%s${C_RESET}\n" "$PORT"
printf "  ${C_BOLD}用 户 UUID${C_RESET}  : ${C_GREEN}%s${C_RESET}\n" "$USER_UUID"
printf "  ${C_BOLD}认 证 密 码${C_RESET} : ${C_GREEN}%s${C_RESET}\n" "$PASSWORD"
printf "${C_BOLD}${C_CYAN}----------------------------------------------------${C_RESET}\n"
printf "按 ${C_BOLD}[Enter]${C_RESET} 开始自动化部署，或按 ${C_BOLD}[Ctrl+C]${C_RESET} 取消退出..."
read CONFIRM_CONTINUE || true
