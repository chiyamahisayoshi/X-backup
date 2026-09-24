#!/usr/bin/env bash
set -Eeuo pipefail

readonly SERVICE="XrayR"
readonly BINARY="/usr/local/XrayR/XrayR"
readonly RAW_INSTALLER="https://raw.githubusercontent.com/chiyamahisayoshi/X-backup/master/install.sh"
readonly RAW_MANAGER="https://raw.githubusercontent.com/chiyamahisayoshi/X-backup/master/XrayR.sh"
readonly DEFAULT_VERSION="0.9.4"

require_root() {
    [[ "${EUID}" -eq 0 ]] || { echo "错误：请使用 root 运行此命令。" >&2; exit 1; }
}

require_systemd() {
    command -v systemctl >/dev/null 2>&1 || { echo "错误：未找到 systemctl。" >&2; exit 1; }
}

show_menu() {
    cat <<'EOF'
========== XrayR 管理菜单 ==========
0. 修改配置
1. 安装 XrayR
2. 更新 XrayR
3. 卸载 XrayR
4. 启动 XrayR
5. 停止 XrayR
6. 重启 XrayR
7. 查看状态
8. 查看日志
9. 设置开机自启
10. 取消开机自启
11. BBR（仅查看状态，不自动修改）
12. 查看版本
13. 升级维护脚本
q. 退出
EOF
}

show_service_summary() {
    local service_state="未运行"
    local boot_state="未设置"
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet "$SERVICE"; then
            service_state="运行中"
        fi
        if systemctl is-enabled --quiet "$SERVICE" 2>/dev/null; then
            boot_state="已启用"
        fi
    fi
    echo
    echo "当前状态：${service_state}"
    echo "开机自启：${boot_state}"
    echo
}

download_file() {
    local url="$1" output="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 --output "$output" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$output" "$url"
    else
        echo "错误：需要 curl 或 wget。" >&2
        return 1
    fi
}

edit_config() {
    local editor="${EDITOR:-nano}"
    [[ -f /etc/XrayR/config.yml ]] || { echo "错误：配置文件不存在，请先安装 XrayR。" >&2; return 1; }
    command -v "$editor" >/dev/null 2>&1 || editor=vi
    command -v "$editor" >/dev/null 2>&1 || { echo "错误：未找到 nano 或 vi。" >&2; return 1; }
    require_root
    "$editor" /etc/XrayR/config.yml
    echo "配置编辑完成。"
}

install_xrayr() {
    require_root
    local installer
    installer="$(mktemp)"
    trap 'rm -f "$installer"' RETURN
    download_file "$RAW_INSTALLER" "$installer"
    chmod 0755 "$installer"
    "$installer" "$DEFAULT_VERSION"
    echo "XrayR 安装完成。"
}

update_xrayr() {
    require_root
    local installer
    installer="$(mktemp)"
    trap 'rm -f "$installer"' RETURN
    download_file "$RAW_INSTALLER" "$installer"
    chmod 0755 "$installer"
    "$installer" "${1:-$DEFAULT_VERSION}"
    echo "XrayR 更新完成。"
}

update_manager() {
    require_root
    local manager
    manager="$(mktemp)"
    trap 'rm -f "$manager"' RETURN
    download_file "$RAW_MANAGER" "$manager"
    grep -q '^#!/usr/bin/env bash$' "$manager" ||
        { echo "错误：维护脚本校验失败。" >&2; return 1; }
    chmod 0755 "$manager"
    install -m 0755 "$manager" /usr/local/bin/XrayR
    echo "维护脚本升级完成。"
}

run_command() {
    local command="$1"
    case "$command" in
    config) edit_config ;;
    install) install_xrayr ;;
    update) update_xrayr "${2:-$DEFAULT_VERSION}" ;;
    uninstall)
        require_root; require_systemd
        systemctl disable --now "$SERVICE" >/dev/null 2>&1 || true
        rm -f /etc/systemd/system/XrayR.service /usr/local/bin/XrayR /usr/bin/XrayR /usr/bin/xrayr
        rm -rf /usr/local/XrayR /etc/XrayR
        systemctl daemon-reload
        echo "XrayR 已卸载；配置和程序目录已删除。"
        ;;
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
        require_systemd
        echo "XrayR 日志跟踪中，按 Ctrl+C 停止跟踪并退出..."
        journalctl -u XrayR.service -e --no-pager -f
        ;;
    version)
        [[ -x "$BINARY" ]] || { echo "错误：XrayR 尚未安装。" >&2; exit 1; }
        echo "XrayR 版本："
        "$BINARY" version
        ;;
    enable)
        require_root; require_systemd; systemctl enable "$SERVICE"
        echo "XrayR 已设置为开机自启。"
        ;;
    disable)
        require_root; require_systemd; systemctl disable "$SERVICE"
        echo "XrayR 已取消开机自启。"
        ;;
    bbr)
        if [[ -r /proc/sys/net/ipv4/tcp_congestion_control ]]; then
            echo "当前拥塞控制算法：$(cat /proc/sys/net/ipv4/tcp_congestion_control)"
        else
            echo "当前系统不支持读取 BBR 状态。"
        fi
        echo "BBR 菜单项仅查看状态，不会自动修改系统内核参数。"
        ;;
    manager-update) update_manager ;;
    *)
        return 2
        ;;
    esac
}

if [[ $# -eq 0 ]]; then
    show_menu
    show_service_summary
    read -r -p "请选择操作 [0-13/q]： " choice
    case "$choice" in
        0) run_command config ;;
        1) run_command install ;;
        2) run_command update ;;
        3) run_command uninstall ;;
        4) run_command start ;;
        5) run_command stop ;;
        6) run_command restart ;;
        7) run_command status ;;
        8) run_command log ;;
        9) run_command enable ;;
        10) run_command disable ;;
        11) run_command bbr ;;
        12) run_command version ;;
        13) run_command manager-update ;;
        q|Q) echo "已退出。" ;;
        *) echo "无效选择，请运行 XrayR 查看菜单。" >&2; exit 2 ;;
    esac
else
    case "$1" in
        config|install|update|uninstall|start|stop|restart|status|log|enable|disable|bbr|version|manager-update)
            run_command "$1" "${2:-$DEFAULT_VERSION}" ;;
        *) echo "用法：$0 {config|install|update|uninstall|start|stop|restart|status|log|enable|disable|bbr|version|manager-update}" >&2; exit 2 ;;
    esac
fi
