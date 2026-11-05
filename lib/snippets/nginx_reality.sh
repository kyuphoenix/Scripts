# ---------- 部署本地 Nginx 并挂载伪装静态网站 (Reality 偷自己证书回落) ----------
ui_step "4/7" "安装配置 Nginx 伪装网站并设置 Reality 本地回落..."

# 1. 安装 Nginx 和 unzip
if command -v apk >/dev/null 2>&1; then
    ui_info "正在通过 apk 安装 nginx 和 unzip..."
    apk add --no-cache nginx unzip
elif command -v apt-get >/dev/null 2>&1; then
    ui_info "正在通过 apt 安装 nginx 和 unzip..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y && apt-get install -y --no-install-recommends nginx unzip
fi

# 2. 清理默认的 80/443 站点配置，避免与 sing-box 产生端口冲突
[ -f /etc/nginx/http.d/default.conf ] && mv /etc/nginx/http.d/default.conf /etc/nginx/http.d/default.conf.bak 2>/dev/null || true
[ -f /etc/nginx/conf.d/default.conf ] && mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak 2>/dev/null || true
[ -f /etc/nginx/sites-enabled/default ] && rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# 3. 部署 margin 静态网页模板 (已有则跳过)
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
        # 定位 index.html 所在的目录层级
        INDEX_PARENT=$(find "$TMP_ZIP_DIR" -type f -name "index.html" -exec dirname {} \; 2>/dev/null | head -n 1)
        if [ -n "$INDEX_PARENT" ] && [ -f "$INDEX_PARENT/index.html" ]; then
            cp -rf "$INDEX_PARENT"/* "$WEB_ROOT/"
            ui_success "静态网页模板部署成功: $WEB_ROOT"
        else
            ui_warn "解压未找到 index.html，生成默认静态页..."
            cat << 'HTML_EOF' > "$WEB_ROOT/index.html"
<!DOCTYPE html><html><head><meta charset="utf-8"><title>Welcome</title></head>
<body style="font-family:sans-serif;text-align:center;padding:50px;background:#111;color:#eee;">
<h1>System Normal</h1><p>Website is under maintenance.</p></body></html>
HTML_EOF
        fi
    else
        ui_warn "远程静态资源下载失败，生成本地精简伪装网页..."
        cat << 'HTML_EOF' > "$WEB_ROOT/index.html"
<!DOCTYPE html><html><head><meta charset="utf-8"><title>Welcome</title></head>
<body style="font-family:sans-serif;text-align:center;padding:50px;background:#111;color:#eee;">
<h1>System Online</h1><p>Welcome to our cloud node service.</p></body></html>
HTML_EOF
    fi
    rm -rf "$TMP_ZIP_DIR" 2>/dev/null || true
fi

# 4. 写入 Nginx 本地回落配置 (监听 127.0.0.1:8443，加载自己的证书)
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

# 5. 校验并重启 Nginx
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
