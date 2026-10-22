# ---------- 3. 安装与配置 acme.sh 自动化证书环境 ----------
ui_step "2/6" "配置 acme.sh 自动化证书环境 (匿名注册)..."
ACME_DIR="${HOME:-/root}/.acme.sh"
mkdir -p "$CERT_DIR"

# 检查本地是否已存在当前域名的有效证书 (支持中断重跑自动跳过，避免 Let's Encrypt 限额)
SKIP_CERT_ISSUE=0
if [ -s "$CERT_DIR/server.key" ] && [ -s "$CERT_DIR/server.crt" ]; then
    CERT_VALID=1
    CERT_MATCH=1
    if command -v openssl >/dev/null 2>&1; then
        # 检查证书是否包含当前绑定的域名
        if ! openssl x509 -noout -text -in "$CERT_DIR/server.crt" 2>/dev/null | grep -qE "DNS:${USER_DOMAIN}\b"; then
            CERT_MATCH=0
        fi
        # 检查证书剩余有效期 (至少大于 1 天)
        if ! openssl x509 -checkend 86400 -noout -in "$CERT_DIR/server.crt" >/dev/null 2>&1; then
            CERT_VALID=0
        fi
    fi

    if [ "$CERT_MATCH" -eq 1 ] && [ "$CERT_VALID" -eq 1 ]; then
        ui_success "检测到已有有效证书 ($CERT_DIR/server.crt)，自动复用并跳过申请！"
        SKIP_CERT_ISSUE=1
    else
        ui_warn "检测到旧证书已过期或域名不匹配，准备重新申请证书..."
    fi
fi

if [ "$SKIP_CERT_ISSUE" -ne 1 ]; then
    if [ ! -f "$ACME_DIR/acme.sh" ]; then
        ui_info "正在在线安装 acme.sh..."
        curl -sSL https://get.acme.sh | sh
    fi
    ACME_BIN="$ACME_DIR/acme.sh"

    ui_info "设置证书颁发机构为 Let's Encrypt 并匿名注册账号..."
    "$ACME_BIN" --set-default-ca --server letsencrypt
    "$ACME_BIN" --register-account || true

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
fi
