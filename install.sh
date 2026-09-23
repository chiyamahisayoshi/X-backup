#!/usr/bin/env bash
set -Eeuo pipefail

readonly DEFAULT_VERSION="0.9.6"
readonly REPOSITORY="chiyamahisayoshi/X-backup"
readonly RAW_BASE="https://raw.githubusercontent.com/${REPOSITORY}/master"
readonly INSTALL_DIR="/usr/local/XrayR"
readonly CONFIG_DIR="/etc/XrayR"
readonly SERVICE_FILE="/etc/systemd/system/XrayR.service"
readonly CONFIG_FILES=(
    config.yml
    custom_inbound.json
    custom_outbound.json
    geoip.dat
    geosite.dat
    dns.json
    route.json
    rulelist
)
readonly SUPPORT_FILES=(
    install.sh
    XrayR.sh
    XrayR.service
)

version="${1:-$DEFAULT_VERSION}"
version="${version#v}"
if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
    echo "错误：版本必须是类似 0.9.6 的数字版本。" >&2
    exit 2
fi

if [[ "${EUID}" -ne 0 ]]; then
    echo "错误：请使用 root 运行此脚本。" >&2
    exit 1
fi

case "$(uname -m)" in
    x86_64) asset_arch="64" ;;
    aarch64) asset_arch="arm64-v8a" ;;
    *)
        echo "错误：不支持的架构 $(uname -m)，仅支持 x86_64 和 aarch64。" >&2
        exit 1
        ;;
esac

if ! command -v systemctl >/dev/null 2>&1; then
    echo "错误：未找到 systemd/systemctl，无法安装服务。" >&2
    exit 1
fi

install_packages() {
    local missing=()
    command -v unzip >/dev/null 2>&1 || missing+=(unzip)
    command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || missing+=(curl)
    ((${#missing[@]} == 0)) && return 0

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y "${missing[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "${missing[@]}"
    elif command -v yum >/dev/null 2>&1; then
        yum install -y "${missing[@]}"
    else
        echo "错误：缺少 ${missing[*]}，且未找到 apt-get/dnf/yum。" >&2
        exit 1
    fi
}

download() {
    local url="$1" output="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 --output "$output" "$url"
    else
        wget -q --show-progress -O "$output" "$url"
    fi
}

tmp_dir="$(mktemp -d)"
backup_dir="${INSTALL_DIR}.backup.$$"
cleanup() {
    local status=$?
    if [[ "$status" -ne 0 && -d "$backup_dir" && ! -e "$INSTALL_DIR" ]]; then
        mv -- "$backup_dir" "$INSTALL_DIR" || true
        echo "安装失败，已恢复旧版本。" >&2
    fi
    rm -rf -- "$tmp_dir"
    exit "$status"
}
trap cleanup EXIT

install_packages
config_source="${tmp_dir}/config"
mkdir -p "$config_source"
for config_file in "${CONFIG_FILES[@]}"; do
    destination="${config_source}/${config_file}"
    echo "下载配置 ${config_file}..."
    if ! download "${RAW_BASE}/config/${config_file}" "$destination"; then
        echo "错误：公开仓库缺少 config/${config_file}，安装已停止。" >&2
        exit 1
    fi
    [[ -s "$destination" ]] || {
        echo "错误：公开仓库中的 config/${config_file} 为空，安装已停止。" >&2
        exit 1
    }
done
support_source="${tmp_dir}/support"
mkdir -p "$support_source"
for support_file in "${SUPPORT_FILES[@]}"; do
    destination="${support_source}/${support_file}"
    echo "下载安装文件 ${support_file}..."
    if ! download "${RAW_BASE}/${support_file}" "$destination"; then
        echo "错误：公开仓库缺少 ${support_file}，安装已停止。" >&2
        exit 1
    fi
    [[ -s "$destination" ]] || {
        echo "错误：公开仓库中的 ${support_file} 为空，安装已停止。" >&2
        exit 1
    }
done
grep -q '^#!/usr/bin/env bash$' "${support_source}/install.sh" ||
    { echo "错误：下载的 install.sh 校验失败，安装已停止。" >&2; exit 1; }
grep -q '^#!/usr/bin/env bash$' "${support_source}/XrayR.sh" ||
    { echo "错误：下载的 XrayR.sh 校验失败，安装已停止。" >&2; exit 1; }
grep -q '^\[Unit\]$' "${support_source}/XrayR.service" ||
    { echo "错误：下载的 XrayR.service 校验失败，安装已停止。" >&2; exit 1; }

archive="${tmp_dir}/XrayR-linux-${asset_arch}.zip"
url="https://github.com/${REPOSITORY}/releases/download/v${version}/XrayR-linux-${asset_arch}.zip"
echo "下载 XrayR ${version} (${asset_arch})..."
download "$url" "$archive"
[[ -s "$archive" ]] || { echo "错误：下载文件为空。" >&2; exit 1; }
unzip -t "$archive" >/dev/null
unzip -Z1 "$archive" | awk -F/ '$NF == "XrayR" { found=1 } END { exit !found }' ||
    { echo "错误：ZIP 中未找到 XrayR 可执行文件。" >&2; exit 1; }

extract_dir="${tmp_dir}/extract"
mkdir -p "$extract_dir"
unzip -q "$archive" -d "$extract_dir"
binary="$(find "$extract_dir" -type f -name XrayR -print -quit)"
[[ -n "$binary" ]] || { echo "错误：无法定位 XrayR 可执行文件。" >&2; exit 1; }
chmod 0755 "$binary"
staged_install="${tmp_dir}/XrayR"
mkdir -p "$staged_install"
cp -f "$binary" "$staged_install/XrayR"
cp -f "${support_source}/XrayR.sh" "${staged_install}/XrayR.sh"
cp -f "${support_source}/install.sh" "${staged_install}/install.sh"
mkdir -p "${staged_install}/config"
cp -a "${config_source}/." "${staged_install}/config/"
chmod 0755 "${staged_install}/XrayR.sh" "${staged_install}/install.sh"

systemctl stop XrayR >/dev/null 2>&1 || true
if [[ -e "$INSTALL_DIR" ]]; then
    mv -- "$INSTALL_DIR" "$backup_dir"
fi
mv -- "$staged_install" "$INSTALL_DIR"

install -d -m 0755 "$CONFIG_DIR"
cp -a "${config_source}/." "$CONFIG_DIR/"
install -m 0644 "${support_source}/XrayR.service" "$SERVICE_FILE"
install -m 0755 "${support_source}/XrayR.sh" /usr/local/bin/XrayR
for command_link in /usr/bin/XrayR /usr/bin/xrayr; do
    if [[ -L "$command_link" ]]; then
        rm -f "$command_link"
    elif [[ -e "$command_link" ]]; then
        echo "警告：${command_link} 已存在且不是软链接，保留原文件。" >&2
        continue
    fi
    ln -s /usr/local/bin/XrayR "$command_link"
done

systemctl daemon-reload
systemctl enable XrayR
echo "正在启动 XrayR..."
systemctl start XrayR
if systemctl is-active --quiet XrayR; then
    echo "XrayR ${version} 启动成功。"
    echo "查看状态：sudo XrayR status"
else
    echo "错误：XrayR 启动失败。" >&2
    echo "请查看日志：sudo XrayR log" >&2
    exit 1
fi
if [[ -e "$backup_dir" ]]; then
    rm -rf -- "$backup_dir"
fi
echo "XrayR ${version} 安装完成。配置文件：${CONFIG_DIR}/config.yml"
echo "使用 'XrayR start' 启动服务。"
