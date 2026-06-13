# =============================================================
#  Windows Setup Script — Gaming + Daily
#  Run as Administrator in PowerShell
#  irm https://raw.githubusercontent.com/CuB1z/setup/main/scripts/windows/setup.ps1 | iex
# =============================================================

Set-ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = "SilentlyContinue"

function Step($msg) { Write-Host "`n== $msg ==" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }

# ── Windows Update ────────────────────────────────────────────
Step "Windows Update"
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
    Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
}
Import-Module PSWindowsUpdate
Install-WindowsUpdate -AcceptAll -AutoReboot:$false -Confirm:$false
Ok "Windows Update completed"

# ── Install apps with winget ──────────────────────────────────
Step "Installing apps via winget"
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (Test-Path "$script_dir\winget.json") {
    winget import -i "$script_dir\winget.json" `
        --accept-package-agreements `
        --accept-source-agreements
} else {
    Warn "winget.json not found. Installing apps manually..."
    $apps = @(
        "Valve.Steam",
        "EpicGames.EpicGamesLauncher",
        "Spotify.Spotify",
        "Brave.Brave",
        "Discord.Discord",
        "Microsoft.WindowsTerminal",
        "Git.Git",
        "Microsoft.VisualStudioCode"
    )
    foreach ($app in $apps) {
        winget install --id $app --accept-package-agreements --accept-source-agreements --silent
    }
}
Ok "Apps installed"

# ── Upgrade all existing packages ────────────────────────────
Step "Upgrading existing packages"
winget upgrade --all --accept-package-agreements --accept-source-agreements --silent
Ok "Packages upgraded"

# ── Power plan: Ultimate Performance ─────────────────────────
Step "Setting power plan to Ultimate Performance"
powercfg /setactive SCHEME_MIN
$ultimate = powercfg /list | Select-String "Ultimate"
if (-not $ultimate) {
    powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
}
$guid = (powercfg /list | Select-String "Ultimate" | Select-Object -First 1) -replace '.*\(([0-9a-f-]+)\).*','$1'
if ($guid) { powercfg /setactive $guid }
Ok "Power plan: Ultimate Performance active"

# ── Disable Game Bar and DVR ──────────────────────────────────
Step "Disabling Game Bar / DVR"
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "GameDVR_Enabled"   -Value 0 -Type DWord
Set-ItemProperty -Path "HKCU:\System\GameConfigStore"                             -Name "GameDVR_Enabled"   -Value 0 -Type DWord
$gamePath = "HKCU:\SOFTWARE\Microsoft\GameBar"
if (-not (Test-Path $gamePath)) { New-Item -Path $gamePath -Force | Out-Null }
Set-ItemProperty -Path $gamePath -Name "AutoGameModeEnabled"       -Value 0 -Type DWord
Set-ItemProperty -Path $gamePath -Name "ShowStartupPanel"          -Value 0 -Type DWord
Set-ItemProperty -Path $gamePath -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord

# Enable Hardware-Accelerated GPU Scheduling (HAGS)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Type DWord
Ok "Game Bar disabled, HAGS enabled"

# ── Enable Game Mode ──────────────────────────────────────────
Step "Enabling Game Mode"
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1 -Type DWord
Ok "Game Mode enabled"

# ── Gaming tweaks ─────────────────────────────────────────────
Step "Applying gaming tweaks"

# Disable mouse acceleration
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0"
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0"
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0"

# Disable Power Throttling
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1 -Type DWord

# Disable transparency effects
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord

# Disable Windows animations
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00))

# Prioritize foreground apps
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 26 -Type DWord

Ok "Gaming tweaks applied"

# ── GPU drivers ───────────────────────────────────────────────
Step "GPU Drivers"
$gpu = (Get-WmiObject Win32_VideoController | Select-Object -First 1).Name
Write-Host "  Detected GPU: $gpu" -ForegroundColor White

if ($gpu -match "NVIDIA") {
    Warn "NVIDIA detected. Installing GeForce Experience..."
    winget install Nvidia.GeForceExperience --accept-package-agreements --accept-source-agreements --silent
    Ok "GeForce Experience installed. Open it to install the latest drivers."
} elseif ($gpu -match "AMD|Radeon") {
    Warn "AMD detected. Installing AMD Software: Adrenalin Edition..."
    winget install AMD.AdrenalinEdition --accept-package-agreements --accept-source-agreements --silent
    Ok "AMD Adrenalin installed. Open it to install the latest drivers."
} elseif ($gpu -match "Intel") {
    winget install Intel.GraphicsCommandCenter --accept-package-agreements --accept-source-agreements --silent
    Ok "Intel Graphics Command Center installed."
} else {
    Warn "Could not detect GPU automatically. Install drivers manually."
}

# ── Remove bloatware ──────────────────────────────────────────
Step "Removing bloatware"
$bloat = @(
    "*xbox*", "*solitaire*", "*BingWeather*", "*ZuneMusic*",
    "*ZuneVideo*", "*MixedReality*", "*SkypeApp*", "*GetHelp*",
    "*Getstarted*", "*windowscommunicationsapps*"
)
foreach ($app in $bloat) {
    Get-AppxPackage $app | Remove-AppxPackage
}
Ok "Bloatware removed"

# ── Brave extensions (via managed policy) ────────────────────
Step "Brave extensions"
$bravePolicyDir = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
$braveExtensionsKey = Join-Path $bravePolicyDir "ExtensionInstallForcelist"

New-Item -Path $braveExtensionsKey -Force | Out-Null

$braveExtensions = @(
    "nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx",  # Bitwarden
    "bggfcpfjbdkhfhfmkjpbhnkhnpjjeomc;https://clients2.google.com/service/update2/crx",  # Material Icons for GitHub
    "ckkdlimhmcjmikdlpkmbgfkaikojcbjk;https://clients2.google.com/service/update2/crx"   # Markdown Viewer
)

for ($index = 0; $index -lt $braveExtensions.Count; $index++) {
    New-ItemProperty -Path $braveExtensionsKey -Name ($index + 1) -Value $braveExtensions[$index] -PropertyType String -Force | Out-Null
}

Warn "Extensions configured via policy - they install automatically when Brave opens."
Ok "Brave extension policy created"

# ── Brave settings (managed policy) ──────────────────────────
# Enforceable, update-proof settings. NOTE: these lock the matching
# toggles in brave://settings (shown as "managed by your organization").
Step "Brave settings policy"
New-Item -Path $bravePolicyDir -Force | Out-Null

$braveDwordSettings = @{
    "BookmarkBarEnabled"           = 1
    "ShowHomeButton"               = 0
    "RestoreOnStartup"             = 5
    "PasswordManagerEnabled"       = 0
    "BraveRewardsDisabled"         = 1
    "BraveWalletDisabled"          = 1
    "BraveVPNDisabled"             = 1
    "BraveAIChatEnabled"           = 0
    "BraveNewsDisabled"            = 1
    "DefaultSearchProviderEnabled" = 1
}
foreach ($name in $braveDwordSettings.Keys) {
    New-ItemProperty -Path $bravePolicyDir -Name $name -Value $braveDwordSettings[$name] -PropertyType DWord -Force | Out-Null
}

$braveStringSettings = @{
    "DefaultSearchProviderName"      = "Google"
    "DefaultSearchProviderKeyword"   = ":g"
    "DefaultSearchProviderSearchURL"  = "https://www.google.com/search?q={searchTerms}"
    "DefaultSearchProviderSuggestURL" = "https://www.google.com/complete/search?output=chrome&q={searchTerms}"
}
foreach ($name in $braveStringSettings.Keys) {
    New-ItemProperty -Path $bravePolicyDir -Name $name -Value $braveStringSettings[$name] -PropertyType String -Force | Out-Null
}
Ok "Brave settings policy created (Google search, bookmark bar, no Rewards/Wallet/VPN/News/Leo)"

# ── Brave profile preferences (look & feel, not policy-controllable) ──
# Vertical tabs, grayscale dark theme, new-tab widgets, sidebar. Seeded into
# the profile; only applied while Brave is closed (else Brave overwrites on exit).
Step "Brave profile preferences"
if (Get-Process -Name brave -ErrorAction SilentlyContinue) {
    Warn "Brave is running - close it and re-run to apply its profile preferences"
} else {
    function ConvertTo-HashtableDeep($obj) {
        if ($obj -is [System.Collections.IDictionary]) {
            $h = @{}; foreach ($k in $obj.Keys) { $h[$k] = ConvertTo-HashtableDeep $obj[$k] }; return $h
        } elseif ($obj -is [PSCustomObject]) {
            $h = @{}; foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = ConvertTo-HashtableDeep $p.Value }; return $h
        } elseif ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
            return @($obj | ForEach-Object { ConvertTo-HashtableDeep $_ })
        } else { return $obj }
    }
    function Merge-Hashtable($dst, $src) {
        foreach ($k in $src.Keys) {
            if (($src[$k] -is [hashtable]) -and ($dst[$k] -is [hashtable])) {
                Merge-Hashtable $dst[$k] $src[$k]
            } else { $dst[$k] = $src[$k] }
        }
    }

    $braveProfile = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
    $prefsPath = Join-Path $braveProfile "Preferences"
    New-Item -Path $braveProfile -ItemType Directory -Force | Out-Null

    $prefs = @{}
    if (Test-Path $prefsPath) {
        try { $prefs = ConvertTo-HashtableDeep (Get-Content $prefsPath -Raw | ConvertFrom-Json) } catch { $prefs = @{} }
    }

    $desired = @{
        browser = @{ theme = @{ color_scheme2 = 2; is_grayscale2 = $true } }
        brave = @{
            tabs = @{
                vertical_tabs_enabled          = $true
                vertical_tabs_collapsed        = $true
                vertical_tabs_floating_enabled = $true
                vertical_tabs_on_right         = $false
            }
            new_tab_page = @{
                show_background_image         = $true
                show_branded_background_image = $false
                show_brave_news               = $false
                show_clock                    = $true
                clock_format                  = "h24"
                show_rewards                  = $false
                show_stats                    = $false
                show_together                 = $false
            }
            today                          = @{ opted_in = $false }
            sidebar                        = @{ sidebar_show_option = 3 }
            show_side_panel_button         = $false
            always_show_bookmark_bar_on_ntp = $false
            ai_chat                        = @{ show_toolbar_button = $false; autocomplete_provider_enabled = $false }
            wallet                         = @{ show_wallet_icon_on_toolbar = $false }
            rewards                        = @{ show_brave_rewards_button_in_location_bar = $false }
        }
    }

    Merge-Hashtable $prefs $desired
    try {
        $prefs | ConvertTo-Json -Depth 50 -Compress | Set-Content -Path $prefsPath -Encoding UTF8 -NoNewline
        Ok "Brave profile preferences seeded (vertical tabs, grayscale theme, new-tab look, sidebar hidden)"
    } catch {
        Warn "Could not seed Brave preferences"
    }
}

# ── Brave bookmarks ───────────────────────────────────────────
$braveBookmarks = Join-Path $script_dir "brave_bookmarks.html"
if (Test-Path $braveBookmarks) {
    Step "Brave bookmarks"
    Warn "brave_bookmarks.html found - import it manually via brave://bookmarks -> Import"
}

# ── Disable startup apps ──────────────────────────────────────
Step "Disabling startup apps"
$startupApps = @(
    "Spotify",
    "Discord",
    "EpicGamesLauncher"
)

Get-CimInstance Win32_StartupCommand | ForEach-Object {
    foreach ($appName in $startupApps) {
        if ($_.Name -like "*$appName*") {
            $_ | Remove-CimInstance
        }
    }
}
Ok "Common startup apps disabled"

# ── Desktop wallpaper ─────────────────────────────────────────
Step "Setting desktop wallpaper"
$bgSrc = Join-Path $script_dir "..\..\assets\background.jpg"
if (Test-Path $bgSrc) {
    $picturesDir = [Environment]::GetFolderPath("MyPictures")
    $wallpaperPath = Join-Path $picturesDir "background.jpg"
    Copy-Item $bgSrc $wallpaperPath -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $wallpaperPath
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value "10"
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -Value "0"
    Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
  [DllImport("user32.dll", CharSet=CharSet.Auto)]
  public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
    [Wallpaper]::SystemParametersInfo(20, 0, $wallpaperPath, 3) | Out-Null
    Ok "Wallpaper set to $wallpaperPath"
} else {
    Warn "assets\background.jpg not found — skipping wallpaper"
}

# ── Enable Dark Mode  ─────────────────────────────────────────
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
  -Name "AppsUseLightTheme" -Value 0

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
  -Name "SystemUsesLightTheme" -Value 0

$accentColor = 0x001E1EFF

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" `
  -Name "AccentColor" -Value $accentColor

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" `
  -Name "ColorizationColor" -Value $accentColor

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" `
  -Name "ColorPrevalence" -Value 1

Stop-Process -Name explorer -Force
Start-Process explorer

# ── Done ──────────────────────────────────────────────────────
Write-Host "`n============================================" -ForegroundColor Green
Write-Host "  Setup complete." -ForegroundColor Green
Write-Host "  Next steps:"
Write-Host "  1. Open GeForce Experience / AMD Adrenalin and install drivers"
Write-Host "  2. Restart to apply all changes"
Write-Host "============================================`n" -ForegroundColor Green
