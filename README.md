# GitHub Desktop Portable

GitHub Desktop Portable is a portable build of [GitHub Desktop](https://desktop.github.com/), GitHub's open-source app for working with Git and GitHub repositories. It runs the build that's native to the computer (x64 or ARM64) and keeps itself up to date.

It's built with the [PortableApps Compiler](https://github.com/daemondevin/pac-man) (pac-man): every change it makes to Windows is recorded first and undone when GitHub Desktop closes, or on the next launch if something went wrong.

## Download

Downloads are in the [Releases section](../../releases/latest). The package is in [PortableApps.com](https://portableapps.com/) format, so it installs into the PortableApps.com Platform or any folder you like.

## Features

* The full GitHub Desktop, with its bundled Git.
* **Native on every PC:** x64 and ARM64 builds. On Windows on ARM the launcher downloads and runs the ARM64 build instead of running x64 under emulation. (See [Builds](#builds))
* **Updates itself:** checks GitHub's official downloads at start and updates the builds the package has. A failed or interrupted update keeps the version you had. (See [Updates](#updates))
* **Your data travels with it:** settings, the repository list, and the repositories you clone into the default folder are kept in `Data`. (See [Data](#data))
* **Leaves the PC's Git alone:** your Git name and email live in `Data\\.gitconfig`, not in the PC's `.gitconfig`.
* **Leaves nothing behind:** the `x-github-client`, `x-github-desktop-auth` and `github-windows` links GitHub Desktop registers for itself only exist while it runs. An installed GitHub Desktop's links are put back exactly as they were.
* **No administrator rights:** everything is done for the current user only.

## System Requirements

* Windows 10 or later, 64-bit (x64 or ARM64). GitHub Desktop has no 32-bit build.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).
* An internet connection for updates and for working with GitHub.
* `Data` on a local drive (a USB drive is fine; a network share isn't). See [Data](#data).

## Configuration

`GitHubDesktopPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\\Source\\GitHubDesktopPortable.ini` over it.

```INI
[GitHubDesktopPortable]
AdditionalParameters=
RunLocally=false
UpdateCheck=true
Architecture=auto
```

|Key|Values|Default|What it does|
|-|-|-|-|
|`UpdateCheck`|`true`, `false`|`true`|Check for a new GitHub Desktop at start and offer to update.|
|`Architecture`|`auto`, `x64`, `arm64`|`auto`|Which build to run. `auto` picks the native one.|
|`AdditionalParameters`|text|empty|Extra command line switches passed to GitHub Desktop.|
|`RunLocally`|`true`, `false`|`false`|Copy GitHub Desktop to the `TEMP` folder and run it from there.|

## Builds

|Folder|Build|Runs on|
|-|-|-|
|`App\\GitHubDesktop`|x64|x64 Windows, and Windows 11 on ARM under emulation|
|`App\\GitHubDesktopARM64`|ARM64|ARM64 Windows|

The package ships the x64 build. The first time it starts on ARM64 Windows (with `UpdateCheck=true`), it offers to download the ARM64 build; until then the x64 build runs under emulation. If the build the launcher wants is missing, it falls back to the other one instead of failing to start.

To force a build, set `Architecture=x64` or `arm64`. The ARM64 build can only be forced on ARM64 Windows.

## Updates

With `UpdateCheck=true`, the launcher asks GitHub for the latest GitHub Desktop each time it starts, the same download links the [GitHub Desktop website](https://desktop.github.com/) uses. When there's a newer version for a build the package has, it asks before doing anything.

An update is all or nothing:

1. Every installer is downloaded, with a progress bar. If a download fails, nothing changes.
2. GitHub Desktop is unpacked straight out of each installer, next to the current build. The installer is never run, so nothing gets installed on the PC. If anything can't be unpacked, or isn't the version GitHub announced, nothing changes.
3. The new builds are swapped in. Each swap is recorded first, so if one fails, or the launcher is interrupted halfway, the previous version is put back, on the spot or on the next launch.

The launcher carries its own copy of 7-Zip for the unpacking, so it needs no other tools.

A build can't be replaced while it's in use. If the update says so, close GitHub Desktop and any Git window started from it, then try again.

GitHub Desktop's own **Check for updates** (in **Help > About GitHub Desktop**) doesn't work in the portable build, because it relies on the installed version's updater. Use the launcher's instead, or install a newer release of GitHub Desktop Portable over the old one. Your `Data` folder is kept either way.

### Packages without GitHub Desktop

If the package has no build it can run, the launcher offers to download one before it starts. This also happens once for copies made by older versions of GitHub Desktop Portable, which kept GitHub Desktop the way its installer does (`Update.exe` and `app-<version>` folders); the new build replaces that copy, and `Data` is kept.

## Data

GitHub Desktop keeps everything in two places, which the launcher links into `Data` while it runs:

|GitHub Desktop uses|Kept in|
|-|-|
|`%APPDATA%\\GitHub Desktop` (settings, repository list, sign-in state)|`Data\\AppData\\GitHub Desktop`|
|`Documents\\GitHub` (the default folder for cloned repositories)|`Data\\GitHub`|

The links are NTFS junctions, so nothing is copied back and forth, however big your repositories get. If an installed GitHub Desktop already has either folder, it's moved aside for the session and put back when GitHub Desktop Portable closes.

Because the repositories are reached through `Documents\\GitHub`, their paths don't change when the drive letter does. Repositories you add from anywhere else are remembered by their full path, so keep them under the default folder if they travel with the package.

> \[!NOTE]
> GitHub Desktop stores your GitHub sign-in in the Windows Credential Manager of the PC you sign in on. On a different PC you'll be asked to sign in again.

> \[!IMPORTANT]
> Junctions can only point to a local drive. Running from a network share isn't supported.

## If something goes wrong

If GitHub Desktop Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes everything the last session changed before it starts again. You don't need to do anything else.

When reporting a problem, please include an export of the `HKEY\_CURRENT\_USER\\Software\\pac-man\\Journal` registry key and the contents of `%LOCALAPPDATA%\\pac-man\\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler](https://github.com/daemondevin/pac-man). Its configuration lives in `App\\AppInfo`:

|File|Contents|
|-|-|
|`App\\AppInfo\\appinfo.ini`|Package details and version|
|`App\\AppInfo\\Launcher\\GitHubDesktopPortable.ini`|The launcher configuration: executables per build, the data links, the Git settings|
|`App\\AppInfo\\Launcher\\custom.nsh`|Build selection, the updater and the protocol links|
|`Other\\Source\\7-Zip`|The 7-Zip the updater uses, embedded in the launcher at compile time|

Point PortableApps Compiler at the package folder and compile. The `ProgramExecutableARM64` key needs the current pac-man.

## Credits

* GitHub Desktop Portable is a redistribution of [GitHub Desktop](https://desktop.github.com/) by GitHub, Inc., licensed under the MIT license.
* The updater uses [7-Zip](https://www.7-zip.org/) by Igor Pavlov, licensed under the GNU LGPL. See `Other\\Source\\7-Zip\\License.txt`.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler](https://github.com/daemondevin/pac-man) developed by daemon.devin.

