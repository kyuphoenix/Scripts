# ---------- 5. 写入节点配置文件 ----------
ui_step "4/6" "生成节点配置文件 ($PROTO_TITLE)..."
mkdir -p "$CONF_DIR"

if [ "$PROTO_NAME" = "hy2" ]; then
cat << EOF > "$CONF_DIR/config.json"
{
  "log": {
    "disabled": true,
    "level": "fatal",
    "timestamp": false
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [
        {
          "password": "${PASSWORD}"
        }
      ],
      "ignore_client_bandwidth": false,
      "tls": {
        "enabled": true,
        "server_name": "${USER_DOMAIN}",
        "alpn": [
          "h3"
        ],
        "certificate_path": "${CERT_DIR}/server.crt",
        "key_path": "${CERT_DIR}/server.key"
      },
      "masquerade": "https://bing.com"
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
else
cat << EOF > "$CONF_DIR/config.json"
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "tuic",
      "tag": "tuic-in",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [
        {
          "uuid": "${USER_UUID}",
          "password": "${PASSWORD}"
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "server_name": "${USER_DOMAIN}",
        "alpn": [
          "h3"
        ],
        "certificate_path": "${CERT_DIR}/server.crt",
        "key_path": "${CERT_DIR}/server.key"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
fi

ui_info "验证配置文件正确性..."
"$INSTALL_DIR/sing-box" check -c "$CONF_DIR/config.json"
ui_success "配置文件校验通过: $CONF_DIR/config.json"

# ---------- 6. 配置守护服务托管并启动 ----------
ui_step "5/6" "注册服务托管并启动 ($OS_DESC)..."

if [ "$OS_TYPE" = "alpine" ]; then
cat << 'SVC_EOF' > /etc/init.d/sing-box
#!/sbin/openrc-run

name="sing-box"
description="sing-box Service"
command="/usr/local/bin/sing-box"
command_args="run -c /etc/sing-box/config.json"
command_background="true"
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/dev/null"
error_log="/dev/null"

depend() {
    need net
    after firewall
}
SVC_EOF
    chmod +x /etc/init.d/sing-box
    rc-update add sing-box default 2>/dev/null || true
    rc-service sing-box restart 2>/dev/null || rc-service sing-box start 2>/dev/null || true
    rm -f /var/log/sing-box.log /var/log/sing-box.err
    ui_success "sing-box OpenRC 服务已注册并启动"
else
cat << 'SVC_EOF' > /etc/systemd/system/sing-box.service
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=5s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
SVC_EOF
    systemctl daemon-reload
    systemctl enable sing-box 2>/dev/null || true
    systemctl restart sing-box 2>/dev/null || systemctl start sing-box 2>/dev/null || true
    ui_success "sing-box Systemd 服务已注册并启动"
fi

# ---------- 7. 验证并输出节点信息 ----------
ui_step "6/6" "检查节点服务运行状态..."
sleep 2

STATUS_OK=0
if [ "$OS_TYPE" = "debian" ]; then
    systemctl is-active --quiet sing-box && STATUS_OK=1
    SVC_MGR_CMD="systemctl {start|stop|restart|status} sing-box"
    LOG_PATH="/var/log/sing-box.log (或 journalctl -u sing-box -f)"
else
    rc-service sing-box status 2>/dev/null | grep -qi "started" && STATUS_OK=1
    SVC_MGR_CMD="rc-service sing-box {start|stop|restart|status}"
    LOG_PATH="/var/log/sing-box.log | /var/log/sing-box.err"
fi

if [ "$STATUS_OK" -ne 1 ]; then
    ui_error "服务启动失败，请检查配置文件与运行环境！"
    exit 1
fi

ui_info "正在查询公网 IP 地址..."
SERVER_IP=$(curl -s4m 5 https://api.ipify.org || curl -s4m 5 https://ifconfig.me || echo "你的公网IP")

clear 2>/dev/null || true
printf "${C_GREEN}${C_BOLD}"
printf "==========================================================\n"
printf "🎉 sing-box (%s) 部署成功！\n" "$PROTO_TITLE"
printf "==========================================================\n"
printf "${C_RESET}"
printf "  ${C_BOLD}节点协议          :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${PROTO_TITLE}"
printf "  ${C_BOLD}服务器地址 (域名) :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${USER_DOMAIN}"
printf "  ${C_BOLD}服务器真实 IP     :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${SERVER_IP}"
printf "  ${C_BOLD}连接端口 (UDP)    :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${PORT}"
if [ "$PROTO_NAME" = "tuic" ]; then
    printf "  ${C_BOLD}用户 UUID         :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${USER_UUID}"
fi
printf "  ${C_BOLD}认证密码          :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${PASSWORD}"
printf "  ${C_BOLD}SNI 伪装域名      :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${USER_DOMAIN}"
printf "  ${C_BOLD}ALPN              :${C_RESET} ${C_CYAN}h3${C_RESET}\n"
printf "  ${C_BOLD}操作系统与架构    :${C_RESET} ${C_GRAY}%s (%s)%${C_RESET}\n" "${OS_DESC}" "${ARCH}"
printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"

if [ "$PROTO_NAME" = "hy2" ]; then
    HY2_LINK="hysteria2://${PASSWORD}@${USER_DOMAIN}:${PORT}?sni=${USER_DOMAIN}&alpn=h3#Hysteria2-Node"
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
else
    TUIC_LINK="tuic://${USER_UUID}:${PASSWORD}@${USER_DOMAIN}:${PORT}?congestion_control=bbr&alpn=h3&sni=${USER_DOMAIN}&udp_relay_mode=native#TUIC-Node"
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
fi

printf "${C_CYAN}==========================================================${C_RESET}\n"
printf "管理服务命令: ${C_YELLOW}%s${C_RESET}\n" "${SVC_MGR_CMD}"
if [ "$PROTO_NAME" = "tuic" ]; then
    printf "日志文件路径: ${C_YELLOW}%s${C_RESET}\n" "${LOG_PATH}"
fi
printf "${C_CYAN}==========================================================${C_RESET}\n"
