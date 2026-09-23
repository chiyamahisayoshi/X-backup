# XrayR 0.9.6 安装脚本

本仓库只提供 Debian/Ubuntu（尽量兼容 CentOS）的安装基础文件，不包含
XrayR 主程序二进制或任何真实配置、密钥。

## 使用前准备

1. 在本仓库创建 GitHub Release **v0.9.6**。
2. 上传 `XrayR-linux-64.zip`（x86_64）和 `XrayR-linux-arm64-v8a.zip`（aarch64）。
   ZIP 必须包含名为 `XrayR` 的可执行文件。
3. 将自己的配置填写或上传到脚本所在目录的 `config/config.yml`。安装器找不到该文件
   会明确停止，不会从第三方仓库下载配置。密钥、证书和真实配置不得提交到 Git。

## 安装

```bash
chmod +x install.sh
sudo ./install.sh                 # 默认 0.9.6
sudo ./install.sh 0.9.6           # 指定版本
```

安装器会严格校验下载和 ZIP 内容，在临时目录完成下载和解压后才替换旧程序；
安装的服务使用 `/usr/local/XrayR/XrayR --config /etc/XrayR/config.yml`。

## 管理命令

```text
XrayR start|stop|restart|status|log|version|uninstall
XrayR update [版本]
```

`update` 优先调用安装目录中保存的 `install.sh`，找不到时才使用本仓库公开的
`master` 分支 raw 地址。服务日志可用 `XrayR log` 查看。

## 许可

脚本按仓库中的 MPL-2.0 文本发布。XrayR 主程序由其上游项目按其许可证发布，
请在分发 Release 资产时同时遵守上游许可证。
