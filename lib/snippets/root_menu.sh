# ---------- 根主引导交互控制台 ----------
ui_banner "sing-box 综合管理与部署向导"

# 1. 运行全面系统部署状态检测
detect_system_status

# 2. 状态卡片展示面板
printf "${C_BOLD}📋 当前系统代理状态检测：${C_RESET}\n"

if [ "$IS_CONFIGURED" -eq 1 ]; then
    # 已安装并配置过服务
    if [ "$SB_RUNNING" -eq 1 ]; then
        printf "  ● sing-box 运行状态 : ${C_GREEN}🟢 运行中${C_RESET} ${C_GRAY}(PID: %s, 内存: %s, 版本: %s)${C_RESET}\n" "${SB_PID:-未知}" "${SB_MEM}" "${SB_VERSION}"
    else
        printf "  ● sing-box 运行状态 : ${C_RED}🔴 已停止${C_RESET} ${C_GRAY}(服务状态: %s, 版本: %s)${C_RESET}\n" "${SB_SERVICE_STATUS}" "${SB_VERSION}"
    fi

    printf "  ● 当前部署协议     : ${C_CYAN}⚡ %s${C_RESET} ${C_GRAY}(监听端口: %s)${C_RESET}\n" "${ACTIVE_PROTO}" "${ACTIVE_PORT}"
    printf "  ● 绑定服务域名     : ${C_CYAN}🌐 %s${C_RESET}\n" "${ACTIVE_DOMAIN}"

    if [ "$HAS_CERT" -eq 1 ]; then
        if [ "$ACME_CRON" -eq 1 ]; then
            printf "  ● SSL 证书状态     : ${C_GREEN}🔒 正常${C_RESET} ${C_GRAY}(剩余: %s, acme.sh 自动续期已配置)${C_RESET}\n" "${CERT_DAYS_LEFT}"
        else
            printf "  ● SSL 证书状态     : ${C_GREEN}🔒 正常${C_RESET} ${C_GRAY}(剩余: %s)${C_RESET}\n" "${CERT_DAYS_LEFT}"
        fi
    else
        printf "  ● SSL 证书状态     : ${C_YELLOW}⚠️  未检测到有效证书 (%s)${C_RESET}\n" "${CERT_DAYS_LEFT}"
    fi

    if [ "$ACTIVE_PROTO" = "VLESS + Reality" ] || [ "$NGINX_INSTALLED" -eq 1 ]; then
        if [ "$NGINX_RUNNING" -eq 1 ]; then
            printf "  ● Nginx 伪装网站   : ${C_GREEN}🟢 正常运行${C_RESET} ${C_GRAY}(/var/www/margin)${C_RESET}\n"
        else
            printf "  ● Nginx 伪装网站   : ${C_RED}🔴 未运行${C_RESET}\n"
        fi
    fi
    printf "${C_GRAY}──────────────────────────────────────────────────────────${C_RESET}\n"
    printf "  ${C_GREEN}✔ 检测到当前系统已成功部署代理节点服务！${C_RESET}\n\n"
else
    # 未安装或未完成配置
    if [ "$SB_INSTALLED" -eq 1 ]; then
        printf "  ● sing-box 程序     : ${C_YELLOW}🟡 已下载程序 (版本: %s)${C_RESET}，但尚未完成完整配置\n" "${SB_VERSION}"
    else
        printf "  ● sing-box 程序     : ${C_GRAY}⚪ 未安装${C_RESET}\n"
    fi
    printf "  ● 代理协议配置     : ${C_GRAY}⚪ 未部署${C_RESET}\n"
    if [ "$HAS_CERT" -eq 1 ]; then
        printf "  ● SSL 域名证书     : ${C_GREEN}🔒 已存在有效证书${C_RESET} ${C_GRAY}(%s, 剩余: %s)${C_RESET}\n" "${ACTIVE_DOMAIN}" "${CERT_DAYS_LEFT}"
    else
        printf "  ● SSL 域名证书     : ${C_GRAY}⚪ 未配置${C_RESET}\n"
    fi
    printf "${C_GRAY}──────────────────────────────────────────────────────────${C_RESET}\n"
    printf "  ${C_BLUE}ℹ️  当前系统尚未运行代理服务，推荐选择 [1] 开始一键部署！${C_RESET}\n\n"
fi

# 3. 呈现三大核心选项
printf "${C_BOLD}📝 请选择要执行的操作：${C_RESET}\n"
printf "  ${C_CYAN}1)${C_RESET} 🚀 部署 / 变更代理协议 ${C_GRAY}(Deploy & Setup)${C_RESET}\n"
printf "     ${C_GRAY}└─ 全新安装节点、切换传输协议或重新配置参数${C_RESET}\n"
printf "  ${C_CYAN}2)${C_RESET} 🛠️  节点服务管理与日常维护 ${C_GRAY}(Maintenance & Diagnostics)${C_RESET}\n"
printf "     ${C_GRAY}└─ 查看运行状态与连接信息、启停重启、证书检测、实时日志${C_RESET}\n"
printf "  ${C_CYAN}3)${C_RESET} 🚪 退出脚本向导 ${C_GRAY}(Exit)${C_RESET}\n\n"

# 4. 读取用户选择
while true; do
    printf " ${C_CYAN}?${C_RESET} 请输入选项 [1-3] ${C_GRAY}[默认: 1]${C_RESET}: "
    ui_read MAIN_CHOICE
    MAIN_CHOICE=$(echo "$MAIN_CHOICE" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    MAIN_CHOICE="${MAIN_CHOICE:-1}"

    if [ "$MAIN_CHOICE" = "1" ]; then
        ui_info "正在连接并拉取代理协议部署向导..."
        clear 2>/dev/null || true
        curl -fsSL "${SERVER_URL}/deploy" | sh
        exit 0
    elif [ "$MAIN_CHOICE" = "2" ]; then
        ui_info "正在连接并拉取服务管理与维护面板..."
        clear 2>/dev/null || true
        curl -fsSL "${SERVER_URL}/manage" | sh
        exit 0
    elif [ "$MAIN_CHOICE" = "3" ] || [ "$MAIN_CHOICE" = "q" ] || [ "$MAIN_CHOICE" = "exit" ]; then
        printf "\n${C_GREEN}👋 已退出向导，祝你使用愉快！${C_RESET}\n\n"
        exit 0
    fi
    ui_warn "选项无效，请输入 1、2 或 3！"
done
