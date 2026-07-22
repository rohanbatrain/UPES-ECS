; UPES-ECS Emergency PBX - professional branded offline installer (Inno Setup 6).
; Payload is >4 GB so a single self-extracting .exe is impossible; Inno DiskSpanning ships a
; branded UPES-ECS-Setup.exe (<4 GB) + UPES-ECS-Setup-N.bin data slices. The wizard runs as
; admin, extracts the payload to a temp folder, and launches offline-bootstrap.ps1 which
; deploys + boots the PBX. Compile:  ISCC.exe packaging\UPES-ECS.iss
; #Payload / #Brand can be overridden:  ISCC /DPayload=<staged-folder> /DBrand=<brand-dir> ...

#define MyApp        "UPES-ECS Emergency PBX"
#define MyVersion    "1.0.0"
#define MyPublisher  "UPES"
#define BuildDate    GetDateTimeString('yyyy-mm-dd', '', '')
#ifndef Brand
  #define Brand      "C:\Users\Rohan\UPES\packaging\brand"
#endif
#ifndef Payload
  #define Payload    "C:\Users\Rohan\AppData\Local\Temp\innosrc\UPES-ECS-Setup"
#endif

[Setup]
AppId={{7F3A9C2E-4B1D-4E8A-9C6F-1A2B3C4D5E6F}
AppName={#MyApp}
AppVersion={#MyVersion}
AppVerName={#MyApp} {#MyVersion} (built {#BuildDate})
AppPublisher={#MyPublisher}
AppComments=Self-contained offline emergency phone system (Asterisk PBX on a bundled VM).
VersionInfoVersion=1.0.0.0
VersionInfoCompany={#MyPublisher}
VersionInfoProductName={#MyApp}
VersionInfoDescription={#MyApp} Setup
DefaultDirName={autopf}\UPES-ECS
DefaultGroupName=UPES-ECS
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir=C:\Users\Rohan\UPES\dist
OutputBaseFilename=UPES-ECS-Setup
SetupIconFile={#Brand}\brand.ico
UninstallDisplayIcon={app}\brand.ico
UninstallDisplayName={#MyApp}
WizardStyle=modern
WizardImageFile={#Brand}\wizard-large.bmp,{#Brand}\wizard-large-2x.bmp
WizardSmallImageFile={#Brand}\wizard-small.bmp,{#Brand}\wizard-small-2x.bmp
InfoBeforeFile={#Brand}\readme-before.txt
DisableWelcomePage=no
SetupLogging=yes
Compression=none
DiskSpanning=yes
DiskSliceSize=1900000000
SolidCompression=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
WelcomeLabel2=This will install [name] on your computer.%n%nEverything is included - no internet connection, Python, or QEMU install is required. The pre-provisioned phone server boots on first run.%n%nYou will be asked to approve opening the phone (SIP/RTP) ports in the firewall.
FinishedLabelNoIcons=Setup has finished installing [name].%n%nThe Operations Console is at http://localhost:8080 and phones can register to upes-ecs.local:5060 (dial 111). A "UPES-ECS Repair" shortcut is on your Desktop if anything needs attention.

[Tasks]
Name: "desktopicon"; Description: "Create a Desktop shortcut to the Operations Console"; GroupDescription: "Additional shortcuts:"

[Files]
; Brand icon + uninstaller kept on disk (Programs & Features icon + clean removal).
Source: "{#Brand}\brand.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\Rohan\UPES\deploy\qemu\Uninstall-UpesEcs.ps1"; DestDir: "{app}"; Flags: ignoreversion
; Full payload -> temp (auto-removed when Setup exits); bootstrap deploys it to the runtime.
Source: "{#Payload}\*"; DestDir: "{tmp}\upes"; Excludes: "Setup.cmd"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\UPES-ECS Operations Console"; Filename: "http://localhost:8080"; IconFilename: "{app}\brand.ico"
Name: "{group}\Uninstall UPES-ECS"; Filename: "{uninstallexe}"
Name: "{autodesktop}\UPES-ECS Operations Console"; Filename: "http://localhost:8080"; IconFilename: "{app}\brand.ico"; Tasks: desktopicon

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{tmp}\upes\offline-bootstrap.ps1"" -Mode Install"; StatusMsg: "Provisioning the emergency PBX (this can take a few minutes)..."; Flags: waituntilterminated
Filename: "http://localhost:8080"; Description: "Open the Operations Console now"; Flags: postinstall shellexec skipifsilent unchecked nowait

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Uninstall-UpesEcs.ps1"""; RunOnceId: "upescleanup"; Flags: waituntilterminated runhidden
