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

case "${1:-}" in
    start)
        require_root; require_systemd; systemctl start "$SERVICE"
        ;;
    stop)
        require_root; require_systemd; systemctl stop "$SERVICE"
        ;;
    restart)
        require_root; require_systemd; systemctl restart "$SERVICE"
        ;;
    status)
        require_systemd; systemctl status "$SERVICE" --no-pager -l
        ;;
    log)
        require_systemd; journalctl -u "$SERVICE" --no-pager -e
        ;;
    version)
        [[ -x "$BINARY" ]] || { echo "错误：XrayR 尚未安装。" >&2; exit 1; }
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
        echo "用法：$0 {start|stop|restart|status|log|version|uninstall|update [版本]}"
        exit 2
        ;;
esac
