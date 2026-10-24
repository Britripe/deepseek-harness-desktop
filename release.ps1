<#
.SYNOPSIS
    同步 DeepSeek Harness 桌面版（Windows x64）官方安装包到 GitHub 仓库。

.DESCRIPTION
    读取官方更新源 nightly.yml，取得最新版本、下载地址、大小与 sha512；
    与仓库中已发布的 Release 比较，若为新版本则：
      下载 -> 校验 sha512 -> 创建 Release -> 上传 exe 资产。

    幂等：已存在的 Release 或资产不会重复上传。

.PARAMETER Token
    GitHub Token（需 repo 范围）。也可用环境变量 GH_TOKEN。

.PARAMETER Repo
    GitHub 仓库，格式 owner/name。

.PARAMETER Force
    即使该版本已发布，也重新检查并补齐缺失的资产。

.EXAMPLE
    $env:GH_TOKEN = 'ghp_xxx'
    .\release.ps1
#>
[CmdletBinding()]
param(
    [string]$Token = $env:GH_TOKEN,
    [string]$Repo  = 'Britripe/deepseek-harness-desktop',
    [string]$WorkDir = $PSScriptRoot,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Windows PowerShell 5.1 默认可能不用 TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$FeedUrl   = 'https://download.deepseek.com/dsh-desk/feeds/win-x64/nightly.yml'
$ApiRoot   = 'https://api.github.com'
$UserAgent = 'dsh-desktop-archiver'

function Write-Step { param([string]$m) Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok   { param([string]$m) Write-Host "    $m" -ForegroundColor Green }
function Write-Warn { param([string]$m) Write-Host "    $m" -ForegroundColor Yellow }

function Get-ApiHeaders {
    if (-not $Token) {
        throw '缺少 GitHub Token。请设置 $env:GH_TOKEN 或用 -Token 传入。'
    }
    return @{
        Authorization          = "Bearer $Token"
        Accept                 = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'User-Agent'           = $UserAgent
    }
}

# 从 nightly.yml 的折叠标量中取值，避免依赖完整 YAML 解析器
function Get-FoldedValue {
    param([string]$Text, [string]$Key)
    $lines = $Text -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ("^(\s*)" + [regex]::Escape($Key) + ":\s*(>-?|\|)?\s*(.*)$")) {
            $indent = $Matches[1].Length
            $inline = $Matches[3].Trim()
            if ($inline) { return $inline }
            $parts = @()
            # 折叠标量的续行必须比键所在行缩进更深，否则已经进入下一个键
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                $next = $lines[$j]
                if ($next -notmatch '^\s+\S') { break }
                $nextIndent = ($next -replace '^(\s*).*$', '$1').Length
                if ($nextIndent -le $indent) { break }
                $parts += $next.Trim()
            }
            return ($parts -join '')
        }
    }
    return $null
}

# ---------- 1. 读取官方更新源 ----------
function Get-OfficialRelease {
    Write-Step "读取官方更新源 $FeedUrl"
    $resp = Invoke-WebRequest -Uri $FeedUrl -UseBasicParsing -TimeoutSec 30
    # 该服务器对 .yml 返回二进制内容类型，PS 5.1 下 .Content 会是 byte[]，需显式解码
    $content = $resp.Content
    if ($content -is [byte[]]) {
        $raw = [System.Text.Encoding]::UTF8.GetString($content)
    } else {
        $raw = [string]$content
    }
    $raw = $raw -replace "`r`n", "`n"

    $version = Get-FoldedValue $raw 'version'
    $url     = Get-FoldedValue $raw 'path'
    $sha512  = Get-FoldedValue $raw 'sha512'
    $size    = Get-FoldedValue $raw 'size'

    if (-not $version) { throw "无法从更新源解析 version" }
    if (-not $url)     { throw "无法从更新源解析 path" }
    if (-not $sha512)  { throw "无法从更新源解析 sha512" }

    $fileName = Split-Path $url -Leaf
    if (-not $fileName) { $fileName = "deepseek-harness-$version-win-x64.exe" }

    $sizeVal = 0
    if ($size) { $sizeVal = [int64]$size }

    $info = New-Object psobject -Property @{
        Version  = $version
        Url      = $url
        Sha512   = $sha512
        Size     = $sizeVal
        FileName = $fileName
        Tag      = "v$version"
    }
    Write-Ok "最新版本 $($info.Version)  文件 $($info.FileName)"
    return $info
}

# ---------- 2. 校验本地文件 ----------
function Test-AssetHash {
    param([string]$Path, [string]$ExpectedBase64)
    $hex = (Get-FileHash -Path $Path -Algorithm SHA512).Hash
    $bytes = New-Object byte[] ($hex.Length / 2)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16)
    }
    $actual = [Convert]::ToBase64String($bytes)
    return ($actual -eq $ExpectedBase64)
}

# ---------- 3. 确保仓库存在 ----------
function Confirm-Repo {
    param([hashtable]$Headers, [string]$FullName)
    Write-Step "检查仓库 $FullName"
    try {
        $null = Invoke-RestMethod -Uri "$ApiRoot/repos/$FullName" -Headers $Headers -Method Get -TimeoutSec 30
        Write-Ok '仓库已存在'
        return
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -ne 404) { throw }
    }
    $parts = $FullName -split '/'
    if ($parts.Count -ne 2) { throw "仓库格式应为 owner/name，收到：$FullName" }
    Write-Warn '仓库不存在，正在创建…'
    $body = @{
        name        = $parts[1]
        description = 'DeepSeek Harness desktop (Windows x64) official installer archive'
        private     = $false
        has_issues  = $false
        has_wiki    = $false
    } | ConvertTo-Json
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $null = Invoke-RestMethod -Uri "$ApiRoot/user/repos" -Headers $Headers -Method Post -Body $bodyBytes -ContentType 'application/json; charset=utf-8' -TimeoutSec 60
    Write-Ok "已创建 $FullName"
}

# ---------- 4. 查询已发布的 Release ----------
function Get-ExistingRelease {
    param([hashtable]$Headers, [string]$FullName, [string]$Tag)
    try {
        return Invoke-RestMethod -Uri "$ApiRoot/repos/$FullName/releases/tags/$Tag" -Headers $Headers -Method Get -TimeoutSec 30
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 404) { return $null }
        throw
    }
}

# ---------- 5. 抓取官方 Release 更新说明 ----------
function Get-UpstreamReleaseNotes {
    param([string]$Version)
    $upstreamRepo = 'deepseek-ai/deepseek-harness'
    $upstreamTag  = "dsh-v$Version"
    Write-Step "抓取官方发布说明 $upstreamRepo@$upstreamTag"
    try {
        # 公开仓库，不需要令牌；失败不影响发布
        $publicHeaders = @{
            Accept       = 'application/vnd.github+json'
            'User-Agent' = $UserAgent
        }
        $r = Invoke-RestMethod -Uri "$ApiRoot/repos/$upstreamRepo/releases/tags/$upstreamTag" -Headers $publicHeaders -TimeoutSec 30
        if ($r.body) {
            Write-Ok "已获取官方更新说明（$($r.body.Length) 字符）"
            return [pscustomobject]@{ Body = $r.body; Url = $r.html_url }
        }
        Write-Warn '官方 Release 正文为空'
        return $null
    } catch {
        $code = 0
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        Write-Warn "未能获取官方更新说明（HTTP $code），仅写入本地生成的信息"
        return $null
    }
}

# ---------- 主流程 ----------
$headers  = Get-ApiHeaders
$official = Get-OfficialRelease

Confirm-Repo -Headers $headers -FullName $Repo

$existing = Get-ExistingRelease -Headers $headers -FullName $Repo -Tag $official.Tag

if ($existing -and $existing.assets.Count -gt 0 -and -not $Force) {
    Write-Ok "版本 $($official.Tag) 已发布，资产：$(($existing.assets | ForEach-Object { $_.name }) -join ', ')"
    Write-Ok '没有新版本，退出。'
    return
}

# 下载（若本地已有且校验通过则复用）
$local = Join-Path $WorkDir $official.FileName
$needDownload = $true
if (Test-Path $local) {
    Write-Step '发现本地文件，校验 sha512…'
    if (Test-AssetHash -Path $local -ExpectedBase64 $official.Sha512) {
        Write-Ok '本地文件校验通过，复用'
        $needDownload = $false
    } else {
        Write-Warn '本地文件校验失败，重新下载'
    }
}

if ($needDownload) {
    Write-Step "下载 $($official.Url)"
    & curl.exe -L --fail --retry 3 --retry-delay 2 -o $local $official.Url
    if ($LASTEXITCODE -ne 0) { throw "下载失败，curl 退出码 $LASTEXITCODE" }
    Write-Step '校验下载结果 sha512…'
    if (-not (Test-AssetHash -Path $local -ExpectedBase64 $official.Sha512)) {
        throw 'sha512 校验失败，文件可能不完整或被篡改，已中止。'
    }
    Write-Ok '校验通过'
}

$localSize = (Get-Item $local).Length

# 创建 Release
if (-not $existing) {
    Write-Step "创建 Release $($official.Tag)"
    $meta = @"
DeepSeek Harness 桌面版 **$($official.Version)** · Windows x64

| 项目 | 值 |
| --- | --- |
| 版本 | $($official.Version) |
| 平台 | Windows x64 |
| 文件 | $($official.FileName) |
| 大小 | $localSize 字节 |

### 校验值

SHA512(base64): $($official.Sha512)

### 官方来源

- 官方下载页 <https://www.deepseek.com/download/>
- 官方更新源 <https://download.deepseek.com/dsh-desk/feeds/win-x64/nightly.yml>
"@

    # 若官方仓库存在对应 Release，把它的更新说明放到正文最前面
    $upstream = Get-UpstreamReleaseNotes -Version $official.Version
    if ($upstream) {
        $notes = "## 官方更新说明`n`n> 摘自 $($upstream.Url)`n`n$($upstream.Body)`n`n---`n`n## 安装包信息`n`n$meta"
    } else {
        $notes = $meta
    }
    $body = @{
        tag_name   = $official.Tag
        name       = "DeepSeek Harness $($official.Version) (Windows x64)"
        body       = $notes
        draft      = $false
        # 不标 prerelease：DSH 当前所有版本都是 rc，标了就永远无法用 /releases/latest 指向最新版
        prerelease = $false
    } | ConvertTo-Json
    # PS 5.1 用 -Body 传字符串会按 ANSI 编码发送，含中文时 GitHub 报 Problems parsing JSON
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $existing = Invoke-RestMethod -Uri "$ApiRoot/repos/$Repo/releases" -Headers $headers -Method Post -Body $bodyBytes -ContentType 'application/json; charset=utf-8' -TimeoutSec 60
    Write-Ok "Release 已创建：$($existing.html_url)"
} else {
    Write-Ok "Release $($official.Tag) 已存在"
}

# 上传资产
$alreadyUploaded = @($existing.assets | Where-Object { $_.name -eq $official.FileName })
if ($alreadyUploaded.Count -gt 0 -and -not $Force) {
    Write-Ok "资产 $($official.FileName) 已存在，跳过上传"
    return
}

Write-Step "上传资产 $($official.FileName)（$([math]::Round($localSize / 1MB, 1)) MiB）"

# 用 curl 流式上传，避免大文件走 Invoke-RestMethod 的内存缓冲
$uploadUrl = ($existing.upload_url -replace '\{.*$', '') + "?name=" + [uri]::EscapeDataString($official.FileName)
& curl.exe --fail --retry 3 --retry-delay 3 --progress-bar `
    -X POST `
    -H "Authorization: Bearer $Token" `
    -H 'Accept: application/vnd.github+json' `
    -H 'X-GitHub-Api-Version: 2022-11-28' `
    -H "User-Agent: $UserAgent" `
    -H 'Content-Type: application/vnd.microsoft.portable-executable' `
    --data-binary "@$local" `
    $uploadUrl
if ($LASTEXITCODE -ne 0) { throw "资产上传失败，curl 退出码 $LASTEXITCODE" }

Write-Host ''
Write-Ok "下载页：$($existing.html_url)"
Write-Ok "永久直链：https://github.com/$Repo/releases/latest/download/$($official.FileName)"
