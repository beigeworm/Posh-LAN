<#
================================================= Beigeworm's Screen Stream over HTTP ==========================================================

SYNOPSIS
Start up a HTTP server and stream the desktop to a browser window.

USAGE
1. Run this script on target computer and note the URL provided
2. on another device on the same network, enter the provided URL in a browser window

#>

# Setup for the console
[Console]::BackgroundColor = "Black"
Clear-Host
[Console]::SetWindowSize(88, 30)
$windowTitle = "BeigeTools | LAN Tools"
[Console]::Title = $windowTitle
Write-Host "=======================================================================================" -ForegroundColor Green -BackgroundColor Black
Write-Host "============================= Beigeworm's LAN Toolset =================================" -ForegroundColor Green -BackgroundColor Black
Write-Host "=======================================================================================`n" -ForegroundColor Green -BackgroundColor Black
Write-Host "More info at : https://github.com/beigeworm" -ForegroundColor DarkGray
Write-Host "This script will start a local area network toolset.`n"
sleep 1

# Add Libraries
Write-Host "================================== Server Setup =======================================" -ForegroundColor Green
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationCore,PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()


# Admin perms
Write-Host "Checking User Permissions.." -ForegroundColor DarkGray
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Host "Admin privileges needed for this script..." -ForegroundColor Red
    Write-Host "This script will self elevate to run as an Administrator and continue." -ForegroundColor DarkGray
    Write-Host "Sending User Prompt."  -ForegroundColor Green
    $fpath = $PWD.Path
    $fpath | Out-File -FilePath "$env:temp/homepath.txt" -Force
    sleep 1
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    exit
    }
    else{
    sleep 1
    Write-Host "This script is running as Admin!"  -ForegroundColor Green
    if (-Not (Test-Path -Path "$env:temp/homepath.txt")){
    $fpath = Read-Host "Input the local path for the folder you want to host "
    $fpath | Out-File -FilePath "$env:temp/homepath.txt"
    }
    }

# Detect Network Hardware
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

# Root folder setup
Write-Host "===================================== Folder Setup ===================================="  -ForegroundColor Green
Write-Host "Checking folder path.." -ForegroundColor DarkGray
$hpath = Get-Content -Path "$env:temp/homepath.txt"
cd "$hpath"
Write-Host "Setting folder root as : $hpath `n" 
$webroot = New-PSDrive -Name webroot -PSProvider FileSystem -Root $PWD.Path


# Open Port 8080 and start listener
New-NetFirewallRule -DisplayName "AllowWebServer" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow | Out-Null
$webServer = New-Object System.Net.HttpListener 
$webServer.Prefixes.Add("http://"+$loip+":8080/")
$webServer.Prefixes.Add("http://localhost:8080/")
$webServer.Start()
[byte[]]$buffer = $null
Write-Host ("Network Devices Can Reach the server at : http://"+$loip+":8080 `n")
Remove-Item -Path "$env:temp/homepath.txt" -Force

# Functions
Function CommandInput{
# ============================================================== COMMAND PAGE ====================================================================
Function DisplayWebpage {
    $html = "<html><head><style>"
    $html += "body { font-family: Arial, sans-serif; margin: 30px; background-color: #7c7d71; }"
    $html += ".container { display: flex; align-items: center; }"
    $html += "textarea { width: 80%; padding: 10px; font-size: 14px; }"
    $html += "input[type='submit'] { position: relative; top: -12px; margin-left: 30px; padding: 10px 20px; background-color: #cf2b2b; color: #FFF; border: none; border-radius: 5px; font-size: 18px; cursor: pointer; }"
    $html += "button { background-color: #40ad24; color: #FFF; border: none; padding: 5px 10px; border-radius: 4px; cursor: pointer; }"
    $html += ".stop-button { position: relative; top: -5px; font-size: 18px; margin-left: 30px; background-color: #cf2b2b; color: #FFF; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; }"
    $html += "pre { background-color: #f7f7f7; padding: 10px; border-radius: 4px; }"
    $html += "</style></head><body>"
    $html += "<div class='container'><h1> PowerShell Command Input</h1><a href='/stop'><button class='stop-button'>STOP SERVER</button></a></div><ul>"
    $html += "<h3>Command Input</h3>"
    $html += "<form method='post' action='/execute'>"
    $html += "<span><textarea name='command' rows='1' cols='80'></textarea><input type='submit' value='Execute'></span><br>"
    $html += "</form>"
    $html += "<h3>Output</h3><pre name='output' rows='10' cols='80'>$output</pre></body></html>"
    $html += "</body></html>"
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html);
    $ctx.Response.ContentLength64 = $buffer.Length;
    $ctx.Response.OutputStream.WriteAsync($buffer, 0, $buffer.Length)
}

while ($webServer.IsListening){try {$ctx = $webServer.GetContext();

    if ($ctx.Request.RawUrl -eq "/") {
        DisplayWebpage
    }
    elseif ($ctx.Request.RawUrl -eq "/stop") {
        $webServer.Stop();
        Remove-PSDrive -Name webroot -PSProvider FileSystem;
    }
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
    
    }catch [System.Net.HttpListenerException] {Write-Host ($_);}}

}


Function FileServer{
# =============================================================== FILESERVER PAGE ===================================================================
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
    $html += "input[type='submit'] { position: relative; top: -15px; margin-left: 30px; padding: 10px 20px; background-color: #cf2b2b; color: #FFF; border: none; border-radius: 5px; font-size: 18px; cursor: pointer; }"
    $html += "button { background-color: #40ad24; color: #FFF; border: none; padding: 5px 10px; border-radius: 4px; cursor: pointer; }"
    $html += ".stop-button { position: relative; top: -5px; font-size: 18px; margin-left: 30px; background-color: #cf2b2b; color: #FFF; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; }"
    $html += "pre { background-color: #f7f7f7; padding: 10px; border-radius: 4px; }"
    $html += "</style></head><body>"
    $html += "<div class='container'><h1> HTTP File Server</h1><a href='/stop'><button class='stop-button'>STOP SERVER</button></a></div><ul>"
    $html += "<h3> Root Folder Path : $folderPath </h3><ul>"
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
while ($webServer.IsListening){try {$ctx = $webServer.GetContext();
    if ($ctx.Request.RawUrl -eq "/") {
        $files = Get-ChildItem -Path $PWD.Path -Force
        $folderPath = $PWD.Path
        DisplayWebpage
    }
    elseif ($ctx.Request.RawUrl -eq "/stop") {
        $webServer.Stop();
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
    elseif ($ctx.Request.RawUrl -match "^/browse/.+") {
        $folderPath = Join-Path -Path $PWD.Path -ChildPath ($ctx.Request.RawUrl.Replace('%20', ' ') -replace "^/browse", "")
        if ([System.IO.Directory]::Exists($folderPath)) {
        $files = Get-ChildItem -Path $folderPath -Force
        DisplayWebpage
    }}
    }catch [System.Net.HttpListenerException] {Write-Host ($_);}}
}


Function Screenshare{
# =========================================================== SCREENSHARE PAGE ======================================================================
$refreshIntervalInSeconds = 0.5  # Adjust this interval as needed
while ($true) {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $bitmap = New-Object System.Drawing.Bitmap $screen.Bounds.Width, $screen.Bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($screen.Bounds.X, $screen.Bounds.Y, 0, 0, $screen.Bounds.Size)
    $stream = New-Object System.IO.MemoryStream 
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $stream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
    $webServerContext = $webServer.GetContext() 
    $request = $webServerContext.Request
    $response = $webServerContext.Response

        if ($request.RawUrl -eq "/stream") {
            $response.ContentType = "image/png"
            $stream.CopyTo($response.OutputStream)
        }
        else {
            $response.ContentType = "text/html"
            $refreshScript = @"
            <!DOCTYPE html>
            <html>
            <head>
                <title>Streaming Video</title>
                <meta http-equiv='refresh' content='$refreshIntervalInSeconds'>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
              img {
                width: 90vw;
                height: auto;
                max-width: 100%;
                max-height: 100%;
              }
            </style>
            </head>
            <body>
                <img src='/stream' alt='Streaming Video' />
            </body>
            </html>
"@
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($refreshScript)
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        }

    $response.Close()
    $stream.Dispose()
}
} Out-Null

Function Header {
Clear-Host
Write-Host "=======================================================================================" -ForegroundColor Green
Write-Host "============================= Beigeworm's LAN Toolset =================================" -ForegroundColor Green 
Write-Host "=======================================================================================`n" -ForegroundColor Green
}

pause

Header
$Option = Read-Host "============================
1. File Server
2. Screenshare
3. Command Input
============================
Choose an Option"

Header
$hide = Read-Host "Would you like to hide this window (Y/N)"

Header
Write-Host "Loading Script.." -ForegroundColor Yellow
sleep 1

if ($hide -eq 'y'){
$Import = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);';
add-type -name win -member $Import -namespace native;
[native.win]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0);
}

Write-Host ("Network Devices Can Reach the server at : http://"+$loip+":8080") -ForegroundColor Gray

if ($Option -eq '1'){Write-Host "Starting File Server";FileServer}
if ($Option -eq '2'){Write-Host "Starting Screenshare";Screenshare}
if ($Option -eq '3'){Write-Host "Starting Command Input";CommandInput}

# ============================================================ END OF SCRIPT =================================================================

$webServer.Stop()
Write-Host "Server Stopped!" -ForegroundColor Green
Sleep 1