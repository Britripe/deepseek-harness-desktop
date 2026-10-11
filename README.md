# DeepSeek Harness 桌面版 · Windows x64 归档

本仓库归档 **DeepSeek Harness 桌面版（Windows x64）官方安装包**。官方每发布新版本，这里就会新增一个 Release。

> ⚠️ 本仓库**不是** DeepSeek 官方仓库，仅作官方安装包的搬运与归档。
> 安装包版权归杭州深度求索人工智能基础技术研究有限公司所有，请以官方下载页为准。

## 下载

**最新版本：`0.2.0-rc.2`**

| 项目 | 值 |
| --- | --- |
| 平台 | Windows x64 |
| 文件名 | `deepseek-harness-0.2.0-rc.2-win-x64.exe` |
| 大小 | 289,313,640 字节（275.9 MiB） |

本版本直链（永久有效）：

```
https://github.com/Britripe/deepseek-harness-desktop/releases/download/v0.2.0-rc.2/deepseek-harness-0.2.0-rc.2-win-x64.exe
```

最新版入口（始终指向最新 Release，可收藏）：

<https://github.com/Britripe/deepseek-harness-desktop/releases/latest>

> 说明：安装包文件名带版本号，所以 `/releases/latest/download/<文件名>` 这种写法需要配合
> 当时最新版的具体文件名；而上面这个 `/releases/latest` 页面链接不随版本变化。

## 官方来源

- 官方下载页：<https://www.deepseek.com/download/>
- Windows x64 官方直链：<https://download.deepseek.com/desktop/dsh-latest-windows-x64.exe>
- 官方桌面端更新源：<https://download.deepseek.com/dsh-desk/feeds/win-x64/nightly.yml>

本仓库中的安装包与上述官方地址提供的文件**字节完全一致**，可用下方校验值自行验证。

## 校验值

`0.2.0-rc.2` / `deepseek-harness-0.2.0-rc.2-win-x64.exe`

```
大小    289313640
MD5     7754925fe3c4542123eca76c0e11076e
SHA256  d61cd8882f8b8a1251144320493ad27920d15139503eba2465b9579eee720cfc
SHA512  raIlxMQd9ESXgktmViW7QwVLcjBR5JIsrNOu+SpelY8kskdSr2H51/f+ey1EqFI/eIIrKQCuRANMeb5SptRZcg==
```

其中 SHA-512 与官方更新源 `nightly.yml` 中声明的值一致；SHA-256 也与 GitHub 在资产上传后
回报的 `digest` 一致，可交叉验证。

PowerShell 校验：

```powershell
Get-FileHash .\deepseek-harness-0.2.0-rc.2-win-x64.exe -Algorithm SHA256
```

## 更新流程

仓库内的 [`release.ps1`](release.ps1) 负责后续版本的同步：读取官方更新源，比较已发布的版本，
若有新版本则下载、校验 sha512、创建 Release 并上传安装包。重复运行是安全的（幂等）。

```powershell
# 需要带 repo 范围的 GitHub Token
$env:GH_TOKEN = 'ghp_xxx'
.\release.ps1
```

可选参数：`-Repo owner/name`、`-Force`（已存在也补齐资产）、`-Token`。

## 版本记录

| 版本 | 安装包 | 大小 | Release |
| --- | --- | --- | --- |
| 0.2.0-rc.2 | `deepseek-harness-0.2.0-rc.2-win-x64.exe` | 275.9 MiB | [v0.2.0-rc.2](https://github.com/Britripe/deepseek-harness-desktop/releases/tag/v0.2.0-rc.2) |
