#!/usr/bin/env bash
# ==============================================================================
# Ookla Speedtest CLI to Zabbix Sender (Linux / zabbix_sender 版)
#
# pip や Python 外部ライブラリが利用できないセキュア・閉域環境向けのシェルスクリプト。
# speedtest CLI の結果を zabbix_sender 経由で Zabbix サーバーへ送信します。
# ==============================================================================

set -euo pipefail

# デフォルト設定
ZABBIX_SERVER="52.194.38.180"
ZABBIX_PORT="10051"
ZABBIX_HOST="Speedtest"
ITEM_KEY="speedtest.json"
DRY_RUN=0
MAX_RETRIES=3
RETRY_DELAY=5

# ログ関数
log() {
    local level="$1"; shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
}

# ヘルプ表示
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -z <server>    Zabbix サーバー IP またはホスト名 (デフォルト: ${ZABBIX_SERVER})
  -p <port>      Zabbix トラッパーポート (デフォルト: ${ZABBIX_PORT})
  -s <host>      Zabbix 上の登録ホスト名 (デフォルト: ${ZABBIX_HOST})
  -k <key>       マスターアイテムキー (デフォルト: ${ITEM_KEY})
  -d             DryRun (Zabbix への送信を行わず結果を表示)
  -h             このヘルプを表示

Requirements:
  - speedtest CLI (https://www.speedtest.net/ja/apps/cli)
  - zabbix_sender (sudo apt install zabbix-sender / sudo dnf install zabbix-sender)
EOF
    exit 0
}

# コマンドライン引数のパース
while getopts "z:p:s:k:dh" opt; do
    case "$opt" in
        z) ZABBIX_SERVER="$OPTARG" ;;
        p) ZABBIX_PORT="$OPTARG" ;;
        s) ZABBIX_HOST="$OPTARG" ;;
        k) ITEM_KEY="$OPTARG" ;;
        d) DRY_RUN=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

# 1. 依存コマンドのチェック
if ! command -v speedtest >/dev/null 2>&1; then
    log "ERROR" "speedtest コマンドが見つかりません。"
    log "ERROR" "公式ドキュメントを参照して speedtest CLI をインストールしてください:"
    log "ERROR" "  https://www.speedtest.net/ja/apps/cli"
    exit 1
fi

if [ "$DRY_RUN" -eq 0 ] && ! command -v zabbix_sender >/dev/null 2>&1; then
    log "ERROR" "zabbix_sender コマンドが見つかりません。"
    log "ERROR" "パッケージマネージャーからインストールしてください:"
    log "ERROR" "  Debian/Ubuntu: sudo apt-get install zabbix-sender"
    log "ERROR" "  RHEL/CentOS:   sudo dnf install zabbix-sender"
    exit 1
fi

# 2. Speedtest CLI の実行 (リトライループ)
JSON_OUTPUT=""
for attempt in $(seq 1 "$MAX_RETRIES"); do
    log "INFO" "Speedtest CLI を実行中 (試行 ${attempt}/${MAX_RETRIES})..."
    
    # 実行して出力を取得 (エラーもキャプチャ)
    set +e
    RAW_OUT=$(speedtest --format=json --accept-license --accept-gdpr 2>&1)
    EXIT_CODE=$?
    set -e

    if [ "$EXIT_CODE" -eq 0 ]; then
        # ライセンス警告行をスキップし、"type":"result" を含む JSON 行を抽出
        JSON_LINE=$(echo "$RAW_OUT" | grep -F '"type":"result"' | tail -n 1 || true)
        if [ -n "$JSON_LINE" ]; then
            JSON_OUTPUT="$JSON_LINE"
            break
        fi
        log "WARN" "有効な結果 JSON を検出できませんでした。"
    else
        log "WARN" "Speedtest CLI がエラーを返しました (ExitCode: ${EXIT_CODE}):"
        echo "$RAW_OUT" | sed 's/^/  /' >&2
    fi

    if [ "$attempt" -lt "$MAX_RETRIES" ]; then
        log "INFO" "${RETRY_DELAY} 秒待機して再試行します..."
        sleep "$RETRY_DELAY"
    fi
done

if [ -z "$JSON_OUTPUT" ]; then
    log "ERROR" "最大試行回数 (${MAX_RETRIES} 回) を超過したため中止します。"
    exit 1
fi

# 1行のコンパクトな JSON に整形 (改行・復帰コードの除去)
CLEAN_JSON=$(echo "$JSON_OUTPUT" | tr -d '\r\n')

log "INFO" "計測が完了しました (データサイズ: ${#CLEAN_JSON} bytes)。"

# 3. 送信処理 / DryRun
if [ "$DRY_RUN" -eq 1 ]; then
    log "INFO" "[DryRun] Zabbix サーバーへの送信はスキップされました。"
    log "INFO" "[DryRun] 送信データプレビュー:"
    echo "  Host: ${ZABBIX_HOST} | Key: ${ITEM_KEY} | Value: ${CLEAN_JSON:0:150}..."
    exit 0
fi

# zabbix_sender の一括入力形式 (-i -: 標準入力からタブ区切り <host>\t<key>\t<value>) で送信
log "INFO" "Zabbix サーバー (${ZABBIX_SERVER}:${ZABBIX_PORT}) へ送信中 (送信キー: ${ITEM_KEY})..."

SENDER_OUTPUT=$(printf "%s\t%s\t%s\n" "$ZABBIX_HOST" "$ITEM_KEY" "$CLEAN_JSON" | \
    zabbix_sender -z "$ZABBIX_SERVER" -p "$ZABBIX_PORT" -i - 2>&1)

log "INFO" "Zabbix Sender 出力:"
echo "$SENDER_OUTPUT" | sed 's/^/  /'

# 処理結果の判定 (processed / failed)
if echo "$SENDER_OUTPUT" | grep -q "processed: [1-9]"; then
    log "INFO" "Zabbix サーバーへの送信が正常に完了しました。"
else
    log "WARN" "送信が失敗したか、Zabbix 側でアイテムが未登録の可能性があります。"
    exit 1
fi
