# ---------- 5. 写入 sing-box VLESS + Reality 配置 (偷自己证书) ----------
ui_step "5/7" "生成 VLESS + Reality 配置文件..."
mkdir -p "$CONF_DIR"

# 1. 提取或生成 Reality 密钥对与 Short ID
REALITY_KEY_FILE="/etc/sing-box/reality.key"
if [ -s "$REALITY_KEY_FILE" ]; then
    . "$REALITY_KEY_FILE" 2>/dev/null || true
    if [ -n "$REALITY_PRIVKEY" ] && [ -n "$REALITY_PUBKEY" ] && [ -n "$REALITY_SHORT_ID" ]; then
        ui_success "检测到已有 Reality 密钥对，自动复用！"
    fi
fi

if [ -z "$REALITY_PRIVKEY" ] || [ -z "$REALITY_PUBKEY" ] || [ -z "$REALITY_SHORT_ID" ]; then
    ui_info "正在通过 sing-box 生成全新 Reality X25519 密钥对与 Short ID..."
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
    ui_success "Reality 密钥对生成完成并持久化保存"
fi

# 2. 写入 sing-box VLESS+Reality 配置 (回落至本地 Nginx 8443)
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

ui_info "验证配置文件正确性..."
"$INSTALL_DIR/sing-box" check -c "$CONF_DIR/config.json"
ui_success "配置文件校验通过: $CONF_DIR/config.json"
