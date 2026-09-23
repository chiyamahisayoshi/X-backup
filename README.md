# XrayR 安装仓库

这是一个不包含 XrayR 主程序二进制的安装仓库。安装器默认安装
**XrayR 0.9.6**，支持 `x86_64` 和 `aarch64` Linux。仓库中的 `config/`
目录保存 VPS 备份的安装配置。

## 给新手的安装步骤

### 1. 准备 Release

在本仓库创建 GitHub Release `v0.9.6`，并上传以下两个资产（文件名必须完全一致）：

```text
XrayR-linux-64.zip
XrayR-linux-arm64-v8a.zip
```

每个 ZIP 都必须包含一个名为 `XrayR` 的可执行文件。不要把二进制文件提交到
Git 仓库。

### 2. 检查配置备份

安装器会从公开仓库下载下面 8 个文件到服务器的 `/etc/XrayR/`：

```text
config.yml
custom_inbound.json
custom_outbound.json
geoip.dat
geosite.dat
dns.json
route.json
rulelist
```

这 8 个文件都必须存在且非空；任何文件在公开仓库中缺失时，安装器会明确报错并
停止，不会改用模板，也不会从第三方下载 geodata。请在发布前确认备份中的密钥、
证书和节点信息符合你的部署需求。

### 3. 一条命令安装

在目标 Linux 服务器执行（需要 root 权限）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/chiyamahisayoshi/X-backup/master/install.sh)
```

如果没有 `curl`，也可以先下载脚本再执行：

```bash
wget -O install.sh https://raw.githubusercontent.com/chiyamahisayoshi/X-backup/master/install.sh
sudo bash install.sh
```

安装器会按服务器架构下载对应 Release，检查 ZIP 内容后安装到
`/usr/local/XrayR/`，并把上述 8 个文件放到 `/etc/XrayR/`。安装完成后启动服务：

```bash
sudo XrayR start
sudo XrayR status
```

### 4. 日常管理

直接运行 `XrayR` 会显示完整管理菜单：

```text
0 修改配置
1 安装 XrayR
2 更新 XrayR
3 卸载 XrayR
4 启动 XrayR
5 停止 XrayR
6 重启 XrayR
7 状态
8 日志
9 开机自启
10 取消自启
11 BBR（仅查看状态，不自动修改）
12 版本
13 升级维护脚本
```

菜单中的更新和维护脚本升级只从本仓库 `master` 获取，不使用第三方地址。

也可以直接使用命令：

```text
sudo XrayR start
sudo XrayR stop
sudo XrayR restart
XrayR status
XrayR log
XrayR version
sudo XrayR update [版本]
sudo XrayR uninstall
```

`update` 默认仍使用 0.9.6，并会重新从本仓库 `master/config/` 取得全部 8 个文件。

## 文件说明

仓库只保留一份 `install.sh`、`XrayR.sh` 和 `XrayR.service`，以及安装所需的
`config/` 8 个备份文件。服务使用 `/usr/local/XrayR/XrayR --config
/etc/XrayR/config.yml` 启动。

## 许可

脚本按仓库中的 MPL-2.0 文本发布。XrayR 主程序由上游项目按其许可证发布，分发
Release 资产时请同时遵守上游许可证。
