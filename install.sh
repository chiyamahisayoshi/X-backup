#!/usr/bin/env bash
set -Eeuo pipefail

readonly DEFAULT_VERSION="0.9.6"
readonly REPOSITORY="chiyamahisayoshi/X-backup"
readonly INSTALL_DIR="/usr/local/XrayR"
readonly CONFIG_DIR="/etc/XrayR"
readonly SERVICE_FILE="/etc/systemd/system/XrayR.service"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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

config_source="${SCRIPT_DIR}/config"
if [[ ! -f "${config_source}/config.yml" ]]; then
    echo "错误：缺少 ${config_source}/config.yml。" >&2
    echo "请先上传或填写自己的配置；密钥不得提交到 Git。" >&2
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
cp -f "${SCRIPT_DIR}/XrayR.sh" "${staged_install}/XrayR.sh"
cp -f "${SCRIPT_DIR}/install.sh" "${staged_install}/install.sh"
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
install -m 0644 "${SCRIPT_DIR}/XrayR.service" "$SERVICE_FILE"
install -m 0755 "${SCRIPT_DIR}/XrayR.sh" /usr/local/bin/XrayR
ln -sfn /usr/local/bin/XrayR /usr/bin/XrayR

systemctl daemon-reload
systemctl enable XrayR
if [[ -e "$backup_dir" ]]; then
    rm -rf -- "$backup_dir"
fi
echo "XrayR ${version} 安装完成。配置文件：${CONFIG_DIR}/config.yml"
echo "使用 'XrayR start' 启动服务。"
