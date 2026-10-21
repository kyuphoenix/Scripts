# ---------- 2. 安装核心系统依赖 (Debian / Ubuntu) ----------
SB_TARGET="glibc"
RELOAD_CMD="systemctl restart sing-box 2>/dev/null || true"

ui_step "1/6" "安装最小核心系统依赖 (Debian / Ubuntu)..."
ui_info "正在更新包索引并安装基础依赖 (curl, openssl, ca-certificates, cron, systemd, tar)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends curl openssl ca-certificates cron systemd tar procps
ui_success "核心系统依赖安装完成"

# 启动并自启 cron 服务以支持证书自动续签
systemctl enable cron 2>/dev/null || systemctl enable crond 2>/dev/null || true
systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null || systemctl start cron 2>/dev/null || true
ui_success "Cron 定时服务配置并运行成功"
