; GitHub Desktop Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; What lives here and why:
;   Architecture  GitHub Desktop comes in x64 and ARM64 builds, kept in
;                 App\GitHubDesktop and App\GitHubDesktopARM64. The package
;                 ships the x64 build; the ARM64 one is downloaded on the
;                 first launch on ARM64 Windows. The user can force a build
;                 with Architecture= in GitHubDesktopPortable.ini.
;   Update        Optional self update from GitHub's official installers.
;                 The app is unpacked straight out of the installer (it is
;                 never run, so nothing gets installed), extracted next to the
;                 current build and then swapped in under the journal, so a
;                 failure or a crash keeps the version you had.
;   GitHub        Journaled session changes: the URL protocols GitHub Desktop
;                 registers for itself each time it starts (x-github-client,
;                 x-github-desktop-auth, github-windows) and its notification
;                 class, all put back the way they were when it closes.
;
; The AppData and Documents\GitHub links are not done here: they are declared
; in GitHubDesktopPortable.ini and handled by the journaled Symlinks segment.

; Variables
Var GhdWant
Var GhdIdx
Var GhdDir
Var GhdLabel
Var GhdChannel
Var GhdVer
Var GhdUrl
Var GhdKB
Var GhdDo
Var GhdLocal
Var GhdVer1
Var GhdUrl1
Var GhdKB1
Var GhdDo1
Var GhdVer2
Var GhdUrl2
Var GhdKB2
Var GhdDo2
Var GhdText
Var GhdFailed
Var GhdSwapped
Var GhdTool
Var GhdForce
Var DlWindow
Var DlLabel
Var DlBar
Var DlMsg
Var DlShown
Var DlText

; Defines
!define APPARM64    `GitHubDesktopARM64`
!define EXENAME     `GitHubDesktop.exe`
!define CURL        `$SYSDIR\curl.exe`
!define DEPLOY      `https://central.github.com/deployments/desktop/desktop/latest`
!define UPD         `$PLUGINSDIR\ghdupdate`
!define TOASTCLSID  `{27D44D0C-A542-5B90-BCDB-AC3126048BA2}`
!define CLIBIN      `$EXEDIR\App\bin`
!define /ifndef HWND_BROADCAST 0xFFFF
!define /ifndef WM_SETTINGCHANGE 0x001A

; Functions

; Architecture

; Applies the user's Architecture= setting (auto, x64 or arm64) to $Arch
; before the framework picks the [Launch] executable from it, and notes the
; build this PC should run in $GhdWant. There is no 32-bit GitHub Desktop.
Function GHD_SelectArch
	Push $0
	!ifdef GHD_TEST
		; The Wine test bed is 32-bit: let it pretend to be anything.
		ReadEnvStr $0 GHDTEST_ARCH
		${IfThen} $0 != "" ${|} StrCpy $Arch $0 ${|}
	!endif
	!ifndef GHD_TEST
		${If} $Arch == x86
			MessageBox MB_ICONSTOP|MB_TOPMOST "GitHub Desktop needs 64-bit Windows (x64 or ARM64).$\r$\n$\r$\n${PORTABLEAPPNAME} can't run on this computer."
			Quit
		${EndIf}
	!endif
	${ReadUserConfig} $0 Architecture
	${If} $0 == x64
		StrCpy $Arch x64
	${EndIf}
	; arm64 can only be forced on ARM64 Windows, where it is already the
	; default; anything else keeps what the framework found.
	${If} $Arch == arm64
		StrCpy $GhdWant ${APPARM64}
	${Else}
		StrCpy $GhdWant ${APP}
	${EndIf}
	Pop $0
FunctionEnd

; Points $ProgramExecutable at the build that will run, after an update may
; have added the ARM64 one. The framework built its choice the same way.
Function GHD_Select
	${If} $GhdWant == ${APPARM64}
	${AndIf} ${FileExists} `$EXEDIR\App\${APPARM64}\${EXENAME}`
		StrCpy $ProgramExecutable `${APPARM64}\${EXENAME}`
	${Else}
		StrCpy $ProgramExecutable `${APP}\${EXENAME}`
	${EndIf}
FunctionEnd

; Update helpers

; The per build values live in $GhdVer1, $GhdUrl1, ... (x64) and $GhdVer2,
; ... (ARM64). GHD_Load copies the ones of build $GhdIdx into $GhdDir,
; $GhdLabel, $GhdChannel, $GhdVer, $GhdUrl, $GhdKB and $GhdDo, and
; GHD_Store copies the ones that change back.
Function GHD_Load
	${If} $GhdIdx = 1
		StrCpy $GhdDir ${APP}
		StrCpy $GhdLabel x64
		StrCpy $GhdChannel win32
		StrCpy $GhdVer $GhdVer1
		StrCpy $GhdUrl $GhdUrl1
		StrCpy $GhdKB $GhdKB1
		StrCpy $GhdDo $GhdDo1
	${Else}
		StrCpy $GhdDir ${APPARM64}
		StrCpy $GhdLabel ARM64
		StrCpy $GhdChannel win32-arm64
		StrCpy $GhdVer $GhdVer2
		StrCpy $GhdUrl $GhdUrl2
		StrCpy $GhdKB $GhdKB2
		StrCpy $GhdDo $GhdDo2
	${EndIf}
FunctionEnd

Function GHD_Store
	${If} $GhdIdx = 1
		StrCpy $GhdVer1 $GhdVer
		StrCpy $GhdUrl1 $GhdUrl
		StrCpy $GhdKB1 $GhdKB
		StrCpy $GhdDo1 $GhdDo
	${Else}
		StrCpy $GhdVer2 $GhdVer
		StrCpy $GhdUrl2 $GhdUrl
		StrCpy $GhdKB2 $GhdKB
		StrCpy $GhdDo2 $GhdDo
	${EndIf}
FunctionEnd

; Runs the function _FUNC once per build.
!define GHD::EachBuild "!insertmacro _GHD::EachBuild"
!macro _GHD::EachBuild _FUNC
	StrCpy $GhdIdx 1
	Call GHD_Load
	Call ${_FUNC}
	Call GHD_Store
	StrCpy $GhdIdx 2
	Call GHD_Load
	Call ${_FUNC}
	Call GHD_Store
!macroend

; Sets $1 to the version ("3.6.7") of the GitHub Desktop executable $0, or
; "" when it isn't there.
Function GHD_ExeVersion
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	StrCpy $1 ""
	${If} ${FileExists} $0
		ClearErrors
		GetDllVersion $0 $R0 $R1
		${IfNot} ${Errors}
			IntOp $R2 $R0 >> 16
			IntOp $R2 $R2 & 0xFFFF
			IntOp $R3 $R0 & 0xFFFF
			IntOp $R1 $R1 >> 16
			IntOp $R1 $R1 & 0xFFFF
			StrCpy $1 `$R2.$R3.$R1`
		${EndIf}
	${EndIf}
	Pop $R3
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Sets $1 to true when $0 looks like a version (digits and dots, starting
; and ending with a digit), else false.
Function GHD_IsVersion
	Push $2
	Push $3
	StrCpy $1 false
	StrCpy $2 $0 1
	StrCpy $3 $0 1 -1
	${If} $2 S>= 0
	${AndIf} $2 S<= 9
	${AndIf} $3 S>= 0
	${AndIf} $3 S<= 9
		StrCpy $1 true
		StrCpy $3 0
		${Do}
			StrCpy $2 $0 1 $3
			${IfThen} $2 == "" ${|} ${ExitDo} ${|}
			${If} $2 S< 0
			${OrIf} $2 S> 9
				${If} $2 != .
					StrCpy $1 false
					${ExitDo}
				${EndIf}
			${EndIf}
			IntOp $3 $3 + 1
		${Loop}
	${EndIf}
	Pop $3
	Pop $2
FunctionEnd

; Looks up the latest installer for the build: GitHub's download link for
; it redirects to a URL with the version in it
; (https://desktop.githubusercontent.com/releases/3.6.7-dbc92f97/
; GitHubDesktopSetup-x64.exe), so one HEAD request gives the version, the
; file to download and its size. Sets $GhdVer, $GhdUrl and $GhdKB; $GhdVer
; is "" when the lookup failed.
Function GHD_LatestInstaller
	Push $0
	Push $1
	Push $2
	StrCpy $GhdVer ""
	StrCpy $GhdUrl ""
	StrCpy $GhdKB 0
	Delete `${UPD}\headers.txt`
	nsExec::Exec `"${CURL}" -sSIL --max-redirs 5 -o "${UPD}\headers.txt" "${DEPLOY}/$GhdChannel"`
	Pop $0
	ClearErrors
	FileOpen $0 `${UPD}\headers.txt` r
	${IfNot} ${Errors}
		${Do}
			ClearErrors
			FileRead $0 $1
			${IfThen} ${Errors} ${|} ${ExitDo} ${|}
			; == ignores case, and HTTP/2 headers are lower case.
			StrCpy $2 $1 9
			${If} $2 == "location:"
				StrCpy $1 $1 "" 9
				${Trim} $1 $1
				${WordFind} $1 "/releases/" "E+1}" $2
				${IfNot} ${Errors}
					StrCpy $GhdUrl $1
					; $2 is "3.6.7-dbc92f97/GitHubDesktopSetup-x64.exe".
					${WordFind} $2 "/" "+1" $2
					${WordFind} $2 "-" "+1" $GhdVer
				${EndIf}
			${EndIf}
			; The last Content-Length is the installer's; the ones before it
			; belong to the redirects.
			StrCpy $2 $1 15
			${If} $2 == "content-length:"
				StrCpy $1 $1 "" 15
				${Trim} $1 $1
				StrCpy $2 $1 1
				${If} $2 S>= 0
				${AndIf} $2 S<= 9
					IntOp $GhdKB $1 / 1024
				${EndIf}
			${EndIf}
		${Loop}
		FileClose $0
	${EndIf}
	StrCpy $0 $GhdVer
	Call GHD_IsVersion
	${If} $1 != true
		StrCpy $GhdVer ""
	${EndIf}
	${IfThen} $GhdKB < 0 ${|} StrCpy $GhdKB 0 ${|}
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Decides whether the build gets updated ($GhdDo 1): when it is older than
; the latest release, or missing while it's the build this PC should run.
; Builds the package doesn't have and doesn't need are left alone.
Function GHD_Check
	Push $0
	Push $1
	StrCpy $GhdDo 0
	StrCpy $0 `$EXEDIR\App\$GhdDir\${EXENAME}`
	Call GHD_ExeVersion
	${If} ${FileExists} `$EXEDIR\App\$GhdDir\Update.exe`
		; An older GitHub Desktop Portable kept the installed (Squirrel)
		; layout here; its GitHubDesktop.exe is only a stub.
		StrCpy $1 legacy
	${EndIf}
	${If} $1 == ""
	${AndIf} $GhdDir != $GhdWant
		Goto check_done
	${EndIf}
	StrCpy $GhdLocal $1
	Call GHD_LatestInstaller
	${If} $GhdVer == ""
		StrCpy $GhdFailed "Couldn't find out the latest version of the $GhdLabel build."
		Goto check_done
	${EndIf}
	${If} $GhdLocal == legacy
		StrCpy $GhdDo 1
		StrCpy $GhdText "$GhdText$\r$\n- GitHub Desktop $GhdVer for the $GhdLabel build, replacing the installer-style copy an older ${PORTABLEAPPNAME} kept."
	${ElseIf} $GhdLocal == ""
		StrCpy $GhdDo 1
		StrCpy $GhdText "$GhdText$\r$\n- The $GhdLabel build, GitHub Desktop $GhdVer, which this copy doesn't have yet."
		${If} $GhdDir == ${APPARM64}
			StrCpy $GhdText "$GhdText Until it does, the x64 build runs under emulation."
		${EndIf}
	${Else}
		${VersionCompare} $GhdVer $GhdLocal $0
		${If} $0 = 1
			StrCpy $GhdDo 1
			StrCpy $GhdText "$GhdText$\r$\n- GitHub Desktop $GhdVer for the $GhdLabel build (this copy has $GhdLocal)."
		${EndIf}
	${EndIf}
	check_done:
	Pop $1
	Pop $0
FunctionEnd

; Opens the download window: the banner, made wider, with a progress bar
; under its text. The bar belongs to this thread, so GHD_Pump has to run
; while the download is waiting, or it would never be drawn.
Function GHD_ProgressOpen
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	Push $6
	Push $7
	Push $8
	Push $9
	Banner::show "$DlText"
	Banner::getWindow
	Pop $DlWindow
	GetDlgItem $DlLabel $DlWindow 1030
	StrCpy $DlShown ""
	System::Call 'comctl32::InitCommonControls()'
	System::Call '*(i,i,i,i) p .r0'
	System::Call 'user32::GetWindowRect(p $DlWindow, p r0)'
	System::Call '*$0(i .r1, i .r2, i .r3, i .r4)'
	System::Call 'user32::GetWindowRect(p $DlLabel, p r0)'
	System::Call 'user32::MapWindowPoints(p 0, p $DlWindow, p r0, i 2)'
	System::Call '*$0(i .r5, i .r6, i .r7, i .r8)'
	System::Free $0
	; Sizes come from the label, so they follow the DPI the banner uses:
	; the bar is as tall as the label, with half that as the gap above it,
	; and both are made half as wide again.
	Push $R8
	Push $R9
	IntOp $9 $7 - $5
	IntOp $0 $8 - $6
	IntOp $R9 $0 / 2
	IntOp $R8 $9 / 2
	IntOp $9 $9 + $R8
	; The window grows by the same amounts and stays centred where it was.
	IntOp $3 $3 - $1
	IntOp $3 $3 + $R8
	IntOp $4 $4 - $2
	IntOp $4 $4 + $0
	IntOp $4 $4 + $R9
	IntOp $7 $R8 / 2
	IntOp $1 $1 - $7
	IntOp $7 $0 + $R9
	IntOp $7 $7 / 2
	IntOp $2 $2 - $7
	; SWP_NOZORDER|SWP_NOACTIVATE
	System::Call 'user32::SetWindowPos(p $DlWindow, p 0, i r1, i r2, i r3, i r4, i 0x14)'
	; SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE
	System::Call 'user32::SetWindowPos(p $DlLabel, p 0, i 0, i 0, i r9, i r0, i 0x16)'
	IntOp $8 $8 + $R9
	Pop $R9
	Pop $R8
	; WS_CHILD|WS_VISIBLE, PBS_SMOOTH
	System::Call 'user32::CreateWindowExW(i 0, w "msctls_progress32", w "", i 0x50000001, i r5, i r8, i r9, i r0, p $DlWindow, p 0, p 0, p 0) p .s'
	Pop $DlBar
	${If} $GhdKB > 0
		; PBM_SETRANGE32 0 to 100
		SendMessage $DlBar 0x406 0 100
	${Else}
		; Size unknown: a marquee (PBS_MARQUEE, PBM_SETMARQUEE).
		System::Call 'user32::GetWindowLongW(p $DlBar, i -16) i .r1'
		IntOp $1 $1 | 0x08
		System::Call 'user32::SetWindowLongW(p $DlBar, i -16, i r1)'
		SendMessage $DlBar 0x40A 1 30
	${EndIf}
	System::Call '*(&i32) p .s'
	Pop $DlMsg
	Call GHD_Pump
	Pop $9
	Pop $8
	Pop $7
	Pop $6
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

Function GHD_ProgressClose
	${If} $DlBar != ""
		System::Call 'user32::DestroyWindow(p $DlBar)'
		StrCpy $DlBar ""
	${EndIf}
	${If} $DlMsg != ""
		System::Free $DlMsg
		StrCpy $DlMsg ""
	${EndIf}
	${If} $DlWindow != ""
		Banner::destroy
		StrCpy $DlWindow ""
	${EndIf}
FunctionEnd

; Shows plain text $0 in the banner, opening it when it isn't up yet.
Function GHD_Banner
	${If} $DlWindow == ""
		Banner::show ""
		Banner::getWindow
		Pop $DlWindow
		GetDlgItem $DlLabel $DlWindow 1030
	${EndIf}
	SendMessage $DlLabel ${WM_SETTEXT} 0 "STR:$0"
FunctionEnd

; Handles the messages waiting for this thread (the progress bar's).
Function GHD_Pump
	Push $0
	${Do}
		; PM_REMOVE
		System::Call 'user32::PeekMessageW(p $DlMsg, p 0, i 0, i 0, i 1) i .r0'
		${IfThen} $0 = 0 ${|} ${ExitDo} ${|}
		System::Call 'user32::TranslateMessage(p $DlMsg)'
		System::Call 'user32::DispatchMessageW(p $DlMsg)'
	${Loop}
	Pop $0
FunctionEnd

; Shows $0 bytes downloaded: "45%  (60.2 / 133.4 MB)", or "60.2 MB" when
; the size is unknown. The text only changes when the numbers do.
Function GHD_ProgressSet
	Push $1
	Push $2
	Push $3
	Push $4
	IntOp $1 $0 / 1024
	; Tenths of a MB.
	IntOp $2 $1 * 10
	IntOp $2 $2 / 1024
	IntOp $3 $2 % 10
	IntOp $2 $2 / 10
	StrCpy $2 `$2.$3`
	${If} $GhdKB > 0
		IntOp $4 $1 * 100
		IntOp $4 $4 / $GhdKB
		${IfThen} $4 > 100 ${|} StrCpy $4 100 ${|}
		IntOp $3 $GhdKB * 10
		IntOp $3 $3 / 1024
		IntOp $1 $3 % 10
		IntOp $3 $3 / 10
		StrCpy $3 `$4%  ($2 / $3.$1 MB)`
		SendMessage $DlBar 0x402 $4 0
	${Else}
		StrCpy $3 `$2 MB`
	${EndIf}
	${If} $3 != $DlShown
		StrCpy $DlShown $3
		SendMessage $DlLabel ${WM_SETTEXT} 0 `STR:$DlText  $3`
	${EndIf}
	Pop $4
	Pop $3
	Pop $2
	Pop $1
FunctionEnd

; Downloads the build's installer to ${UPD}\<label>.exe with curl, showing
; its progress.
Function GHD_Download
	${IfThen} $GhdDo != 1 ${|} Return ${|}
	${IfThen} $GhdFailed != "" ${|} Return ${|}
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	Push $6
	Push $7
	Call GHD_ProgressClose
	StrCpy $7 `${UPD}\$GhdLabel.exe`
	Delete $7
	StrCpy $DlText "Downloading GitHub Desktop $GhdVer ($GhdLabel).."
	Call GHD_ProgressOpen
	StrCpy $0 -1
	StrCpy $1 `"${CURL}" -fsSL -o "$7" "$GhdUrl"`
	System::Call '*(i 68, &i64) p .r2'
	System::Call '*(&i16) p .r3'
	; CREATE_NO_WINDOW
	System::Call 'kernel32::CreateProcessW(p 0, w r1, p 0, p 0, i 0, i 0x08000000, p 0, p 0, p r2, p r3) i .r4'
	${If} $4 <> 0
		System::Call '*$3(p .r4, p .r5)'
		System::Call 'kernel32::CloseHandle(p r5)'
		System::Call '*(&i36) p .r6'
		${Do}
			System::Call 'kernel32::WaitForSingleObject(p r4, i 100) i .r5'
			Call GHD_Pump
			; nFileSizeLow of WIN32_FILE_ATTRIBUTE_DATA, at offset 32.
			StrCpy $0 0
			Push $4
			System::Call 'kernel32::GetFileAttributesExW(w r7, i 0, p r6) i .r4'
			${If} $4 <> 0
				System::Call '*$6(&i32, i .r0)'
			${EndIf}
			Pop $4
			Call GHD_ProgressSet
		${LoopWhile} $5 <> 0
		System::Call 'kernel32::GetExitCodeProcess(p r4, *i .r0)'
		System::Call 'kernel32::CloseHandle(p r4)'
		System::Free $6
	${EndIf}
	System::Free $2
	System::Free $3
	Call GHD_ProgressClose
	${If} $0 <> 0
	${OrIfNot} ${FileExists} $7
		StrCpy $GhdFailed "The $GhdLabel download failed (curl exit code $0)."
	${EndIf}
	Pop $7
	Pop $6
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Sets $1 to file or folder name $0 with its %XX escapes decoded. NuGet
; packages store names that way (a space is %20), and Squirrel decodes them
; when it installs. Only ASCII escapes are decoded.
Function GHD_Unescape
	Push $2
	Push $3
	Push $4
	Push $5
	Push $6
	StrCpy $1 ""
	StrCpy $2 0
	${Do}
		StrCpy $3 $0 1 $2
		${IfThen} $3 == "" ${|} ${ExitDo} ${|}
		${If} $3 == "%"
			IntOp $5 $2 + 1
			StrCpy $4 $0 2 $5
			; Two hex digits: they survive a round trip through a number
			; (== ignores case, so "2b" matches "2B").
			IntOp $5 0x$4 + 0
			IntFmt $6 "%02X" $5
			StrLen $5 $4
			${If} $5 = 2
			${AndIf} $6 == $4
				IntOp $5 0x$4 + 0
				${If} $5 >= 32
				${AndIf} $5 < 128
					IntFmt $3 "%c" $5
					IntOp $2 $2 + 2
				${EndIf}
			${EndIf}
		${EndIf}
		StrCpy $1 `$1$3`
		IntOp $2 $2 + 1
	${Loop}
	Pop $6
	Pop $5
	Pop $4
	Pop $3
	Pop $2
FunctionEnd

; Locate callback: notes the first escaped name in $R0 and stops.
Function GHD_FindEscaped
	StrCpy $R0 $R9
	Push StopLocate
FunctionEnd

; Decodes every escaped name under folder $0. One name is renamed per pass
; and the search starts over, so a renamed folder never leaves a stale path
; behind; most packages have no escaped names and need a single pass.
Function GHD_UnescapeTree
	Push $0
	Push $1
	Push $2
	Push $R0
	StrCpy $2 $0
	${Do}
		StrCpy $R0 ""
		${Locate} $2 "/L=FD /M=*%*" GHD_FindEscaped
		${IfThen} $R0 == "" ${|} ${ExitDo} ${|}
		${GetFileName} $R0 $0
		Call GHD_Unescape
		${If} $1 == $0
			; Nothing to decode: a real percent sign. Stop rather than loop.
			${ExitDo}
		${EndIf}
		${GetParent} $R0 $0
		ClearErrors
		Rename $R0 `$0\$1`
		${IfThen} ${Errors} ${|} ${ExitDo} ${|}
	${Loop}
	Pop $R0
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; The installers are Squirrel setups: the app is a NuGet package inside a
; zip file inside Setup.exe's resources. 7-Zip opens the setup straight
; through to that zip; older 7-Zip versions need the resource taken out
; first. The package's lib\net45 folder is the app, as Squirrel would
; install it. Each build is extracted next to the current one, into
; <build>-new, so nothing in use is touched yet.
Function GHD_Extract
	${IfThen} $GhdDo != 1 ${|} Return ${|}
	${IfThen} $GhdFailed != "" ${|} Return ${|}
	Push $0
	Push $1
	Push $2
	Push $R0
	StrCpy $0 `${UPD}\$GhdLabel`
	StrCpy $2 `$EXEDIR\App\$GhdDir-tmp`
	RMDir /r $0
	RMDir /r $2
	RMDir /r `$EXEDIR\App\$GhdDir-new`
	nsExec::Exec `"$GhdTool" e "${UPD}\$GhdLabel.exe" "*-full.nupkg" -o"$0" -y -bso0 -bsp0`
	Pop $1
	FindFirst $1 $R0 `$0\*-full.nupkg`
	FindClose $1
	${If} $R0 == ""
		nsExec::Exec `"$GhdTool" e -tpe "${UPD}\$GhdLabel.exe" ".rsrc\DATA\131" -o"$0" -y -bso0 -bsp0`
		Pop $1
		nsExec::Exec `"$GhdTool" e "$0\131" "*-full.nupkg" -o"$0" -y -bso0 -bsp0`
		Pop $1
		FindFirst $1 $R0 `$0\*-full.nupkg`
		FindClose $1
	${EndIf}
	${If} $R0 == ""
		StrCpy $GhdFailed "The $GhdLabel download is not a GitHub Desktop installer."
		Goto extract_done
	${EndIf}
	nsExec::Exec `"$GhdTool" x "$0\$R0" "lib\net45\*" -o"$2" -y -bso0 -bsp0`
	Pop $1
	ClearErrors
	Rename `$2\lib\net45` `$EXEDIR\App\$GhdDir-new`
	${If} ${Errors}
	${OrIf} $1 <> 0
		StrCpy $GhdFailed "The $GhdLabel build could not be extracted (7-Zip exit code $1)."
		Goto extract_done
	${EndIf}
	StrCpy $0 `$EXEDIR\App\$GhdDir-new`
	Call GHD_UnescapeTree
	; The new build has to be the version the download promised.
	StrCpy $0 `$EXEDIR\App\$GhdDir-new\${EXENAME}`
	Call GHD_ExeVersion
	${VersionCompare} $1 $GhdVer $0
	${If} $1 == ""
	${OrIf} $0 != 0
		StrCpy $GhdFailed "The $GhdLabel download holds GitHub Desktop $1, not $GhdVer."
	${EndIf}
	extract_done:
	RMDir /r $2
	RMDir /r `${UPD}\$GhdLabel`
	Delete `${UPD}\$GhdLabel.exe`
	Pop $R0
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

Function GHD_DropNew
	RMDir /r `$EXEDIR\App\$GhdDir-new`
	RMDir /r `$EXEDIR\App\$GhdDir-tmp`
FunctionEnd

Function GHD_DropBackup
	RMDir /r `$EXEDIR\App\$GhdDir-backup`
FunctionEnd

; Swaps <build>-new in. Moving the current build aside is the backup, and it
; is journaled straight away, so from here on a failure or a crash puts it
; back: the undo deletes the new build and moves the backup into place. A
; build that wasn't there before is journaled with no backup, so the undo
; simply removes it.
Function GHD_Swap
	${IfThen} $GhdDo != 1 ${|} Return ${|}
	${IfThen} $GhdFailed != "" ${|} Return ${|}
	Push $0
	StrCpy $0 `$EXEDIR\App\$GhdDir`
	${If} ${FileExists} `$0\*.*`
		ClearErrors
		Rename $0 `$0-backup`
		${If} ${Errors}
			StrCpy $GhdFailed "The $GhdLabel build is in use and can't be replaced right now. Close GitHub Desktop and every Git window started from it, then try again."
			Pop $0
			Return
		${EndIf}
		${Journal::Record} GHDUpdate DIR $0 `$0-backup` recursive ""
	${Else}
		${Journal::Record} GHDUpdate DIR $0 "" recursive ""
	${EndIf}
	IntOp $GhdSwapped $GhdSwapped + 1
	ClearErrors
	Rename `$0-new` $0
	${If} ${Errors}
		StrCpy $GhdFailed "The new $GhdLabel build could not be moved into place."
	${EndIf}
	Pop $0
FunctionEnd

; Puts the builds back after an update that was interrupted. Called from the
; InstanceManagement segment before the launcher checks that the executable
; exists, and only for a primary launch, so it never touches an update
; another launcher is still doing.
Function GHD_RepairBuild
	Push $0
	StrCpy $0 `$EXEDIR\App\$GhdDir`
	${If} ${FileExists} `$0-backup\*.*`
		${If} ${FileExists} `$0\${EXENAME}`
			; The update was committed; the old copy is left over.
			RMDir /r `$0-backup`
		${Else}
			; The new build never got in place; put the old one back.
			RMDir /r $0
			Rename `$0-backup` $0
		${EndIf}
	${EndIf}
	RMDir /r `$0-new`
	RMDir /r `$0-tmp`
	Pop $0
FunctionEnd

Function GHD_Repair
	Push $0
	${Journal::HasEntries} GHDUpdate $0
	${If} $0 > 0
		${Journal::Rollback} GHDUpdate
	${EndIf}
	${GHD::EachBuild} GHD_RepairBuild
	Pop $0
FunctionEnd

; Checks for a newer GitHub Desktop and, if the user agrees, updates the
; builds the package has. Also offers to download the build this PC should
; run when the package doesn't have it (ARM64, the first time on Windows on
; ARM).
Function GHD_Update
	Push $0
	Push $1
	${ReadUserConfig} $0 UpdateCheck
	${If} $0 != true
	${AndIf} $GhdForce != true
		Goto update_done
	${EndIf}
	; An earlier update that could not be undone yet is retried by the
	; journal; don't start another one.
	${Journal::HasEntries} GHDUpdate $0
	${If} $0 > 0
		Goto update_done
	${EndIf}

	InitPluginsDir
	RMDir /r `${UPD}`
	CreateDirectory `${UPD}`
	StrCpy $GhdFailed ""
	StrCpy $GhdText ""
	${GHD::EachBuild} GHD_Check
	${If} $GhdFailed != ""
		MessageBox MB_ICONSTOP|MB_TOPMOST "Update check failed! $GhdFailed$\r$\n$\r$\nYou need to update ${PORTABLEAPPNAME} manually."
		Goto update_done
	${EndIf}
	${If} $GhdDo1 != 1
	${AndIf} $GhdDo2 != 1
		Goto update_done
	${EndIf}
	${If} $GhdForce == true
		StrCpy $0 "GitHub Desktop has to be downloaded before ${PORTABLEAPPNAME} can start:"
	${Else}
		StrCpy $0 "An update for GitHub Desktop is available:"
	${EndIf}
	MessageBox MB_USERICON|MB_YESNO|MB_TOPMOST "$0$\r$\n$GhdText$\r$\n$\r$\nDo you want to download it now?" IDYES +2
	Goto update_done

	; Download everything first: nothing changes if a download fails.
	${GHD::EachBuild} GHD_Download
	${If} $GhdFailed != ""
		Goto update_failed
	${EndIf}

	StrCpy $0 "Updating GitHub Desktop. Almost done.."
	Call GHD_Banner
	StrCpy $GhdTool `${UPD}\7z.exe`
	File `/oname=${UPD}\7z.exe` `${PACKAGE}\Other\Source\7-Zip\7z.exe`
	File `/oname=${UPD}\7z.dll` `${PACKAGE}\Other\Source\7-Zip\7z.dll`
	${GHD::EachBuild} GHD_Extract
	${If} $GhdFailed != ""
		${GHD::EachBuild} GHD_DropNew
		Goto update_failed
	${EndIf}

	StrCpy $GhdSwapped 0
	${GHD::EachBuild} GHD_Swap
	${If} $GhdFailed != ""
		${Journal::Rollback} GHDUpdate
		${GHD::EachBuild} GHD_DropNew
		Goto update_failed
	${EndIf}

	; Commit. The entries go first: if the launcher stops before the old
	; copies are deleted, GHD_Repair deletes them on the next launch.
	${DoWhile} $GhdSwapped > 0
		${Journal::Discard} GHDUpdate
		IntOp $GhdSwapped $GhdSwapped - 1
	${Loop}
	${GHD::EachBuild} GHD_DropBackup
	Call GHD_Select
	StrCpy $0 `$EXEDIR\App\$ProgramExecutable`
	Call GHD_ExeVersion
	${WriteAppInfoConfig} Version PackageVersion `$1.0`
	${WriteAppInfoConfig} Version DisplayVersion $1
	Call GHD_ProgressClose
	MessageBox MB_ICONINFORMATION|MB_TOPMOST "GitHub Desktop has been updated to $1.$\r$\n$\r$\nNow launching ${PORTABLEAPPNAME}."
	Goto update_done

	update_failed:
	Call GHD_ProgressClose
	MessageBox MB_ICONSTOP|MB_TOPMOST "The update failed. $GhdFailed$\r$\n$\r$\nThe current version of GitHub Desktop was kept."

	update_done:
	Call GHD_ProgressClose
	RMDir /r `${UPD}`
	Pop $1
	Pop $0
FunctionEnd

; Gets the package a build it can run when it has none: a package shipped
; without GitHub Desktop, an ARM64 only copy on an x64 PC, or one from an
; older ${PORTABLEAPPNAME} that still has the installed (Squirrel) layout.
; This runs before the launcher checks for the executable, which is before
; the journal session is opened, so the update's own entries are closed out
; here when it's done.
Function GHD_Bootstrap
	Push $0
	StrCpy $0 false
	${IfNot} ${FileExists} `$EXEDIR\App\$ProgramExecutable`
		StrCpy $0 true
	${EndIf}
	${If} ${FileExists} `$EXEDIR\App\${APP}\Update.exe`
	${OrIf} ${FileExists} `$EXEDIR\App\${APPARM64}\Update.exe`
		StrCpy $0 true
	${EndIf}
	${If} $0 == true
		StrCpy $GhdForce true
		Call GHD_Update
		StrCpy $GhdForce false
		ReadRegStr $0 HKCU `${JOURNAL_KEY}\GHDUpdate` Count
		${If} $0 == 0
			DeleteRegKey HKCU `${JOURNAL_KEY}\GHDUpdate`
		${EndIf}
		${Journal::End}
		Call GHD_Select
		${If} ${FileExists} `$EXEDIR\App\${APP}\Update.exe`
		${AndIf} $ProgramExecutable == `${APP}\${EXENAME}`
			MessageBox MB_ICONSTOP|MB_TOPMOST "This copy of ${PORTABLEAPPNAME} still has GitHub Desktop the way an older version of it kept it, which this version can't run.$\r$\n$\r$\nStart ${PORTABLEAPPNAME} again with an internet connection to download the current GitHub Desktop."
			Quit
		${EndIf}
	${EndIf}
	Pop $0
FunctionEnd

; Session changes

; Removes the command line folder GitHub Desktop can add to the user's PATH
; (App\bin, next to the builds) and the folder itself. Installed copies add
; it when Squirrel installs them, which never happens here, so this is only
; a safety net.
Function GHD_CleanCLI
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	ClearErrors
	ReadRegStr $0 HKCU Environment Path
	${IfNot} ${Errors}
	${AndIf} $0 != ""
		; Rebuild the list without that folder, one character at a time.
		StrCpy $1 ""
		StrCpy $3 ""
		StrCpy $4 0
		StrCpy $5 false
		${Do}
			StrCpy $2 $0 1 $4
			${If} $2 == ";"
			${OrIf} $2 == ""
				${If} $3 == "${CLIBIN}"
				${OrIf} $3 == "${CLIBIN}\"
					StrCpy $5 true
				${ElseIf} $1 == ""
					StrCpy $1 $3
				${Else}
					StrCpy $1 `$1;$3`
				${EndIf}
				StrCpy $3 ""
				${IfThen} $2 == "" ${|} ${ExitDo} ${|}
			${Else}
				StrCpy $3 `$3$2`
			${EndIf}
			IntOp $4 $4 + 1
		${Loop}
		${If} $5 == true
			; Keep the value's type: PATH is usually REG_EXPAND_SZ.
			System::Call 'advapi32::RegOpenKeyExW(p 0x80000001, w "Environment", i 0, i 0x20019, *p .r2) i .r3'
			StrCpy $4 2
			${If} $3 = 0
				System::Call 'advapi32::RegQueryValueExW(p r2, w "Path", p 0, *i .r4, p 0, p 0)'
				System::Call 'advapi32::RegCloseKey(p r2)'
			${EndIf}
			${If} $4 = 1
				WriteRegStr HKCU Environment Path $1
			${Else}
				WriteRegExpandStr HKCU Environment Path $1
			${EndIf}
			SendMessage ${HWND_BROADCAST} ${WM_SETTINGCHANGE} 0 "STR:Environment" /TIMEOUT=500
		${EndIf}
	${EndIf}
	RMDir /r `${CLIBIN}`
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Journals the registry keys GitHub Desktop writes for itself when it
; starts: its three URL protocols (Electron registers them under
; HKCU\Software\Classes, pointing at this copy's executable) and the class
; its notifications use. An installed GitHub Desktop's keys are exported
; first and come back exactly as they were.
Function GHD_Apply
	Push $0
	${Journal::RegKey} GitHub HKCU `Software\Classes\x-github-client` $0
	${Journal::RegKey} GitHub HKCU `Software\Classes\x-github-desktop-auth` $0
	${Journal::RegKey} GitHub HKCU `Software\Classes\github-windows` $0
	${Journal::RegKey} GitHub HKCU `Software\Classes\CLSID\${TOASTCLSID}` $0
	Pop $0
FunctionEnd

; Hooks

; InstanceManagement segment, Init, right before the executable is looked for.
!macro EXE
	${If} $SecondaryLaunch != true
		Call GHD_Repair
		Call GHD_Bootstrap
	${EndIf}
!macroend

${SegmentFile}

${Segment.OnInit}
	Call GHD_SelectArch
!macroend

${SegmentPre}
	; Runs after crash recovery and after the journal session is open, and
	; before the launcher builds the command line, so a build added by the
	; update is the one that starts.
	${If} ${PrimaryInstance}
		Call GHD_Update
	${EndIf}
!macroend

${SegmentPrePrimary}
	Call GHD_CleanCLI
	Call GHD_Apply
!macroend

${SegmentPostPrimary}
	${Journal::HasEntries} GitHub $R0
	${If} $R0 > 0
		${Journal::Rollback} GitHub
	${EndIf}
	Call GHD_CleanCLI
!macroend
