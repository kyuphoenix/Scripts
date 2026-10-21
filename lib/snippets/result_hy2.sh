# ---------- 7. 验证并输出节点信息 (Hysteria 2) ----------
ui_step "6/6" "检查节点服务运行状态..."
sleep 2

STATUS_OK=0
if command -v systemctl >/dev/null 2>&1 && [ -f /etc/systemd/system/sing-box.service ]; then
    systemctl is-active --quiet sing-box && STATUS_OK=1
    SVC_MGR_CMD="systemctl {start|stop|restart|status} sing-box"
else
    rc-service sing-box status 2>/dev/null | grep -qi "started" && STATUS_OK=1
    SVC_MGR_CMD="rc-service sing-box {start|stop|restart|status}"
fi

if [ "$STATUS_OK" -ne 1 ]; then
    ui_error "服务启动失败，请检查配置文件是否正确！"
    exit 1
fi

ui_info "正在查询公网 IP 地址..."
SERVER_IP=$(curl -s4m 5 https://api.ipify.org || curl -s4m 5 https://ifconfig.me || echo "你的公网IP")
HY2_LINK="hysteria2://${PASSWORD}@${USER_DOMAIN}:${PORT}?sni=${USER_DOMAIN}&alpn=h3#Hysteria2-Node"

# 最终成果输出面板
clear 2>/dev/null || true
printf "${C_GREEN}${C_BOLD}"
printf "==========================================================\n"
printf "🎉 sing-box (Hysteria 2) 部署成功！\n"
printf "==========================================================\n"
printf "${C_RESET}"
printf "  ${C_BOLD}服务器地址 (域名) :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${USER_DOMAIN}"
printf "  ${C_BOLD}服务器真实 IP     :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${SERVER_IP}"
printf "  ${C_BOLD}连接端口 (UDP)    :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${PORT}"
printf "  ${C_BOLD}认证密码          :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${PASSWORD}"
printf "  ${C_BOLD}SNI 伪装域名      :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${USER_DOMAIN}"
printf "  ${C_BOLD}ALPN              :${C_RESET} ${C_CYAN}h3${C_RESET}\n"
printf "  ${C_BOLD}运行环境          :${C_RESET} ${C_GRAY}%s (%s)${C_RESET}\n" "${SB_TARGET:-native}" "$(uname -s)"
printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"
printf "${C_BOLD}🔗 Hysteria 2 通用导入链接:${C_RESET}\n\n"
printf "${C_GREEN}%s${C_RESET}\n\n" "${HY2_LINK}"
printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"
printf "${C_BOLD}📋 sing-box 客户端 Outbound 配置片段:${C_RESET}\n"
cat << CLIENT_EOF
{
  "type": "hysteria2",
  "tag": "hy2-out",
  "server": "${USER_DOMAIN}",
  "server_port": ${PORT},
  "password": "${PASSWORD}",
  "tls": {
    "enabled": true,
    "server_name": "${USER_DOMAIN}",
    "alpn": ["h3"],
    "insecure": false
  }
}
CLIENT_EOF
printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"
printf "${C_BOLD}📋 Mihomo (Clash Meta) 客户端 Proxy 配置片段:${C_RESET}\n"
cat << MIHOMO_EOF
- name: "Hysteria2-Node"
  type: hysteria2
  server: ${USER_DOMAIN}
  port: ${PORT}
  password: ${PASSWORD}
  sni: ${USER_DOMAIN}
  alpn:
    - h3
  skip-cert-verify: false
MIHOMO_EOF
printf "${C_CYAN}==========================================================${C_RESET}\n"
printf "管理服务命令: ${C_YELLOW}%s${C_RESET}\n" "${SVC_MGR_CMD}"
printf "${C_CYAN}==========================================================${C_RESET}\n"
