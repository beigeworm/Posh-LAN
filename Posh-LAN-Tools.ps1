<# ================================================= Powershell LAN Toolset ==========================================================

SYNOPSIS
Start up a HTTP server and run a selection of Local Area Network Tools.

USAGE
1. Run this script on target computer and note the URL provided
2. on another device on the same network, enter the provided URL in a browser window
#>

# Setup for the console
[Console]::BackgroundColor = "Black"
Clear-Host
[Console]::SetWindowSize(78, 30)
$windowTitle = "BeigeTools | LAN Tools"
[Console]::Title = $windowTitle

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MouseSimulator {
    [DllImport("user32.dll", CharSet=CharSet.Auto, CallingConvention=CallingConvention.StdCall)]
    public static extern void mouse_event(long dwFlags, long dx, long dy, long cButtons, long dwExtraInfo);

    public const int MOUSEEVENTF_LEFTDOWN = 0x02;
    public const int MOUSEEVENTF_LEFTUP = 0x04;
    public const int MOUSEEVENTF_RIGHTDOWN = 0x08;
    public const int MOUSEEVENTF_RIGHTUP = 0x10;

    public static void LeftClick() {
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
        System.Threading.Thread.Sleep(50);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
    }

    public static void RightClick() {
        mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0);
        System.Threading.Thread.Sleep(50);
        mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0);
    }
}
"@


# Escape to exit key detection
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Keyboard
{
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
}
"@
$VK_ESCAPE = 0x1B
$startTime = $null


Function Header {
Clear-Host
Write-Host "=============================================================================" -ForegroundColor Green
Write-Host "======================== Beigeworm's LAN Toolset ============================" -ForegroundColor Green 
Write-Host "=============================================================================" -ForegroundColor Green
Write-Host "More info `@ https://github.com/beigeworm`n" -ForegroundColor DarkGray
}

Header
Write-Host "This script will start a local area network toolset.`n"
sleep 1

# Add Libraries
Write-Host "============================= Server Setup ==================================" -ForegroundColor Green
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationCore,PresentationFramework
[System.Windows.Forms.Application]::EnableVisualStyles()

# Check for Admin perms and stager indicator ($stage = 'y')
Write-Host "Checking User Permissions.." -ForegroundColor DarkGray
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Host "Admin privileges needed for this script..." -ForegroundColor Red
    Write-Host "This script will self elevate to run as an Administrator and continue." -ForegroundColor DarkGray
    Write-Host "Sending User Prompt."  -ForegroundColor Green
    $fpath = $PWD.Path
    $fpath | Out-File -FilePath "$env:temp/homepath.txt" -Force
    sleep 1
    if ($stage -eq 'y'){
        Start-Process PowerShell.exe -ArgumentList ("-NoP -Ep Bypass -C `$stage = 'y'; irm https://raw.githubusercontent.com/beigeworm/Posh-LAN/main/Posh-LAN-Tools.ps1 | iex") -Verb RunAs
    }
    else{
        Start-Process PowerShell.exe -ArgumentList ("-NoP -Ep Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    }
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
Write-Host "=============================== Folder Setup ================================"  -ForegroundColor Green
Write-Host "Checking folder path.." -ForegroundColor DarkGray
$hpath = Get-Content -Path "$env:temp/homepath.txt"
cd "$hpath"
Write-Host "Setting folder root as : $hpath" -ForegroundColor Cyan
$webroot = New-PSDrive -Name webroot -PSProvider FileSystem -Root $PWD.Path
[byte[]]$buffer = $null
# Open Port 8080 and start listener
Write-Host "=============================== Network Setup ==============================="  -ForegroundColor Green
Write-Host "Opening Firewall at Port 8080" -ForegroundColor DarkGray
New-NetFirewallRule -DisplayName "AllowWebServer" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow | Out-Null
$webServer = New-Object System.Net.HttpListener 
$webServer.Prefixes.Add("http://"+$loip+":8080/")
$webServer.Prefixes.Add("http://localhost:8080/")
Write-Host "Starting HTTP Server.." -ForegroundColor DarkGray
$webServer.Start()
Write-Host ("Other Network Devices Can Reach the Server At : http://"+$loip+":8080 `n") -ForegroundColor Cyan
Remove-Item -Path "$env:temp/homepath.txt" -Force

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
    $html += "button { background-color: #40ad24; color: #FFF; border: none; padding: 5px 10px; border-radius: 4px; cursor: pointer; }"
    $html += ".stop-button { position: relative; top: -5px; font-size: 18px; margin-left: 30px; background-color: #cf2b2b; color: #FFF; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; }"
    $html += "</style></head><body>"

    $html += "<div class='container'><h1> Simple HTTP Server</h1><a href='/stop'><button class='stop-button'>STOP SERVER</button></a></div>"

    # Add "Go Up" button if not in root directory
    if ($folderPath -ne (Get-Location).Path) {
        $parentFolder = (Get-Item $folderPath).Parent.FullName
        $parentUrl = "/browse" + $parentFolder.Replace(' ', '%20') -replace [regex]::Escape($PWD.Path.Replace(' ', '%20')), ""
        $html += "<div class='container'><a href='$parentUrl'><button>â¬† Go Up</button></a></div>"
    }

    $html += "<h3> Root Folder Path : $folderPath </h3><ul>"
    $html += "<ul><table>"
    $html += "<thead><tr><th> FOLDERS</th></tr></thead><tbody>"

    foreach ($file in $files) {
        $fileUrl = $file.FullName.Replace(' ', '%20') -replace [regex]::Escape($PWD.Path.Replace(' ', '%20')), ''
        if ($file.PSIsContainer) {
            $html += "<tr><td><a href='/browse$fileUrl'><button>Open Folder</button></a><a>$file</a></td></tr>"
        }
    }

    $html += "</tbody></table>"
    $html += "<ul><table>"
    $html += "<thead><tr><th> FILES</th><th>Size</th><th>Type</th><th>Created</th><th>Last Modified</th></tr></thead><tbody>"

    foreach ($file in $files) {
        $fileUrl = $file.FullName.Replace(' ', '%20') -replace [regex]::Escape($PWD.Path.Replace(' ', '%20')), ''
        $fileDetails = "<td>$(Format-FileSize $file.Length)</td><td>$($file.Extension)</td><td>$($file.CreationTime)</td><td>$($file.LastWriteTime)</td>"
        if (-not $file.PSIsContainer) {
            $html += "<tr><td><a href='/download$fileUrl'><button>Download</button></a><a>$file</a></td>$fileDetails</tr>"
        }
    }

    $html += "</tbody></table>"
    $html += "</ul>"
    $html += "</body></html>"

    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html);
    $ctx.Response.ContentLength64 = $buffer.Length;
    $ctx.Response.OutputStream.WriteAsync($buffer, 0, $buffer.Length)
}
while ($webServer.IsListening){

try {$ctx = $webServer.GetContext();
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


function Start-Streaming {
    param ($context, $imgWidth, $imgHeight)

    $streamRunspace = [runspacefactory]::CreateRunspace()
    $streamRunspace.Open()
    $streamPowerShell = [powershell]::Create().AddScript({
        param ($context, $imgWidth, $imgHeight)
        $response = $context.Response
        $response.ContentType = "multipart/x-mixed-replace; boundary=frame"
        $response.Headers.Add("Cache-Control", "no-cache")
        $boundary = "--frame"

        try {
            while ($response.OutputStream.CanWrite) {
                $screen = [System.Windows.Forms.Screen]::PrimaryScreen
                $bitmap = New-Object System.Drawing.Bitmap $screen.Bounds.Width, $screen.Bounds.Height
                $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
                $graphics.CopyFromScreen($screen.Bounds.X, $screen.Bounds.Y, 0, 0, $screen.Bounds.Size)

                $stream = New-Object System.IO.MemoryStream
                $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
                $bitmap.Dispose()
                $graphics.Dispose()

                $bytes = $stream.ToArray()
                $stream.Dispose()

                $writer = [System.Text.Encoding]::ASCII.GetBytes("$boundary`r`nContent-Type: image/png`r`nContent-Length: $($bytes.Length)`r`n`r`n")
                $response.OutputStream.Write($writer, 0, $writer.Length)
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                $boundaryWriter = [System.Text.Encoding]::ASCII.GetBytes("`r`n")
                $response.OutputStream.Write($boundaryWriter, 0, $boundaryWriter.Length)

                Start-Sleep -Milliseconds 100

            }
        } catch {
            Write-Host "Stream closed: $_"
        } finally {
            $response.OutputStream.Close()
        }
    }).AddArgument($context).AddArgument($imgWidth).AddArgument($imgHeight)

    $streamPowerShell.Runspace = $streamRunspace
    $streamPowerShell.BeginInvoke()
}


Function Screenshare{

$screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
$screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
$imgWidth = $screenWidth
$imgHeight = $screenHeight

while ($true) {

    # Check for the escape key press to exit
    $isEscapePressed = [Keyboard]::GetAsyncKeyState($VK_ESCAPE) -lt 0
    if ($isEscapePressed) {
        if (-not $startTime) {
            $startTime = Get-Date
        }
        $elapsedTime = (Get-Date) - $startTime
        if ($elapsedTime.TotalSeconds -ge 5) {
            (New-Object -ComObject Wscript.Shell).Popup("Screenshare Closed.",3,"Information",0x0)
            sleep 1
            exit
        }
    } else {
        $startTime = $null
    }


    try {
        $context = $webServer.GetContext()
        $request = $context.Request
        $response = $context.Response

        if ($request.RawUrl.StartsWith("/stream?")) {
            $query = $request.RawUrl -replace "/stream\?", ""
            $params = $query -split "&"
            $imgWidth = ($params -match "w=").Split("=")[1]
            $imgHeight = ($params -match "h=").Split("=")[1]
        
            if (-not $imgHeight -or $imgHeight -eq "0") {
                Write-Host "Received imgHeight = 0, defaulting to screen height: $screenHeight"
                $imgHeight = $screenHeight
            }
        
            Write-Host "Stream started with img size: ${imgWidth}x${imgHeight}"
            Start-Streaming -context $context -imgWidth $imgWidth -imgHeight $imgHeight
        
                }
        
        elseif ($request.RawUrl.StartsWith("/keypress")) {
            $query = $request.RawUrl -replace "/keypress\?", ""
            $params = $query -split "&"
            $key = ($params -match "key=").Split("=")[1]
        
            if ($key) {
                $decodedKey = [System.Web.HttpUtility]::UrlDecode($key)
        
                switch ($decodedKey) {
                    "Backspace" { $decodedKey = "{BACKSPACE}" }
                    "Enter" { $decodedKey = "{ENTER}" }
                }
        
                Write-Host "Key Pressed: $decodedKey"
                [System.Windows.Forms.SendKeys]::SendWait($decodedKey)
            }
        
            $response.StatusCode = 200
            $response.Close()
        }
        
        
        elseif ($request.RawUrl.StartsWith("/move")) {
            $query = $request.RawUrl -replace "/move\?", ""
            $params = $query -split "&"
            $moveX = ($params -match "x=").Split("=")[1]
            $moveY = ($params -match "y=").Split("=")[1]
        
            if ($moveX -and $moveY -and $imgWidth -and $imgHeight) {
                $scaledX = [math]::Round(($moveX / $imgWidth) * $screenWidth)
                $scaledY = [math]::Round(($moveY / $imgHeight) * $screenHeight)
        
                Write-Host "Move at Browser: ($moveX, $moveY) -> Adjusted to: ($scaledX, $scaledY)"
                [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($scaledX, $scaledY)
            }
        
            $response.StatusCode = 200
            $response.Close()
        }

        elseif ($request.RawUrl.StartsWith("/click")) {
            $query = $request.RawUrl -replace "/click\?", ""
            $params = $query -split "&"
            $clickX = ($params -match "x=").Split("=")[1]
            $clickY = ($params -match "y=").Split("=")[1]

            if ($clickX -and $clickY -and $imgWidth -and $imgHeight) {
                $scaledX = [math]::Round(($clickX / $imgWidth) * $screenWidth)
                $scaledY = [math]::Round(($clickY / $imgHeight) * $screenHeight)

                Write-Host "Click at Browser: ($clickX, $clickY) -> Adjusted to: ($scaledX, $scaledY)"
                [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($scaledX, $scaledY)
                [MouseSimulator]::LeftClick()
            }

            $response.StatusCode = 200
            $response.Close()
        }
        
        else {
            $response.ContentType = "text/html"
            $html = @"
            <!DOCTYPE html>
            <html>
            <head>
                <title>Remote Desktop</title>
                <script>
                    function sendMove(event) {
                        let img = document.getElementById("stream");
                        let rect = img.getBoundingClientRect();
                        let x = event.clientX - rect.left;
                        let y = event.clientY - rect.top;
                        fetch('/move?x=' + x + '&y=' + y);
                    }
                    function updateStreamSize() {
                        let img = document.getElementById("stream");
                        let w = img.clientWidth;
                        let h = img.clientHeight;
                        img.src = '/stream?w=' + w + '&h=' + h;
                    }
                    function sendClick(event) {
                        let img = document.getElementById("stream");
                        let rect = img.getBoundingClientRect();
                        let x = event.clientX - rect.left;
                        let y = event.clientY - rect.top;
                        fetch('/click?x=' + x + '&y=' + y);
                    }
                    function sendKeyPress(event) {
                        let key = encodeURIComponent(event.key);
                        fetch('/keypress?key=' + key);
                    }

                    window.onload = () => {
                        setTimeout(() => {
                            let img = document.getElementById("stream");
                            img.addEventListener('mousemove', sendMove);
                            img.addEventListener('keydown', sendKeyPress);
                            img.src = "/stream";
                            updateStreamSize();
                            img.setAttribute("tabindex", "0");
                            img.focus();
                        }, 500);
                        updateStreamSize();
                        updateStreamSize();
                        updateStreamSize();
                    };

                    window.onresize = updateStreamSize;
                </script>
                <style>
                    body { background-color: black; margin: 0; display: flex; justify-content: center; align-items: center; height: 100vh; }
                    img { min-height: 500px; display: block; width: 90vw; height: auto; max-width: 100%; max-height: 100%; cursor: pointer; }
                </style>
            </head>
            <body>
                <img id="stream" onclick="sendClick(event)" />
            </body>
            </html>
"@
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.Close()
        }
    } 
    catch {
        Write-Host "Error encountered: $_"
    }
}

$webServer.Stop()
}


# ==================================================== MAIN WAIT LOOP ============================================================

Write-Host "============================== Setup Complete ==============================="  -ForegroundColor Green
pause

Header
$Option = Read-Host "===========================================================
1. File Server - Share files from $hpath
2. Screenshare - Show $env:COMPUTERNAME's screen
3. Exit
===========================================================
Choose an Option"

Header
if (!($Option -eq '5')){
$hide = Read-Host "Would you like to hide this window (Y/N)"
}

Header
Write-Host "Loading Script.." -ForegroundColor Yellow
sleep 1

if ($hide -eq 'y'){
$Async = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
$Type = Add-Type -MemberDefinition $Async -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
$hwnd = (Get-Process -PID $pid).MainWindowHandle
    if($hwnd -ne [System.IntPtr]::Zero){
        $Type::ShowWindowAsync($hwnd, 0)
    }
    else{
        $Host.UI.RawUI.WindowTitle = 'hideme'
        $Proc = (Get-Process | Where-Object { $_.MainWindowTitle -eq 'hideme' })
        $hwnd = $Proc.MainWindowHandle
        $Type::ShowWindowAsync($hwnd, 0)
    }
}

Write-Host ("Network Devices Can Reach the server at : http://"+$loip+":8080") -ForegroundColor Gray

if ($Option -eq '1'){Write-Host "Starting File Server";FileServer}
if ($Option -eq '2'){Write-Host "Starting Screenshare";Screenshare}
if ($Option -eq '5'){Write-Host "Closing Beigeworm's LAN Toolset.."}
# ============================================================ END OF SCRIPT =================================================================

$webServer.Stop()
Write-Host "Server Stopped!" -ForegroundColor Green
Sleep 1

