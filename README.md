# generate-synch-scripts

[![Build Status](https://travis-ci.org/robert-impey/generate-synch-scripts.svg?branch=master)](https://travis-ci.org/robert-impey/generate-synch-scripts)

A program for generating scripts for synchronising directories using rsync.

For example, create a file `C:\scripts\gss.txt` with this content:

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

`PS C:\scripts> generate-synch-scripts.exe .\gss.txt`

will create a script called `_all.sh` that will synch the subfolders (config, data, etc.) between the two main folders (OneDrive and X:\\)

The first line is the invocation of rsync that you wish to use as the base for the commands in the scripts.
Other programs (such as RoboCopy) may work here.

This script can now be invoked as a scheduled task.

Note that synchronizing two folders in this way can make file deletion a problem.
This tool may help: https://github.com/robert-impey/staydeleted
