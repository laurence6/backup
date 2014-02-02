#! /bin/bash
#
# Backup the configure files.
#
# Written by Laurence Liu <liuxy6@gmail.com>
# GNU General Public License
#
# Requirements:
# - tar
# - md5sum
#
# TODO: restore
# TODO: bz\xz
#

####################

MYNAME=$(basename "$0")
VERSION="0.3.1"
DATE=$(date +%F)

backupdir="/etc"
exclude="*cache* *Cache* *tmp* *.log* *.old*"
owner="root"
owngrp="root"
source backup.conf

####################

print_help() {
    cat << EOF
$MYNAME $VERSION, backup the configure files.
Useage: $MYNAME [OPTION]

Backup:
    -o, --output [/path/to/directory] output the file to the specified directory
    -q, --quiet                       keep quiet
    
Check:
    -c, --check [/path/to/md5sumfile] check the file
    
Miscellaneous:
    -h, --help                        display this help and exit
    -V, --version                     print version information and exit

Written by Laurence Liu <liuxy6@gmail.com>
EOF
}

backup() {
    if [ $UID != 0 ]
    then
        echo "Non root user. Please run as root." >&2
        exit 1
    else
        echo "Today is $DATE. Backup begins."
        echo $exclude | tr " " "\n" > /tmp/backup_exclude_$DATE
        cd $1
        tar -cpvzf $DATE.backup.tgz $backupdir --exclude-from /tmp/backup_exclude_$DATE 2>/dev/null
        comm -23 <(pacman -Qeq|sort) <(pacman -Qmq|sort) > $DATE.packagelist.txt
        md5sum $DATE.backup.tgz $DATE.packagelist.txt > $DATE.md5sum.txt
        chown $owner:$owngrp $DATE.backup.tgz $DATE.packagelist.txt $DATE.md5sum.txt
        rm /tmp/backup_exclude_$DATE
        echo "Done!"
    fi
}

check() {
    cd $(dirname $1)
    md5sum -c $(basename $1)
    exit 0
}

####################

if [ $# = 0 ]
then
    backup .
    exit 0
fi

while [ $# != 0 ]
do
    case $1 in
        -o | --output )
            shift
            if [ "$2" = "-q" -o "$2" = "--quiet" ]
            then
                backup $1 1> /dev/null
                exit 0
            else
                backup $1
                exit 0
            fi
            ;;
        -q | --quiet )
            backup . > /dev/null
            exit 0
            ;;
        -c | --check )
            shift
            check $1
            ;;
        -h | --help )
            print_help
            exit 0
            ;;
        -V | --version )
            printf "$MYNAME $VERSION\nWritten by Laurence Liu <liuxy6@gmail.com>\n"
            exit 0
            ;;
         * )
            printf "$MYNAME: Invalid option \"$1\"\nTry \"$MYNAME --help\" for more information.\n" >&2
            exit 1
            ;;
    esac
    shift
done
