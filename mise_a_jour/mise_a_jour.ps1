[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$RebootIfNeeded,
    [switch]$AcceptAll
)

$ErrorActionPreference = "Stop"

$LogDir  = "C:\ProgramData\AutoUpdate"
$LogFile = Join-Path $LogDir "auto_update.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp [$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Vérification des droits administrateur ---
if (-not (Test-Admin)) {
    Write-Error "Ce script doit être exécuté en tant qu'administrateur."
    exit 1
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Write-Log "=== Début de la mise à jour ==="

$success = $true

try {
    # --- Installation du module PSWindowsUpdate si absent ---
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Log "Installation du module PSWindowsUpdate..."
        if (-not $DryRun) {
            Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
            Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -Confirm:$false
        } else {
            Write-Log "[dry-run] Installation du module ignorée."
        }
    }

    Import-Module PSWindowsUpdate -ErrorAction Stop

    # --- Recherche des mises à jour disponibles ---
    Write-Log "Recherche des mises à jour disponibles..."
    $updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction Stop

    if (-not $updates -or $updates.Count -eq 0) {
        Write-Log "Aucune mise à jour disponible."
    } else {
        foreach ($u in $updates) {
            Write-Log ("Trouvé : {0} ({1})" -f $u.Title, $u.KB)
        }

        if ($DryRun) {
            Write-Log "[dry-run] Installation des mises à jour ignorée."
        } else {
            Write-Log "Installation des mises à jour en cours..."
            $params = @{
                MicrosoftUpdate = $true
                AcceptAll       = $true
                IgnoreReboot    = $true
                Verbose         = $true
            }
            $result = Install-WindowsUpdate @params 2>&1
            $result | ForEach-Object { Write-Log $_.ToString() }
        }
    }

    Write-Log "Toutes les étapes se sont terminées avec succès."
}
catch {
    $success = $false
    Write-Log "Erreur : $($_.Exception.Message)" "ERROR"
}

# --- Redémarrage si nécessaire ---
if ($success -and $RebootIfNeeded) {
    $rebootRequired = Get-WURebootStatus -Silent
    if ($rebootRequired) {
        Write-Log "Un redémarrage est requis. Redémarrage en cours..." "WARN"
        if (-not $DryRun) {
            Restart-Computer -Force
        }
    }
}

Write-Log "=== Fin de la mise à jour ==="

if ($success) { exit 0 } else { exit 1 }