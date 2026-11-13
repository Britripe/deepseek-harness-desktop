# DeepSeek Harness 桌面版 · Windows x64 归档

本仓库归档 **DeepSeek Harness 桌面版（Windows x64）官方安装包**。官方每发布新版本，这里就会新增一个 Release，
并在 Release 正文里附上官方更新说明。

> ⚠️ 本仓库**不是** DeepSeek 官方仓库，仅作官方安装包的搬运与归档。
> 安装包版权归杭州深度求索人工智能基础技术研究有限公司所有，请以官方下载页为准。
> 官方源码与更新日志：<https://github.com/deepseek-ai/deepseek-harness>

## 下载

**最新版本：`0.2.2-rc.3`**

| 项目 | 值 |
| --- | --- |
| 平台 | Windows x64 |
| 文件名 | `deepseek-harness-0.2.2-rc.3-win-x64.exe` |
| 大小 | 299,595,752 字节（285.7 MiB） |

本版本直链（永久有效）：

```
https://github.com/Britripe/deepseek-harness-desktop/releases/download/v0.2.2-rc.3/deepseek-harness-0.2.2-rc.3-win-x64.exe
```

最新版入口（始终指向最新 Release，可收藏）：

<https://github.com/Britripe/deepseek-harness-desktop/releases/latest>

> 说明：安装包文件名带版本号，所以 `/releases/latest/download/<文件名>` 这种写法需要配合
> 当时最新版的具体文件名；而上面这个 `/releases/latest` 页面链接不随版本变化。

## 官方来源

- 官方下载页：<https://www.deepseek.com/download/>
- Windows x64 官方直链：<https://download.deepseek.com/desktop/dsh-latest-windows-x64.exe>
- 官方桌面端更新源：<https://download.deepseek.com/dsh-desk/feeds/win-x64/nightly.yml>
- 官方 Release 与更新日志：<https://github.com/deepseek-ai/deepseek-harness/releases>

本仓库中的安装包与上述官方地址提供的文件**字节完全一致**，可用下方校验值自行验证。

## 校验值

### `0.2.2-rc.3`（最新）

`deepseek-harness-0.2.2-rc.3-win-x64.exe`

```
大小    299595752
MD5     a00249bd408a1341c8c453294c03c506
SHA256  786c9b26050c35b62c7be6a01dee2541dc1c2c5d9bd5f2dbe77beeeb8d50704e
SHA512  GiJf8kx+C7eoiZ0xQSYBcTyh5xmXQl+vh63U6uSm963McK1AkMgB8PydzuekWdUY7hyURvhVMHANM4pn+tCKzQ==
```

历史版本的完整校验值见 [`SHA512SUMS.txt`](SHA512SUMS.txt)。

其中 SHA-512 与官方更新源 `nightly.yml` 中声明的值一致；SHA-256 也与 GitHub 在资产上传后
回报的 `digest` 一致；MD5 与官方**版本化地址**的 ETag 一致，可交叉验证。

> ⚠️ 注意：`0.2.2-rc.3` 官方是 **`stagingPercentage: 10`** 的分阶段发布，所以
> `dsh-latest-windows-x64.exe` 这个别名当时仍指向 `0.2.2-rc.2`（299,659,528 字节）。
> 想确认拿到的是 rc.3，请用上面的版本化地址或核对本文档的校验值，不要只看 `dsh-latest`。

PowerShell 校验：

```powershell
Get-FileHash .\deepseek-harness-0.2.2-rc.3-win-x64.exe -Algorithm SHA256
```

## 更新流程

仓库内的 [`release.ps1`](release.ps1) 负责后续版本的同步：读取官方更新源，比较已发布的版本，
若有新版本则下载、校验 sha512、创建 Release 并上传安装包；Release 正文会自动抓取官方
`deepseek-ai/deepseek-harness` 对应标签的更新说明。重复运行是安全的（幂等）。

```powershell
# 需要带 repo 范围的 GitHub Token
$env:GH_TOKEN = 'ghp_xxx'
.\release.ps1
```

可选参数：`-Repo owner/name`、`-Force`（已存在也补齐资产）、`-Token`、`-NoProxy`。

> 脚本会自动沿用 Windows 系统代理（curl 本身不读取系统代理设置）。若代理反而导致失败，
> 加 `-NoProxy` 走直连。

## 版本记录

| 版本 | 发布日期 | 安装包 | 大小 | Release |
| --- | --- | --- | --- | --- |
| 0.2.2-rc.3 | 2026-11-13 | `deepseek-harness-0.2.2-rc.3-win-x64.exe` | 285.7 MiB | [v0.2.2-rc.3](https://github.com/Britripe/deepseek-harness-desktop/releases/tag/v0.2.2-rc.3) |
| 0.2.2-rc.1 | 2026-11-04 | `deepseek-harness-0.2.2-rc.1-win-x64.exe` | 279.8 MiB | [v0.2.2-rc.1](https://github.com/Britripe/deepseek-harness-desktop/releases/tag/v0.2.2-rc.1) |
| 0.2.1-rc.5 | 2026-10-30 | `deepseek-harness-0.2.1-rc.5-win-x64.exe` | 276.0 MiB | [v0.2.1-rc.5](https://github.com/Britripe/deepseek-harness-desktop/releases/tag/v0.2.1-rc.5) |
| 0.2.1-rc.3 | 2026-10-23 | `deepseek-harness-0.2.1-rc.3-win-x64.exe` | 276.0 MiB | [v0.2.1-rc.3](https://github.com/Britripe/deepseek-harness-desktop/releases/tag/v0.2.1-rc.3) |
| 0.2.1-rc.2 | 2026-10-17 | `deepseek-harness-0.2.1-rc.2-win-x64.exe` | 276.0 MiB | [v0.2.1-rc.2](https://github.com/Britripe/deepseek-harness-desktop/releases/tag/v0.2.1-rc.2) |
| 0.2.0-rc.2 | 2026-09-29 | `deepseek-harness-0.2.0-rc.2-win-x64.exe` | 275.9 MiB | [v0.2.0-rc.2](https://github.com/Britripe/deepseek-harness-desktop/releases/tag/v0.2.0-rc.2) |

> 未归档的中间版本：`0.2.1-rc.4`（2026-10-28）、`0.2.2-rc.2`（2026-11-11，Git Worktree 审阅、
> 具名多层子代理、网页搜索改 DeepSeek Search API 等大变更）。它们的桌面端安装包已被后续版本覆盖，
> 官方不再提供独立下载地址。
