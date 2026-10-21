# ---------- 6. 配置 Systemd 服务托管并启动 (Debian / Ubuntu) ----------
ui_step "5/6" "注册 Systemd 服务托管并启动..."
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
