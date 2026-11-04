#define MyAppName "TaskManager"
#define MyAppVersion "1.1.2"
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
CloseApplications=yes
CloseApplicationsFilter=*taskmanager.exe
RestartApplications=yes

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#VcRedistExe}"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: NeedsVcRedist

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{tmp}\{#VcRedistExe}"; Parameters: "/install /quiet /norestart"; StatusMsg: "Visual C++ Runtime installing..."; Flags: waituntilterminated; Check: NeedsVcRedist
Filename: "{app}\{#MyAppExeName}"; Flags: nowait runasoriginaluser; Check: IsSilentUpdate
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent; Check: not IsSilentUpdate
[UninstallDelete]

[Code]
function IsSilentUpdate(): Boolean;
begin
  Result := WizardSilent();
end;

// 동봉한 VC++ 런타임(14.44.35211)과 같거나 새 버전이 이미 있으면 설치 건너뜀
const
  VcRedistMinor = 44;
  VcRedistBld = 35211;
  VcRuntimeKey = 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64';

function VcRuntimeInstalled(RootKey: Integer): Boolean;
var
  Installed, Minor, Bld: Cardinal;
begin
  Result :=
    RegQueryDWordValue(RootKey, VcRuntimeKey, 'Installed', Installed) and
    RegQueryDWordValue(RootKey, VcRuntimeKey, 'Minor', Minor) and
    RegQueryDWordValue(RootKey, VcRuntimeKey, 'Bld', Bld) and
    (Installed = 1) and
    ((Minor > VcRedistMinor) or ((Minor = VcRedistMinor) and (Bld >= VcRedistBld)));
end;

function NeedsVcRedist(): Boolean;
begin
  Result := not (VcRuntimeInstalled(HKLM64) or VcRuntimeInstalled(HKLM32));
end;