#
<#
.SYNOPSIS
    Speedtest to Zabbix の Windows 自動セットアップスクリプト。

.DESCRIPTION
    1. speedtest CLI の存在確認
    2. 動作検証 (DryRun)
    3. Windows タスクスケジューラへの定期実行タスク自動登録
    4. (オプション) Zabbix API を経由したテンプレートの自動インポート

.PARAMETER ZabbixServer
    送信先 Zabbix サーバー (省略時は zabbix_agentd.conf または 127.0.0.1)

.PARAMETER Hostname
    Zabbix 登録ホスト名 (デフォルト: Speedtest)

.PARAMETER Schedule
    定期実行間隔: "Hourly" (毎時0分), "Daily" (毎日深夜0時), "None" (スケジューラ登録なし)

.PARAMETER ZabbixUrl
    テンプレート登録を行う場合の Zabbix Web URL (例: http://192.168.1.10/zabbix)

.PARAMETER ApiToken
    テンプレート登録を行う場合の Zabbix API トークン

.EXAMPLE
    .\setup.ps1 -Schedule Hourly
    ローカル環境で毎時0分の定期実行タスクをタスクスケジューラに登録します。

.EXAMPLE
    .\setup.ps1 -ZabbixServer 192.168.1.10 -Hostname MyPC -ZabbixUrl "http://192.168.1.10/zabbix" -ApiToken "xxx"
    サーバーを指定し、テンプレート登録からタスクスケジューラ登録まで一括で完了させます。
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ZabbixServer = "",

    [Parameter()]
    [string]$Hostname = "Speedtest",

    [Parameter()]
    [ValidateSet("Hourly", "Daily", "None")]
    [string]$Schedule = "Hourly",

    [Parameter()]
    [string]$ZabbixUrl = "",

    [Parameter()]
    [string]$ApiToken = ""
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$timestamp] [$Level] $Message"
}

Write-Log "=== Speedtest to Zabbix Setup Wizard ===" "INFO"

# 1. speedtest.exe の確認
$speedtestExe = Join-Path $PSScriptRoot "speedtest.exe"
if (-not (Test-Path $speedtestExe) -and -not (Get-Command speedtest.exe -ErrorAction SilentlyContinue)) {
    Write-Log "speedtest CLI が見つかりません。" "ERROR"
    Write-Log "以下の公式サイトから speedtest.exe をダウンロードして、本フォルダ ($PSScriptRoot) に配置してください:" "WARN"
    Write-Log "  https://www.speedtest.net/ja/apps/cli" "WARN"
    exit 1
}
Write-Log "speedtest CLI を検出しました。" "INFO"

# 2. 動作検証 (DryRun)
Write-Log "動作確認 (DryRun) を実行中..." "INFO"
$testArgs = @("-DryRun")
if (-not [string]::IsNullOrWhiteSpace($ZabbixServer)) {
    $testArgs += @("-ZabbixServer", $ZabbixServer)
}
if (-not [string]::IsNullOrWhiteSpace($Hostname)) {
    $testArgs += @("-Hostname", $Hostname)
}

& (Join-Path $PSScriptRoot "speedtest.ps1") @testArgs
if ($LASTEXITCODE -ne 0) {
    Write-Log "DryRun 検証でエラーが発生しました。設定やネットワークを確認してください。" "ERROR"
    exit 1
}
Write-Log "DryRun 検証が正常に完了しました。" "INFO"

# 3. テンプレートのインポート (URL と API トークンが提供された場合)
if (-not [string]::IsNullOrWhiteSpace($ZabbixUrl) -and -not [string]::IsNullOrWhiteSpace($ApiToken)) {
    Write-Log "Zabbix サーバーへテンプレートをインポート中..." "INFO"
    $importArgs = @(
        "-ZabbixUrl", $ZabbixUrl,
        "-ApiToken", $ApiToken,
        "-LinkToHost", $Hostname
    )
    & (Join-Path $PSScriptRoot "import_template.ps1") @importArgs
}

# 4. タスクスケジューラへの自動登録
if ($Schedule -ne "None") {
    $taskName = "Speedtest-to-Zabbix"
    Write-Log "タスクスケジューラにタスク '$taskName' を登録中 (スケジュール: $Schedule)..." "INFO"

    $pwshExe = (Get-Command pwsh.exe -ErrorAction SilentlyContinue)
    $psExePath = if ($pwshExe) { "pwsh.exe" } else { "powershell.exe" }

    $scriptPath = Join-Path $PSScriptRoot "speedtest.ps1"
    $actionArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
    if (-not [string]::IsNullOrWhiteSpace($ZabbixServer)) {
        $actionArgs += " -ZabbixServer `"$ZabbixServer`""
    }
    if (-not [string]::IsNullOrWhiteSpace($Hostname) -and $Hostname -ne "Speedtest") {
        $actionArgs += " -Hostname `"$Hostname`""
    }

    $schArgs = @("/create", "/tn", $taskName, "/tr", "$psExePath $actionArgs", "/f")
    if ($Schedule -eq "Hourly") {
        $schArgs += @("/sc", "hourly")
    } elseif ($Schedule -eq "Daily") {
        $schArgs += @("/sc", "daily", "/st", "00:00")
    }

    $schResult = & schtasks.exe @schArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Log "タスク '$taskName' を正常に登録しました！" "INFO"
    } else {
        Write-Log "タスクの登録に失敗しました。管理者権限の PowerShell で再試行してください。" "WARN"
    }
}

Write-Log "=== セットアップが完了しました ===" "INFO"
