# Speedtest to Zabbix

<div align="right">

[![GitHub Release](https://img.shields.io/github/v/release/qryuu/speedtest-to-zabbix?color=blue&label=version)](https://github.com/qryuu/speedtest-to-zabbix/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Zabbix Community Template PR](https://img.shields.io/badge/Zabbix%20Community%20Template-PR%20%23863-orange.svg)](https://github.com/zabbix/community-templates/pull/863)
[![English](https://img.shields.io/badge/Language-English-blue.svg)](#)
[![日本語](https://img.shields.io/badge/Language-%E6%97%A5%E6%9C%AC%E8%AA%9E-lightgrey.svg)](./README.md)

</div>

A lightweight, robust toolset to run Ookla Speedtest CLI periodically on Windows and Linux, parse latency/bandwidth metrics, and push them to a Zabbix server.

> [!TIP]
> **🤖 For AI Coding Assistants (AI-setup-ready)**:  
> If you are using an AI assistant (Antigravity, Cursor, Claude Code, GitHub Copilot, etc.), simply ask: **"Set up this repository"**. The assistant will automatically inspect your environment, guide you through questions, run DryRun tests, register scheduler tasks, and import the Zabbix template. See [`AGENTS.md`](./AGENTS.md) for details.

> [!NOTE]
> **🏛️ Zabbix Community Template Submission**:  
> This template has been submitted to the official Zabbix Community Templates repository: [zabbix/community-templates#863](https://github.com/zabbix/community-templates/pull/863).

---

## Features

- **🤖 AI-Automated Setup**: Fully compliant with [`AGENTS.md`](./AGENTS.md) interactive wizard protocol.
- **Multiple Send Methods**: Choose between native PowerShell (no binaries required), Python (`zabbix-utils`), or Linux Shell (`zabbix-sender`).
- **Clean & Lightweight**: No compiled binaries bundled; download the latest official CLI safely from Ookla.
- **Zabbix 7.0 / 6.0 Unified Template**: Includes `Speedtest.yaml` for both Windows & Linux, complete with an automated Zabbix API import script.
- **Robust Auto-Detection**: Automatically extracts `ServerActive`, `Server`, and `Hostname` from existing `zabbix_agentd.conf` / `zabbix_agent2.conf`. Includes retry logic and JSON validation.

---

## Comparison of Send Methods

| Method | Script / Command | Requirements | Recommended For |
| :--- | :--- | :--- | :--- |
| **1. PowerShell Native**<br>(Recommended for Windows) | `speedtest.ps1`<br>(or `speedtest.bat`) | Windows<br>(PS 5.1 / 7+) | **Zero extra installation**.<br>Sends trapper data directly over .NET TCP sockets without `zabbix_sender.exe` or Python. |
| **2. Python Method**<br>(Recommended for Cross-platform) | `speedtest_zabbix.py` | Python 3.8+<br>`zabbix-utils` | **Identical code on Windows & Linux**.<br>Uses the official `zabbix_utils` library, ideal for multi-OS environments. |
| **3. Linux Shell Method**<br>(Recommended for Secure/Locked Linux) | `speedtest_zabbix.sh` | Linux (bash)<br>`zabbix-sender` | **Strict/pip-restricted environments**.<br>Requires only OS package-managed `zabbix-sender` (`apt` / `dnf`). |
| **4. ZabbixSender (Win)** | `speedtest.ps1 -SendMethod ZabbixSender` | `zabbix_sender.exe` | When you already have the official Zabbix Sender binary on Windows. |

---

## Prerequisites (Download Tools)

This repository does not bundle external binaries. Please download the official tools:

### 1. Ookla Speedtest CLI (Required)
- **Official Download Site**: [https://www.speedtest.net/apps/cli](https://www.speedtest.net/apps/cli)
- **Windows**: Download `speedtest.exe` and place it in this repository folder or anywhere on your `PATH`.
- **Linux**:
  ```bash
  # Ubuntu / Debian
  curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
  sudo apt-get install speedtest
  ```

### 2. Zabbix Tools
- **For Python Method**:
  ```bash
  pip install zabbix-utils
  ```
- **For ZabbixSender Method**:
  - **Windows**: Download from [Zabbix Official Agent Downloads](https://www.zabbix.com/download_agents) and place `zabbix_sender.exe` in the repository.
  - **Linux**: `sudo apt install zabbix-sender` (or `dnf install zabbix-sender`).

---

## Usage

### Auto-Detection & Parameter Resolution Priority

Both server address and host name are resolved using a clear priority chain. **Systems with an existing Zabbix Agent work with zero configuration**, and **systems without an agent can run standalone using device hostnames or arguments**:

#### Hostname Resolution Priority
1. **1st Priority**: Command-line argument (`-Hostname` / `--host` / `-s`)
2. **2nd Priority**: `Hostname` setting in `zabbix_agentd.conf` / `zabbix_agent2.conf`
3. **3rd Priority**: Device Hostname (Windows computer name `$env:COMPUTERNAME` / Linux `hostname`)
4. **Fallback**: **`SpeedtestHost`**

#### Zabbix Server Resolution Priority
1. **1st Priority**: Command-line argument (`-ZabbixServer` / `--server` / `-z`)
2. **2nd Priority**: `ServerActive` (preferred) or `Server` in Zabbix Agent config file
3. **3rd Priority**: Environment variable `ZABBIX_SERVER`
4. **Default**: **`127.0.0.1`** (port `10051`)

```bash
# Example: Setting environment variable in advance
export ZABBIX_SERVER="192.168.1.10"       # Linux / macOS
$env:ZABBIX_SERVER = "192.168.1.10"       # PowerShell
```

---

### Method 1: PowerShell Native (Windows)

```powershell
# Test run (parse JSON without sending to Zabbix)
.\speedtest.ps1 -DryRun

# Standard run (sends to detected server or 127.0.0.1)
.\speedtest.ps1

# Override server and host name explicitly
.\speedtest.ps1 -ZabbixServer 192.168.1.10 -Hostname "MyPC"

# Run via batch wrapper (auto-selects PowerShell 7 or 5.1)
speedtest.bat
speedtest.bat -ZabbixServer 192.168.1.10
```

### Method 2: Python (Cross-platform)

```bash
# Test run
python speedtest_zabbix.py --dry-run

# Standard run
python speedtest_zabbix.py

# Override server and host
python speedtest_zabbix.py --server 192.168.1.10 --host MyServer
```

### Method 3: Linux Shell Script (pip-restricted environments)

```bash
# Grant execution permission
chmod +x speedtest_zabbix.sh

# Test run
./speedtest_zabbix.sh -d

# Standard run
./speedtest_zabbix.sh

# Override server and host
./speedtest_zabbix.sh -z 192.168.1.10 -s "MyServer"

# (Reference) Minimal one-liner pipe
speedtest --format=json --accept-license --accept-gdpr | zabbix_sender -z "<ZabbixServer_IP>" -s "Speedtest" -k speedtest.json -i -
```

### Method 4: Windows ZabbixSender Binary

```powershell
.\speedtest.ps1 -SendMethod ZabbixSender
```

---

## Zabbix Template Import & Configuration

Two template editions are available depending on your preferred language:
- **English edition (Recommended)**: `Speedtest_EN.yaml` (fully compliant with official Zabbix Community Templates)
- **Japanese edition**: `Speedtest.yaml` (item and trigger names in Japanese)

You can import either template into your Zabbix server using automated API scripts or the Web UI.

### Method A: Automated Import via Zabbix API (Recommended)
Use the included scripts to import the template and link it to your target host without opening a browser. The script automatically selects the template matching your OS culture, or you can specify it explicitly via `-Language EN` / `-Language JA`:

```powershell
# Windows (PowerShell) - Automatically selects English unless OS culture is Japanese
.\import_template.ps1 -ZabbixUrl "http://192.168.1.10/zabbix" -ApiToken "<API_TOKEN>" -LinkToHost "Speedtest"

# Explicitly specifying English edition
.\import_template.ps1 -ZabbixUrl "http://192.168.1.10/zabbix" -ApiToken "<API_TOKEN>" -LinkToHost "Speedtest" -Language EN
```

```bash
# Linux / Cross-platform (Python standard library only)
python3 import_template.py -u "http://192.168.1.10/zabbix" -t "<API_TOKEN>" -s "Speedtest"

# Explicitly specifying English edition
python3 import_template.py -u "http://192.168.1.10/zabbix" -t "<API_TOKEN>" -s "Speedtest" -l EN
```

> [!NOTE]
> **How to create a Zabbix API Token (Zabbix 6.0 / 7.0)**:
> 1. Log in to your Zabbix Web UI and click the **User Settings** icon in the top right.
> 2. Open the **API tokens** tab and click **Create API token**.
> 3. Enter a name (e.g. `Speedtest Setup`) and click **Add**.
> 4. Copy the generated **Auth token** string (make sure to copy it before closing the window).

---

### Method B: Manual Web UI Import
1. Navigate to **Data collection** → **Templates** in Zabbix Web UI.
2. Click **Import** in the upper right, choose `Speedtest.yaml`, and confirm.
3. Link the `Speedtest（Ookla CLI）` template to your target host.

---

### Template Item Architecture (Master & Dependent Items)

This template follows Zabbix's best practice: **"Single Master Item (Trapper) + Dependent Items (JSONPATH extraction & calculation)"**. Scripts only send a single `speedtest.json` payload, and Zabbix server automatically extracts and calculates all individual metrics instantaneously.

| Item Key | Item Type | Data Type | Units | Description |
| :--- | :--- | :--- | :--- | :--- |
| `speedtest.json` | **Master (Trapper)** | Text | - | Raw JSON result (scripts send this single item) |
| `speedtest.download.bps` | Dependent (JSONPATH) | Numeric (unsigned) | `bps` | Download bandwidth |
| `speedtest.upload.bps` | Dependent (JSONPATH) | Numeric (unsigned) | `bps` | Upload bandwidth |
| `speedtest.ping.latency` | Dependent (JSONPATH) | Numeric (float) | `ms` | Idle ping latency |
| `speedtest.ping.jitter` | Dependent (JSONPATH) | Numeric (float) | `ms` | Latency jitter |
| `speedtest.download.latency` | Dependent (JSONPATH) | Numeric (float) | `ms` | Latency under download load (Bufferbloat) |
| `speedtest.upload.latency` | Dependent (JSONPATH) | Numeric (float) | `ms` | Latency under upload load (Bufferbloat) |
| `speedtest.packetloss` | Dependent (JSONPATH) | Numeric (float) | `%` | Packet loss percentage |
| `speedtest.download.bytes` | Dependent (JSONPATH) | Numeric (unsigned) | `B` | Total download data transfer |
| `speedtest.upload.bytes` | Dependent (JSONPATH) | Numeric (unsigned) | `B` | Total upload data transfer |
| `speedtest.server.name` | Dependent (JSONPATH) | Character | - | Connected test server name |
| `speedtest.server.id` | Dependent (JSONPATH) | Numeric (unsigned) | - | Connected test server ID |
| `speedtest.result.url` | Dependent (JSONPATH) | Character | - | Ookla web result URL |

---

## Periodic Scheduling

### Using Automated Setup Scripts (Recommended)

One-command setup that verifies CLI execution, performs a DryRun, and schedules recurring jobs:

```powershell
# Windows: Schedules an hourly task in Windows Task Scheduler
.\setup.ps1 -Schedule Hourly

# Full setup including custom server and automated template import
.\setup.ps1 -ZabbixServer "192.168.1.10" -Hostname "MyPC" -Schedule Hourly -ZabbixUrl "http://192.168.1.10/zabbix" -ApiToken "<API_TOKEN>"
```

```bash
# Linux: Schedules an hourly cron job
./setup.sh -c hourly

# Full setup including custom server and automated template import
./setup.sh -z 192.168.1.10 -s MyServer -c hourly -u "http://192.168.1.10/zabbix" -t "<API_TOKEN>"
```

---

### Manual Scheduling

#### Windows Task Scheduler
- **Program/script**: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
  > [!TIP]
  > When using Microsoft Store editions of PowerShell 7 or background non-interactive sessions, relative name `pwsh.exe` may fail to resolve (`0x80070002`). Use the absolute path to Windows built-in `powershell.exe` or full path to standard `pwsh.exe`.
- **Add arguments**:
  ```powershell
  -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Path\To\speedtest-to-zabbix\speedtest.ps1"
  ```
- **Start in**: `C:\Path\To\speedtest-to-zabbix`
- *(For Python method, use full path to `pythonw.exe` and pass `speedtest_zabbix.py` as argument)*

#### Linux (cron)

```bash
# Pattern A: Linux Shell Script (recommended for locked environments)
0 * * * * /path/to/speedtest_zabbix.sh > /dev/null 2>&1

# Pattern B: Python Method
0 * * * * python3 /path/to/speedtest_zabbix.py > /dev/null 2>&1

# Pattern C: One-liner Pipe
0 * * * * speedtest --format=json --accept-license --accept-gdpr | zabbix_sender -z "<ZabbixServer_IP>" -s "Speedtest" -k speedtest.json -i - > /dev/null 2>&1
```

---

## Repository Structure

| File | Purpose |
| :--- | :--- |
| [`README.md`](./README.md) | Japanese documentation |
| [`README_EN.md`](./README_EN.md) | English documentation |
| [`AGENTS.md`](./AGENTS.md) | **AI coding assistant setup protocol** (AI-setup-ready) |
| [`Speedtest.yaml`](./Speedtest.yaml) | Zabbix 7.0 / 6.0 unified template (Japanese edition) |
| [`Speedtest_EN.yaml`](./Speedtest_EN.yaml) | Zabbix 7.0 / 6.0 unified template (English edition / official submission) |
| [`speedtest.ps1`](./speedtest.ps1) | Windows PowerShell sender (native TCP socket & ZabbixSender support) |
| [`speedtest.bat`](./speedtest.bat) | Windows batch wrapper (auto-selects PowerShell 7 or 5.1) |
| [`speedtest_zabbix.py`](./speedtest_zabbix.py) | Cross-platform Python sender (uses official `zabbix-utils`) |
| [`speedtest_zabbix.sh`](./speedtest_zabbix.sh) | Linux shell script (uses `zabbix-sender`, zero pip dependencies) |
| [`setup.ps1`](./setup.ps1) | Windows automated setup wizard (checks, DryRun, Task Scheduler, API import) |
| [`setup.sh`](./setup.sh) | Linux automated setup wizard (checks, DryRun, cron, API import) |
| [`import_template.ps1`](./import_template.ps1) | Zabbix API template importer (PowerShell) |
| [`import_template.py`](./import_template.py) | Zabbix API template importer (Python standard library only) |
| [`LICENSE`](./LICENSE) | MIT License |
