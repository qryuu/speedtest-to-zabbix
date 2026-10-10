# Speedtest to Zabbix

<div align="right">

[![日本語](https://img.shields.io/badge/Language-%E6%97%A5%E6%9C%AC%E8%AA%9E-blue.svg)](#)
[![English](https://img.shields.io/badge/Language-English-lightgrey.svg)](./README_EN.md)

</div>

Windows および Linux 上で Ookla Speedtest CLI を定期実行し、回線計測結果をパースして Zabbix サーバーへ送信するツールセットです。

> [!TIP]
> **🤖 AI コーディングアシスタントをご利用の場合 (AI-setup-ready)**:  
> Antigravity, Cursor, Claude Code, GitHub Copilot などの AI アシスタントに対して**「このリポジトリをセットアップして」**と伝えるだけで、対話形式で環境判定・動作テスト・タスク登録・テンプレートインポートまで自動完了します。詳細は [`AGENTS.md`](./AGENTS.md) をご覧ください。

---

## 特徴

- **🤖 AI 自動セットアップ対応**: [`AGENTS.md`](./AGENTS.md) に基づき、AI アシスタントが対話型ウィザード形式で全自動セットアップ。
- **選べる 3 つの送信方式**: 環境や好みに合わせて、PowerShell / Python / ZabbixSender の中から最適な送信方法を選択可能。
- **軽量リポジトリ**: 実行バイナリを同梱せず、公式最新版を安全にダウンロードして使用する設計。
- **Zabbix 7.0 共通テンプレート付属**: Windows と Linux の両環境を同一の `Speedtest.yaml` テンプレートで監視可能（Zabbix API による自動登録スクリプトも同梱）。
- **ゼロコンフィグ & 堅牢性**: `zabbix_agentd.conf` からのサーバー設定自動読取、および JSON パース・リトライ機構を完備。

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

### Zabbix サーバーおよびホスト名の自動検出（優先順位）
各スクリプトとも、送信先 Zabbix サーバー・ポート・ホスト名は以下の優先順位で自動解決されます。**Zabbix Agent が既に導入されている環境では完全なゼロコンフィグ（設定不要）で動作**し、**Agent 未導入の環境でもマシンのホスト名等を自動採用して単体で動作**します：

#### 監視ホスト名 (Hostname) の解決ルール
1. **第1優先（最優先）**: コマンドライン引数 (`-Hostname` / `--host` / `-s`)
2. **第2優先**: Zabbix Agent 設定ファイル (`zabbix_agentd.conf` / `zabbix_agent2.conf`) の `Hostname`
3. **第3優先**: デバイスのマシン名（Windows コンピューター名 `$env:COMPUTERNAME` / Linux ホスト名 `hostname`）
4. **フォールバック**: **`SpeedtestHost`**

#### 送信先サーバー (Zabbix Server) の解決ルール
1. **第1優先（最優先）**: コマンドライン引数 (`-ZabbixServer` / `--server` / `-z`)
2. **第2優先**: Zabbix Agent 設定ファイルの `ServerActive`（アクティブ送信先、優先）または `Server`
3. **第3優先**: 環境変数 `ZABBIX_SERVER`
4. **デフォルト値**: **`127.0.0.1`**（ポート: `10051`）

```bash
# Agent 未導入環境などで環境変数を事前指定しておく例
export ZABBIX_SERVER="192.168.1.10"       # Linux / macOS
$env:ZABBIX_SERVER = "192.168.1.10"       # PowerShell
```

---

### 方式 1: PowerShell ネイティブ送信（Windows 推奨）

```powershell
# 動作確認 (Zabbix への送信なしで画面表示)
.\speedtest.ps1 -DryRun

# 通常実行 (ローカルホスト 127.0.0.1 または環境変数 ZABBIX_SERVER へ送信)
.\speedtest.ps1

# 引数で直接サーバー IP を指定して実行
.\speedtest.ps1 -ZabbixServer 192.168.1.10 -Hostname "MyPC"

# バッチ経由での実行 (PowerShell 7 優先起動)
speedtest.bat
speedtest.bat -ZabbixServer 192.168.1.10
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

# （参考）最小限のワンライナー送信 (サーバーIPを指定)
speedtest --format=json --accept-license --accept-gdpr | zabbix_sender -z "<ZabbixServer_IP>" -s "Speedtest" -k speedtest.json -i -
```

### 方式 4: Windows ZabbixSender バイナリ送信

```powershell
.\speedtest.ps1 -SendMethod ZabbixSender
```

---

---

## Zabbix テンプレートのインポートと設定

テンプレート `Speedtest.yaml` は以下のいずれかの方法で Zabbix サーバーへ登録できます。

### 方法 A: Zabbix API で自動インポート（推奨）
同梱のインポートスクリプトを使用すると、Web ブラウザを開かずにテンプレートのインポートとホストへの紐付けが完了します。

```powershell
# Windows (PowerShell)
.\import_template.ps1 -ZabbixUrl "http://192.168.1.10/zabbix" -ApiToken "<API_TOKEN>" -LinkToHost "Speedtest"
```

```bash
# Linux / クロスプラットフォーム (Python 標準ライブラリのみで動作)
python3 import_template.py -u "http://192.168.1.10/zabbix" -t "<API_TOKEN>" -s "Speedtest"
```

> [!NOTE]
> **API トークンの取得方法 (Zabbix 6.0 / 7.0 共通)**:
> 1. Zabbix Web UI にログインし、右上の **ユーザー設定アイコン** をクリック。
> 2. **「APIトークン (API tokens)」** タブを選択し、右上の **「APIトークン作成 (Create API token)」** をクリック。
> 3. 任意の名前（例: `Speedtest Setup`）を入力して「追加」をクリック。
> 4. 表示された **認証トークン文字列** をコピーして使用します。

---

### 方法 B: Zabbix Web UI で手動インポート
1. Zabbix Web UI の「データ収集 (Data collection)」→「テンプレート (Templates)」を開く。
2. 右上の「インポート (Import)」をクリックし、本リポジトリの `Speedtest.yaml` を選択してインポート。
3. 監視対象のホスト（Windows または Linux）に `Speedtest（Ookla CLI）` テンプレートをリンク。

---

### アイテム構成一覧（マスターアイテム & 依存アイテム設計）

本テンプレートは、Zabbix 推奨の **「マスターアイテム（生 JSON 1 回受信）＋ 依存アイテム（JSONPATH 自動抽出・計算）」** アーキテクチャを採用しています。各スクリプトは `speedtest.json` 1 件のみを送信し、Zabbix サーバー側で全指標が即時展開されます。

| アイテムキー | アイテムタイプ | データ型 | 単位 | 説明 |
| :--- | :--- | :--- | :--- | :--- |
| `speedtest.json` | **マスター (トラッパー)** | テキスト | - | 計測結果の生 JSON（各スクリプトからこれを受信） |
| `speedtest.download.bps` | 依存アイテム (JSONPATH) | 数値 (符号なし) | `bps` | ダウンロード実効速度 |
| `speedtest.upload.bps` | 依存アイテム (JSONPATH) | 数値 (符号なし) | `bps` | アップロード実効速度 |
| `speedtest.ping.latency` | 依存アイテム (JSONPATH) | 数値 (浮動小数) | `ms` | Ping 遅延時間 |
| `speedtest.ping.jitter` | 依存アイテム (JSONPATH) | 数値 (浮動小数) | `ms` | ジッター |
| `speedtest.download.latency` | 依存アイテム (JSONPATH) | 数値 (浮動小数) | `ms` | ダウンロード負荷時遅延 (Bufferbloat) |
| `speedtest.upload.latency` | 依存アイテム (JSONPATH) | 数値 (浮動小数) | `ms` | アップロード負荷時遅延 (Bufferbloat) |
| `speedtest.packetloss` | 依存アイテム (JSONPATH) | 数値 (浮動小数) | `%` | パケットロス率 |
| `speedtest.download.bytes` | 依存アイテム (JSONPATH) | 数値 (符号なし) | `B` | ダウンロード通信量 |
| `speedtest.upload.bytes` | 依存アイテム (JSONPATH) | 数値 (符号なし) | `B` | アップロード通信量 |
| `speedtest.server.name` | 依存アイテム (JSONPATH) | 文字列 | - | 接続先サーバー名 |
| `speedtest.server.id` | 依存アイテム (JSONPATH) | 数値 (符号なし) | - | 接続先サーバー ID |
| `speedtest.result.url` | 依存アイテム (JSONPATH) | 文字列 | - | 結果 Web 共有 URL |

---

## 定期実行（スケジューラ登録）

### 自動セットアップスクリプトを使う場合（推奨）

ワンライナーで動作検証から定期実行登録まで自動化されます：

```powershell
# Windows: 毎時0分のタスクスケジューラ登録を一括実行
.\setup.ps1 -Schedule Hourly

# Zabbix サーバー指定およびテンプレート登録も同時に行う例
.\setup.ps1 -ZabbixServer "192.168.1.10" -Hostname "MyPC" -Schedule Hourly -ZabbixUrl "http://192.168.1.10/zabbix" -ApiToken "<API_TOKEN>"
```

```bash
# Linux: 毎時0分の cron 登録を一括実行
./setup.sh -c hourly

# Zabbix サーバー指定およびテンプレート登録も同時に行う例
./setup.sh -z 192.168.1.10 -s MyServer -c hourly -u "http://192.168.1.10/zabbix" -t "<API_TOKEN>"
```

---

### 手動でスケジューラ登録する場合

#### Windows タスクスケジューラ
- **プログラム/スクリプト**: `pwsh.exe`（または `powershell.exe`）
- **引数の追加**:
  ```powershell
  -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Path\To\speedtest-to-zabbix\speedtest.ps1"
  ```
- **開始**: `C:\Path\To\speedtest-to-zabbix`
- （※Python 方式の場合は、プログラムに `pythonw.exe`、引数に `C:\Path\To\speedtest-to-zabbix\speedtest_zabbix.py` を指定）

#### Linux (cron)

```bash
# パターン A: Linux Shell スクリプト方式 (pip 禁止環境・セキュア環境推奨)
0 * * * * /path/to/speedtest_zabbix.sh > /dev/null 2>&1

# パターン B: Python 方式
0 * * * * python3 /path/to/speedtest_zabbix.py > /dev/null 2>&1

# パターン C: パイプワンライナー方式
0 * * * * speedtest --format=json --accept-license --accept-gdpr | zabbix_sender -z "<ZabbixServer_IP>" -s "Speedtest" -k speedtest.json -i - > /dev/null 2>&1
```

---

## リポジトリ構成一覧

| ファイル | 役割・説明 |
| :--- | :--- |
| [`AGENTS.md`](./AGENTS.md) | **AI コーディングアシスタント向け対話指示書** (AI-setup-ready プロトコル) |
| [`Speedtest.yaml`](./Speedtest.yaml) | Zabbix 7.0 共通監視テンプレート (トラッパーアイテム群 & 自動計算) |
| [`speedtest.ps1`](./speedtest.ps1) | Windows 用 PowerShell 送信スクリプト (ソケット送信 / ZabbixSender 兼用) |
| [`speedtest.bat`](./speedtest.bat) | Windows 用実行ラッパーバッチ (PowerShell 7 / 5.1 振り分け) |
| [`speedtest_zabbix.py`](./speedtest_zabbix.py) | Linux / Windows 共通 Python 送信スクリプト (`zabbix-utils` 使用) |
| [`speedtest_zabbix.sh`](./speedtest_zabbix.sh) | Linux 用シェルスクリプト (`zabbix-sender` 使用・pip 不要) |
| [`setup.ps1`](./setup.ps1) | Windows 自動セットアップスクリプト (検証・タスク登録・テンプレート登録) |
| [`setup.sh`](./setup.sh) | Linux 自動セットアップスクリプト (検証・cron 登録・テンプレート登録) |
| [`import_template.ps1`](./import_template.ps1) | Zabbix API テンプレート自動登録スクリプト (PowerShell 版) |
| [`import_template.py`](./import_template.py) | Zabbix API テンプレート自動登録スクリプト (Python 標準ライブラリ版) |
| [`README.md`](./README.md) | プロジェクト仕様書・マニュアル (日本語) |
| [`README_EN.md`](./README_EN.md) | Project Documentation (English) |

