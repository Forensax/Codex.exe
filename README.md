# ChatGPT Windows 安装包自动构建

这个仓库用于把 Microsoft Store 的 `OpenAI.Codex` MSIX 包重新封装为传统 Windows EXE 安装器和便携版，并通过 GitHub Actions 自动发布到 GitHub Release。

## 工作方式

- 每小时自动检查一次 `OpenAI.Codex` Retail x64 MSIX 是否有新版本。
- 如果 GitHub Release 中已经存在对应的 `v版本号`，说明没有新版本，本次 workflow 会正常停止。
- 如果发现新版本，会自动下载 MSIX、构建 EXE 安装包和 Portable ZIP、在 GitHub Actions 的 Windows runner 中做安装/卸载验证，然后创建 GitHub Release。
- 也可以在 Actions 页面手动运行 workflow，并在自动解析失败时填写 `msix_url`。

## 安装包策略

- Release 会同时输出 `ChatGPTSetup-x64-版本号.exe` 和 `ChatGPTPortable-x64-版本号.zip`。
- 安装器类型：传统 NSIS EXE。
- 安装范围：全机器安装，需要管理员权限。
- 默认安装目录：`%ProgramFiles%\ChatGPT`，不会迁移或删除已有的 `%ProgramFiles%\Codex`。
- 安装器图标：从 MSIX 根目录 `assets/` 中的多尺寸应用图标自动生成。
- 注册内容：开始菜单快捷方式、公共桌面快捷方式、卸载项、`codex:` 协议和 `.skill` 打开方式。
- `.skill` 只加入“打开方式”，不会强制修改默认程序。
- Portable ZIP：解压后运行 MSIX 清单指定的入口；当前版本为 `ChatGPT.exe`，不写注册表、不创建快捷方式、不注册协议或文件关联。
- 不注册 `.csv`、`.tsv`、`.xls`、`.xlsm`、`.xlsx` 文件关联。
- 压缩方式：`zlib`，在构建速度和安装包体积之间折中。
- 签名策略：当前安装器不签名，运行时可能出现 SmartScreen 或未知发布者提示。

## 常用操作

手动触发：

1. 打开 GitHub 仓库的 Actions 页面。
2. 选择 `构建 ChatGPT Windows 安装器`。
3. 点击 `Run workflow`。
4. 如果自动解析 MSIX 失败，在 `msix_url` 中填写 OpenAI.Codex x64 Retail MSIX 直链。

本地静态测试：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\packaging.tests.ps1
```

本机不会运行真实安装/卸载测试；真实安装验证只在 GitHub Actions 的 Windows runner 中执行。

## 注意事项

- `store.rg-adguard.net` 是第三方服务，不是 Microsoft 官方稳定 API，自动解析可能偶发失败。
- 重新分发 Microsoft Store/OpenAI 应用包前，请自行确认许可、品牌和再分发合规性。
- 后续更新通过新的 GitHub Release 分发，不保留 Microsoft Store 自动更新能力。
- 新旧传统版并排安装时，后安装的 ChatGPT 会接管 `codex:` 协议；之后卸载旧 Codex 可能删除该协议，重新运行 ChatGPT 安装器即可恢复。
