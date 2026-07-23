; UPES-ECS Emergency PBX - professional, localized, offline installer (Inno Setup 6.3+).
;
; Payload is >4 GB, so a single self-extracting .exe is impossible; Inno DiskSpanning ships a
; branded UPES-ECS-Setup.exe (<2 GB) + UPES-ECS-Setup-N.bin data slices. The wizard runs as
; admin, verifies the host, extracts the payload to a temp folder, shows a progress page while
; offline-bootstrap.ps1 deploys + boots the PBX, then offers the Console.
;
; Compile (paths default to this script's location; override with /D as needed):
;   ISCC.exe packaging\UPES-ECS.iss /DPayload=<staged-folder>
; Optional code signing (define Sign + configure a Sign Tool named "upessign"):
;   ISCC.exe packaging\UPES-ECS.iss /DPayload=<...> /DSign ^
;     "/Supessign=signtool.exe sign /sha1 <THUMBPRINT> /fd sha256 /tr http://timestamp.digicert.com /td sha256 /d $qUPES-ECS$q $f"

#define MyApp        "UPES-ECS Emergency PBX"
#define MyVersion    "1.0.0"
#define MyPublisher  "UPES"
#define BuildDate    GetDateTimeString('yyyy-mm-dd', '', '')
#ifndef Brand
  #define Brand      AddBackslash(SourcePath) + "brand"
#endif
#ifndef Payload
  ; No sensible relative default for a >4 GB staged payload; Build-InnoInstaller.ps1 passes it.
  #define Payload    "C:\ProgramData\upes-innosrc\UPES-ECS-Setup"
#endif
#ifndef RepoRoot
  #define RepoRoot   AddBackslash(SourcePath) + ".."
#endif

[Setup]
AppId={{7F3A9C2E-4B1D-4E8A-9C6F-1A2B3C4D5E6F}
AppName={#MyApp}
AppVersion={#MyVersion}
AppVerName={#MyApp} {#MyVersion} (built {#BuildDate})
AppPublisher={#MyPublisher}
AppComments=Self-contained offline emergency phone system (Asterisk PBX on a bundled VM).
VersionInfoVersion=1.0.0.0
VersionInfoProductVersion=1.0.0.0
VersionInfoCompany={#MyPublisher}
VersionInfoProductName={#MyApp}
VersionInfoDescription={#MyApp} Setup
DefaultDirName={autopf}\UPES-ECS
DefaultGroupName=UPES-ECS
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
OutputDir={#RepoRoot}\dist
OutputBaseFilename=UPES-ECS-Setup-{#MyVersion}-x64
SetupIconFile={#Brand}\brand.ico
UninstallDisplayIcon={app}\brand.ico
UninstallDisplayName={#MyApp}
UninstallDisplaySize=10737418240
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
#ifdef Sign
SignTool=upessign
SignedUninstaller=yes
#endif

[Languages]
; Official bundled translations only (so the script compiles on any Inno 6 install).
Name: "en";    MessagesFile: "compiler:Default.isl"
Name: "ar";    MessagesFile: "compiler:Languages\Arabic.isl"
Name: "bg";    MessagesFile: "compiler:Languages\Bulgarian.isl"
Name: "ca";    MessagesFile: "compiler:Languages\Catalan.isl"
Name: "cs";    MessagesFile: "compiler:Languages\Czech.isl"
Name: "da";    MessagesFile: "compiler:Languages\Danish.isl"
Name: "de";    MessagesFile: "compiler:Languages\German.isl"
Name: "es";    MessagesFile: "compiler:Languages\Spanish.isl"
Name: "fi";    MessagesFile: "compiler:Languages\Finnish.isl"
Name: "fr";    MessagesFile: "compiler:Languages\French.isl"
Name: "he";    MessagesFile: "compiler:Languages\Hebrew.isl"
Name: "hu";    MessagesFile: "compiler:Languages\Hungarian.isl"
Name: "it";    MessagesFile: "compiler:Languages\Italian.isl"
Name: "ja";    MessagesFile: "compiler:Languages\Japanese.isl"
Name: "ko";    MessagesFile: "compiler:Languages\Korean.isl"
Name: "nl";    MessagesFile: "compiler:Languages\Dutch.isl"
Name: "no";    MessagesFile: "compiler:Languages\Norwegian.isl"
Name: "pl";    MessagesFile: "compiler:Languages\Polish.isl"
Name: "pt";    MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "ptbr";  MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "ru";    MessagesFile: "compiler:Languages\Russian.isl"
Name: "sk";    MessagesFile: "compiler:Languages\Slovak.isl"
Name: "sl";    MessagesFile: "compiler:Languages\Slovenian.isl"
Name: "sv";    MessagesFile: "compiler:Languages\Swedish.isl"
Name: "ta";    MessagesFile: "compiler:Languages\Tamil.isl"
Name: "th";    MessagesFile: "compiler:Languages\Thai.isl"
Name: "tr";    MessagesFile: "compiler:Languages\Turkish.isl"
Name: "uk";    MessagesFile: "compiler:Languages\Ukrainian.isl"

[CustomMessages]
; --- Wizard chrome overrides (default = every language unless a lang-specific one exists) ---
WelcomeBlurb=This will install [name] on your computer.%n%nEverything is included - no internet connection, Python, or QEMU install is required. The pre-provisioned phone server boots on first run.%n%nYou will be asked to approve opening the phone (SIP/RTP) ports in the firewall.
FinishedBlurb=Setup has finished installing [name].%n%nThe Operations Console is at http://localhost:8080 and phones can register to upes-ecs.local:5060 (dial 111). A "UPES-ECS Repair" shortcut is on your Desktop if anything needs attention.
DesktopTask=Create a Desktop shortcut to the Operations Console
OpenConsole=Open the Operations Console now
Provisioning=Provisioning the emergency PBX (this can take a few minutes)...
BuildCaption=Setting up the emergency phone server
BuildDesc=Please wait while the pre-built phone server is deployed and started. This can take a few minutes on first run.
; --- Prerequisite abort/warn messages ---
MsgNeedWin10=UPES-ECS requires 64-bit Windows 10 (version 2004 / build 19041) or newer.
MsgNeed64Bit=UPES-ECS requires a 64-bit edition of Windows.
MsgNeedRam=UPES-ECS needs at least %1 GB of RAM to run the bundled virtual machine.
MsgNeedDisk=UPES-ECS needs at least %1 GB of free disk space to install and run.
MsgVirtMaybeOff=Hardware virtualization does not appear to be enabled in your BIOS/UEFI. The bundled phone server may run slowly or fail to start.%n%nContinue anyway?

; --- Spanish ---
es.WelcomeBlurb=Esto instalar%E1 [name] en su equipo.%n%nTodo est%E1 incluido: no se necesita conexi%F3n a Internet, Python ni QEMU. El servidor telef%F3nico preconfigurado se inicia en el primer arranque.%n%nSe le pedir%E1 aprobar la apertura de los puertos de tel%E9fono (SIP/RTP) en el firewall.
es.DesktopTask=Crear un acceso directo en el escritorio a la Consola de Operaciones
es.OpenConsole=Abrir la Consola de Operaciones ahora
es.Provisioning=Aprovisionando la central de emergencia (esto puede tardar unos minutos)...
es.BuildCaption=Configurando el servidor telef%F3nico de emergencia
es.BuildDesc=Espere mientras se despliega e inicia el servidor telef%F3nico preconfigurado. Puede tardar unos minutos.
es.MsgNeedRam=UPES-ECS necesita al menos %1 GB de RAM para ejecutar la m%E1quina virtual incluida.
es.MsgNeedDisk=UPES-ECS necesita al menos %1 GB de espacio libre en disco para instalarse y ejecutarse.

; --- French ---
fr.WelcomeBlurb=Ceci va installer [name] sur votre ordinateur.%n%nTout est inclus : aucune connexion Internet, ni Python, ni QEMU n'est requis. Le serveur t%E9l%E9phonique pr%E9configur%E9 d%E9marre au premier lancement.%n%nIl vous sera demand%E9 d'autoriser l'ouverture des ports t%E9l%E9phoniques (SIP/RTP) dans le pare-feu.
fr.DesktopTask=Cr%E9er un raccourci sur le Bureau vers la Console d'exploitation
fr.OpenConsole=Ouvrir la Console d'exploitation maintenant
fr.Provisioning=Provisionnement de la centrale d'urgence (cela peut prendre quelques minutes)...
fr.BuildCaption=Configuration du serveur t%E9l%E9phonique d'urgence
fr.BuildDesc=Veuillez patienter pendant le d%E9ploiement et le d%E9marrage du serveur t%E9l%E9phonique pr%E9configur%E9. Cela peut prendre quelques minutes.
fr.MsgNeedRam=UPES-ECS n%E9cessite au moins %1 Go de RAM pour ex%E9cuter la machine virtuelle incluse.
fr.MsgNeedDisk=UPES-ECS n%E9cessite au moins %1 Go d'espace disque libre pour s'installer et fonctionner.

; --- German ---
de.WelcomeBlurb=Dies installiert [name] auf Ihrem Computer.%n%nAlles ist enthalten - keine Internetverbindung, kein Python und keine QEMU-Installation erforderlich. Der vorkonfigurierte Telefonserver startet beim ersten Start.%n%nSie werden gebeten, das %D6ffnen der Telefon-Ports (SIP/RTP) in der Firewall zu best%E4tigen.
de.DesktopTask=Eine Desktop-Verkn%FCpfung zur Betriebskonsole erstellen
de.OpenConsole=Die Betriebskonsole jetzt %F6ffnen
de.Provisioning=Die Notruf-Telefonanlage wird eingerichtet (dies kann einige Minuten dauern)...
de.BuildCaption=Einrichten des Notruf-Telefonservers
de.BuildDesc=Bitte warten Sie, w%E4hrend der vorkonfigurierte Telefonserver bereitgestellt und gestartet wird. Dies kann beim ersten Start einige Minuten dauern.
de.MsgNeedRam=UPES-ECS ben%F6tigt mindestens %1 GB RAM, um die mitgelieferte virtuelle Maschine auszuf%FChren.
de.MsgNeedDisk=UPES-ECS ben%F6tigt mindestens %1 GB freien Speicherplatz zur Installation und Ausf%FChrung.

; --- Portuguese ---
pt.WelcomeBlurb=Isto ir%E1 instalar [name] no seu computador.%n%nEst%E1 tudo inclu%EDdo - n%E3o %E9 necess%E1ria liga%E7%E3o %E0 Internet, Python ou QEMU. O servidor telef%F3nico pr%E9-configurado arranca na primeira execu%E7%E3o.
pt.OpenConsole=Abrir a Consola de Opera%E7%F5es agora
pt.Provisioning=A aprovisionar a central de emerg%EAncia (pode demorar alguns minutos)...
pt.BuildCaption=A configurar o servidor telef%F3nico de emerg%EAncia
pt.BuildDesc=Aguarde enquanto o servidor telef%F3nico pr%E9-configurado %E9 implementado e iniciado.

; --- Italian ---
it.WelcomeBlurb=Verr%E0 installato [name] sul computer.%n%nTutto %E8 incluso - non sono necessari connessione Internet, Python o QEMU. Il server telefonico preconfigurato si avvia al primo avvio.
it.OpenConsole=Apri ora la Console operativa
it.Provisioning=Provisioning del centralino di emergenza (potrebbe richiedere alcuni minuti)...
it.BuildCaption=Configurazione del server telefonico di emergenza
it.BuildDesc=Attendere il deployment e l'avvio del server telefonico preconfigurato.

; --- Russian ---
ru.OpenConsole=%CE%F2%EA%F0%FB%F2%FC %EA%EE%ED%F1%EE%EB%FC %EE%EF%E5%F0%E0%F6%E8%E9 %F1%E5%E9%F7%E0%F1
ru.Provisioning=%CF%EE%E4%E3%EE%F2%EE%E2%EA%E0 %F1%E8%F1%F2%E5%EC%FB %FD%EA%F1%F2%F0%E5%ED%ED%EE%E9 %F1%E2%FF%E7%E8 (%FD%F2%EE %EC%EE%E6%E5%F2 %E7%E0%ED%FF%F2%FC %ED%E5%F1%EA%EE%EB%FC%EA%EE %EC%E8%ED%F3%F2)...

[Messages]
; Fold the localized custom blurbs into the Welcome/Finished pages.
WelcomeLabel2={cm:WelcomeBlurb}
FinishedLabelNoIcons={cm:FinishedBlurb}

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopTask}"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "{#Brand}\brand.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RepoRoot}\deploy\qemu\Uninstall-UpesEcs.ps1"; DestDir: "{app}"; Flags: ignoreversion
; Full payload -> temp (auto-removed when Setup exits); bootstrap deploys it to the runtime.
Source: "{#Payload}\*"; DestDir: "{tmp}\upes"; Excludes: "Setup.cmd"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\UPES-ECS Operations Console"; Filename: "http://localhost:8080"; IconFilename: "{app}\brand.ico"
Name: "{group}\Uninstall UPES-ECS"; Filename: "{uninstallexe}"
Name: "{autodesktop}\UPES-ECS Operations Console"; Filename: "http://localhost:8080"; IconFilename: "{app}\brand.ico"; Tasks: desktopicon

[Run]
; The console open is offered on the Finished page; the long VM provision runs from [Code] with a progress page.
Filename: "http://localhost:8080"; Description: "{cm:OpenConsole}"; Flags: postinstall shellexec skipifsilent unchecked nowait

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Uninstall-UpesEcs.ps1"""; RunOnceId: "upescleanup"; Flags: waituntilterminated runhidden

[Code]
const
  PF_VIRT_FIRMWARE_ENABLED = 21;
  REQ_RAM_GB  = 4;
  REQ_DISK_GB = 20;

function GetPhysicallyInstalledSystemMemory(var TotalKB: Int64): Boolean;
  external 'GetPhysicallyInstalledSystemMemory@kernel32.dll stdcall';
function IsProcessorFeaturePresent(Feature: Cardinal): Boolean;
  external 'IsProcessorFeaturePresent@kernel32.dll stdcall';

var
  BuildPage: TOutputProgressWizardPage;

{ Hard + advisory prerequisite gate, before any UI. Localized abort text. }
function InitializeSetup(): Boolean;
var
  KB, FreeB, TotalB: Int64;
begin
  Result := True;

  if not IsWin64 then
  begin
    MsgBox(CustomMessage('MsgNeed64Bit'), mbCriticalError, MB_OK);
    Result := False; Exit;
  end;

  if GetPhysicallyInstalledSystemMemory(KB) then
    if KB < Int64(REQ_RAM_GB) * 1024 * 1024 then
    begin
      MsgBox(FmtMessage(CustomMessage('MsgNeedRam'), [IntToStr(REQ_RAM_GB)]), mbCriticalError, MB_OK);
      Result := False; Exit;
    end;

  if GetSpaceOnDisk64(ExpandConstant('{sd}'), FreeB, TotalB) then
    if FreeB < Int64(REQ_DISK_GB) * 1073741824 then
    begin
      MsgBox(FmtMessage(CustomMessage('MsgNeedDisk'), [IntToStr(REQ_DISK_GB)]), mbCriticalError, MB_OK);
      Result := False; Exit;
    end;

  { Virtualization is ADVISORY only (unreliable to detect) - warn, never hard-block. }
  if not IsProcessorFeaturePresent(PF_VIRT_FIRMWARE_ENABLED) then
    if MsgBox(CustomMessage('MsgVirtMaybeOff'), mbConfirmation, MB_YESNO) = IDNO then
    begin
      Result := False; Exit;
    end;
end;

procedure InitializeWizard;
begin
  BuildPage := CreateOutputProgressPage(CustomMessage('BuildCaption'), CustomMessage('BuildDesc'));
end;

{ Run the long offline provisioning with a visible progress page. }
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    BuildPage.Show;
    try
      BuildPage.SetText(CustomMessage('Provisioning'), '');
      BuildPage.SetProgress(1, 2);
      WizardForm.Refresh;
      if not Exec('powershell.exe',
           '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{tmp}\upes\offline-bootstrap.ps1') + '" -Mode Install',
           '', SW_HIDE, ewWaitUntilTerminated, ResultCode) or (ResultCode <> 0) then
        RaiseException('Provisioning failed (exit ' + IntToStr(ResultCode) + '). See the setup log.');
      BuildPage.SetProgress(2, 2);
    finally
      BuildPage.Hide;
    end;
  end;
end;
