# generate-synch-scripts

A program for generating scripts for synchronising directories using rsync.

For example, create a file `C:\scripts\OneDrive.txt` with this content:

```
rsync --update --recursive --verbose --times --iconv=utf8 
/cygdrive/x
/cygdrive/c/Users/rober/OneDrive

config
data
docs
local-scripts
```

Then running

`PS C:\scripts> generate-synch-scripts.exe .\OneDrive.txt`

will create a script called `OneDrive.sh` that will synch the subfolders (config, data, etc.)
between the two main folders (OneDrive and X:\\). The script will be put in `HOME\autogen\synch`.

The first line is the invocation of rsync that you wish to use as the base for the commands in the scripts.
Other programs (such as RoboCopy) may work here.

This script can now be invoked as a scheduled task.

Note that synchronizing two folders in this way can make file deletion a problem.
This tool may help: https://github.com/robert-impey/staydeleted
