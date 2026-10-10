# AI Agent Setup Guide (Speedtest to Zabbix)

このドキュメントは、別のパソコンや環境で稼働する AI コーディングアシスタント（Antigravity, Cursor, Claude Code, GitHub Copilot 等）が、本リポジトリのセットアップをユーザーと対話しながら自律的に完結させるためのプロトコル定義です。

ユーザーから「セットアップして」「設定して」「動くようにして」と指示された場合は、独断で推測せず、以下の【対話型セットアッププロトコル】に厳密に従ってください。

---

## 対話型セットアッププロトコル

### ステップ 1: 環境の自動調査（ユーザーに質問する前に静かに実行）
まず、以下のコマンドやファイル探索を静かに実行し、環境の現状を把握してください：
1. **OS の判定**: Windows か Linux か
2. **Zabbix Agent 設定ファイルの有無**:
   - Windows: `%ProgramFiles%\Zabbix Agent\zabbix_agentd.conf`, `%ProgramFiles%\Zabbix Agent 2\zabbix_agent2.conf`, `C:\zabbix\zabbix_agentd.conf`
   - Linux: `/etc/zabbix/zabbix_agentd.conf`, `/etc/zabbix/zabbix_agent2.conf`
   - ※存在する場合、サーバー IP (`ServerActive`/`Server`) および `Hostname` は自動取得できるため、ユーザーに尋ねる必要はありません。
3. **`speedtest` CLI の有無**:
   - `speedtest.exe` または `speedtest` コマンドが PATH 上、あるいはリポジトリ内に存在するか確認。

---

### ステップ 2: ユーザーへのヒアリング（最小限の質問）
ステップ 1 で判明しなかった不足情報のみを、番号付きで簡潔にユーザーへ確認してください：

1. **送信先 Zabbix サーバー**:
   - （Zabbix Agent が見つからなかった場合のみ質問）
   - 「送信先 Zabbix サーバーの IP アドレス（またはホスト名）を教えてください（デフォルト: `127.0.0.1`）」
2. **監視ホスト名**:
   - 「Zabbix 上に登録するホスト名を教えてください（デフォルト: `Speedtest`）」
3. **定期実行スケジュール**:
   - 「回線測定の実行頻度はどれにしますか？（推奨: 1時間ごと / 毎日深夜0時 / スケジュール登録なし）」
4. **テンプレートの自動インポート希望有無**:
   - 「Zabbix サーバーへのテンプレート（`Speedtest.yaml`）のインポートとホスト紐付けも AI が行いますか？」
   - 「自動で行う場合は、Zabbix Web の URL（例: `http://192.168.1.10/zabbix`）と **APIトークン** をお知らせください。」

---

### ステップ 2-補足: API トークンの取得方法ガイド（ユーザー案内用）
ユーザーから「APIトークンはどうやって取るの？」と聞かれた場合、またはテンプレート自動登録を案内する際は、以下の手順をユーザーに提示してください：

> **【Zabbix API トークンの取得手順（Zabbix 6.0 / 7.0 共通）】**
> 1. Zabbix Web UI にログインします。
> 2. 画面右上の **ユーザーアイコン（ユーザー設定 / User settings）** をクリックします。
>    - （または、管理者権限がある場合は左メニューの「管理」→「APIトークン」でも可）
> 3. タブの中から **「APIトークン (API tokens)」** を選択します。
> 4. 右上の **「APIトークン作成 (Create API token)」** ボタンをクリックします。
> 5. 設定項目を入力します：
>    - **名前**: 任意の名前（例: `Speedtest Setup`）
>    - **有効期限**: チェックを外すと無期限（一時的なセットアップなら任意の日時）
> 6. **「追加 (Add)」** ボタンをクリックします。
> 7. 画面に一度だけ表示される **「認証トークン (Auth token)」** の長い英数字文字列をコピーして、AI に伝えてください。
>    - ※この画面を閉じると二度と再表示されないため、コピーを忘れないように注意してください。

---

### ステップ 3: ツールの準備と DryRun 検証

1. **Ookla Speedtest CLI が未配置の場合**:
   - **Windows**:
     「公式サイト（ https://www.speedtest.net/ja/apps/cli ）から Windows 用 `speedtest.exe` をダウンロードし、このフォルダに配置してください」と案内し、配置完了を待ちます。
   - **Linux**:
     パッケージマネージャーでのインストールを代行または案内します：
     ```bash
     curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
     sudo apt-get install speedtest
     ```
2. **DryRun テストの実行**:
   - 配置確認後、Zabbix への送信を行わない DryRun でパースが成功するか確認します：
     - Windows: `.\speedtest.ps1 -DryRun`
     - Linux: `./speedtest_zabbix.sh -d`

---

### ステップ 4: セットアップコマンドの実行

ユーザーの回答内容に応じて、同梱の自動セットアップスクリプトを呼び出します：

#### Windows の場合:
```powershell
# 基本セットアップ (毎時0分登録)
.\setup.ps1 -Schedule Hourly

# パラメータやテンプレート登録を含む場合
.\setup.ps1 -ZabbixServer "<IP>" -Hostname "<Host>" -Schedule Hourly -ZabbixUrl "<URL>" -ApiToken "<TOKEN>"
```

#### Linux の場合:
```bash
# 基本セットアップ (毎時0分 cron 登録)
./setup.sh -c hourly

# パラメータやテンプレート登録を含む場合
./setup.sh -z "<IP>" -s "<Host>" -c hourly -u "<URL>" -t "<TOKEN>"
```

---

### ステップ 5: 完了報告

セットアップスクリプトの実行結果を確認し、ユーザーに以下を報告して完了してください：
1. **動作テスト**: 計測とデータパースが正常に完了したこと
2. **スケジューラ登録**: タスクスケジューラ / cron に指定スケジュールで登録されたこと
3. **テンプレート登録結果**:
   - API で登録した場合: テンプレートのインポートとホスト紐付けが成功したこと
   - 手動で行う場合: Zabbix Web UI の [データ収集] → [テンプレート] → [インポート] から `Speedtest.yaml` を登録するよう案内
