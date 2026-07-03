[CmdletBinding()]
param(
    [switch]$DryRun
)

$LogDir  = "$env:LOCALAPPDATA\LaunchApps"
$LogFile = Join-Path $LogDir "launch_apps.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp [$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$Apps = @(
    @{ Path = "C:\Program Files\Mozilla Firefox\firefox.exe"; Arguments = ""; DelaySec = 2 }
    @{ Path = "C:\Users\$env:USERNAME\AppData\Local\Programs\Microsoft VS Code\Code.exe"; Arguments = ""; DelaySec = 2 }
    @{ Path = "C:\Program Files\Slack\slack.exe"; Arguments = ""; DelaySec = 2 }
    # @{ Path = "notepad.exe"; Arguments = "C:\notes.txt"; DelaySec = 0 }
    # @{ Path = "C:\Program Files\Spotify\Spotify.exe"; Arguments = ""; DelaySec = 0 }
)


Write-Log "=== Lancement des applications ==="

foreach ($app in $Apps) {
    $path = $app.Path
    $arguments = $app.Arguments
    $delay = $app.DelaySec

    if (-not (Test-Path $path) -and -not (Get-Command $path -ErrorAction SilentlyContinue)) {
        Write-Log "AVERTISSEMENT : application introuvable, ignorée -> $path" "WARN"
        continue
    }

    Write-Log "Lancement : $path $arguments"

    if ($DryRun) {
        Write-Log "[dry-run] Application non lancée."
    } else {
        try {
            if ([string]::IsNullOrWhiteSpace($arguments)) {
                Start-Process -FilePath $path
            } else {
                Start-Process -FilePath $path -ArgumentList $arguments
            }
        } catch {
            Write-Log "Erreur lors du lancement de $path : $($_.Exception.Message)" "ERROR"
        }
    }

    if ($delay -gt 0) {
        Start-Sleep -Seconds $delay
    }
}

Write-Log "=== Toutes les applications ont été traitées ==="