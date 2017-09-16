################################################################################
##                             ADVANCED USERS                                 ##
################################################################################
The files in this directory mirror that of an installed version in
Program Files or Program Files (x86).

Usually.. there is no need for end-users to edit these files.
These files are important for proper functionality.

However.. there are situations where one could add or remove features.
This of course requires sufficient knowledge of the application and
the PortableApps specifications.

Typically.. only advanced users should edit or modify files in this
directory.

################################################################################
##                             EXAMPLE SCENARIO                               ##
################################################################################

Photoshop supports 3rd party plugins.
To add such features would require copying the 3rd party plugin into
this directory at the appropriate location.

Additionally.. additional entries may be required in the launcher file
for correct functionality.

An example of this would be if the 3rd party plugin leaves trash in the
registry or file-system. To tell the launcher to clean up these additional
files at exit would require adding a line or two in the launcher file.

Please refer to the online manual for further assistance.

[Online Manual]
http://portableapps.com/manuals/PortableApps.comLauncher/

[Registry]
ref/launcher.ini/registry.html

[Files]
ref/launcher.ini/filesystem.html

[Custom]
advanced/custom.html#custom-code