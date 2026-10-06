; ============================================================
;  Inno Setup скрипт для pro420x1kmuxsk (muzik420_new)
;  Створює ОДИН setup.exe, який встановлює застосунок
;  БЕЗ адмін-прав (в AppData поточного користувача).
; ============================================================
;
; ЯК ВИКОРИСТАТИ:
; 1. Завантаж і встанови Inno Setup (безкоштовно):
;    https://jrsoftware.org/isdl.php
; 2. Переконайся, що проєкт зібраний у Release-режимі:
;    cd C:\muzik420_new
;    flutter build windows --release
; 3. Відкрий цей файл (muzik420_setup.iss) через Inno Setup Compiler
;    (просто подвійний клік, якщо Inno Setup встановлено)
; 4. Натисни Build -> Compile (або F9)
; 5. Готовий інсталятор з'явиться в папці C:\muzik420_new\installer_output\
;    Це і є твій ОДИН файл — muzik420_setup.exe

#define MyAppName "pro420x1kmuxsk"
#define MyAppVersion "5.0"
#define MyAppPublisher "pro420x1kmuxsk"
#define MyAppExeName "muzik420_new.exe"
#define MySourceDir "C:\muzik420_new\build\windows\x64\runner\Release"

[Setup]
AppId={{A1B2C3D4-1234-4E5F-9A8B-MUZIK420PLAYER}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
; Встановлення в AppData поточного користувача -> НЕ потребує адмін-прав
DefaultDirName={localappdata}\{#MyAppName}
DefaultGroupName={#MyAppName}
PrivilegesRequired=lowest
OutputDir=C:\muzik420_new\installer_output
OutputBaseFilename=muzik420_setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Якщо є власна іконка .ico — розкоментуй і вкажи шлях:
; SetupIconFile=C:\muzik420_new\windows\runner\resources\app_icon.ico
DisableProgramGroupPage=yes
DisableWelcomePage=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "ukrainian"; MessagesFile: "compiler:Languages\Ukrainian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Створити ярлик на робочому столі"; GroupDescription: "Додаткові ярлики:"
Name: "startupicon"; Description: "Запускати автоматично при вході в Windows"; GroupDescription: "Додаткові опції:"; Flags: unchecked

[Files]
; Копіюємо ВСЕ з Release-папки (exe + всі .dll + data\) -- саме тому
; це раніше падало окремим .exe: тепер інсталятор сам розкладе все
; правильно в одну папку на машині користувача.
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Видалити {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Запустити {#MyAppName} зараз"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Прибираємо тимчасові файли плеєра при видаленні
Type: files; Name: "{%TEMP}\muzik420_*.ps1"
Type: files; Name: "{%TEMP}\muzik420_*.txt"
Type: files; Name: "{%TEMP}\muzik420_*.log"
Type: files; Name: "{%TEMP}\muzik420_*.pid"
