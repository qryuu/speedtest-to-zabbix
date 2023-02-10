@echo off
setlocal
cd /d %~dp0

set ZabbixServer=52.194.38.180
set Hostname=Speedtest
set Itemkey=speedtest.json

for /f "usebackq delims=" %%A in (`speedtest.exe -f json`) do set speedtestout=%%A

echo %speedtestout%
call zabbix_sender.exe -z %ZabbixServer% -s %Hostname% -k %Itemkey% -o %speedtestout%