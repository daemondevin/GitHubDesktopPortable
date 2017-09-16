
;= CHANGELOG 
;= ################
Month #th, Year
 • Created AppName Portable

 
;= NOTES
;= ################


;= PRESERVE
;= ################
If you would like to preserve any directories and/or file(s) during upgrades or reinstalls you can do so by writing in the installer.ini located within the AppInfo directory (..\FLStudioPortable\App\AppInfo). If there isn't an installer.ini file than simply create it within the AppInfo folder and use the example format below. 

For more information on preserving files and directories please visit the following:
FILES: //portableapps.com/manuals/PortableApps.comLauncher/ref/paf/installer.html#within-the-optional-filestopreserve-section
DIRECTORIES: //portableapps.com/manuals/PortableApps.comLauncher/ref/paf/installer.html#within-the-optional-directoriestopreserve-section

FILES EXAMPLE:

[FilesToPreserve]
PreserveFile1=App\AppName\plugins\*.dll
PreserveFile2=App\AppName\filters\filename.ext

DIRECTORIES EXAMPLE:

[DirectoriesToPreserve]
PreserveDirectory1=App\AppName\plugins
PreserveDirectory1=App\AppName\filters
