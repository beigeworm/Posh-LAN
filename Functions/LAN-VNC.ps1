<#
================================================= Beigeworm's VNC over HTTP ==========================================================

SYNOPSIS
Start up a HTTP server and stream the desktop to a browser window on another device on LAN with basic mouse and keyboard functionality.

USAGE
1. Run this script on target computer and note the URL provided
2. On another device on the same network, enter the provided URL in a browser window
3. Hold escape key on target for 5 seconds to exit screenshare.

#>

# Hide the powershell console (1 = yes)
$hide = 1

[Console]::BackgroundColor = "Black"
Clear-Host
[Console]::SetWindowSize(88,30)
[Console]::Title = "VNC over LAN"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationCore,PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

# Define port number
if ($port.length -lt 1){
    $port = 8080
}

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


If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -Ep Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
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

$port = 8080

# Get primary network interface and IP
$networkInterfaces = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Virtual' }
$filteredInterfaces = $networkInterfaces | Where-Object { $_.Name -match 'Wi*' -or  $_.Name -match 'Eth*'}
$primaryInterface = $filteredInterfaces | Select-Object -First 1
if ($primaryInterface) {
    if ($primaryInterface.Name -match 'Wi*') {
        $localIP = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi*" | Select-Object -ExpandProperty IPAddress
    } elseif ($primaryInterface.Name -match 'Eth*') {
        $localIP = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Eth*" | Select-Object -ExpandProperty IPAddress
    }
}

New-NetFirewallRule -DisplayName "AllowWebServer" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow | Out-Null

$webServer = New-Object System.Net.HttpListener 
$webServer.Prefixes.Add("http://$localIP`:$port/")
$webServer.Prefixes.Add("http://localhost`:$port/")
$webServer.Start()

Write-Host "Server started at http://$localIP`:$port" -f Cyan

$screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
$screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
$imgWidth = $screenWidth
$imgHeight = $screenHeight

Write-Host "`nPress escape key for 5 seconds to exit" -f Gray


# Code to hide the console on Windows 10 and 11
if ($hide -eq 1){
    Write-Host "Hiding this window.." -f Yellow
    sleep 4
    $Async = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $Type = Add-Type -MemberDefinition $Async -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
    $hwnd = (Get-Process -PID $pid).MainWindowHandle
    
    if ($hwnd -ne [System.IntPtr]::Zero) {
        $Type::ShowWindowAsync($hwnd, 0)
    }
    else {
        $Host.UI.RawUI.WindowTitle = 'hideme'
        $Proc = (Get-Process | Where-Object { $_.MainWindowTitle -eq 'hideme' })
        $hwnd = $Proc.MainWindowHandle
        $Type::ShowWindowAsync($hwnd, 0)
    }
}



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