; TaskManager Windows installer for Inno Setup 6
;
; Build order:
;   1. flutter build windows --release
;   2. Put vc_redist.x64.exe next to this .iss file
;   3. Compile this script with Inno Setup
#define MyAppName "TaskManager"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "JH"
#define MyAppExeName "taskmanager.exe"
#define MyAppId "{{052817F2-E157-48D0-BF2A-AFBBC5A06B65}"
#define ReleaseDir "build\windows\x64\runner\Release"
#define VcRedistExe "vc_redist.x64.exe"
[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableDirPage=no
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=installer_output
OutputBaseFilename=TaskManager_Setup_{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
SetupLogging=yes
[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"
[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
[Files]
; Flutter Windows release output. This includes the exe, Flutter/plugin DLLs,
; native assets, and the required data directory.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Required for clean Windows machines that do not already have the MSVC runtime.
; Download the x64 redistributable from Microsoft and place it next to this .iss file:
; https://aka.ms/vs/17/release/vc_redist.x64.exe
Source: "{#VcRedistExe}"; DestDir: "{tmp}"; Flags: deleteafterinstall
[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
[Run]
Filename: "{tmp}\{#VcRedistExe}"; Parameters: "/install /quiet /norestart"; StatusMsg: "Visual C++ Runtime installing..."; Flags: waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
[UninstallDelete]
; Keep user-created memos, database files, and attachments under AppData.
; Only installed program files are removed by the uninstaller.
