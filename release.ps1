<#
.SYNOPSIS
    同步 DeepSeek Harness 桌面版（Windows x64）官方安装包到 GitHub 仓库。

.DESCRIPTION
    读取官方更新源 nightly.yml，取得最新版本、下载地址、大小与 sha512；
    与仓库中已发布的 Release 比较，若为新版本则：
      下载 -> 校验 sha512 -> 创建 Release -> 上传 exe 资产。

    幂等：已存在的 Release 或资产不会重复上传。

.PARAMETER Token
    GitHub Token（需 repo / Contents 读写权限）。也可用环境变量 GH_TOKEN。

.PARAMETER Repo
    GitHub 仓库，格式 owner/name。

.PARAMETER Force
    即使该版本已发布，也重新检查并补齐缺失的资产。

.EXAMPLE
    $env:GH_TOKEN = 'ghp_xxx'
    pwsh -File .\release.ps1
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

# ---------- 1. 读取官方更新源 ----------
function Get-OfficialRelease {
    Write-Step "读取官方更新源 $FeedUrl"
    $raw = (Invoke-WebRequest -Uri $FeedUrl -UseBasicParsing -TimeoutSec 30).Content

    # nightly.yml 使用折叠标量 (url: >-)，这里用轻量解析而非完整 YAML 依赖
    function Get-FoldedValue {
        param([string]$Text, [string]$Key)
        $lines = $Text -split "`r?`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "^\s*$([regex]::Escape($Key)):\s*(>-?|\|)?\s*(.*)$") {
                $inline = $Matches[2].Trim()
                if ($inline) { return $inline }
                $parts = @()
                for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                    if ($lines[$j] -match '^\s+\S') { $parts += $lines[$j].Trim() }
                    else { break }
                }
                return ($parts -join '')
            }
        }
        return $null
    }

    $version = Get-FoldedValue $raw 'version'
    $url     = Get-FoldedValue $raw 'path'
    $sha512  = Get-FoldedValue $raw 'sha512'
    $size    = Get-FoldedValue $raw 'size'

    if (-not $version) { throw "无法从更新源解析 version：`n$raw" }
    if (-not $url)     { throw "无法从更新源解析 path：`n$raw" }
    if (-not $sha512)  { $sha512 = Get-FoldedValue ($raw -replace '(?m)^path:.*$', '') 'sha512' }

    $fileName = Split-Path $url -Leaf
    if (-not $fileName) { $fileName = "deepseek-harness-$version-win-x64.exe" }

    $info = [pscustomobject]@{
        Version  = $version
        Url      = $url
        Sha512   = $sha512
        Size     = if ($size) { [int64]$size } else { 0 }
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
    $bytes = for ($i = 0; $i -lt $hex.Length; $i += 2) { [Convert]::ToByte($hex.Substring($i, 2), 16) }
    $actual = [Convert]::ToBase64String($bytes)
    return ($actual -eq $ExpectedBase64)
}

# ---------- 3. 确保仓库存在 ----------
function Confirm-Repo {
    param([hashtable]$Headers, [string]$FullName)
    Write-Step "检查仓库 $FullName"
    try {
        $null = Invoke-RestMethod -Uri "$ApiRoot/repos/$FullName" -Headers $Headers -Method Get
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
        description = 'DeepSeek Harness 桌面版（Windows x64）官方安装包归档'
        private     = $false
        has_issues  = $false
        has_wiki    = $false
    } | ConvertTo-Json
    $null = Invoke-RestMethod -Uri "$ApiRoot/user/repos" -Headers $Headers -Method Post -Body $body -ContentType 'application/json'
    Write-Ok "已创建 $FullName"
}

# ---------- 4. 查询已发布的 Release ----------
function Get-ExistingRelease {
    param([hashtable]$Headers, [string]$FullName, [string]$Tag)
    try {
        return Invoke-RestMethod -Uri "$ApiRoot/repos/$FullName/releases/tags/$Tag" -Headers $Headers -Method Get
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 404) { return $null }
        throw
    }
}

# ---------- 主流程 ----------
$headers = Get-ApiHeaders
$official = Get-OfficialRelease

Confirm-Repo -Headers $headers -FullName $Repo

$existing = Get-ExistingRelease -Headers $headers -FullName $Repo -Tag $official.Tag

if ($existing -and $existing.assets.Count -gt 0 -and -not $Force) {
    Write-Ok "版本 $($official.Tag) 已发布，资产：$($existing.assets.name -join ', ')"
    Write-Ok '没有新版本，退出。'
    return
}

# 下载（若本地已有且校验通过则复用）
$local = Join-Path $WorkDir $official.FileName
$needDownload = $true
if (Test-Path $local) {
    Write-Step "发现本地文件，校验 sha512…"
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

# 创建 Release
if (-not $existing) {
    Write-Step "创建 Release $($official.Tag)"
    $notes = @"
DeepSeek Harness 桌面版 **$($official.Version)** · Windows x64

| 项目 | 值 |
| --- | --- |
| 版本 | ``$($official.Version)`` |
| 平台 | Windows x64 |
| 文件 | ``$($official.FileName)`` |
| 大小 | $((Get-Item $local).Length) 字节 |

### 校验值

``````
SHA512(base64) $($official.Sha512)
``````

### 官方来源

- 官方下载页 <https://www.deepseek.com/download/>
- 官方更新源 <https://download.deepseek.com/dsh-desk/feeds/win-x64/nightly.yml>
"@
    $body = @{
        tag_name         = $official.Tag
        name             = "DeepSeek Harness $($official.Version) (Windows x64)"
        body             = $notes
        draft            = $false
        prerelease       = ($official.Version -match '-')
    } | ConvertTo-Json
    $existing = Invoke-RestMethod -Uri "$ApiRoot/repos/$Repo/releases" -Headers $headers -Method Post -Body $body -ContentType 'application/json'
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

Write-Step "上传资产 $($official.FileName)（$([math]::Round((Get-Item $local).Length / 1MB, 1)) MiB）"
$uploadUrl = ($existing.upload_url -replace '\{.*$', '') + "?name=$([uri]::EscapeDataString($official.FileName))"
$uploadHeaders = $headers.Clone()
$uploadHeaders['Content-Type'] = 'application/vnd.microsoft.portable-executable'

$asset = Invoke-RestMethod -Uri $uploadUrl -Headers $uploadHeaders -Method Post -InFile $local -TimeoutSec 3600
Write-Ok "上传完成：$($asset.browser_download_url)"
Write-Host ''
Write-Host "完成。下载页：$($existing.html_url)" -ForegroundColor Green
