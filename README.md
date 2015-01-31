backup
======

A bash script backup and restore files using tar and package list using dpkg or pacman.


## Usage

./backup.sh [OPTION]...   
   
Interface:   
    -q, --quiet            keep quiet   
        --nocolor          disable colors   
   
Backup & Restore:   
        --files            files or directories will be backed up ("/dir1 /dir2 /file1 ...")   
        --exclude          excluded files or directories ("/file1 /file2 /dir1...")   
        --compression      compression type (gz, xz, bz2)   
        --pkgmgr           the package manager is used (dpkg, pacman, none)   
        --owner            owner of the backup files (owner:group)   
    -o, --output           output files to the specified directory (/path/to/dir)   
    -r, --restore          restore (/path/to/md5file)   
   
Check:   
    -c, --check            check the file (/path/to/md5file)   
   
Miscellaneous:   
    -h, --help             display this help and exit   
    -V, --version          print version information   


## License

Copyright (C) 2014-2015  Laurence Liu <liuxy6@gmail.com>

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
