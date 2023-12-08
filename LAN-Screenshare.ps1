<#
================================================= Beigeworm's Screen Stream over HTTP ==========================================================

SYNOPSIS
Start up a HTTP server and stream the desktop to a browser window.

USAGE
1. Run this script on target computer and note the URL provided
2. on another device on the same network, enter the provided URL in a browser window

#>

$HideWindow = "false"   #     true = HIDE WINDOW  /   false = SHOW WINDOW

$Host.UI.RawUI.BackgroundColor = "Black"
Clear-Host
$width = 88
$height = 30
[Console]::SetWindowSize($width, $height)
$windowTitle = "HTTP Screenshare"
[Console]::Title = $windowTitle
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationCore,PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

if ($HideWindow -eq "true"){
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    sleep 1
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -Ep Bypass -W Hidden -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}
}else{
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    sleep 1
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -Ep Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
    }
}

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


$refreshIntervalInSeconds = 0.5  # Adjust this interval as needed

New-NetFirewallRule -DisplayName "AllowWebServer" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow | Out-Null
$webServer = New-Object System.Net.HttpListener 
$webServer.Prefixes.Add("http://"+$loip+":8080/")
$webServer.Prefixes.Add("http://localhost:8080/")
$webServer.Start()
Write-Host ("Network Devices Can Reach the server at : http://"+$loip+":5000")
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
    } else {
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

$webServer.Stop()

