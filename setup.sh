#!/usr/bin/env bash
#
# Speedtest to Zabbix - Linux 自動セットアップスクリプト
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2"
}

ZABBIX_SERVER=""
HOSTNAME="Speedtest"
SCHEDULE="hourly"
ZABBIX_URL=""
API_TOKEN=""

usage() {
    cat <<EOF
Usage: setup.sh [OPTIONS]

Options:
  -z <server>    送信先 Zabbix サーバー (省略時は agentd.conf または 127.0.0.1)
  -s <host>      Zabbix 上の登録ホスト名 (デフォルト: Speedtest)
  -c <schedule>  cron 登録間隔: "hourly" (毎時0分), "daily" (毎日深夜0時), "none" (デフォルト: hourly)
  -u <url>       テンプレート登録を行う場合の Zabbix Web URL
  -t <token>     テンプレート登録を行う場合の Zabbix API Token
  -h             このヘルプを表示

Example:
  ./setup.sh -z 192.168.1.10 -s MyServer -c hourly
EOF
    exit 0
}

while getopts "z:s:c:u:t:h" opt; do
    case "$opt" in
        z) ZABBIX_SERVER="$OPTARG" ;;
        s) HOSTNAME="$OPTARG" ;;
        c) SCHEDULE="$OPTARG" ;;
        u) ZABBIX_URL="$OPTARG" ;;
        t) API_TOKEN="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

log "INFO" "=== Speedtest to Zabbix Linux Setup Wizard ==="

# 1. 実行権限の付与
chmod +x "$SCRIPT_DIR/speedtest_zabbix.sh" || true
chmod +x "$SCRIPT_DIR/speedtest_zabbix.py" || true
chmod +x "$SCRIPT_DIR/import_template.py" || true

# 2. speedtest CLI の存在確認
if ! command -v speedtest &> /dev/null; then
    log "ERROR" "speedtest CLI が見つかりません。"
    log "WARN" "以下のコマンドまたは公式サイトから speedtest CLI をインストールしてください:"
    log "WARN" "  curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash"
    log "WARN" "  sudo apt-get install speedtest"
    exit 1
fi
log "INFO" "speedtest CLI を検出しました。"

# 3. 動作確認 (DryRun)
log "INFO" "動作確認 (DryRun) を実行中..."
DRY_ARGS=("-d")
if [ -n "$ZABBIX_SERVER" ]; then
    DRY_ARGS+=("-z" "$ZABBIX_SERVER")
fi
if [ -n "$HOSTNAME" ]; then
    DRY_ARGS+=("-s" "$HOSTNAME")
fi

"$SCRIPT_DIR/speedtest_zabbix.sh" "${DRY_ARGS[@]}"
log "INFO" "DryRun 検証が正常に完了しました。"

# 4. テンプレートのインポート (URL と Token が提供された場合)
if [ -n "$ZABBIX_URL" ] && [ -n "$API_TOKEN" ]; then
    log "INFO" "Zabbix サーバーへテンプレートをインポート中..."
    python3 "$SCRIPT_DIR/import_template.py" -u "$ZABBIX_URL" -t "$API_TOKEN" -s "$HOSTNAME" || true
fi

# 5. cron への登録
if [ "$SCHEDULE" != "none" ]; then
    RUN_CMD="$SCRIPT_DIR/speedtest_zabbix.sh"
    if [ -n "$ZABBIX_SERVER" ]; then
        RUN_CMD="$RUN_CMD -z $ZABBIX_SERVER"
    fi
    if [ -n "$HOSTNAME" ] && [ "$HOSTNAME" != "Speedtest" ]; then
        RUN_CMD="$RUN_CMD -s $HOSTNAME"
    fi

    CRON_LINE=""
    if [ "$SCHEDULE" = "hourly" ]; then
        CRON_LINE="0 * * * * $RUN_CMD > /dev/null 2>&1"
    elif [ "$SCHEDULE" = "daily" ]; then
        CRON_LINE="0 0 * * * $RUN_CMD > /dev/null 2>&1"
    fi

    if [ -n "$CRON_LINE" ]; then
        log "INFO" "cron に定期実行タスクを登録中..."
        # 既存のエントリがなければ追記
        (crontab -l 2>/dev/null | grep -F -v "$SCRIPT_DIR/speedtest_zabbix.sh" ; echo "$CRON_LINE") | crontab -
        log "INFO" "cron への登録が完了しました: $CRON_LINE"
    fi
fi

log "INFO" "=== セットアップが完了しました ==="
