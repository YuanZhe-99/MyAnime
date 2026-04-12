[Setup]
AppId={{C3D4E5F6-A7B8-9012-CDEF-123456789ABC}
AppName=MyAnime!!!!!
AppVersion=0.6.4
AppPublisher=yuanzhe
AppPublisherURL=https://github.com/yuanzhe
DefaultDirName={autopf}\MyAnime!!!!!
DefaultGroupName=MyAnime!!!!!
UninstallDisplayIcon={app}\my_anime.exe
OutputDir=build\installer
OutputBaseFilename=MyAnime_0.6.4_Setup
VersionInfoVersion=0.6.4.0
VersionInfoCompany=yuanzhe
VersionInfoDescription=MyAnime!!!!! Installer
VersionInfoProductName=MyAnime!!!!!
VersionInfoProductVersion=0.6.4
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
SetupIconFile=windows\runner\resources\app_icon.ico
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\MyAnime!!!!!"; Filename: "{app}\my_anime.exe"
Name: "{group}\{cm:UninstallProgram,MyAnime!!!!!}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\MyAnime!!!!!"; Filename: "{app}\my_anime.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\my_anime.exe"; Description: "{cm:LaunchProgram,MyAnime!!!!!}"; Flags: nowait postinstall skipifsilent

[Registry]
Root: HKA; Subkey: "Software\Classes\.myanimeitem"; ValueType: string; ValueName: ""; ValueData: "MyAnimeItem"; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\MyAnimeItem"; ValueType: string; ValueName: ""; ValueData: "MyAnime Item"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\MyAnimeItem\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\my_anime.exe,0"
Root: HKA; Subkey: "Software\Classes\MyAnimeItem\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\my_anime.exe"" ""%1"""
