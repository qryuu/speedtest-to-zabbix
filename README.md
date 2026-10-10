# Speedtest to Zabbix Sender

Windows 上で Ookla Speedtest CLI を定期実行し、計測結果をパースして Zabbix サーバーへ一括送信するスクリプトです。

---

## 概要

従来のバッチファイル（`.bat`）で発生していた **JSON のクォート展開破綻** や **Speedtest CLI の初回ライセンス表示によるパース失敗** を解消するため、PowerShell 実装に刷新しました。

- `speedtest.exe` から JSON 行のみを安全に抽出・パース。
- Bandwidth (Byte/s) から bps / Mbps を自動計算。
- `zabbix_sender.exe` の入力ファイル機能 (`-i`) を使用し、1 回の通信で全メトリクスを一括送信。
- 生の JSON（`speedtest.json`）と個別メトリクスの両方を同時に送信するため、Zabbix 側のアイテム構成（単一アイテム＋JSONPath、または個別アイテムトラッパー）のどちらでも対応可能。

---

## ファイル構成

| ファイル | 概要 |
| :--- | :--- |
| `speedtest.ps1` | メインの PowerShell スクリプト |
| `speedtest.bat` | PowerShell スクリプトを実行するバッチラッパー |
| `speadtest.bat` | 従来のバッチファイル名互換用ラッパー |
| `speedtest.exe` | Ookla Speedtest CLI（Windows x64） |
| `zabbix_sender.exe` | Zabbix Sender（Windows x64） |
| `speedtest.md` | Speedtest CLI 公式ドキュメント |

---

## 使い方

### 1. 動作確認（DryRun）
Zabbix サーバーへ送信せず、計測とパース結果のみをコンソールに出力します。

```powershell
.\speedtest.ps1 -DryRun
```

### 2. 通常実行（Zabbix へ送信）

```powershell
.\speedtest.ps1
```

引数を省略した場合、スクリプト内のデフォルト値（`ZabbixServer: 52.194.38.180`, `Hostname: Speedtest`）で送信されます。

### 3. オプション引数を指定した実行

```powershell
.\speedtest.ps1 -ZabbixServer 192.168.1.10 -Hostname MyPC -DryRun
```

### 4. バッチファイル経由での実行
タスクスケジューラなどで `.bat` を呼び出す場合もそのまま実行可能です。

```cmd
speedtest.bat
rem 引数もそのまま引き渡せます
speedtest.bat -DryRun
```

---

## Zabbix 側で受信可能なアイテムキー一覧

タイプ: **Zabbix トラッパー** (Zabbix trapper)

| アイテムキー | データ型 | 単位 | 説明 |
| :--- | :--- | :--- | :--- |
| `speedtest.ping.latency` | 数値 (浮動小数) | `ms` | Ping 遅延時間 |
| `speedtest.ping.jitter` | 数値 (浮動小数) | `ms` | Ping ジッター |
| `speedtest.download.bps` | 数値 (符号なし) | `bps` | ダウンロード速度 (bps) |
| `speedtest.download.mbps` | 数値 (浮動小数) | `Mbps` | ダウンロード速度 (Mbps) |
| `speedtest.upload.bps` | 数値 (符号なし) | `bps` | アップロード速度 (bps) |
| `speedtest.upload.mbps` | 数値 (浮動小数) | `Mbps` | アップロード速度 (Mbps) |
| `speedtest.download.bytes` | 数値 (符号なし) | `B` | ダウンロード通信量 |
| `speedtest.upload.bytes` | 数値 (符号なし) | `B` | アップロード通信量 |
| `speedtest.packetloss` | 数値 (浮動小数) | `%` | パケットロス率 |
| `speedtest.server.name` | 文字列 | - | 接続先 Speedtest サーバー名 |
| `speedtest.server.id` | 数値 (符号なし) | - | 接続先サーバー ID |
| `speedtest.result.url` | 文字列 | - | 計測結果 URL (Web 共有用) |
| `speedtest.json` | テキスト | - | 計測結果の生 JSON (依存アイテム/JSONPath 用) |

---

## Windows タスクスケジューラでの定期実行設定

1. **タスクスケジューラ**（`taskschd.msc`）を開く。
2. 「タスクの作成」を選択。
3. **全般**:
   - 名前: `Speedtest to Zabbix`
   - 「最上位の特権で実行する」にチェック。
4. **トリガー**:
   - 毎日、または「繰り返し間隔: 1時間」など任意の頻度を設定。
5. **操作**:
   - 操作: `プログラムの開始`
   - プログラム/スクリプト: `pwsh.exe`（PowerShell 7 系）または `powershell.exe`（5.1 系）
     ※または直接バッチファイルを指定: `C:\Path\To\speeadtest_bat\speedtest.bat`
   - 引数の追加: `-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Path\To\speeadtest_bat\speedtest.ps1"`
   - 開始 (オプション): `C:\Path\To\speeadtest_bat`
