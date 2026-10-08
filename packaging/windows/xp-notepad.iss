; Inno Setup script for the XP Notepad Windows installer.
;
; The release workflow (.github/workflows/release.yml) runs the Inno Setup compiler with:
;   ISCC /DAppVersion=0.1.0 /DTargetArch=x64 /DSourceDir=<Flutter Release folder>
;        /DOutputDir=<output folder> packaging\windows\xp-notepad.iss
; TargetArch is x64 or arm64. Each installer contains only that architecture.

#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef TargetArch
  #define TargetArch "x64"
#endif
#ifndef SourceDir
  #error SourceDir must be given, for example /DSourceDir=build\windows\x64\runner\Release
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

#if TargetArch == "arm64"
  #define AllowedArch "arm64"
#else
  #define AllowedArch "x64compatible"
#endif

[Setup]
AppId={{B0E6C9B4-3F5A-4C1E-9D7B-2A8F4E6C1D53}
AppName=XP Notepad
AppVersion={#AppVersion}
AppVerName=XP Notepad {#AppVersion}
AppPublisher=Gosh Apps
AppPublisherURL=https://github.com/goshitsarch-eng/notepad
AppSupportURL=https://github.com/goshitsarch-eng/notepad/issues
AppUpdatesURL=https://github.com/goshitsarch-eng/notepad/releases
DefaultDirName={autopf}\XP Notepad
DefaultGroupName=XP Notepad
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE
OutputDir={#OutputDir}
OutputBaseFilename=xp-notepad-{#AppVersion}-windows-{#TargetArch}-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\xp_notepad.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed={#AllowedArch}
ArchitecturesInstallIn64BitMode={#AllowedArch}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\XP Notepad"; Filename: "{app}\xp_notepad.exe"
Name: "{group}\Uninstall XP Notepad"; Filename: "{uninstallexe}"
Name: "{autodesktop}\XP Notepad"; Filename: "{app}\xp_notepad.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\xp_notepad.exe"; Description: "Launch XP Notepad"; Flags: nowait postinstall skipifsilent
