; USBAnywhere Server Installer Script
; Inno Setup 6
; (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server

#define MyAppName "USBAnywhere Server"
#ifndef MyAppVersion
#define MyAppVersion "3.5.0"
#endif
#define MyAppPublisher "oscarlosu-lab"
#define MyAppURL "https://github.com/oscarlosu-lab/USBAnywhere-Server"
#define MyAppExeName "USBAnywhere-Server.exe"
#ifndef SourceDir
#define SourceDir "Portable"
#endif

[Setup]
AppId={{6A1F8C3D-9B42-4E7A-8C5F-2D9E1A4B7C83}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile={#SourceDir}\LICENSE
OutputDir=..\
OutputBaseFilename=USBAnywhere-Server_Setup_v{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=force
CloseApplicationsFilter=*.exe,*.dll
SetupIconFile={#SourceDir}\..\icon.ico

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Iniciar con Windows / Start with Windows"; GroupDescription: "Options:"; Flags: unchecked

[Files]
; Main application
Source: "{#SourceDir}\USBAnywhere-Server.exe"; DestDir: "{app}"; Flags: ignoreversion

; Bundled usbipd-win Drivers
Source: "{#SourceDir}\drivers\*"; DestDir: "{app}\drivers"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; Documentation
Source: "{#SourceDir}\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\CHANGELOG.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Start with Windows (if selected)
Root: HKCU; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExeName}"" --minimized"; Flags: uninsdeletevalue; Tasks: startupicon

[Run]
; Launch after install
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent shellexec

[UninstallRun]
; Remove scheduled startup task and firewall rules on uninstall
Filename: "{sys}\schtasks.exe"; Parameters: "/delete /tn ""USBAnywhere Server"" /f"; Flags: runhidden; RunOnceId: "DelStartupTask"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""USBAnywhere Server (TCP 3240)"""; Flags: runhidden; RunOnceId: "DelFwTcp"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""USBAnywhere Discovery (UDP 3241)"""; Flags: runhidden; RunOnceId: "DelFwUdp"

[UninstallDelete]
; Clean up settings and logs on uninstall
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\data"
Type: files; Name: "{app}\settings.json"
Type: filesandordirs; Name: "{userappdata}\USBAnywhere-Server\logs"

[Code]
procedure CleanupLegacyServerKey(RootKey: Integer);
var
  LegacyKey, DisplayName, OldDir, OldExe, CurDir: String;
  ResultCode: Integer;
begin
  LegacyKey := 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{B2C3D4E5-F6A7-8901-BCDE-F12345678901}_is1';
  if RegQueryStringValue(RootKey, LegacyKey, 'DisplayName', DisplayName) then
  begin
    if CompareText(Trim(DisplayName), 'USBAnywhere Server') = 0 then
    begin
      if RegQueryStringValue(RootKey, LegacyKey, 'InstallLocation', OldDir) then
      begin
        OldDir := RemoveBackslashUnlessRoot(Trim(OldDir));
        CurDir := RemoveBackslashUnlessRoot(ExpandConstant('{app}'));
        if (OldDir <> '') and (CompareText(OldDir, CurDir) <> 0) then
        begin
          OldExe := AddBackslash(OldDir) + 'USBAnywhere-Server.exe';
          if FileExists(OldExe) then
          begin
            Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM USBAnywhere-Server.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
            DeleteFile(OldExe);
          end;
        end;
      end;
      RegDeleteKeyIncludingSubkeys(RootKey, LegacyKey);
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  RunVal: String;
begin
  if CurStep = ssPostInstall then
  begin
    CleanupLegacyServerKey(HKLM64);
    CleanupLegacyServerKey(HKLM32);
    CleanupLegacyServerKey(HKCU);
    if RegQueryStringValue(HKCU, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run', '{#MyAppName}', RunVal) then
      RegWriteStringValue(HKCU, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run', '{#MyAppName}', '"' + ExpandConstant('{app}\{#MyAppExeName}') + '" --minimized');
  end;
end;
