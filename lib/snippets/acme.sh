# ---------- 3. 安装与配置 acme.sh 自动化证书环境 ----------
ui_step "2/6" "配置 acme.sh 自动化证书环境 (匿名注册)..."
ACME_DIR="${HOME:-/root}/.acme.sh"
if [ ! -f "$ACME_DIR/acme.sh" ]; then
    ui_info "正在在线安装 acme.sh..."
    curl -sSL https://get.acme.sh | sh
fi
ACME_BIN="$ACME_DIR/acme.sh"

ui_info "设置证书颁发机构为 Let's Encrypt 并匿名注册账号..."
"$ACME_BIN" --set-default-ca --server letsencrypt
"$ACME_BIN" --register-account || true

mkdir -p "$CERT_DIR"

ui_info "正在通过 Cloudflare DNS-01 验证申请证书..."
if ! "$ACME_BIN" --issue --dns dns_cf -d "$USER_DOMAIN" --force; then
    ui_warn "DNS-01 证书申请初次未通过，正在按需安装 socat 并重试..."
    if command -v apk >/dev/null 2>&1; then
        apk add --no-cache socat
    elif command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y --no-install-recommends socat
    fi
    "$ACME_BIN" --issue --dns dns_cf -d "$USER_DOMAIN" --force
fi

RELOAD_CMD="${RELOAD_CMD:-rc-service sing-box restart 2>/dev/null || systemctl restart sing-box 2>/dev/null || true}"

ui_info "安装证书至 ${CERT_DIR}..."
"$ACME_BIN" --install-cert -d "$USER_DOMAIN" \
    --key-file "$CERT_DIR/server.key" \
    --fullchain-file "$CERT_DIR/server.crt" \
    --reloadcmd "$RELOAD_CMD"
ui_success "证书申请与自动续签绑定完成"
