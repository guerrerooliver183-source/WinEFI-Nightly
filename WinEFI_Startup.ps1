param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Install", "Uninstall")]
    [string]$Action
)

$InstallDir = "C:\Program Files (x86)\WinEFI"
$TempDir = "$env:LOCALAPPDATA\Temp\WinEFI-Temp"
$HackBGRTZip = "$TempDir\HackBGRT-2.6.0.zip"
$HackBGRTContentDir = "$TempDir\HackBGRT-2.6.0\HackBGRT-2.6.0"
$BootresDllPath = "$env:SystemRoot\Boot\Resources\bootres.dll"
$ExtractedBootresDir = "$TempDir\bootres_extracted"
$WinLogo3Bmp = "$ExtractedBootresDir\winlogo3.bmp"
$HackBGRTSplashBmp = "$InstallDir\splash.bmp"

function Show-MessageBox {
    param(
        [string]$Message,
        [string]$Title,
        [string]$Icon = "Information"
    )
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, "OK", $Icon)
}

function Check-SecureBoot {
    try {
        $secureBootStatus = Confirm-SecureBootUEFI
        if ($secureBootStatus -eq $true) {
            return $true
        } else {
            return $false
        }
    } catch {
        # Handle cases where Confirm-SecureBootUEFI might not be available (e.g., non-UEFI systems)
        return $false
    }
}

if ($Action -eq "Install") {
    # Secure Boot check is handled by Inno Setup, but a redundant check here is fine.
    # if (-not (Check-SecureBoot)) {
    #     Show-MessageBox -Message "Secure Boot is disabled. Installation cannot proceed." -Title "Installation Error" -Icon "Error"
    #     exit 1
    # }

    # Create directories
    if (-not (Test-Path $InstallDir)) { New-Item -Path $InstallDir -ItemType Directory | Out-Null }
    if (-not (Test-Path $TempDir)) { New-Item -Path $TempDir -ItemType Directory | Out-Null }

    # Move HackBGRT contents
    Copy-Item -Path "$HackBGRTContentDir\*" -Destination $InstallDir -Recurse -Force

    # Extract bootres.dll and winlogo3.bmp
    # This part will be handled by ExtractBootres.ps1
    & "powershell.exe" -ExecutionPolicy Bypass -File "$InstallDir\ExtractBootres.ps1" -BootresDllPath $BootresDllPath -ExtractedBootresDir $ExtractedBootresDir

    # Delete splash.bmp from HackBGRT installation
    if (Test-Path $HackBGRTSplashBmp) { Remove-Item -Path $HackBGRTSplashBmp -Force }

    # Move winlogo3.bmp to HackBGRT installation as splash.bmp
    if (Test-Path $WinLogo3Bmp) {
        Copy-Item -Path $WinLogo3Bmp -Destination $HackBGRTSplashBmp -Force
    }

    # Install HackBGRT (UEFI)
    # Assuming setup.exe is in $InstallDir
    Start-Process -FilePath "$InstallDir\setup.exe" -ArgumentList "batch install enable-bcdedit allow-secure-boot" -Wait -WindowStyle Hidden

    # Create Task Scheduler task (handled by Inno Setup)
    # Registry entries (handled by Inno Setup)

    # Show success message (handled by Inno Setup)
}
elseif ($Action -eq "Uninstall") {
    # Remove HackBGRT (UEFI, Logo) with official uninstaller
    # Assuming setup.exe is in $InstallDir
    if (Test-Path "$InstallDir\setup.exe") {
        Start-Process -FilePath "$InstallDir\setup.exe" -ArgumentList "batch uninstall" -Wait -WindowStyle Hidden
    }

    # Remove Registry entries (handled by Inno Setup)
    # Remove Task Scheduler task (handled by Inno Setup)

    # Show success message (handled by Inno Setup)
    # Delete installation folder (handled by Inno Setup)
}
