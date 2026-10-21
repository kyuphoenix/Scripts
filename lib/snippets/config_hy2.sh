# ---------- 5. 写入 sing-box Hysteria 2 配置 ----------
ui_step "4/6" "生成 Hysteria 2 配置文件..."
mkdir -p "$CONF_DIR"

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

ui_info "验证配置文件正确性..."
"$INSTALL_DIR/sing-box" check -c "$CONF_DIR/config.json"
ui_success "配置文件校验通过: $CONF_DIR/config.json"
