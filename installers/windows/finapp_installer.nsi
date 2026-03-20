; Installer script for finapp

OutFile "finapp_installer.exe"
InstallDir "$PROGRAMFILES\FinApp"

Page directory
Page instfiles

Section "Install"
    SetOutPath "$INSTDIR"
    File "finapp.exe"  ; Specify the main executable file
    ; You can add additional files to install here
SectionEnd
