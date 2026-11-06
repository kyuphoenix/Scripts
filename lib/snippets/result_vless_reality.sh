# ---------- 7. 验证并输出节点信息 (VLESS + Reality) ----------
ui_step "7/7" "检查节点服务运行状态..."
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

# 确保读取持久化的 Reality 密钥与公钥
REALITY_KEY_FILE="/etc/sing-box/reality.key"
[ -s "$REALITY_KEY_FILE" ] && . "$REALITY_KEY_FILE" 2>/dev/null || true

ui_info "正在查询公网 IP 地址..."
SERVER_IP=$(curl -s4m 5 https://api.ipify.org || curl -s4m 5 https://ifconfig.me || echo "你的公网IP")
VLESS_LINK="vless://${USER_UUID}@${SERVER_IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${USER_DOMAIN}&fp=chrome&pbk=${REALITY_PUBKEY}&sid=${REALITY_SHORT_ID}&type=tcp#VLESS-Reality"

# 最终成果输出面板
clear 2>/dev/null || true
printf "${C_GREEN}${C_BOLD}"
printf "==========================================================\n"
printf "🎉 sing-box (VLESS + Reality) 部署成功！\n"
printf "==========================================================\n"
printf "${C_RESET}"
printf "  ${C_BOLD}服务器地址 (域名) :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${USER_DOMAIN}"
printf "  ${C_BOLD}服务器真实 IP     :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${SERVER_IP}"
printf "  ${C_BOLD}连接端口 (TCP)    :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${PORT}"
printf "  ${C_BOLD}用户 UUID         :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${USER_UUID}"
printf "  ${C_BOLD}SNI 伪装域名      :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${USER_DOMAIN}"
printf "  ${C_BOLD}Reality 公钥(pbk) :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${REALITY_PUBKEY}"
printf "  ${C_BOLD}Reality Short ID  :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${REALITY_SHORT_ID}"
printf "  ${C_BOLD}伪装回落架构      :${C_RESET} ${C_GRAY}本地 Nginx (127.0.0.1:8443) 偷自己真实证书 + margin 静态页${C_RESET}\n"
printf "  ${C_BOLD}运行环境          :${C_RESET} ${C_GRAY}%s (%s)${C_RESET}\n" "${SB_TARGET:-native}" "$(uname -s)"
printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"
printf "${C_BOLD}🔗 VLESS + Reality 通用导入链接:${C_RESET}\n\n"
printf "${C_GREEN}%s${C_RESET}\n\n" "${VLESS_LINK}"
printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"
printf "${C_BOLD}📋 sing-box 客户端 Outbound 配置片段:${C_RESET}\n"
cat << CLIENT_EOF
{
  "type": "vless",
  "tag": "vless-out",
  "server": "${USER_DOMAIN}",
  "server_port": ${PORT},
  "uuid": "${USER_UUID}",
  "flow": "xtls-rprx-vision",
  "tls": {
    "enabled": true,
    "server_name": "${USER_DOMAIN}",
    "utls": {
      "enabled": true,
      "fingerprint": "chrome"
    },
    "reality": {
      "enabled": true,
      "public_key": "${REALITY_PUBKEY}",
      "short_id": "${REALITY_SHORT_ID}"
    }
  },
  "packet_encoding": "xudp"
}
CLIENT_EOF
printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"
printf "${C_BOLD}📋 Mihomo (Clash Meta) 客户端 Proxy 配置片段:${C_RESET}\n"
cat << MIHOMO_EOF
- name: "VLESS-Reality"
  type: vless
  server: ${USER_DOMAIN}
  port: ${PORT}
  uuid: ${USER_UUID}
  network: tcp
  tls: true
  udp: true
  flow: xtls-rprx-vision
  servername: ${USER_DOMAIN}
  reality-opts:
    public-key: ${REALITY_PUBKEY}
    short-id: ${REALITY_SHORT_ID}
  client-fingerprint: chrome
MIHOMO_EOF
printf "${C_CYAN}==========================================================${C_RESET}\n"
printf "管理服务命令: ${C_YELLOW}%s${C_RESET}\n" "${SVC_MGR_CMD}"
printf "Nginx 管理:   ${C_YELLOW}systemctl/rc-service nginx {start|stop|restart|status}${C_RESET}\n"
printf "${C_CYAN}==========================================================${C_RESET}\n"
post_install_prompt
