# ---------- sing-box 节点运维与服务管理面板 ----------

while true; do
    # 每次刷新检测最新运行状态
    detect_system_status

    ui_banner "sing-box 节点服务维护与管理面板"

    # 简要状态卡片
    printf "${C_BOLD}📌 当前状态摘要：${C_RESET}\n"
    if [ "$IS_CONFIGURED" -eq 1 ]; then
        if [ "$SB_RUNNING" -eq 1 ]; then
            printf "  服务: ${C_GREEN}🟢 运行中${C_RESET} (PID: %s) | 协议: ${C_CYAN}%s${C_RESET} (端口: %s) | 证书: ${C_GREEN}%s${C_RESET}\n" "${SB_PID:-未知}" "${ACTIVE_PROTO}" "${ACTIVE_PORT}" "${CERT_DAYS_LEFT}"
        else
            printf "  服务: ${C_RED}🔴 已停止${C_RESET} | 协议: ${C_CYAN}%s${C_RESET} (端口: %s) | 证书: ${C_YELLOW}%s${C_RESET}\n" "${ACTIVE_PROTO}" "${ACTIVE_PORT}" "${CERT_DAYS_LEFT}"
        fi
    else
        printf "  服务: ${C_GRAY}⚪ 未安装 / 未配置${C_RESET}\n"
    fi
    printf "${C_GRAY}----------------------------------------------------------${C_RESET}\n\n"

    # 维护功能菜单
    printf " ${C_BOLD}请选择管理操作：${C_RESET}\n"
    printf "  ${C_CYAN}1)${C_RESET} 📊 查看综合状态与资源占用 ${C_GRAY}(服务、PID、CPU/内存、端口监听)${C_RESET}\n"
    printf "  ${C_CYAN}2)${C_RESET} 🔗 查看节点连接信息与客户端链接 ${C_GRAY}(协议、密码/UUID、导入链接)${C_RESET}\n"
    printf "  ${C_CYAN}3)${C_RESET} 📜 查看运行日志 ${C_GRAY}(sing-box 最新日志 / 实时日志 / Nginx 日志)${C_RESET}\n"
    printf "  ${C_CYAN}4)${C_RESET} 🔄 服务启停控制 ${C_GRAY}(启动 / 停止 / 重启 sing-box 及 Nginx)${C_RESET}\n"
    printf "  ${C_CYAN}5)${C_RESET} 🛡️  SSL 证书状态与手动续期 ${C_GRAY}(证书详情、有效期、强制测试续订)${C_RESET}\n"
    printf "  ${C_CYAN}6)${C_RESET} 🧹 一键完全卸载与清除环境 ${C_GRAY}(停止服务、删除配置、卸载Nginx)${C_RESET}\n"
    printf "  ${C_CYAN}0)${C_RESET} ⬅️  返回主引导菜单 ${C_GRAY}(Return to Main Menu)${C_RESET}\n"
    printf "  ${C_CYAN}q)${C_RESET} 🚪 退出管理面板 ${C_GRAY}(Exit)${C_RESET}\n\n"

    printf " ${C_CYAN}?${C_RESET} 请输入选项 [0-6 或 q] ${C_GRAY}[默认: 1]${C_RESET}: "
    ui_read OP_CHOICE
    OP_CHOICE=$(echo "$OP_CHOICE" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    OP_CHOICE="${OP_CHOICE:-1}"

    case "$OP_CHOICE" in
        1)
            # 1. 查看综合状态与资源占用
            clear 2>/dev/null || true
            ui_banner "sing-box 系统综合运行状态"
            detect_system_status

            printf "${C_BOLD}🖥️  程序与服务状态：${C_RESET}\n"
            printf "  ● sing-box 路径 : %s\n" "${SB_BIN:-未安装}"
            printf "  ● sing-box 版本 : %s\n" "${SB_VERSION:-未知}"
            printf "  ● 服务状态      : %s\n" "${SB_SERVICE_STATUS}"
            if [ "$SB_RUNNING" -eq 1 ]; then
                printf "  ● 进程 PID      : %s\n" "${SB_PID:-未知}"
                printf "  ● CPU / 内存占用: %s / %s\n" "${SB_CPU}" "${SB_MEM}"
            fi
            printf "  ● 部署协议      : %s\n" "${ACTIVE_PROTO}"
            printf "  ● 监听端口      : %s\n" "${ACTIVE_PORT}"
            printf "  ● 绑定域名      : %s\n" "${ACTIVE_DOMAIN}"
            printf "  ● SSL 证书状态  : %s (到期日: %s)\n" "${CERT_DAYS_LEFT}" "${CERT_EXPIRY:-无}"

            if [ "$NGINX_INSTALLED" -eq 1 ]; then
                printf "\n${C_BOLD}🌐 Nginx 伪装网站状态：${C_RESET}\n"
                if [ "$NGINX_RUNNING" -eq 1 ]; then
                    printf "  ● Nginx 状态    : %s\n" "${C_GREEN}🟢 运行中${C_RESET}"
                else
                    printf "  ● Nginx 状态    : %s\n" "${C_RED}🔴 已停止${C_RESET}"
                fi
                printf "  ● 静态网页目录  : /var/www/margin (%s)\n" "$( [ "$MARGIN_SITE_EXISTS" -eq 1 ] && echo "存在" || echo "缺失" )"
            fi

            printf "\n${C_BOLD}📡 网络端口监听 (sing-box & nginx)：${C_RESET}\n"
            if command -v ss >/dev/null 2>&1; then
                ss -tulnp 2>/dev/null | grep -E "sing-box|nginx" || printf "  ${C_GRAY}(未检测到对应端口监听)${C_RESET}\n"
            elif command -v netstat >/dev/null 2>&1; then
                netstat -tulnp 2>/dev/null | grep -E "sing-box|nginx" || printf "  ${C_GRAY}(未检测到对应端口监听)${C_RESET}\n"
            else
                printf "  ${C_GRAY}(系统缺少 ss / netstat 工具)${C_RESET}\n"
            fi

            printf "\n${C_CYAN}按 [Enter] 键返回管理面板...${C_RESET}"
            ui_read DUMMY
            ;;

        2)
            # 2. 查看节点连接信息与客户端链接
            clear 2>/dev/null || true
            ui_banner "当前节点连接信息与客户端导入"
            detect_system_status

            if [ "$HAS_CONFIG" -ne 1 ]; then
                ui_warn "未检测到已保存的 sing-box 配置文件 (${CONF_FILE})！"
            else
                SERVER_IP=$(curl -s4m 5 https://api.ipify.org || curl -s4m 5 https://ifconfig.me || echo "你的公网IP")
                printf "  ${C_BOLD}节点协议类型 :${C_RESET} ${C_GREEN}%s${C_RESET}\n" "${ACTIVE_PROTO}"
                printf "  ${C_BOLD}绑定服务器域名:${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${ACTIVE_DOMAIN}"
                printf "  ${C_BOLD}公网 IP 地址  :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${SERVER_IP}"
                printf "  ${C_BOLD}连接服务端口  :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${ACTIVE_PORT}"
                if [ -n "$ACTIVE_PASSWORD" ]; then
                    printf "  ${C_BOLD}连接认证密码  :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${ACTIVE_PASSWORD}"
                fi
                if [ -n "$ACTIVE_UUID" ]; then
                    printf "  ${C_BOLD}用户 UUID     :${C_RESET} ${C_CYAN}%s${C_RESET}\n" "${ACTIVE_UUID}"
                fi

                printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"

                if [ "$ACTIVE_PROTO" = "Hysteria 2" ]; then
                    HY2_URL="hysteria2://${ACTIVE_PASSWORD}@${ACTIVE_DOMAIN}:${ACTIVE_PORT}?sni=${ACTIVE_DOMAIN}&alpn=h3#Hysteria2-Node"
                    printf "${C_BOLD}🔗 通用导入链接 (Hysteria 2):${C_RESET}\n"
                    printf "${C_GREEN}%s${C_RESET}\n\n" "${HY2_URL}"
                elif [ "$ACTIVE_PROTO" = "TUIC v5" ]; then
                    TUIC_URL="tuic://${ACTIVE_UUID}:${ACTIVE_PASSWORD}@${ACTIVE_DOMAIN}:${ACTIVE_PORT}?congestion_control=bbr&alpn=h3&sni=${ACTIVE_DOMAIN}&udp_relay_mode=native#TUIC-Node"
                    printf "${C_BOLD}🔗 通用导入链接 (TUIC v5):${C_RESET}\n"
                    printf "${C_GREEN}%s${C_RESET}\n\n" "${TUIC_URL}"
                elif [ "$ACTIVE_PROTO" = "VLESS + Reality" ]; then
                    VLESS_URL="vless://${ACTIVE_UUID}@${ACTIVE_DOMAIN}:${ACTIVE_PORT}?security=reality&encryption=none&pbk=${REALITY_PUBKEY}&headerType=none&type=tcp&sni=${ACTIVE_DOMAIN}&sid=${REALITY_SHORT_ID}&spx=%2F&fp=chrome#VLESS-Reality"
                    printf "  ${C_BOLD}Reality 公钥 (PublicKey):${C_RESET} ${C_GREEN}%s${C_RESET}\n" "${REALITY_PUBKEY}"
                    printf "  ${C_BOLD}ShortId                 :${C_RESET} ${C_GREEN}%s${C_RESET}\n" "${REALITY_SHORT_ID}"
                    printf "\n${C_BOLD}🔗 通用导入链接 (VLESS Reality):${C_RESET}\n"
                    printf "${C_GREEN}%s${C_RESET}\n\n" "${VLESS_URL}"
                elif [ "$ACTIVE_PROTO" = "AnyTLS" ]; then
                    printf "${C_BOLD}ℹ️  AnyTLS 协议参数:${C_RESET}\n"
                    printf "  Server: %s | Port: %s | Password: %s | SNI: %s | ALPN: h2,http/1.1\n\n" "${ACTIVE_DOMAIN}" "${ACTIVE_PORT}" "${ACTIVE_PASSWORD}" "${ACTIVE_DOMAIN}"
                fi

                printf "${C_CYAN}----------------------------------------------------------${C_RESET}\n"
                printf "配置文件路径: ${C_YELLOW}%s${C_RESET}\n" "${CONF_FILE}"
            fi

            printf "\n${C_CYAN}按 [Enter] 键返回管理面板...${C_RESET}"
            ui_read DUMMY
            ;;

        3)
            # 3. 查看运行日志
            clear 2>/dev/null || true
            ui_banner "查看系统与节点运行日志"

            printf " ${C_BOLD}请选择要查看的日志类型：${C_RESET}\n"
            printf "  ${C_CYAN}1)${C_RESET} sing-box 最新 50 行日志\n"
            printf "  ${C_CYAN}2)${C_RESET} sing-box 实时跟踪日志 (Ctrl+C 停止)\n"
            printf "  ${C_CYAN}3)${C_RESET} Nginx 错误日志\n"
            printf "  ${C_CYAN}4)${C_RESET} acme.sh 证书申请/续订日志\n"
            printf "  ${C_CYAN}0)${C_RESET} 返回上一级\n\n"
            printf " ${C_CYAN}?${C_RESET} 请输入选项 [0-4]: "
            ui_read LOG_CHOICE
            LOG_CHOICE=$(echo "$LOG_CHOICE" | tr -d '[:space:]')

            case "$LOG_CHOICE" in
                1)
                    printf "\n${C_BOLD}>>> sing-box 最新 50 行日志：${C_RESET}\n\n"
                    if command -v journalctl >/dev/null 2>&1; then
                        journalctl -u sing-box -n 50 --no-pager 2>/dev/null || true
                    elif [ -f /var/log/sing-box.log ]; then
                        tail -n 50 /var/log/sing-box.log
                    else
                        printf "${C_YELLOW}未找到 sing-box 日志文件或 journalctl 记录。${C_RESET}\n"
                    fi
                    ;;
                2)
                    printf "\n${C_BOLD}>>> 正在实时跟踪 sing-box 日志 (按 Ctrl+C 退出)...${C_RESET}\n\n"
                    if command -v journalctl >/dev/null 2>&1; then
                        journalctl -u sing-box -f 2>/dev/null || true
                    elif [ -f /var/log/sing-box.log ]; then
                        tail -f /var/log/sing-box.log
                    fi
                    ;;
                3)
                    printf "\n${C_BOLD}>>> Nginx 错误日志：${C_RESET}\n\n"
                    if [ -f /var/log/nginx/error.log ]; then
                        tail -n 50 /var/log/nginx/error.log
                    elif command -v journalctl >/dev/null 2>&1; then
                        journalctl -u nginx -n 50 --no-pager 2>/dev/null || true
                    else
                        printf "${C_YELLOW}未找到 Nginx 错误日志。${C_RESET}\n"
                    fi
                    ;;
                4)
                    printf "\n${C_BOLD}>>> acme.sh 日志：${C_RESET}\n\n"
                    ACME_LOG="${HOME:-/root}/.acme.sh/acme.sh.log"
                    if [ -f "$ACME_LOG" ]; then
                        tail -n 50 "$ACME_LOG"
                    else
                        printf "${C_YELLOW}未找到 acme.sh 日志文件。${C_RESET}\n"
                    fi
                    ;;
                *)
                    ;;
            esac

            printf "\n${C_CYAN}按 [Enter] 键返回管理面板...${C_RESET}"
            ui_read DUMMY
            ;;

        4)
            # 4. 服务启停控制
            clear 2>/dev/null || true
            ui_banner "代理服务控制 (sing-box & Nginx)"

            printf " ${C_BOLD}请选择服务控制操作：${C_RESET}\n"
            printf "  ${C_CYAN}1)${C_RESET} 🔄 重启 sing-box 服务\n"
            printf "  ${C_CYAN}2)${C_RESET} ▶️  启动 sing-box 服务\n"
            printf "  ${C_CYAN}3)${C_RESET} ⏹️  停止 sing-box 服务\n"
            printf "  ${C_CYAN}4)${C_RESET} 🌐 重启 Nginx 服务\n"
            printf "  ${C_CYAN}0)${C_RESET} 返回上一级\n\n"
            printf " ${C_CYAN}?${C_RESET} 请输入选项 [0-4]: "
            ui_read SVC_CHOICE
            SVC_CHOICE=$(echo "$SVC_CHOICE" | tr -d '[:space:]')

            if [ "$SVC_CHOICE" = "1" ]; then
                ui_info "正在重启 sing-box..."
                if command -v systemctl >/dev/null 2>&1; then
                    systemctl restart sing-box 2>/dev/null || true
                elif command -v rc-service >/dev/null 2>&1; then
                    rc-service sing-box restart 2>/dev/null || true
                fi
                sleep 1
                ui_success "sing-box 重启命令已执行"
            elif [ "$SVC_CHOICE" = "2" ]; then
                ui_info "正在启动 sing-box..."
                if command -v systemctl >/dev/null 2>&1; then
                    systemctl start sing-box 2>/dev/null || true
                elif command -v rc-service >/dev/null 2>&1; then
                    rc-service sing-box start 2>/dev/null || true
                fi
                sleep 1
                ui_success "sing-box 启动命令已执行"
            elif [ "$SVC_CHOICE" = "3" ]; then
                ui_info "正在停止 sing-box..."
                if command -v systemctl >/dev/null 2>&1; then
                    systemctl stop sing-box 2>/dev/null || true
                elif command -v rc-service >/dev/null 2>&1; then
                    rc-service sing-box stop 2>/dev/null || true
                fi
                pkill -9 sing-box 2>/dev/null || true
                ui_success "sing-box 已停止"
            elif [ "$SVC_CHOICE" = "4" ]; then
                ui_info "正在重启 Nginx..."
                if command -v systemctl >/dev/null 2>&1; then
                    systemctl restart nginx 2>/dev/null || true
                elif command -v rc-service >/dev/null 2>&1; then
                    rc-service nginx restart 2>/dev/null || true
                fi
                ui_success "Nginx 重启命令已执行"
            fi

            printf "\n${C_CYAN}按 [Enter] 键返回管理面板...${C_RESET}"
            ui_read DUMMY
            ;;

        5)
            # 5. 证书状态与手动续签
            clear 2>/dev/null || true
            ui_banner "SSL 证书状态诊断与手动续期"
            detect_system_status

            CERT_FILE="$CERT_DIR/server.crt"
            printf "${C_BOLD}📜 SSL 证书详情：${C_RESET}\n"
            printf "  ● 证书文件路径 : %s\n" "$CERT_FILE"
            if [ -s "$CERT_FILE" ] && command -v openssl >/dev/null 2>&1; then
                printf "  ● 证书绑定域名 : %s\n" "${CERT_DOMAIN:-未知}"
                printf "  ● 证书生效起止 : %s\n" "${CERT_EXPIRY:-未知}"
                printf "  ● 剩余有效期   : %s\n" "${CERT_DAYS_LEFT}"
                printf "  ● 证书颁发机构 : %s\n" "$(openssl x509 -noout -issuer -in "$CERT_FILE" 2>/dev/null | sed 's/issuer= //')"
            else
                printf "  ● 证书文件状态 : ${C_YELLOW}未找到证书文件或证书为空${C_RESET}\n"
            fi

            printf "\n${C_BOLD}⚙️  acme.sh 状态：${C_RESET}\n"
            printf "  ● acme.sh 安装 : %s\n" "$( [ "$ACME_INSTALLED" -eq 1 ] && echo "${C_GREEN}已安装${C_RESET}" || echo "${C_GRAY}未安装${C_RESET}" )"
            printf "  ● 自动续签任务 : %s\n" "$( [ "$ACME_CRON" -eq 1 ] && echo "${C_GREEN}已配置 crontab 计划任务${C_RESET}" || echo "${C_YELLOW}未配置${C_RESET}" )"

            if [ "$ACME_INSTALLED" -eq 1 ] && [ -n "$ACTIVE_DOMAIN" ] && [ "$ACTIVE_DOMAIN" != "未知" ]; then
                printf "\n${C_CYAN}?${C_RESET} 是否立即尝试强制测试续签证书？[y/N]: "
                ui_read RENEW_CHOICE
                RENEW_CHOICE=$(echo "$RENEW_CHOICE" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
                if [ "$RENEW_CHOICE" = "y" ] || [ "$RENEW_CHOICE" = "yes" ]; then
                    ui_info "正在调用 acme.sh 执行强制续签..."
                    ACME_BIN="${HOME:-/root}/.acme.sh/acme.sh"
                    if "$ACME_BIN" --renew -d "$ACTIVE_DOMAIN" --force --ecc; then
                        ui_success "证书强制续签成功！"
                        ui_info "正在重新分发证书到 sing-box..."
                        "$ACME_BIN" --install-cert -d "$ACTIVE_DOMAIN" --ecc \
                            --fullchain-file "$CERT_DIR/server.crt" \
                            --key-file "$CERT_DIR/server.key" 2>/dev/null || true
                        
                        # 顺便重载服务
                        if command -v systemctl >/dev/null 2>&1; then
                            systemctl restart sing-box 2>/dev/null || true
                        elif command -v rc-service >/dev/null 2>&1; then
                            rc-service sing-box restart 2>/dev/null || true
                        fi
                        ui_success "证书已更新并重启 sing-box 服务"
                    else
                        ui_error "续签失败，请检查 Cloudflare 认证凭证或日志！"
                    fi
                fi
            fi

            printf "\n${C_CYAN}按 [Enter] 键返回管理面板...${C_RESET}"
            ui_read DUMMY
            ;;

        6)
            # 6. 一键完全卸载与清除环境
            clear 2>/dev/null || true
            do_uninstall
            if [ -n "$SERVER_URL" ]; then
                printf "\n${C_CYAN}?${C_RESET} 按回车键返回主引导菜单，或输入 q 退出 [默认: 回车]: "
                ui_read RET_MENU
                RET_MENU=$(echo "$RET_MENU" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
                if [ "$RET_MENU" != "q" ]; then
                    if [ "$ROOT_MENU_ACTIVE" = "1" ]; then
                        exit 0
                    fi
                    clear 2>/dev/null || true
                    curl -fsSL "${SERVER_URL}/" | sh
                    exit 0
                fi
            fi
            exit 0
            ;;

        0)
            # 0. 返回主引导菜单
            if [ "$ROOT_MENU_ACTIVE" = "1" ]; then
                exit 0
            fi
            if [ -n "$SERVER_URL" ]; then
                ui_info "正在返回主引导菜单..."
                clear 2>/dev/null || true
                curl -fsSL "${SERVER_URL}/" | sh
            fi
            exit 0
            ;;

        q|exit)
            # q. 退出
            printf "\n${C_GREEN}👋 已退出维护管理面板。${C_RESET}\n\n"
            exit 0
            ;;

        *)
            ui_warn "无效选项，请重新选择！"
            sleep 1
            ;;
    esac
done
