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

# Deep-convert ConvertFrom-Json output (PSCustomObject) to nested hashtables, so
# JSON config files (Brave Preferences, Windows Terminal settings) can be merged.
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

# True if a registered font's display name matches the pattern. Checks both the
# machine and per-user font registries, so it works wherever the font was installed.
function Test-FontInstalled($namePattern) {
    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )
    foreach ($k in $keys) {
        if (Test-Path $k) {
            foreach ($p in (Get-ItemProperty $k).PSObject.Properties) {
                if ($p.Name -like $namePattern) { return $true }
            }
        }
    }
    return $false
}

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

# Prioritize foreground apps
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 26 -Type DWord

Ok "Gaming tweaks applied"

# ── GPU drivers ───────────────────────────────────────────────
Step "GPU Drivers"
$gpu = (Get-WmiObject Win32_VideoController | Select-Object -First 1).Name
Write-Host "  Detected GPU: $gpu" -ForegroundColor White

# Returns $true if any installed program's display name matches one of the patterns.
function Test-AppInstalled($namePatterns) {
    $uninstall = Get-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", `
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue
    foreach ($pattern in $namePatterns) {
        if ($uninstall | Where-Object { $_.DisplayName -like $pattern }) { return $true }
    }
    return $false
}

# Skips if already installed (idempotent). Otherwise tries each winget id in order
# (exit code 0 = success); if none install, opens the official download page once.
function Install-GpuSoftware($wingetIds, $fallbackUrl, $label, $detectPatterns) {
    if (Test-AppInstalled $detectPatterns) {
        Ok "$label already installed - skipping"
        return
    }
    foreach ($id in $wingetIds) {
        Write-Host "  Installing $label via winget ($id)..." -ForegroundColor White
        winget install --id $id --exact --accept-package-agreements --accept-source-agreements --silent
        if ($LASTEXITCODE -eq 0) {
            Ok "$label installed via winget ($id)"
            return
        }
        Warn "$label not installable via '$id' (winget exit $LASTEXITCODE)"
    }
    # Don't open the page: launching the browser leaves it running and blocks the
    # Brave profile config later. Just log the URL for the user to grab afterwards.
    Warn "$label could not be installed silently - download it manually from: $fallbackUrl"
}

if ($gpu -match "NVIDIA") {
    # NVIDIA App (the current driver suite) is blocked on winget; GeForce Experience
    # is the only winget option but is being retired. Fall back to the NVIDIA App page.
    Install-GpuSoftware @("Nvidia.GeForceExperience") "https://www.nvidia.com/en-us/software/nvidia-app/" "NVIDIA drivers" @("NVIDIA App", "NVIDIA GeForce Experience")
} elseif ($gpu -match "AMD|Radeon") {
    # AMD Adrenalin Edition is not published to winget - go straight to the download page.
    Install-GpuSoftware @("AMD.AMDSoftwareAdrenalinEdition", "AMD.AMDSoftware") "https://www.amd.com/en/support/download/drivers.html" "AMD Adrenalin" @("AMD Software*")
} elseif ($gpu -match "Intel") {
    Install-GpuSoftware @("Intel.GraphicsCommandCenter") "https://www.intel.com/content/www/us/en/download-center/home.html" "Intel Graphics" @("*Graphics Command Center*")
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

# ── FiraCode Nerd Font ────────────────────────────────────────
# Needed for the terminal theme (icons + ligatures), matching Ubuntu. No reliable
# winget package exists, so install from the official Nerd Fonts release.
Step "Installing FiraCode Nerd Font"
if (Test-FontInstalled "*FiraCode*Nerd*") {
    Ok "FiraCode Nerd Font already installed"
} else {
    $fontZip = Join-Path $env:TEMP "FiraCode.zip"
    $fontTmp = Join-Path $env:TEMP "FiraCodeNF"
    try {
        Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip" `
            -OutFile $fontZip -UseBasicParsing
        if (Test-Path $fontTmp) { Remove-Item $fontTmp -Recurse -Force }
        Expand-Archive -Path $fontZip -DestinationPath $fontTmp -Force
        $shellFonts = (New-Object -ComObject Shell.Application).Namespace(0x14)
        foreach ($ttf in Get-ChildItem $fontTmp -Filter *.ttf) {
            if (-not (Test-Path (Join-Path "$env:WINDIR\Fonts" $ttf.Name))) {
                $shellFonts.CopyHere($ttf.FullName, 0x10)  # 0x10 = yes to all, no UI
            }
        }
        Ok "FiraCode Nerd Font installed"
    } catch {
        Warn "Could not install FiraCode Nerd Font - terminal will use a fallback font"
    } finally {
        Remove-Item $fontZip -ErrorAction SilentlyContinue
        Remove-Item $fontTmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ── Windows Terminal (Ubuntu-like theme, no tabs, maximized) ──
# Focus mode (no tabs/title bar) + maximized window, gruvbox palette mirroring
# the Ubuntu/Terminator profile. Merged into settings.json so nothing else is lost.
Step "Configuring Windows Terminal"
$wtSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$wtDir = Split-Path -Parent $wtSettings
if (Test-Path $wtDir) {
    $wt = @{}
    if (Test-Path $wtSettings) {
        try { $wt = ConvertTo-HashtableDeep (Get-Content $wtSettings -Raw | ConvertFrom-Json) } catch { $wt = @{} }
    }

    # Maximized window with the title bar/window controls (X) visible. WT can't
    # hide the tab strip without focus mode, which also hides the title bar, so
    # keep tabs in the title bar to get a quick close button.
    $wt["launchMode"] = "maximized"

    # Look & feel applied to every profile
    if ($wt["profiles"] -isnot [hashtable])              { $wt["profiles"] = @{} }
    if ($wt["profiles"]["defaults"] -isnot [hashtable])  { $wt["profiles"]["defaults"] = @{} }
    Merge-Hashtable $wt["profiles"]["defaults"] @{
        colorScheme      = "Ubuntu Gruvbox"
        opacity          = 95
        useAcrylic       = $false
        cursorShape      = "bar"
        intenseTextStyle = "bright"
        padding          = "8"
        font             = @{ face = "FiraCode Nerd Font"; size = 12 }
    }

    # Gruvbox scheme = same 16 ANSI colours as the Ubuntu profile
    $scheme = @{
        name = "Ubuntu Gruvbox"
        background  = "#16181A"; foreground = "#E8E8E8"
        cursorColor = "#AAAAAA"; selectionBackground = "#3C3836"
        black = "#282828"; red = "#CC241D"; green = "#A9A81D"; yellow = "#D79921"
        blue  = "#419A9E"; purple = "#B16286"; cyan = "#689D6A"; white = "#A89984"
        brightBlack = "#928374"; brightRed = "#FB4934"; brightGreen = "#D1EC31"; brightYellow = "#FABD2F"
        brightBlue  = "#8BD5D7"; brightPurple = "#D3869B"; brightCyan = "#8EC07C"; brightWhite = "#EBDBB2"
    }
    $schemes = @()
    if ($wt["schemes"]) { $schemes = @($wt["schemes"] | Where-Object { $_.name -ne "Ubuntu Gruvbox" }) }
    $schemes += $scheme
    $wt["schemes"] = $schemes

    try {
        $wt | ConvertTo-Json -Depth 50 | Set-Content -Path $wtSettings -Encoding UTF8
        Ok "Windows Terminal themed (Ubuntu Gruvbox, no tabs, maximized + focus)"
    } catch {
        Warn "Could not write Windows Terminal settings"
    }
} else {
    Warn "Windows Terminal profile not found - open it once, then re-run"
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
$picturesDir = [Environment]::GetFolderPath("MyPictures")
$wallpaperPath = Join-Path $picturesDir "background.jpg"

# Use the local asset if running from a cloned repo; otherwise download it
# (the script is meant to be run via `irm ... | iex`, where no file exists on disk).
$bgSrc = if ($script_dir) { Join-Path $script_dir "..\..\assets\background.jpg" } else { $null }
if ($bgSrc -and (Test-Path $bgSrc)) {
    Copy-Item $bgSrc $wallpaperPath -Force
} else {
    $bgUrl = "https://raw.githubusercontent.com/CuB1z/setup/main/assets/background.jpg"
    try {
        Invoke-WebRequest -Uri $bgUrl -OutFile $wallpaperPath -UseBasicParsing
    } catch {
        Warn "Could not download wallpaper from $bgUrl"
    }
}

if (Test-Path $wallpaperPath) {
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
    Warn "background.jpg unavailable (local + download failed) — skipping wallpaper"
}

# ── Personalization: Dark Mode + Red Accent ───────────────────
Step "Personalization (Dark Mode + Red Accent)"
$personalize = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
if (-not (Test-Path $personalize)) { New-Item -Path $personalize -Force | Out-Null }

# Dark mode for apps and system
Set-ItemProperty -Path $personalize -Name "AppsUseLightTheme"    -Value 0 -Type DWord
Set-ItemProperty -Path $personalize -Name "SystemUsesLightTheme" -Value 0 -Type DWord

# Disable transparency effects
Set-ItemProperty -Path $personalize -Name "EnableTransparency"   -Value 0 -Type DWord

# Vivid, fully-saturated red accent (#FF0000). ABGR format 0x00BBGGRR.
$accentColor = 0x000000FF
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AccentColor"       -Value $accentColor -Type DWord
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorizationColor" -Value $accentColor -Type DWord
# Don't tint title bars or the taskbar/Start - keep them dark (red only on highlights)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorPrevalence" -Value 0 -Type DWord
Set-ItemProperty -Path $personalize -Name "ColorPrevalence" -Value 0 -Type DWord

# AccentPalette drives the actual accent shade used for buttons/highlights/Start.
# 8 RGBA shades, light -> dark, base #FF0000 at index 3. Green/blue stay at 0 so
# the hue is pure red and the accent looks vivid rather than washed out.
$accentKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent"
if (-not (Test-Path $accentKey)) { New-Item -Path $accentKey -Force | Out-Null }
$accentPalette = [byte[]](
    0xFF,0x99,0x99,0x00,  0xFF,0x66,0x66,0x00,  0xFF,0x33,0x33,0x00,  0xFF,0x00,0x00,0x00,
    0xD4,0x00,0x00,0x00,  0xA8,0x00,0x00,0x00,  0x7D,0x00,0x00,0x00,  0x52,0x00,0x00,0x00
)
Set-ItemProperty -Path $accentKey -Name "AccentPalette"   -Value $accentPalette -Type Binary
Set-ItemProperty -Path $accentKey -Name "AccentColorMenu" -Value $accentColor -Type DWord
Set-ItemProperty -Path $accentKey -Name "StartColorMenu"  -Value $accentColor -Type DWord
Ok "Dark mode + red accent applied (highlights only, dark title bars/taskbar)"

# ── Disable animations ────────────────────────────────────────
Step "Disabling animations"
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Type String
$vfx = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (-not (Test-Path $vfx)) { New-Item -Path $vfx -Force | Out-Null }
Set-ItemProperty -Path $vfx -Name "VisualFXSetting" -Value 2 -Type DWord
Ok "Animations disabled"

# ── Disable Widgets ───────────────────────────────────────────
Step "Disabling Widgets"
# Remove Widgets button from the taskbar
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -Type DWord
# Block Widgets / News and Interests via machine policy
$dshPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
if (-not (Test-Path $dshPolicy)) { New-Item -Path $dshPolicy -Force | Out-Null }
Set-ItemProperty -Path $dshPolicy -Name "AllowNewsAndInterests" -Value 0 -Type DWord
Ok "Widgets disabled"

# ── Clean up menus & taskbar ──────────────────────────────────
Step "Cleaning up menus and taskbar"
$advanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
# Remove Chat and Task View buttons from the taskbar
Set-ItemProperty -Path $advanced -Name "TaskbarMn"          -Value 0 -Type DWord
Set-ItemProperty -Path $advanced -Name "ShowTaskViewButton" -Value 0 -Type DWord
# Collapse the taskbar search box (0 = hidden)
$searchKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
if (-not (Test-Path $searchKey)) { New-Item -Path $searchKey -Force | Out-Null }
Set-ItemProperty -Path $searchKey -Name "SearchboxTaskbarMode" -Value 0 -Type DWord
# Restore the classic full context menu (removes the Win11 "Show more options" extra click)
$ctxKey = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
New-Item -Path $ctxKey -Force | Out-Null
Set-ItemProperty -Path $ctxKey -Name "(Default)" -Value "" -Type String
Ok "Menus and taskbar cleaned"

# ── Empty the Start menu ──────────────────────────────────────
Step "Emptying the Start menu"
# Layout: 1 = More pins (shrinks the Recommended area)
Set-ItemProperty -Path $advanced -Name "Start_Layout" -Value 1 -Type DWord
# Hide recently added / most used / recommended files and tips
Set-ItemProperty -Path $advanced -Name "Start_TrackDocs"            -Value 0 -Type DWord
Set-ItemProperty -Path $advanced -Name "Start_TrackProgs"           -Value 0 -Type DWord
Set-ItemProperty -Path $advanced -Name "Start_IrisRecommendations"  -Value 0 -Type DWord
Set-ItemProperty -Path $advanced -Name "Start_AccountNotifications" -Value 0 -Type DWord
# Disable Start menu suggestions / promoted content
$contentKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
Set-ItemProperty -Path $contentKey -Name "SystemPaneSuggestionsEnabled"    -Value 0 -Type DWord
Set-ItemProperty -Path $contentKey -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord

# Empty pinned list + hide the Recommended section (machine policy).
# HideRecommendedSection is honored on Win11 22H2+; ConfigureStartPins replaces
# the pinned grid with nothing. Note: full effect needs Pro/Enterprise/Education.
$explorerPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
if (-not (Test-Path $explorerPolicy)) { New-Item -Path $explorerPolicy -Force | Out-Null }
Set-ItemProperty -Path $explorerPolicy -Name "ConfigureStartPins"      -Value '{"pinnedList":[]}' -Type String
Set-ItemProperty -Path $explorerPolicy -Name "HideRecommendedSection"  -Value 1 -Type DWord
Ok "Start menu emptied (no pins, no recommendations)"

# ── Pin only our apps + Windows Terminal to the taskbar ──────
# Win11 builds the taskbar pin list from LayoutModification.xml. We list the
# Start-menu shortcuts that actually exist (broken entries are skipped) plus
# Windows Terminal by AUMID, then clear the cached pins so it regenerates.
Step "Configuring taskbar pins"

$startMenuRoots = @(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
)
$wantedApps = @("Brave", "Steam", "Epic Games Launcher", "Spotify", "Discord", "Visual Studio Code")

$desktopEntries = ""
foreach ($name in $wantedApps) {
    $lnk = Get-ChildItem -Path $startMenuRoots -Recurse -Filter "$name.lnk" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($lnk) {
        $desktopEntries += "        <taskbar:DesktopApp DesktopApplicationLinkPath=`"$($lnk.FullName)`" />`n"
        Write-Host "  Pinning: $name" -ForegroundColor White
    } else {
        Warn "Shortcut for '$name' not found - skipping"
    }
}

$layoutXml = @"
<?xml version="1.0" encoding="utf-8"?>
<LayoutModificationTemplate
    xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification"
    xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout"
    xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout"
    xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout"
    Version="1">
  <CustomTaskbarLayoutCollection PinListPlacement="Replace">
    <defaultlayout:TaskbarLayout>
      <taskbar:TaskbarPinList>
$desktopEntries        <taskbar:UWA AppUserModelID="Microsoft.WindowsTerminal_8wekyb3d8bbwe!App" />
      </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
  </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@

$shellDir = "$env:LOCALAPPDATA\Microsoft\Windows\Shell"
New-Item -Path $shellDir -ItemType Directory -Force | Out-Null
Set-Content -Path (Join-Path $shellDir "LayoutModification.xml") -Value $layoutXml -Encoding UTF8

# Clear cached taskbar pins so Windows rebuilds them from the layout
$taskband = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
Remove-ItemProperty -Path $taskband -Name "Favorites"        -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $taskband -Name "FavoritesResolve" -ErrorAction SilentlyContinue
Ok "Taskbar pins configured (Brave, Steam, Epic, Spotify, Discord, VS Code, Windows Terminal)"

# ── Dual-boot clock (use UTC for the hardware clock) ─────────
# Linux keeps the RTC in UTC by default; Windows assumes local time, so on a
# dual boot the clock drifts by the timezone offset each switch. Making Windows
# treat the RTC as UTC aligns it with Ubuntu and stops the time from breaking.
Step "Fixing dual-boot clock (RTC as UTC)"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -Name "RealTimeIsUniversal" -Value 1 -Type DWord
Ok "Windows now reads the hardware clock as UTC"

# ── Clean up the desktop ──────────────────────────────────────
# Remove shortcuts left by installers (only .lnk/.url, never real files).
Step "Cleaning up the desktop"
$desktops = @(
    [Environment]::GetFolderPath("Desktop"),
    "$env:PUBLIC\Desktop"
)
foreach ($d in $desktops) {
    if (Test-Path $d) {
        Get-ChildItem -Path $d -Include *.lnk, *.url -File -ErrorAction SilentlyContinue | Remove-Item -Force
    }
}

# Hide the Recycle Bin from the desktop
$hideIcons = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
if (-not (Test-Path $hideIcons)) { New-Item -Path $hideIcons -Force | Out-Null }
Set-ItemProperty -Path $hideIcons -Name "{645FF040-5081-101B-9F08-00AA002F954E}" -Value 1 -Type DWord
Ok "Desktop cleared and Recycle Bin hidden"

# ── Restart explorer to apply visual changes ──────────────────
Stop-Process -Name explorer -Force
Start-Process explorer

# ── Done ──────────────────────────────────────────────────────
Write-Host "`n============================================" -ForegroundColor Green
Write-Host "  Setup complete." -ForegroundColor Green
Write-Host "  Next steps:"
Write-Host "  1. If a GPU driver URL was logged above, download and install it"
Write-Host "  2. Sign out / restart to apply taskbar pins and all changes"
Write-Host "============================================`n" -ForegroundColor Green
