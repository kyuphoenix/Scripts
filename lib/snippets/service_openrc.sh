# ---------- 6. 配置 OpenRC 服务托管并启动 (Alpine) ----------
ui_step "5/6" "注册 OpenRC 服务托管并启动..."
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
