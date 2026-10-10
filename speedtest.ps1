<#
.SYNOPSIS
    Ookla Speedtest CLI を実行し、計測結果をパースして Zabbix サーバーへ一括送信するスクリプト。

.DESCRIPTION
    speedtest.exe の JSON 出力からメトリクスを抽出・計算し、
    zabbix_sender.exe の一括入力形式 (-i) を使って 1 回の通信で全メトリクスを送信します。
    Zabbix 側では speedtest.json (RAW JSON) のトラッパーアイテム、または個別のメトリクスキーの
    どちらでも受信可能です。

.PARAMETER ZabbixServer
    送信先 Zabbix サーバーの IP またはホスト名 (デフォルト: 52.194.38.180)

.PARAMETER ZabbixPort
    Zabbix トラッパーのポート番号 (デフォルト: 10051)

.PARAMETER Hostname
    Zabbix 上に登録されているホスト名 (デフォルト: Speedtest)

.PARAMETER ItemPrefix
    アイテムキーのプレフィックス (デフォルト: speedtest)

.PARAMETER DryRun
    Zabbix への送信を行わず、パースされたメトリクスと送信予定データをコンソールに表示します。

.PARAMETER SendRawJson
    speedtest.json アイテムとして生の JSON 文字列も送信するかどうか (デフォルト: $true)

.EXAMPLE
    .\speedtest.ps1 -DryRun
    Zabbix へ送信せずに計測とパースの動作確認を行います。

.EXAMPLE
    .\speedtest.ps1
    デフォルト設定で Speedtest を実行し、Zabbix サーバーへ結果を送信します。
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ZabbixServer = "52.194.38.180",

    [Parameter()]
    [int]$ZabbixPort = 10051,

    [Parameter()]
    [string]$Hostname = "Speedtest",

    [Parameter()]
    [string]$ItemPrefix = "speedtest",

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [bool]$SendRawJson = $true,

    [Parameter()]
    [string]$SpeedtestPath = "",

    [Parameter()]
    [string]$ZabbixSenderPath = ""
)

# 出力文字コードを UTF-8 に統一
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# デフォルトパスの安全な解決 (PowerShell 5.1 互換)
if ([string]::IsNullOrWhiteSpace($SpeedtestPath)) {
    $SpeedtestPath = Join-Path $PSScriptRoot "speedtest.exe"
}
if ([string]::IsNullOrWhiteSpace($ZabbixSenderPath)) {
    $ZabbixSenderPath = Join-Path $PSScriptRoot "zabbix_sender.exe"
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$timestamp] [$Level] $Message"
}

# 1. 実行ファイルの存在確認
if (-not (Test-Path $SpeedtestPath)) {
    Write-Log "speedtest.exe が見つかりません: $SpeedtestPath" "ERROR"
    exit 1
}
if (-not $DryRun -and -not (Test-Path $ZabbixSenderPath)) {
    Write-Log "zabbix_sender.exe が見つかりません: $ZabbixSenderPath" "ERROR"
    exit 1
}

# 2. Speedtest CLI の実行
Write-Log "Speedtest CLI を実行中..."
try {
    $rawOutput = & $SpeedtestPath --format=json --accept-license --accept-gdpr 2>&1
} catch {
    Write-Log "Speedtest CLI の実行中にエラーが発生しました: $_" "ERROR"
    exit 1
}

# 3. JSON 行の抽出とパース
# ライセンス同意メッセージや空行をスキップし、有効な JSON 行を特定
$jsonLine = $rawOutput | Where-Object { $_ -match '^\s*\{.*"type"\s*:\s*"result"' } | Select-Object -Last 1

if (-not $jsonLine) {
    Write-Log "Speedtest CLI の出力から有効な結果 JSON を検出できませんでした。" "ERROR"
    Write-Log "--- 出力ログ ---" "ERROR"
    $rawOutput | ForEach-Object { Write-Log $_ "ERROR" }
    exit 1
}

try {
    $data = $jsonLine | ConvertFrom-Json
} catch {
    Write-Log "JSON のパースに失敗しました: $_" "ERROR"
    exit 1
}

# 4. メトリクスの計算・抽出
# Speedtest CLI の bandwidth は Byte/sec なので、8倍して bps を算出
$downloadBps = [math]::Round([double]$data.download.bandwidth * 8, 0)
$downloadMbps = [math]::Round(($downloadBps / 1000000), 2)

$uploadBps = [math]::Round([double]$data.upload.bandwidth * 8, 0)
$uploadMbps = [math]::Round(($uploadBps / 1000000), 2)

$pingLatency = [math]::Round([double]$data.ping.latency, 3)
$pingJitter = [math]::Round([double]$data.ping.jitter, 3)

$packetLoss = 0.0
if ($null -ne $data.packetLoss) {
    $packetLoss = [math]::Round([double]$data.packetLoss, 2)
}

Write-Log "計測完了:"
Write-Log "  Server   : $($data.server.name) ($($data.server.location), $($data.server.country))"
Write-Log "  Ping     : $pingLatency ms (Jitter: $pingJitter ms)"
Write-Log "  Download : $downloadMbps Mbps ($downloadBps bps)"
Write-Log "  Upload   : $uploadMbps Mbps ($uploadBps bps)"
Write-Log "  Loss     : $packetLoss %"
Write-Log "  URL      : $($data.result.url)"

# 5. Zabbix 送信レコードの生成 (タブ区切り: <host>\t<key>\t<value>)
$records = [System.Collections.Generic.List[string]]::new()

$records.Add("$Hostname`t$ItemPrefix.ping.latency`t$pingLatency")
$records.Add("$Hostname`t$ItemPrefix.ping.jitter`t$pingJitter")
$records.Add("$Hostname`t$ItemPrefix.download.bps`t$downloadBps")
$records.Add("$Hostname`t$ItemPrefix.download.mbps`t$downloadMbps")
$records.Add("$Hostname`t$ItemPrefix.upload.bps`t$uploadBps")
$records.Add("$Hostname`t$ItemPrefix.upload.mbps`t$uploadMbps")
$records.Add("$Hostname`t$ItemPrefix.download.bytes`t$($data.download.bytes)")
$records.Add("$Hostname`t$ItemPrefix.upload.bytes`t$($data.upload.bytes)")
$records.Add("$Hostname`t$ItemPrefix.packetloss`t$packetLoss")
$records.Add("$Hostname`t$ItemPrefix.server.name`t$($data.server.name)")
$records.Add("$Hostname`t$ItemPrefix.server.id`t$($data.server.id)")
$records.Add("$Hostname`t$ItemPrefix.result.url`t$($data.result.url)")

# 生の JSON (改行なしの1行) も送信対象に含める場合 (ItemKey: speedtest.json)
if ($SendRawJson) {
    $compactJson = ($jsonLine -replace "[\r\n]+", "").Trim()
    $records.Add("$Hostname`t$ItemPrefix.json`t$compactJson")
}

# 6. 送信処理 / DryRun 処理
if ($DryRun) {
    Write-Log "[DryRun] Zabbix サーバーへの送信はスキップされました。"
    Write-Log "[DryRun] 送信対象レコード一覧 ($($records.Count) 件):"
    foreach ($rec in $records) {
        $parts = $rec.Split("`t")
        if ($parts[1] -eq "$ItemPrefix.json") {
            Write-Host "  Host: $($parts[0]) | Key: $($parts[1]) | Value: [RAW JSON $(($parts[2]).Length) 文字]"
        } else {
            Write-Host "  Host: $($parts[0]) | Key: $($parts[1]) | Value: $($parts[2])"
        }
    }
    exit 0
}

# 一時ファイルを作成して Zabbix Sender (-i) で一括送信
$tempFile = [System.IO.Path]::GetTempFileName()
try {
    # UTF-8 (BOMなし) で一時ファイルに書き込み
    [System.IO.File]::WriteAllLines($tempFile, $records, (New-Object System.Text.UTF8Encoding($false)))

    Write-Log "Zabbix サーバー ($($ZabbixServer):$($ZabbixPort)) へ $($records.Count) 件のメトリクスを送信中..."
    $senderOutput = & $ZabbixSenderPath -z $ZabbixServer -p $ZabbixPort -i $tempFile 2>&1
    Write-Log "Zabbix Sender 出力:"
    $senderOutput | ForEach-Object { Write-Log "  $_" }

    # processed: X; failed: Y; total: Z の結果を確認
    $statusLine = ($senderOutput | Out-String)
    if ($statusLine -match "processed:\s*(\d+);\s*failed:\s*(\d+)") {
        $processed = [int]$matches[1]
        $failed = [int]$matches[2]
        if ($failed -gt 0 -and $processed -gt 0) {
            Write-Log "一部のメトリクスが送信されました (成功: $processed 件, 未登録/失敗: $failed 件)。個別アイテムキーを Zabbix 側に登録すると全件記録されます。" "INFO"
        } elseif ($failed -gt 0 -and $processed -eq 0) {
            Write-Log "全アイテムの送信に失敗しました (成功: 0 件, 失敗: $failed 件)。Zabbix 側のホスト名やアイテムキーを確認してください。" "WARN"
        } else {
            Write-Log "全メトリクスが正常に送信されました (成功: $processed 件)。" "INFO"
        }
    }
} catch {
    Write-Log "Zabbix Sender の実行中にエラーが発生しました: $_" "ERROR"
    exit 1
} finally {
    if (Test-Path $tempFile) {
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
}
