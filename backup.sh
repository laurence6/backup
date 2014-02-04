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
VERSION="0.5.2"

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

check_root() {
    if [ $UID != 0 ]
    then
        echo -e "Non root user. Please run as root." >&2
        exit 1
    else
        return 0
    fi
}

backup() {
    check_root
    #TIME=`date +%F`
    TIME=`date +%F-%H-%M-%S`
    echo -e "[$TIME] $MYNAME $VERSION: Backup begins."
        cd $1
        eval tar -pa$quiet -cf $TIME.backup.tar.$compressed_ext $backupdir --exclude=$exclude 2>/dev/null
        comm -23 <(pacman -Qeq|sort) <(pacman -Qmq|sort) >$TIME.packagelist.txt
        md5sum $TIME.backup.tar.$compressed_ext $TIME.packagelist.txt >$TIME.md5sum.txt
        chown $owner:$owngrp $TIME.backup.tar.$compressed_ext $TIME.packagelist.txt $TIME.md5sum.txt
    echo -e "[`date +%F-%H-%M-%S`] $MYNAME $VERSION: Done."
}

check() {
    cd `dirname $1`
    md5sum -c `basename $1`
}

restore() {
#alpha
    while true
    do
        read -s -n1 -p "Are you sure to restore all files (It will be dangerous) ? (y/N) :"
        echo -e ""
        case $REPLY in
            y | Y )
                check_root
#                eval tar -pa$quiet -xf $1 -C /
                echo -e "Ok"
                ;;
            n | N )
                break
                ;;
            ""  )
                break
                ;;
        esac
    done
}

####################

quiet="v"

if [ $# = 0 ]
then
    backup .
    exit 0
fi

ARGS=`getopt -n $MYNAME -o "qo:rc:hV" -l "quiet,output:,restore,check:,help,version" -- "$@"`
eval set -- "${ARGS}" 

while true
do
    case $1 in
        -q | --quiet )
            quiet=""
            if [ $2 = "--" ]; then backup .; fi
            ;;
        -o | --output )
            shift
            backup $1
            exit 0
            ;;
        -r | --restore )
            shift
            restore $1
            exit 0
            ;;
        -c | --check )
            shift
            check $1
            exit 0
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
