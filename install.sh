#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# ============================================================
# XrayR 自有备份安装脚本
# GitHub: https://github.com/chiyamahisayoshi/X-backup
# ============================================================

# 你的 GitHub 仓库
GITHUB_REPO="chiyamahisayoshi/X-backup"

# 固定 XrayR 版本
# 如果以后使用其他版本，只修改这里即可
XRAYR_VERSION="v0.9.0"

# GitHub Release 下载地址
RELEASE_URL="https://github.com/${GITHUB_REPO}/releases/download/${XRAYR_VERSION}"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系管理员！${plain}\n"
    exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"
echo "XrayR版本: ${XRAYR_VERSION}"
echo "备份仓库: https://github.com/${GITHUB_REPO}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ]; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi

if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n"
        exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n"
        exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n"
        exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi

    temp=$(systemctl status XrayR 2>/dev/null | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)

    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_XrayR() {

    echo -e "${green}开始安装 XrayR ${XRAYR_VERSION}${plain}"

    # 删除旧目录
    if [[ -e /usr/local/XrayR/ ]]; then
        rm -rf /usr/local/XrayR/
    fi

    mkdir -p /usr/local/XrayR/
    cd /usr/local/XrayR/

    # ========================================================
    # 从自己的 GitHub Release 下载 XrayR
    # ========================================================

    package_name="XrayR-linux-${arch}.zip"
    download_url="${RELEASE_URL}/${package_name}"

    echo -e "${yellow}正在从自己的 GitHub 下载：${package_name}${plain}"
    echo "下载地址：${download_url}"

    wget -q --no-check-certificate \
        -O "/usr/local/XrayR/XrayR-linux.zip" \
        "${download_url}"

    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 XrayR 失败！${plain}"
        echo ""
        echo "请确认你的 GitHub Release 中存在："
        echo "${package_name}"
        echo ""
        echo "Release："
        echo "${RELEASE_URL}"
        exit 1
    fi

    # 检查下载文件
    if [[ ! -s /usr/local/XrayR/XrayR-linux.zip ]]; then
        echo -e "${red}XrayR 安装包为空，安装终止！${plain}"
        exit 1
    fi

    # 解压
    unzip -o XrayR-linux.zip

    if [[ $? -ne 0 ]]; then
        echo -e "${red}解压 XrayR 失败！${plain}"
        exit 1
    fi

    rm -f XrayR-linux.zip

    chmod +x XrayR

    # ========================================================
    # 创建配置目录
    # ========================================================

    mkdir -p /etc/XrayR/

    # ========================================================
    # 使用自己的 XrayR.service
    # ========================================================

    rm -f /etc/systemd/system/XrayR.service

    service_url="https://raw.githubusercontent.com/${GITHUB_REPO}/master/XrayR.service"

    echo -e "${yellow}下载自己的 XrayR.service...${plain}"

    wget -q --no-check-certificate \
        -O /etc/systemd/system/XrayR.service \
        "${service_url}"

    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 XrayR.service 失败！${plain}"
        exit 1
    fi

    systemctl daemon-reload

    systemctl stop XrayR 2>/dev/null

    systemctl enable XrayR

    # ========================================================
    # 复制 XrayR 自带文件
    # ========================================================

    if [[ -f geoip.dat ]]; then
        cp -f geoip.dat /etc/XrayR/
    fi

    if [[ -f geosite.dat ]]; then
        cp -f geosite.dat /etc/XrayR/
    fi

    # ========================================================
    # 第一次安装：复制默认 config
    # ========================================================

    if [[ ! -f /etc/XrayR/config.yml ]]; then

        if [[ -f config.yml ]]; then
            cp -f config.yml /etc/XrayR/
        fi

        echo ""
        echo -e "${green}XrayR 全新安装完成！${plain}"
        echo "请先配置："
        echo "/etc/XrayR/config.yml"

    else

        # 已存在配置，直接启动
        systemctl start XrayR

        sleep 2

        check_status

        echo ""

        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR 启动成功${plain}"
        else
            echo -e "${red}XrayR 启动失败，请执行：XrayR log 查看日志${plain}"
        fi
    fi

    # ========================================================
    # 恢复其他配置文件
    # ========================================================

    if [[ ! -f /etc/XrayR/dns.json ]]; then
        if [[ -f dns.json ]]; then
            cp -f dns.json /etc/XrayR/
        fi
    fi

    if [[ ! -f /etc/XrayR/route.json ]]; then
        if [[ -f route.json ]]; then
            cp -f route.json /etc/XrayR/
        fi
    fi

    if [[ ! -f /etc/XrayR/custom_outbound.json ]]; then
        if [[ -f custom_outbound.json ]]; then
            cp -f custom_outbound.json /etc/XrayR/
        fi
    fi

    if [[ ! -f /etc/XrayR/custom_inbound.json ]]; then
        if [[ -f custom_inbound.json ]]; then
            cp -f custom_inbound.json /etc/XrayR/
        fi
    fi

    if [[ ! -f /etc/XrayR/rulelist ]]; then
        if [[ -f rulelist ]]; then
            cp -f rulelist /etc/XrayR/
        fi
    fi

    # ========================================================
    # 安装自己的 XrayR 管理脚本
    # ========================================================

    manager_url="https://raw.githubusercontent.com/${GITHUB_REPO}/master/XrayR.sh"

    echo -e "${yellow}安装自己的 XrayR 管理脚本...${plain}"

    curl -fsSL \
        -o /usr/bin/XrayR \
        "${manager_url}"

    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 XrayR 管理脚本失败！${plain}"
        exit 1
    fi

    chmod +x /usr/bin/XrayR

    # 小写兼容
    rm -f /usr/bin/xrayr
    ln -s /usr/bin/XrayR /usr/bin/xrayr
    chmod +x /usr/bin/xrayr

    cd "$cur_dir"

    # ========================================================
    # 安装完成
    # ========================================================

    echo ""
    echo -e "${green}========================================${plain}"
    echo -e "${green}XrayR ${XRAYR_VERSION} 安装完成${plain}"
    echo -e "${green}========================================${plain}"
    echo ""

    echo "XrayR 程序："
    echo "/usr/local/XrayR/XrayR"
    echo ""

    echo "XrayR 配置："
    echo "/etc/XrayR/"
    echo ""

    echo "管理命令："
    echo "XrayR"
    echo ""

    echo "常用命令："
    echo "XrayR start"
    echo "XrayR stop"
    echo "XrayR restart"
    echo "XrayR status"
    echo "XrayR log"
    echo "XrayR config"
    echo "XrayR version"
    echo ""

    echo -e "${green}已设置 XrayR 开机自启${plain}"
}

echo -e "${green}开始安装 XrayR${plain}"

install_base

# install_acme

install_XrayR "$1"
