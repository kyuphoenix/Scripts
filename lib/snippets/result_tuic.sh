# ---------- 7. 验证并输出节点信息 (TUIC v5) ----------
ui_step "6/6" "检查节点服务运行状态..."
sleep 2

STATUS_OK=0
if command -v systemctl >/dev/null 2>&1 && [ -f /etc/systemd/system/sing-box.service ]; then
    systemctl is-active --quiet sing-box && STATUS_OK=1
    SVC_MGR_CMD="systemctl {start|stop|restart|status} sing-box"
    LOG_PATH="/var/log/sing-box.log (或 journalctl -u sing-box -f)"
else
    rc-service sing-box status 2>/dev/null | grep -qi "started" && STATUS_OK=1
    SVC_MGR_CMD="rc-service sing-box {start|stop|restart|status}"
    LOG_PATH="/var/log/sing-box.log | /var/log/sing-box.err"
fi

if [ "$STATUS_OK" -ne 1 ]; then
    ui_error "服务启动失败，请检查配置文件是否正确！"
    exit 1
fi

ui_info "正在查询公网 IP 地址..."
SERVER_IP=$(curl -s4m 5 https://api.ipify.org || curl -s4m 5 https://ifconfig.me || echo "你的公网IP")
TUIC_LINK="tuic://${USER_UUID}:${PASSWORD}@${USER_DOMAIN}:${PORT}?congestion_control=bbr&alpn=h3&sni=${USER_DOMAIN}&udp_relay_mode=native#TUIC-Node"

# 最终成果输出面板
clear 2>/dev/null || true
printf "${C_GREEN}${C_BOLD}"
printf "==========================================================\n"
printf "🎉 sing-box (TUIC v5) 部署成功！\n"
printf "==========================================================\n"
printf "${C_RESET}"
printf "  ${C_BOLD}服务器地址 (域名) :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${USER_DOMAIN}"
printf "  ${C_BOLD}服务器真实 IP     :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${SERVER_IP}"
printf "  ${C_BOLD}连接端口 (UDP)    :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${PORT}"
printf "  ${C_BOLD}用户 UUID         :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${USER_UUID}"
printf "  ${C_BOLD}认证密码          :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${PASSWORD}"
printf "  ${C_BOLD}SNI 伪装域名      :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${USER_DOMAIN}"
printf "  ${C_BOLD}ALPN              :${C_RESET} ${C_CYAN}h3${C_RESET}\n"
printf "  ${C_BOLD}拥塞控制          :${C_RESET} ${C_CYAN}bbr${C_RESET}\n"
printf "  ${C_BOLD}证书类型          :${C_RESET} ${C_GRAY}Let's Encrypt 官方证书 (已配置自动续签)${C_RESET}\n"
printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"
printf "${C_BOLD}🔗 TUIC v5 通用导入链接 (支持 Shadowrocket、NekoBox 等):${C_RESET}\n\n"
printf "${C_GREEN}%s${C_RESET}\n\n" "${TUIC_LINK}"
printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"
printf "${C_BOLD}📋 sing-box 客户端 Outbound 配置片段:${C_RESET}\n"
cat << CLIENT_EOF
{
  "type": "tuic",
  "tag": "tuic-out",
  "server": "${USER_DOMAIN}",
  "server_port": ${PORT},
  "uuid": "${USER_UUID}",
  "password": "${PASSWORD}",
  "congestion_control": "bbr",
  "udp_relay_mode": "native",
  "tls": {
    "enabled": true,
    "server_name": "${USER_DOMAIN}",
    "alpn": ["h3"],
    "insecure": false
  }
}
CLIENT_EOF
printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"
printf "管理服务命令: ${C_YELLOW}%s${C_RESET}\n" "${SVC_MGR_CMD}"
printf "日志文件路径: ${C_YELLOW}%s${C_RESET}\n" "${LOG_PATH}"
printf "${C_CYAN}==========================================================${C_RESET}\n"
