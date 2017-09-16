
;= VARIABLES
;= ################
Var Developer

;= DEFINES
;= ################
!define APP 		`GitHubDesktop`
!define PORTABLE 	`${APP}Portable`

;= PRE INSTALL
;= ################
!macro CustomCodePreInstall
	SetDetailsPrint textonly
	DetailPrint "Checking if ${APP} Portable is already installed.."
	SetDetailsPrint lastused
	${If} ${FileExists} "$INSTDIR\App\AppInfo\appinfo.ini"
		SetDetailsPrint listonly
		DetailPrint "${APP} Portable is already installed.."
		DetailPrint "Checking if ${APP} was created by a different developer.."
		ReadINIStr $0 "$INSTDIR\App\AppInfo\appinfo.ini" Team Developer
		${IfNot} ${Errors}
		${AndIfNot} "$0" == "demon.devin"
			${If} "$0" == ""
				StrCpy $Developer "Unknown Developer"
			${Else}
				StrCpy $Developer "$0"
			${EndIf}
			SetDetailsPrint textonly
			DetailPrint "Different developer detected!"
			SetDetailsPrint lastused
			MESSAGEBOX MB_OKCANCEL|MB_ICONINFORMATION|MB_TOPMOST "Your current version of ${APP} Portable was created by another developer ($Developer).$\r$\n$\r$\nClick OK to overwrite everything and continue.$\r$\nClick Cancel to abort current installation.$\r$\n$\r$\nNOTE: If you select OK, everything will be overwritten (including any settings in ..\Data)." IDOK +3 IDCANCEL 0
			Call .onInstFailed
			Quit
			SetDetailsPrint textonly
			DetailPrint "Preparing current ${APP} Portable for new installation.."
			SetDetailsPrint listonly
			DetailPrint "Erasing previous settings and data.."
			IfFileExists "$INSTDIR\${PORTABLE}.ini" 0 +2
			Delete `$INSTDIR\${PORTABLE}.ini`
			IfFileExists `$INSTDIR\Data\*.*` 0 +2
			RMDir /r `$INSTDIR\Data`
		${EndIf}
	${Else}
		SetDetailsPrint listonly
		DetailPrint "${APP} Portable is not installed.."
		DetailPrint "Continuing with current installation.."
		SetDetailsPrint lastused
	${EndIf}
!macroend

;= POST INSTALL 
;= ################
!macro CustomCodePostInstall
	IfFileExists "$INSTDIR\${PORTABLE}.ini" +2
	CopyFiles /SILENT "$INSTDIR\Other\Source\${PORTABLE}.ini" "$INSTDIR"
!macroend