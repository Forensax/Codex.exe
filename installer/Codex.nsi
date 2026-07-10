!ifndef APP_VERSION
  !define APP_VERSION "0.0.0.0"
!endif

!ifndef PAYLOAD_DIR
  !error "PAYLOAD_DIR must be defined by the build script"
!endif

!ifndef APP_EXECUTABLE
  !error "APP_EXECUTABLE must be defined by the build script"
!endif

!ifndef APP_EXECUTABLE_NAME
  !error "APP_EXECUTABLE_NAME must be defined by the build script"
!endif

!ifndef OUTPUT_EXE
  !define OUTPUT_EXE "ChatGPTSetup-x64-${APP_VERSION}.exe"
!endif

!define APP_NAME "ChatGPT"
!define APP_PUBLISHER "OpenAI"
!define APP_REGKEY "Software\OpenAI\ChatGPT"
!define APP_UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChatGPT"
!define APP_PROTOCOL_KEY "Software\Classes\codex"
!define APP_SKILL_PROGID "ChatGPT.skill"
!define APP_APPLICATIONS_KEY "Software\Classes\Applications\${APP_EXECUTABLE_NAME}"

Unicode true
SetCompressor zlib
RequestExecutionLevel admin
InstallDir "$PROGRAMFILES64\ChatGPT"
InstallDirRegKey HKLM "${APP_REGKEY}" "InstallDir"
OutFile "${OUTPUT_EXE}"
Name "${APP_NAME}"
BrandingText "${APP_NAME}"

VIProductVersion "${APP_VERSION}"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "CompanyName" "${APP_PUBLISHER}"
VIAddVersionKey "FileDescription" "${APP_NAME} installer"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "LegalCopyright" "${APP_PUBLISHER}"

!include LogicLib.nsh
!include MUI2.nsh
!include x64.nsh

!define MUI_ABORTWARNING
!ifdef INSTALLER_ICON
  !define MUI_ICON "${INSTALLER_ICON}"
  !define MUI_UNICON "${INSTALLER_ICON}"
!endif

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"

Function .onInit
  SetShellVarContext all
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "ChatGPT 需要 64 位 Windows。"
    Abort
  ${EndIf}
FunctionEnd

Section "ChatGPT" SEC01
  SetShellVarContext all
  SetRegView 64

  SetOutPath "$INSTDIR"
  File /r "${PAYLOAD_DIR}\*.*"
!ifdef INSTALLER_ICON
  File /oname=ChatGPT.ico "${INSTALLER_ICON}"
!endif

  CreateDirectory "$SMPROGRAMS\ChatGPT"
!ifdef INSTALLER_ICON
  CreateShortCut "$SMPROGRAMS\ChatGPT\ChatGPT.lnk" "$INSTDIR\${APP_EXECUTABLE}" "" "$INSTDIR\ChatGPT.ico" 0
  CreateShortCut "$DESKTOP\ChatGPT.lnk" "$INSTDIR\${APP_EXECUTABLE}" "" "$INSTDIR\ChatGPT.ico" 0
!else
  CreateShortCut "$SMPROGRAMS\ChatGPT\ChatGPT.lnk" "$INSTDIR\${APP_EXECUTABLE}" "" "$INSTDIR\${APP_EXECUTABLE}" 0
  CreateShortCut "$DESKTOP\ChatGPT.lnk" "$INSTDIR\${APP_EXECUTABLE}" "" "$INSTDIR\${APP_EXECUTABLE}" 0
!endif

  WriteRegStr HKLM "${APP_REGKEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKLM "${APP_REGKEY}" "Version" "${APP_VERSION}"

  WriteRegStr HKLM "Software\Classes\codex" "" "URL:ChatGPT Protocol"
  WriteRegStr HKLM "Software\Classes\codex" "URL Protocol" ""
!ifdef INSTALLER_ICON
  WriteRegStr HKLM "Software\Classes\codex\DefaultIcon" "" '"$INSTDIR\ChatGPT.ico",0'
!else
  WriteRegStr HKLM "Software\Classes\codex\DefaultIcon" "" '"$INSTDIR\${APP_EXECUTABLE}",0'
!endif
  WriteRegStr HKLM "Software\Classes\codex\shell\open\command" "" '"$INSTDIR\${APP_EXECUTABLE}" "%1"'

  WriteRegStr HKLM "Software\Classes\${APP_SKILL_PROGID}" "" "ChatGPT Skill"
!ifdef INSTALLER_ICON
  WriteRegStr HKLM "Software\Classes\${APP_SKILL_PROGID}\DefaultIcon" "" '"$INSTDIR\ChatGPT.ico",0'
!else
  WriteRegStr HKLM "Software\Classes\${APP_SKILL_PROGID}\DefaultIcon" "" '"$INSTDIR\${APP_EXECUTABLE}",0'
!endif
  WriteRegStr HKLM "Software\Classes\${APP_SKILL_PROGID}\shell\open\command" "" '"$INSTDIR\${APP_EXECUTABLE}" "%1"'
  WriteRegStr HKLM "Software\Classes\.skill\OpenWithProgids" "${APP_SKILL_PROGID}" ""

  WriteRegStr HKLM "${APP_APPLICATIONS_KEY}" "FriendlyAppName" "${APP_NAME}"
  WriteRegStr HKLM "${APP_APPLICATIONS_KEY}\SupportedTypes" ".skill" ""
  WriteRegStr HKLM "${APP_APPLICATIONS_KEY}\shell\open\command" "" '"$INSTDIR\${APP_EXECUTABLE}" "%1"'

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  WriteRegStr HKLM "${APP_UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "${APP_UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "${APP_UNINSTALL_KEY}" "Publisher" "${APP_PUBLISHER}"
  WriteRegStr HKLM "${APP_UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
!ifdef INSTALLER_ICON
  WriteRegStr HKLM "${APP_UNINSTALL_KEY}" "DisplayIcon" '"$INSTDIR\ChatGPT.ico",0'
!else
  WriteRegStr HKLM "${APP_UNINSTALL_KEY}" "DisplayIcon" '"$INSTDIR\${APP_EXECUTABLE}",0'
!endif
  WriteRegStr HKLM "${APP_UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKLM "${APP_UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKLM "${APP_UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${APP_UNINSTALL_KEY}" "NoRepair" 1

  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
SectionEnd

Section "Uninstall"
  SetShellVarContext all
  SetRegView 64

  Delete "$SMPROGRAMS\ChatGPT\ChatGPT.lnk"
  RMDir "$SMPROGRAMS\ChatGPT"
  Delete "$DESKTOP\ChatGPT.lnk"

  DeleteRegKey HKLM "${APP_PROTOCOL_KEY}"
  DeleteRegKey HKLM "Software\Classes\${APP_SKILL_PROGID}"
  DeleteRegKey HKLM "${APP_APPLICATIONS_KEY}"
  DeleteRegValue HKLM "Software\Classes\.skill\OpenWithProgids" "${APP_SKILL_PROGID}"
  DeleteRegKey /ifempty HKLM "Software\Classes\.skill\OpenWithProgids"
  DeleteRegKey /ifempty HKLM "Software\Classes\.skill"
  DeleteRegKey HKLM "${APP_UNINSTALL_KEY}"
  DeleteRegKey HKLM "${APP_REGKEY}"

  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'

  RMDir /r "$INSTDIR"
SectionEnd
