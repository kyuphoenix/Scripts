# ---------- 2. 安装核心系统依赖 (Alpine Linux) ----------
SB_TARGET="musl"
RELOAD_CMD="rc-service sing-box restart 2>/dev/null || true"

ui_step "1/6" "安装最小核心系统依赖 (Alpine)..."
ui_info "正在更新包索引并安装基础依赖 (curl, openssl, ca-certificates, cronie, openrc)..."
apk update
apk add --no-cache curl openssl ca-certificates cronie openrc
ui_success "核心系统依赖安装完成"

# 确保 OpenRC 运行环境就绪
[ -d /run/openrc ] || mkdir -p /run/openrc
touch /run/openrc/softlevel 2>/dev/null || true

# 适配 Cron 服务名称
CRON_SVC="cronie"
if [ ! -f /etc/init.d/cronie ] && [ -f /etc/init.d/crond ]; then
    CRON_SVC="crond"
fi

rc-update add "$CRON_SVC" default 2>/dev/null || true
rc-service "$CRON_SVC" restart 2>/dev/null || rc-service "$CRON_SVC" start 2>/dev/null || true
ui_success "Cron 定时服务 ($CRON_SVC) 配置并运行成功"
