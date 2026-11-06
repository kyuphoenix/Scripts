# ---------- 综合系统部署状态检测与诊断模块 ----------
detect_system_status() {
    # 1. 检测 sing-box 二进制与版本
    SB_BIN=""
    SB_INSTALLED=0
    SB_VERSION=""
    if [ -f "$INSTALL_DIR/sing-box" ]; then
        SB_BIN="$INSTALL_DIR/sing-box"
        SB_INSTALLED=1
    elif command -v sing-box >/dev/null 2>&1; then
        SB_BIN=$(command -v sing-box)
        SB_INSTALLED=1
    fi

    if [ "$SB_INSTALLED" -eq 1 ]; then
        SB_VERSION=$("$SB_BIN" version 2>/dev/null | head -n 1 | awk '{print $3}' || true)
        if [ -z "$SB_VERSION" ]; then
            SB_VERSION="已安装"
        fi
    fi

    # 2. 检测服务运行状态与进程信息
    SB_RUNNING=0
    SB_PID=""
    SB_SERVICE_STATUS=""
    SB_CPU="0.0%"
    SB_MEM="0.0%"

    if command -v systemctl >/dev/null 2>&1 && [ -f /etc/systemd/system/sing-box.service ]; then
        if systemctl is-active --quiet sing-box 2>/dev/null; then
            SB_RUNNING=1
            SB_SERVICE_STATUS="运行中 (active)"
        else
            SB_SERVICE_STATUS="已停止 (inactive)"
        fi
    elif command -v rc-service >/dev/null 2>&1 && [ -f /etc/init.d/sing-box ]; then
        if rc-service sing-box status 2>/dev/null | grep -qi "started"; then
            SB_RUNNING=1
            SB_SERVICE_STATUS="运行中 (started)"
        else
            SB_SERVICE_STATUS="已停止 (stopped)"
        fi
    fi

    # 兜底检测 PID
    PIDS=$(pgrep -x sing-box 2>/dev/null || pidof sing-box 2>/dev/null || true)
    if [ -n "$PIDS" ]; then
        SB_RUNNING=1
        SB_PID=$(echo "$PIDS" | awk '{print $1}')
        if [ -z "$SB_SERVICE_STATUS" ]; then
            SB_SERVICE_STATUS="进程运行中 (PID: $SB_PID)"
        fi
        
        # 尝试获取 CPU 与内存占用
        if command -v ps >/dev/null 2>&1 && [ -n "$SB_PID" ]; then
            CPU_MEM=$(ps -o %cpu,%mem -p "$SB_PID" 2>/dev/null | tail -n 1 || true)
            if [ -n "$CPU_MEM" ]; then
                P_CPU=$(echo "$CPU_MEM" | awk '{print $1}')
                P_MEM=$(echo "$CPU_MEM" | awk '{print $2}')
                [ -n "$P_CPU" ] && SB_CPU="${P_CPU}%" || true
                [ -n "$P_MEM" ] && SB_MEM="${P_MEM}%" || true
            fi
        fi
    elif [ -z "$SB_SERVICE_STATUS" ]; then
        if [ "$SB_INSTALLED" -eq 1 ]; then
            SB_SERVICE_STATUS="已停止 (not running)"
        else
            SB_SERVICE_STATUS="未安装"
        fi
    fi

    # 3. 检测配置文件与协议类型
    CONF_FILE="$CONF_DIR/config.json"
    HAS_CONFIG=0
    ACTIVE_PROTO="未配置"
    ACTIVE_PORT="未知"
    ACTIVE_DOMAIN="未知"
    ACTIVE_PASSWORD=""
    ACTIVE_UUID=""

    if [ -f "$CONF_FILE" ]; then
        HAS_CONFIG=1
        if grep -qi '"type": *"hysteria2"' "$CONF_FILE" 2>/dev/null; then
            ACTIVE_PROTO="Hysteria 2"
        elif grep -qi '"type": *"tuic"' "$CONF_FILE" 2>/dev/null; then
            ACTIVE_PROTO="TUIC v5"
        elif grep -qi '"type": *"anytls"' "$CONF_FILE" 2>/dev/null; then
            ACTIVE_PROTO="AnyTLS"
        elif grep -qi '"type": *"vless"' "$CONF_FILE" 2>/dev/null; then
            ACTIVE_PROTO="VLESS + Reality"
        else
            ACTIVE_PROTO="自定义配置"
        fi

        P_VAL=$(grep -oE '"listen_port": *[0-9]+' "$CONF_FILE" 2>/dev/null | head -n 1 | awk '{print $NF}' || true)
        if [ -n "$P_VAL" ]; then
            ACTIVE_PORT="$P_VAL"
        fi

        D_VAL=$(grep -oE '"server_name": *"[^"]+"' "$CONF_FILE" 2>/dev/null | head -n 1 | cut -d'"' -f4 || true)
        if [ -n "$D_VAL" ]; then
            ACTIVE_DOMAIN="$D_VAL"
        fi

        ACTIVE_PASSWORD=$(grep -oE '"password": *"[^"]+"' "$CONF_FILE" 2>/dev/null | head -n 1 | cut -d'"' -f4 || true)
        ACTIVE_UUID=$(grep -oE '"uuid": *"[^"]+"' "$CONF_FILE" 2>/dev/null | head -n 1 | cut -d'"' -f4 || true)
    fi

    # Reality 专有密钥检测
    REALITY_PUBKEY=""
    REALITY_SHORT_ID=""
    if [ -f "$CONF_DIR/reality.key" ]; then
        . "$CONF_DIR/reality.key" 2>/dev/null || true
    fi

    # 4. 检测 SSL 证书与 acme.sh 状态
    HAS_CERT=0
    CERT_DAYS_LEFT="无"
    CERT_EXPIRY=""
    CERT_DOMAIN=""
    CERT_FILE="$CERT_DIR/server.crt"
    if [ -s "$CERT_FILE" ] && command -v openssl >/dev/null 2>&1; then
        CERT_DOMAIN=$(openssl x509 -noout -text -in "$CERT_FILE" 2>/dev/null | grep -oE "DNS:[^ ,]+" | head -n 1 | cut -d: -f2 || true)
        if [ -z "$CERT_DOMAIN" ]; then
            CERT_DOMAIN=$(openssl x509 -noout -subject -in "$CERT_FILE" 2>/dev/null | sed -n 's/.*CN = //p' | cut -d/ -f1 || true)
        fi
        if [ -z "$ACTIVE_DOMAIN" ] || [ "$ACTIVE_DOMAIN" = "未知" ]; then
            if [ -n "$CERT_DOMAIN" ]; then
                ACTIVE_DOMAIN="$CERT_DOMAIN"
            fi
        fi

        EXP_DATE_STR=$(openssl x509 -noout -enddate -in "$CERT_FILE" 2>/dev/null | cut -d= -f2 || true)
        CERT_EXPIRY="$EXP_DATE_STR"
        if [ -n "$EXP_DATE_STR" ]; then
            EXP_SEC=$(date -d "$EXP_DATE_STR" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$EXP_DATE_STR" +%s 2>/dev/null || true)
            NOW_SEC=$(date +%s)
            if [ -n "$EXP_SEC" ] && [ "$EXP_SEC" -gt "$NOW_SEC" ] 2>/dev/null; then
                DIFF_SEC=$(( EXP_SEC - NOW_SEC ))
                DAYS=$(( DIFF_SEC / 86400 ))
                CERT_DAYS_LEFT="${DAYS} 天"
                HAS_CERT=1
            elif openssl x509 -checkend 86400 -noout -in "$CERT_FILE" >/dev/null 2>&1; then
                HAS_CERT=1
                CERT_DAYS_LEFT="有效"
            else
                CERT_DAYS_LEFT="已过期"
            fi
        fi
    fi

    ACME_INSTALLED=0
    ACME_CRON=0
    ACME_BIN="${HOME:-/root}/.acme.sh/acme.sh"
    if [ -f "$ACME_BIN" ]; then
        ACME_INSTALLED=1
        if command -v crontab >/dev/null 2>&1; then
            if crontab -l 2>/dev/null | grep -q "acme.sh"; then
                ACME_CRON=1
            fi
        fi
    fi

    # 5. 检测 Nginx 状态与伪装站
    NGINX_INSTALLED=0
    NGINX_RUNNING=0
    MARGIN_SITE_EXISTS=0
    if command -v nginx >/dev/null 2>&1; then
        NGINX_INSTALLED=1
        if pgrep -x nginx >/dev/null 2>&1 || (command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet nginx 2>/dev/null); then
            NGINX_RUNNING=1
        fi
    fi
    if [ -d "/var/www/margin" ] && [ -f "/var/www/margin/index.html" ]; then
        MARGIN_SITE_EXISTS=1
    fi

    # 6. 综合判断：是否已使用本脚本安装过服务
    IS_CONFIGURED=0
    if [ "$SB_INSTALLED" -eq 1 ] && [ "$HAS_CONFIG" -eq 1 ]; then
        IS_CONFIGURED=1
    fi
}
