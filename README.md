# DeepSeek Harness 桌面版 · Windows x64 归档

本仓库归档 **DeepSeek Harness 桌面版（Windows x64）官方安装包**。官方每发布新版本，这里就会新增一个 Release。

> ⚠️ 本仓库**不是** DeepSeek 官方仓库，仅作官方安装包的搬运与归档。
> 安装包版权归杭州深度求索人工智能基础技术研究有限公司所有，请以官方下载页为准。

## 下载最新版

**最新版本：`0.2.0-rc.2`**

| 项目 | 值 |
| --- | --- |
| 平台 | Windows x64 |
| 文件名 | `deepseek-harness-0.2.0-rc.2-win-x64.exe` |
| 大小 | 289,313,640 字节（275.9 MiB） |

永久直链（始终指向最新 Release）：

```
https://github.com/Britripe/deepseek-harness-desktop/releases/latest/download/deepseek-harness-0.2.0-rc.2-win-x64.exe
```

所有历史版本见 [Releases](https://github.com/Britripe/deepseek-harness-desktop/releases)。

## 官方来源

- 官方下载页：<https://www.deepseek.com/download/>
- Windows x64 官方直链：<https://download.deepseek.com/desktop/dsh-latest-windows-x64.exe>
- 官方桌面端更新源：<https://download.deepseek.com/dsh-desk/feeds/win-x64/nightly.yml>

本仓库中的安装包与上述官方地址提供的文件**字节完全一致**，可通过下方校验值自行验证。

## 校验值

`0.2.0-rc.2` / `deepseek-harness-0.2.0-rc.2-win-x64.exe`

```
大小  289313640
MD5   7754925fe3c4542123eca76c0e11076e
SHA256 d61cd8882f8b8a1251144320493ad27920d15139503eba2465b9579eee720cfc
SHA512(base64) raIlxMQd9ESXgktmViW7QwVLcjBR5JIsrNOu+SpelY8kskdSr2H51/f+ey1EqFI/eIIrKQCuRANMeb5SptRZcg==
```

PowerShell 校验：

```powershell
Get-FileHash .\deepseek-harness-0.2.0-rc.2-win-x64.exe -Algorithm SHA256
```

## 更新流程

仓库内的 [`release.ps1`](release.ps1) 负责后续版本的同步：它会读取官方更新源，比较已发布的版本，
若有新版本则下载、校验 sha512、创建 Release 并上传安装包。

```powershell
$env:GH_TOKEN = '<你的 GitHub Token>'
pwsh -File .\release.ps1
```

## 版本记录

| 版本 | 发布日期 | 安装包 | 大小 |
| --- | --- | --- | --- |
| 0.2.0-rc.2 | 2026-09-29 | `deepseek-harness-0.2.0-rc.2-win-x64.exe` | 275.9 MiB |
