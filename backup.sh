#! /bin/bash
#
# Backup my computer.
#
# Written by Laurence Liu <liuxy6@gmail.com>
# GNU General Public License
#
# Requirements:
# - tar
# - md5sum
#
# TODO: restore
# TODO: incremental backup

####################

MYNAME=`basename "$0"`
VERSION="0.4.2"
DATE=`date +%F`

backupdir="/etc"
exclude="*cache* *Cache* *tmp* *.log* *.old*"
compressed_ext="gz"
owner="root"
owngrp="root"
source /etc/backuprc 2>/dev/null
source backuprc 2>/dev/null

####################

print_help() {
    cat << EOF
$MYNAME $VERSION, backup my computer.
Useage: $MYNAME [OPTION]

Interface:
    -q, --quiet                       keep quiet

Backup & Restore:
    -o, --output [/path/to/directory] output the file to the specified directory
    -r, --restore                     restore

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
        echo -e "Non root user. Please run as root." >&2
        exit 1
    else
        echo -e "Today is $DATE. Backup begins."
        cd $1
        eval tar -pa$quiet -cf $DATE.backup.tar.$compressed_ext $backupdir --exclude=$exclude 2>/dev/null
        comm -23 <(pacman -Qeq|sort) <(pacman -Qmq|sort) >$DATE.packagelist.txt
        md5sum $DATE.backup.tar.$compressed_ext $DATE.packagelist.txt >$DATE.md5sum.txt
        chown $owner:$owngrp $DATE.backup.tar.$compressed_ext $DATE.packagelist.txt $DATE.md5sum.txt
        echo -e "Done!"
    fi
}

check() {
    cd `dirname $1`
    md5sum -c `basename $1`
    exit 0
}

####################

if [ $# = 0 ]
then
    backup .
    exit 0
fi

ARGS=`getopt -n $MYNAME -o "qo:c:hV" -l "quiet,output:,check:,help,version" -- "$@"`
eval set -- "${ARGS}" 

quiet="v"

while true
do
    case $1 in
        -q | --quiet )
            quiet=""
            ;;
        -o | --output )
            shift
            backup $1
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
            echo -e "$MYNAME $VERSION\nWritten by Laurence Liu <liuxy6@gmail.com>"
            exit 0
            ;;
         -- )
            shift
            break
            ;;
    esac
    shift
done
