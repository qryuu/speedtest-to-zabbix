# Speedtest to Zabbix

Windows および Linux 上で Ookla Speedtest CLI を定期実行し、回線計測結果をパースして Zabbix サーバーへ送信するツールセットです。

---

## 特徴

- **選べる 3 つの送信方式**: 環境や好みに合わせて、PowerShell / Python / ZabbixSender の中から最適な送信方法を選択可能。
- **軽量リポジトリ**: 実行バイナリを同梱せず、公式最新版を安全にダウンロードして使用する設計。
- **Zabbix 7.0 共通テンプレート付属**: Windows と Linux の両環境を同一の `Speedtest.yaml` テンプレートで監視可能。
- **堅牢なパースとリトライ機構**: JSON 出力の確実な抽出・パースと、ネットワーク一時エラー時の自動再試行をサポート。

---

## 3 つの送信方式の比較と選び方

| 送信方式 | コマンド / スクリプト | 必要な環境 | 特徴・おすすめシーン |
| :--- | :--- | :--- | :--- |
| **1. PowerShell 方式**<br>(Windows 推奨) | `speedtest.ps1`<br>(または `speedtest.bat`) | Windows<br>(PS 5.1 / 7 系) | **追加インストール不要**。<br>.NET ソケット通信で Zabbix トラッパーへ直接送信するため、`zabbix_sender.exe` や Python のインストールが不要。 |
| **2. Python 方式**<br>(Linux / Windows 共通推奨) | `speedtest_zabbix.py` | Python 3.8+<br>`zabbix-utils` | **OS を問わず完全同一コードで動作**。<br>公式 Python ライブラリ (`zabbix_utils`) を使用し、Windows / Linux (自宅ラック等) で共通運用したい場合に最適。 |
| **3. Linux Shell 方式**<br>(Linux セキュア環境推奨) | `speedtest_zabbix.sh` | Linux (bash)<br>`zabbix-sender` | **pip インストール禁止・セキュア環境に最適**。<br>OS パッケージマネージャー（`apt` / `dnf`）の `zabbix-sender` のみで動作し、リトライやエラー処理も内包。 |
| **4. ZabbixSender (Win) 方式** | `speedtest.ps1 -SendMethod ZabbixSender` | `zabbix_sender.exe` | Windows 環境で既存の Zabbix Sender バイナリを活用したい場合。 |

---

## 事前準備（ツールのダウンロード）

本リポジトリにはバイナリを含んでいません。以下の公式サイトから最新のツールをダウンロードしてください。

### 1. Ookla Speedtest CLI（必須）
- **公式ダウンロードサイト**: [https://www.speedtest.net/ja/apps/cli](https://www.speedtest.net/ja/apps/cli)
- **Windows**: `speedtest.exe` をダウンロードし、本リポジトリと同じディレクトリに配置するか、PATH の通ったフォルダに配置してください。
- **Linux**:
  ```bash
  # Ubuntu / Debian
  curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
  sudo apt-get install speedtest
  ```

### 2. Zabbix 関連ツール
- **Python 方式を利用する場合**:
  ```bash
  pip install zabbix-utils
  ```
- **ZabbixSender 方式を利用する場合**:
  - **Windows**: [Zabbix 公式ダウンロード (Windows Agents)](https://www.zabbix.com/download_agents) からアーカイブ（ZIP）をダウンロードし、同梱の `zabbix_sender.exe` を配置してください。
  - **Linux**: `sudo apt install zabbix-sender`（または `dnf install zabbix-sender`）

---

## 使い方

### 方式 1: PowerShell ネイティブ送信（Windows 推奨）

```powershell
# 動作確認 (Zabbix への送信なしで画面表示)
.\speedtest.ps1 -DryRun

# 通常実行 (PowerShell ネイティブソケットで送信、外部バイナリ不要)
.\speedtest.ps1

# バッチ経由での実行 (PowerShell 7 優先起動)
speedtest.bat
```

### 方式 2: Python 送信（Linux / Windows 共通推奨）

```bash
# 動作確認
python speedtest_zabbix.py --dry-run

# 通常実行
python speedtest_zabbix.py

# 引数で送信先やホスト名を指定
python speedtest_zabbix.py --server 192.168.1.10 --host MyServer
```

### 方式 3: Linux Shell スクリプト送信（pip 禁止環境・セキュア環境推奨）

```bash
# 実行権限の付与
chmod +x speedtest_zabbix.sh

# 動作確認 (Zabbix への送信を行わず画面表示)
./speedtest_zabbix.sh -d

# 通常実行
./speedtest_zabbix.sh

# 引数でサーバーやホスト名を指定
./speedtest_zabbix.sh -z 192.168.1.10 -s "MyServer"

# （参考）最小限のワンライナー送信
speedtest --format=json --accept-license --accept-gdpr | zabbix_sender -z 52.194.38.180 -s "Speedtest" -k speedtest.json -i -
```

### 方式 4: Windows ZabbixSender バイナリ送信

```powershell
.\speedtest.ps1 -SendMethod ZabbixSender
```

---

## Zabbix テンプレートのインポートと設定

1. Zabbix Web UI の「データ収集 (Data collection)」→「テンプレート (Templates)」を開く。
2. 右上の「インポート (Import)」をクリックし、本リポジトリの `Speedtest.yaml` を選択してインポート。
3. 監視対象のホスト（Windows または Linux）に `Speedtest（Ookla CLI）` テンプレートをリンク。

### 受信アイテム一覧（Zabbix トラッパー）

| アイテムキー | データ型 | 単位 | 説明 |
| :--- | :--- | :--- | :--- |
| `speedtest.download.bps` | 数値 (符号なし) | `bps` | ダウンロード実効速度 |
| `speedtest.upload.bps` | 数値 (符号なし) | `bps` | アップロード実効速度 |
| `speedtest.ping.latency` | 数値 (浮動小数) | `ms` | Ping 遅延時間 |
| `speedtest.ping.jitter` | 数値 (浮動小数) | `ms` | ジッター |
| `speedtest.download.latency` | 数値 (浮動小数) | `ms` | ダウンロード負荷時遅延 (Bufferbloat) |
| `speedtest.upload.latency` | 数値 (浮動小数) | `ms` | アップロード負荷時遅延 (Bufferbloat) |
| `speedtest.packetloss` | 数値 (浮動小数) | `%` | パケットロス率 |
| `speedtest.download.bytes` | 数値 (符号なし) | `B` | ダウンロード通信量 |
| `speedtest.upload.bytes` | 数値 (符号なし) | `B` | アップロード通信量 |
| `speedtest.server.name` | 文字列 | - | 接続先サーバー名 |
| `speedtest.server.id` | 数値 (符号なし) | - | 接続先サーバー ID |
| `speedtest.result.url` | 文字列 | - | 結果 Web 共有 URL |
| `speedtest.json` | テキスト | - | 計測結果生 JSON (マスターアイテム) |

---

## 定期実行（スケジューラ登録）

### Windows タスクスケジューラ
- **プログラム/スクリプト**: `pwsh.exe`（または `powershell.exe`）
- **引数の追加**:
  ```powershell
  -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Path\To\speeadtest_bat\speedtest.ps1"
  ```
- **開始**: `C:\Path\To\speeadtest_bat`
- （※Python 方式の場合は、プログラムに `pythonw.exe`、引数に `C:\Path\To\speeadtest_bat\speedtest_zabbix.py` を指定）

### Linux (cron)

```bash
# パターン A: Linux Shell スクリプト方式 (pip 禁止環境・セキュア環境推奨)
0 * * * * /path/to/speedtest_zabbix.sh > /dev/null 2>&1

# パターン B: Python 方式
0 * * * * python3 /path/to/speedtest_zabbix.py > /dev/null 2>&1

# パターン C: パイプワンライナー方式
0 * * * * speedtest --format=json --accept-license --accept-gdpr | zabbix_sender -z 52.194.38.180 -s "Speedtest" -k speedtest.json -i - > /dev/null 2>&1
```
