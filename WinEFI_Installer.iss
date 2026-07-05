; Script generado para WinEFI

#define MyAppName "WinEFI"
#define MyAppVersion "1.0"
#define MyAppPublisher "WinEFI Project"
#define MyAppExeName "winefi.exe"

[Setup]
AppId={{5D7E8B9A-1234-5678-ABCD-EF0123456789}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={commonpf32}\{#MyAppName}
DefaultGroupName={#MyAppName}
PrivilegesRequired=admin
OutputDir=userdocs:Inno Setup Examples Output
OutputBaseFilename=WinEFI_Setup
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; winefi.exe debe ser proporcionado por el usuario, lo marcaremos como no requerido estrictamente para compilar si no existe, o requeriremos que el usuario lo coloque.
; Por ahora asumimos que el usuario lo tiene en la misma carpeta que el script.
Source: "winefi.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "WinEFI_Startup.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "ExtractBootres.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Run]
; Configurar Task Scheduler para que ejecute winefi.exe al iniciar sesión con privilegios más altos (sin UAC)
Filename: "schtasks.exe"; Parameters: "/create /tn ""WinEFI_AutoStart"" /tr ""'{app}\{#MyAppExeName}'"" /sc onlogon /rl highest /f"; Flags: runhidden
; Ejecutar PowerShell script para realizar las operaciones de instalación de HackBGRT
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\WinEFI_Startup.ps1"" -Install"; Flags: waituntilterminated runhidden

[UninstallRun]
; Borrar la tarea programada
Filename: "schtasks.exe"; Parameters: "/delete /tn ""WinEFI_AutoStart"" /f"; Flags: runhidden
; Ejecutar PowerShell script para desinstalar HackBGRT
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\WinEFI_Startup.ps1"" -Uninstall"; Flags: waituntilterminated runhidden

[Registry]
; Asegurar que winefi.exe aparezca en el Administrador de Tareas en la pestaña de Inicio
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "WinEFI"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue
; Configurar AppCompatFlags para que siempre se ejecute como administrador (aunque Task Scheduler ya le da privilegios, esto asegura ejecución manual)
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"; ValueType: String; ValueName: "{app}\{#MyAppExeName}"; ValueData: "RUNASADMIN"; Flags: uninsdeletekeyifempty uninsdeletevalue

[Code]
var
  DownloadPage: TDownloadWizardPage;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if Progress = ProgressMax then
    Log(Format('Successfully downloaded file to {app}: %s', [FileName]));
  Result := True;
end;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing), SetupMessage(msgPreparingDesc), @OnDownloadProgress);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  ResultCode: Integer;
begin
  if CurPageID = wpReady then begin
    DownloadPage.Clear;
    DownloadPage.Add('https://github.com/Metabolix/HackBGRT/releases/download/v2.6.0/HackBGRT-2.6.0.zip', 'HackBGRT-2.6.0.zip', '');
    DownloadPage.Show;
    try
      try
        DownloadPage.Download;
        Result := True;
      except
        if DownloadPage.AbortedByUser then
          Log('Aborted by user.')
        else
          SuppressibleMsgBox(AddPeriod(GetExceptionMessage), mbCriticalError, MB_OK, IDOK);
        Result := False;
      end;
    finally
      DownloadPage.Hide;
    end;
  end else
    Result := True;
end;

function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  // Check Secure Boot status via PowerShell
  if Exec('powershell.exe', '-NoProfile -ExecutionPolicy Bypass -Command "if ((Confirm-SecureBootUEFI) -eq $false) { exit 1 } else { exit 0 }"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if ResultCode = 1 then
    begin
      // Secure Boot is disabled, abort installation
      Exec('powershell.exe', '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.Forms.MessageBox]::Show(''Secure Boot is disabled. Installation cannot proceed.'', ''Installation Error'', ''OK'', ''Error'')"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Result := False;
      Exit;
    end;
  end;
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  TempPath: String;
  ZipFile: String;
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    TempPath := ExpandConstant('{userappdata}\Local\Temp\WinEFI-Temp');
    ZipFile := ExpandConstant('{tmp}\HackBGRT-2.6.0.zip');
    
    // Create Temp Directory
    ForceDirectories(TempPath);
    
    // Extract Zip using PowerShell
    Exec('powershell.exe', '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Expand-Archive -Path ''' + ZipFile + ''' -DestinationPath ''' + TempPath + ''' -Force"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    
    // Move HackBGRT contents to installation directory
    Exec('cmd.exe', '/c xcopy /E /I /Y "' + TempPath + '\HackBGRT-2.6.0\HackBGRT-2.6.0\*" "' + ExpandConstant('{app}') + '\"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
  
  if CurStep = ssPostInstall then
  begin
    Exec('powershell.exe', '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.Forms.MessageBox]::Show(''WinEFI installation completed successfully.'', ''Installation Complete'', ''OK'', ''Information'')"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    if MsgBox(\'Are you sure you want to uninstall WinEFI and restore the original logo?\', mbConfirmation, MB_YESNO) = IDNO then
    begin
      Abort();
    end;
  end;
  
  if CurUninstallStep = usPostUninstall then
  begin
    Exec('powershell.exe', '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.Forms.MessageBox]::Show(''WinEFI uninstalled successfully.'', ''Uninstallation Complete'', ''OK'', ''Information'')"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    // Delete installation folder
    Exec('cmd.exe', '/c rmdir /S /Q "' + ExpandConstant('{app}') + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;
