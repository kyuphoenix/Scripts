# ---------- 5. 写入节点配置文件 ----------
ui_step "4/6" "生成节点配置文件 ($PROTO_TITLE)..."
mkdir -p "$CONF_DIR"

if [ "$PROTO_NAME" = "vless_reality" ]; then
    # 若为 VLESS+Reality，先配置 Nginx 挂载静态网页回落与生成密钥对
    # 1. 安装 Nginx 和 unzip
    if command -v apk >/dev/null 2>&1; then
        ui_info "正在通过 apk 安装 nginx 和 unzip..."
        apk add --no-cache nginx unzip
    elif command -v apt-get >/dev/null 2>&1; then
        ui_info "正在通过 apt 安装 nginx 和 unzip..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y && apt-get install -y --no-install-recommends nginx unzip
    fi

    # 2. 清理默认冲突站点
    [ -f /etc/nginx/http.d/default.conf ] && mv /etc/nginx/http.d/default.conf /etc/nginx/http.d/default.conf.bak 2>/dev/null || true
    [ -f /etc/nginx/conf.d/default.conf ] && mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak 2>/dev/null || true
    [ -f /etc/nginx/sites-enabled/default ] && rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

    # 3. 部署 margin 静态网页模板
    WEB_ROOT="/var/www/margin"
    mkdir -p "$WEB_ROOT"
    if [ -s "$WEB_ROOT/index.html" ]; then
        ui_success "检测到已有静态网页模板 ($WEB_ROOT/index.html)，自动跳过下载！"
    else
        ui_info "正在拉取静态网页资源 (margin.zip)..."
        TMP_ZIP_DIR="/tmp/margin_dl_$$"
        mkdir -p "$TMP_ZIP_DIR"
        DOWNLOAD_SUCCESS=0
        if curl -fSL "https://mrhtml.com/downloads/templates/margin.zip" -o "$TMP_ZIP_DIR/margin.zip" 2>/dev/null; then
            DOWNLOAD_SUCCESS=1
        elif wget -qO "$TMP_ZIP_DIR/margin.zip" "https://mrhtml.com/downloads/templates/margin.zip" 2>/dev/null; then
            DOWNLOAD_SUCCESS=1
        fi
        if [ "$DOWNLOAD_SUCCESS" -eq 1 ] && [ -s "$TMP_ZIP_DIR/margin.zip" ]; then
            unzip -q -o "$TMP_ZIP_DIR/margin.zip" -d "$TMP_ZIP_DIR/" 2>/dev/null || true
            INDEX_PARENT=$(find "$TMP_ZIP_DIR" -type f -name "index.html" -exec dirname {} \; 2>/dev/null | head -n 1)
            if [ -n "$INDEX_PARENT" ] && [ -f "$INDEX_PARENT/index.html" ]; then
                cp -rf "$INDEX_PARENT"/* "$WEB_ROOT/"
                ui_success "静态网页模板部署成功: $WEB_ROOT"
            fi
        fi
        rm -rf "$TMP_ZIP_DIR" 2>/dev/null || true
    fi

    # 4. 写入 Nginx 回落配置 (监听 127.0.0.1:8443)
    FALLBACK_PORT="8443"
    NGINX_CONF_DIR="/etc/nginx/conf.d"
    [ -d /etc/nginx/http.d ] && NGINX_CONF_DIR="/etc/nginx/http.d"
    mkdir -p "$NGINX_CONF_DIR"

    cat << EOF > "$NGINX_CONF_DIR/reality_fallback.conf"
server {
    listen 127.0.0.1:${FALLBACK_PORT} ssl;
    listen [::1]:${FALLBACK_PORT} ssl;
    server_name ${USER_DOMAIN};

    ssl_certificate ${CERT_DIR}/server.crt;
    ssl_certificate_key ${CERT_DIR}/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    root ${WEB_ROOT};
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    nginx -t >/dev/null 2>&1 || true
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload 2>/dev/null || true
        systemctl enable nginx 2>/dev/null || true
        systemctl restart nginx 2>/dev/null || systemctl start nginx 2>/dev/null || true
    elif command -v rc-service >/dev/null 2>&1; then
        rc-update add nginx default 2>/dev/null || true
        rc-service nginx restart 2>/dev/null || rc-service nginx start 2>/dev/null || true
    fi
    ui_success "Nginx 伪装网站与证书回落配置完成 (回落端口: 127.0.0.1:${FALLBACK_PORT})"

    # 5. 提取或生成 Reality 密钥对
    REALITY_KEY_FILE="/etc/sing-box/reality.key"
    if [ -s "$REALITY_KEY_FILE" ]; then
        . "$REALITY_KEY_FILE" 2>/dev/null || true
    fi
    if [ -z "$REALITY_PRIVKEY" ] || [ -z "$REALITY_PUBKEY" ] || [ -z "$REALITY_SHORT_ID" ]; then
        KEYPAIR=$("$INSTALL_DIR/sing-box" generate reality-keypair 2>/dev/null || true)
        REALITY_PRIVKEY=$(echo "$KEYPAIR" | grep -i "PrivateKey" | head -n 1 | awk '{print $NF}' | tr -d '"' | tr -d ',')
        REALITY_PUBKEY=$(echo "$KEYPAIR" | grep -i "PublicKey" | head -n 1 | awk '{print $NF}' | tr -d '"' | tr -d ',')
        REALITY_SHORT_ID=$(openssl rand -hex 8 2>/dev/null || tr -dc 'a-f0-9' < /dev/urandom 2>/dev/null | head -c 16 || echo "12345678abcdef01")
        cat << KEY_EOF > "$REALITY_KEY_FILE"
REALITY_PRIVKEY="${REALITY_PRIVKEY}"
REALITY_PUBKEY="${REALITY_PUBKEY}"
REALITY_SHORT_ID="${REALITY_SHORT_ID}"
KEY_EOF
        chmod 600 "$REALITY_KEY_FILE"
    fi

cat << EOF > "$CONF_DIR/config.json"
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [
        {
          "uuid": "${USER_UUID}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${USER_DOMAIN}",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "127.0.0.1",
            "server_port": 8443
          },
          "private_key": "${REALITY_PRIVKEY}",
          "short_id": [
            "${REALITY_SHORT_ID}"
          ]
        }
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

elif [ "$PROTO_NAME" = "anytls" ]; then
cat << EOF > "$CONF_DIR/config.json"
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "anytls",
      "tag": "anytls-in",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [
        {
          "name": "default",
          "password": "${PASSWORD}"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${USER_DOMAIN}",
        "alpn": [
          "h2",
          "http/1.1"
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

elif [ "$PROTO_NAME" = "hy2" ]; then
cat << EOF > "$CONF_DIR/config.json"
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
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
output_log="/var/log/sing-box.log"
error_log="/var/log/sing-box.err"

depend() {
    need net
    after firewall
}
SVC_EOF
    chmod +x /etc/init.d/sing-box
    rc-update add sing-box default 2>/dev/null || true
    rc-service sing-box restart 2>/dev/null || rc-service sing-box start 2>/dev/null || true
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
printf "  ${C_BOLD}连接端口          :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${PORT}"
if [ "$PROTO_NAME" = "tuic" ] || [ "$PROTO_NAME" = "vless_reality" ]; then
    printf "  ${C_BOLD}用户 UUID         :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${USER_UUID}"
fi
if [ "$PROTO_NAME" != "vless_reality" ]; then
    printf "  ${C_BOLD}认证密码          :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${PASSWORD}"
fi
printf "  ${C_BOLD}SNI 伪装域名      :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${USER_DOMAIN}"
if [ "$PROTO_NAME" = "vless_reality" ]; then
    printf "  ${C_BOLD}Reality 公钥(pbk) :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${REALITY_PUBKEY}"
    printf "  ${C_BOLD}Reality Short ID  :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${REALITY_SHORT_ID}"
    printf "  ${C_BOLD}伪装回落架构      :${C_RESET} ${C_GRAY}本地 Nginx (127.0.0.1:8443) 偷自己真实证书 + margin 静态页${C_RESET}\n"
fi
printf "  ${C_BOLD}操作系统与架构    :${C_RESET} ${C_GRAY}%s (%s)${C_RESET}\n" "${OS_DESC}" "${ARCH}"
printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"

if [ "$PROTO_NAME" = "vless_reality" ]; then
    VLESS_LINK="vless://${USER_UUID}@${SERVER_IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${USER_DOMAIN}&fp=chrome&pbk=${REALITY_PUBKEY}&sid=${REALITY_SHORT_ID}&type=tcp#VLESS-Reality"
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

elif [ "$PROTO_NAME" = "anytls" ]; then
    ANYTLS_LINK="anytls://${PASSWORD}@${USER_DOMAIN}:${PORT}?sni=${USER_DOMAIN}#AnyTLS-Node"
    printf "${C_BOLD}🔗 AnyTLS 通用导入链接:${C_RESET}\n\n"
    printf "${C_GREEN}%s${C_RESET}\n\n" "${ANYTLS_LINK}"
    printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"
    printf "${C_BOLD}📋 sing-box 客户端 Outbound 配置片段:${C_RESET}\n"
cat << CLIENT_EOF
{
  "type": "anytls",
  "tag": "anytls-out",
  "server": "${USER_DOMAIN}",
  "server_port": ${PORT},
  "password": "${PASSWORD}",
  "tls": {
    "enabled": true,
    "server_name": "${USER_DOMAIN}",
    "alpn": [
      "h2",
      "http/1.1"
    ],
    "insecure": false
  }
}
CLIENT_EOF
    printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"
    printf "${C_BOLD}📋 Mihomo (Clash Meta) 客户端 Proxy 配置片段:${C_RESET}\n"
cat << MIHOMO_EOF
- name: "AnyTLS-Node"
  type: anytls
  server: ${USER_DOMAIN}
  port: ${PORT}
  password: ${PASSWORD}
  sni: ${USER_DOMAIN}
  alpn:
    - h2
    - http/1.1
  skip-cert-verify: false
  client-fingerprint: chrome
MIHOMO_EOF

elif [ "$PROTO_NAME" = "hy2" ]; then
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
if [ "$PROTO_NAME" = "vless_reality" ]; then
    printf "Nginx 服务:   ${C_YELLOW}systemctl/rc-service nginx {start|stop|restart|status}${C_RESET}\n"
fi
if [ "$PROTO_NAME" = "tuic" ]; then
    printf "日志文件路径: ${C_YELLOW}%s${C_RESET}\n" "${LOG_PATH}"
fi
printf "${C_CYAN}==========================================================${C_RESET}\n"
