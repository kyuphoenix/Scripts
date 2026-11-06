# ---------- 完全卸载与系统环境清除 ----------
do_uninstall() {
    ui_banner "sing-box 节点完全卸载与环境清除"

    printf "${C_BOLD}${C_RED}⚠️  注意：此操作将执行以下清除与还原操作：${C_RESET}\n"
    printf "  ${C_GRAY}1.${C_RESET} 停止并移除 sing-box 开机自启服务与二进制程序\n"
    printf "  ${C_GRAY}2.${C_RESET} 清除 sing-box 配置文件、所有节点证书与密钥 (${CONF_DIR})\n"
    printf "  ${C_GRAY}3.${C_RESET} 停止并移除 Nginx 服务、清理静态伪装网页模板 (/var/www/margin)\n"
    printf "  ${C_GRAY}4.${C_RESET} 卸载本脚本安装的附加包 (nginx, unzip, socat 等)\n"
    printf "  ${C_GRAY}5.${C_RESET} 卸载 acme.sh 证书申请工具并清理自动续签计划任务 (crontab)\n"
    printf "  ${C_GRAY}6.${C_RESET} 清除临时下载缓存、日志残留与运行状态\n\n"

    printf "${C_YELLOW}? 确定要彻底卸载所有配置并还原系统吗？[y/N]: ${C_RESET}"
    ui_read CONFIRM_UNINSTALL
    CONFIRM_UNINSTALL=$(echo "$CONFIRM_UNINSTALL" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

    if [ "$CONFIRM_UNINSTALL" != "y" ] && [ "$CONFIRM_UNINSTALL" != "yes" ]; then
        printf "\n${C_BLUE}ℹ️  操作已取消，未进行任何更改。${C_RESET}\n\n"
        return 0
    fi

    printf "\n${C_BOLD}${C_BLUE}>>> 开始执行彻底清理...${C_RESET}\n"

    # 1. 停止并移除 sing-box 服务
    ui_info "正在停止并移除 sing-box 服务..."
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop sing-box 2>/dev/null || true
        systemctl disable sing-box 2>/dev/null || true
        rm -f /etc/systemd/system/sing-box.service
        systemctl daemon-reload 2>/dev/null || true
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service sing-box stop 2>/dev/null || true
        rc-update del sing-box default 2>/dev/null || true
        rm -f /etc/init.d/sing-box
    fi
    pkill -9 sing-box 2>/dev/null || true
    ui_success "sing-box 服务已停止并从系统中移除"

    # 2. 停止并清理 Nginx 服务及伪装网站
    ui_info "正在停止并清理 Nginx 服务与伪装网页..."
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop nginx 2>/dev/null || true
        systemctl disable nginx 2>/dev/null || true
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service nginx stop 2>/dev/null || true
        rc-update del nginx default 2>/dev/null || true
    fi
    pkill -9 nginx 2>/dev/null || true

    # 清理 Nginx 站点配置
    rm -f /etc/nginx/conf.d/reality_fallback.conf 2>/dev/null || true
    rm -f /etc/nginx/http.d/reality_fallback.conf 2>/dev/null || true
    [ -f /etc/nginx/http.d/default.conf.bak ] && mv /etc/nginx/http.d/default.conf.bak /etc/nginx/http.d/default.conf 2>/dev/null || true
    [ -f /etc/nginx/conf.d/default.conf.bak ] && mv /etc/nginx/conf.d/default.conf.bak /etc/nginx/conf.d/default.conf 2>/dev/null || true
    rm -rf /var/www/margin 2>/dev/null || true
    ui_success "Nginx 服务已停止，静态网页模板与回落配置已清理"

    # 3. 卸载附加依赖包 (nginx, unzip, socat)
    ui_info "正在卸载通过脚本安装的应用包 (nginx, unzip, socat)..."
    if command -v apk >/dev/null 2>&1; then
        apk del nginx unzip socat 2>/dev/null || true
    elif command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get purge -y nginx nginx-common nginx-core unzip socat 2>/dev/null || apt-get remove -y nginx unzip socat 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
    fi
    if [ -d /etc/nginx ] && [ -z "$(ls -A /etc/nginx 2>/dev/null)" ]; then
        rm -rf /etc/nginx 2>/dev/null || true
    fi
    ui_success "Nginx 及辅助工具包卸载完成"

    # 4. 清除 sing-box 二进制、配置文件与证书目录
    ui_info "正在清理 sing-box 二进制、配置文件与证书..."
    rm -f "$INSTALL_DIR/sing-box" 2>/dev/null || true
    rm -rf "$CONF_DIR" 2>/dev/null || true
    rm -f /var/log/sing-box.log /var/log/sing-box.err 2>/dev/null || true
    ui_success "sing-box 程序、配置及证书目录 (${CONF_DIR}) 已彻底清理"

    # 5. 卸载 acme.sh 并清理 crontab 计划任务
    ui_info "正在卸载 acme.sh 证书环境与计划任务..."
    ACME_DIR="${HOME:-/root}/.acme.sh"
    if [ -f "$ACME_DIR/acme.sh" ]; then
        "$ACME_DIR/acme.sh" --uninstall 2>/dev/null || true
    fi
    rm -rf "$ACME_DIR" 2>/dev/null || true
    rm -rf /root/.acme.sh 2>/dev/null || true
    if command -v crontab >/dev/null 2>&1; then
        crontab -l 2>/dev/null | grep -v "acme.sh" | crontab - 2>/dev/null || true
    fi
    ui_success "acme.sh 环境及定时续签计划任务已清除"

    # 6. 清理临时下载与运行时缓存
    ui_info "正在清理临时缓存文件..."
    rm -rf "$WORK_DIR" 2>/dev/null || true
    rm -rf /tmp/margin_dl* /tmp/sing-box* 2>/dev/null || true
    ui_success "临时缓存清理完成"

    # 7. 完成报告输出
    printf "\n${C_GREEN}${C_BOLD}"
    printf "==========================================================\n"
    printf "🎉 节点环境与相关服务已全部清理完毕！\n"
    printf "==========================================================\n"
    printf "${C_RESET}"
    printf "  ${C_BOLD}已清理内容：${C_RESET}\n"
    printf "   ✔ sing-box 服务、开机自启、主程序与日志已移除\n"
    printf "   ✔ %s 配置目录、Reality 密钥及证书已彻底清除\n" "${CONF_DIR}"
    printf "   ✔ Nginx 服务、站点配置与 /var/www/margin 静态网页已删除\n"
    printf "   ✔ acme.sh 证书环境与定时续订任务已卸载\n"
    printf "   ✔ 系统状态已恢复至未安装节点的纯净状态\n"
    printf "${C_CYAN}==========================================================${C_RESET}\n\n"
}
