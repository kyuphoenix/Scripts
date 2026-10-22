#!/bin/sh
set -e

# 终端 ANSI 颜色定义 (兼容 POSIX sh / BusyBox ash)
if [ -t 1 ]; then
    C_RESET="\033[0m"
    C_BOLD="\033[1m"
    C_RED="\033[31m"
    C_GREEN="\033[32m"
    C_YELLOW="\033[33m"
    C_BLUE="\033[34m"
    C_CYAN="\033[36m"
    C_GRAY="\033[90m"
else
    C_RESET=""
    C_BOLD=""
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_CYAN=""
    C_GRAY=""
fi

# 基础目录与常量
INSTALL_DIR="/usr/local/bin"
CONF_DIR="/etc/sing-box"
CERT_DIR="/etc/sing-box/cert"
WORK_DIR="/root/sb_download_cache"

# 异常退出与清理 Trap
on_exit() {
    rm -rf "$WORK_DIR" 2>/dev/null || true
}

on_interrupt() {
    on_exit
    printf "\n${C_RED}❌ 用户已取消操作，安装退出。${C_RESET}\n" >&2
    exit 130
}

trap on_exit EXIT
trap on_interrupt INT TERM

# 安全的交互输入读取函数 (支持直接运行或 curl 管道直连，绝不篡改标准输入流)
ui_read() {
    if [ -r /dev/tty ]; then
        read -r "$@" < /dev/tty
    else
        read -r "$@"
    fi
}

# 交互式输出辅助函数
ui_banner() {
    clear 2>/dev/null || true
    printf "${C_CYAN}${C_BOLD}"
    printf "==========================================================\n"
    printf "    %s\n" "$1"
    printf "==========================================================\n"
    printf "${C_RESET}\n"
}

ui_step() {
    printf "\n${C_BOLD}${C_BLUE}>>> [%s] %s${C_RESET}\n" "$1" "$2"
}

ui_info() {
    printf "  ${C_GRAY}➜${C_RESET} %s\n" "$1"
}

ui_success() {
    printf "  ${C_GREEN}✔ %s${C_RESET}\n" "$1"
}

ui_warn() {
    printf "  ${C_YELLOW}⚠️  %s${C_RESET}\n" "$1"
}

ui_error() {
    printf "  ${C_RED}❌ %s${C_RESET}\n" "$1"
}
