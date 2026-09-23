#!/usr/bin/env bash
set -Eeuo pipefail

readonly SERVICE="XrayR"
readonly BINARY="/usr/local/XrayR/XrayR"
readonly LOCAL_INSTALLER="/usr/local/XrayR/install.sh"
readonly RAW_INSTALLER="https://raw.githubusercontent.com/chiyamahisayoshi/X-backup/master/install.sh"

require_root() {
    [[ "${EUID}" -eq 0 ]] || { echo "错误：请使用 root 运行此命令。" >&2; exit 1; }
}

require_systemd() {
    command -v systemctl >/dev/null 2>&1 || { echo "错误：未找到 systemctl。" >&2; exit 1; }
}

show_menu() {
    cat <<'EOF'
XrayR 管理菜单
1) 启动
2) 停止
3) 重启
4) 状态
5) 日志
6) 版本
7) 卸载
q) 退出
EOF
}

run_command() {
    local command="$1"
    case "$command" in
    start)
        require_root; require_systemd
        systemctl start "$SERVICE"
        if systemctl is-active --quiet "$SERVICE"; then
            echo "XrayR 启动成功。"
        else
            echo "XrayR 启动失败，请运行：sudo XrayR log" >&2
            return 1
        fi
        ;;
    stop)
        require_root; require_systemd; systemctl stop "$SERVICE"
        echo "XrayR 已停止。"
        ;;
    restart)
        require_root; require_systemd
        systemctl restart "$SERVICE"
        if systemctl is-active --quiet "$SERVICE"; then
            echo "XrayR 重启成功。"
        else
            echo "XrayR 重启失败，请运行：sudo XrayR log" >&2
            return 1
        fi
        ;;
    status)
        require_systemd
        if systemctl is-active --quiet "$SERVICE"; then
            echo "XrayR 当前状态：运行中。"
        else
            echo "XrayR 当前状态：未运行。"
            return 1
        fi
        systemctl status "$SERVICE" --no-pager -l
        ;;
    log)
        require_systemd; echo "XrayR 最近日志："; journalctl -u "$SERVICE" --no-pager -e
        ;;
    version)
        [[ -x "$BINARY" ]] || { echo "错误：XrayR 尚未安装。" >&2; exit 1; }
        echo "XrayR 版本："
        "$BINARY" version
        ;;
    uninstall)
        require_root; require_systemd
        systemctl disable --now "$SERVICE" >/dev/null 2>&1 || true
        rm -f /etc/systemd/system/XrayR.service /usr/local/bin/XrayR /usr/bin/XrayR
        rm -rf /usr/local/XrayR /etc/XrayR
        systemctl daemon-reload
        echo "XrayR 已卸载；配置和程序目录已删除。"
        ;;
    update)
        require_root
        installer="$LOCAL_INSTALLER"
        if [[ ! -x "$installer" ]]; then
            installer="$(mktemp)"
            trap 'rm -f "$installer"' EXIT
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL --output "$installer" "$RAW_INSTALLER"
            else
                wget -q -O "$installer" "$RAW_INSTALLER"
            fi
            chmod 0755 "$installer"
        fi
        "$installer" "${2:-0.9.6}"
        ;;
    *)
        return 2
        ;;
    esac
}

if [[ $# -eq 0 ]]; then
    show_menu
    read -r -p "请选择操作 [1-7/q]： " choice
    case "$choice" in
        1) run_command start ;;
        2) run_command stop ;;
        3) run_command restart ;;
        4) run_command status ;;
        5) run_command log ;;
        6) run_command version ;;
        7) run_command uninstall ;;
        q|Q) echo "已退出。" ;;
        *) echo "无效选择，请运行 XrayR 查看菜单。" >&2; exit 2 ;;
    esac
else
    case "$1" in
        start|stop|restart|status|log|version|uninstall) run_command "$1" ;;
        update) run_command update "${2:-0.9.6}" ;;
        *) echo "用法：$0 {start|stop|restart|status|log|version|uninstall|update [版本]}" >&2; exit 2 ;;
    esac
fi
