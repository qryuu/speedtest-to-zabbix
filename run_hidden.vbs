' Speedtest to Zabbix - Silent Execution Wrapper
' Runs PowerShell without flashing any console window
Option Explicit
Dim objShell, strCommand, i
Set objShell = CreateObject("WScript.Shell")
strCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass"
For i = 0 To WScript.Arguments.Count - 1
    strCommand = strCommand & " """ & WScript.Arguments(i) & """"
Next
objShell.Run strCommand, 0, True