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
# TODO: incremental backup

####################

MYNAME=`basename "$0"`
VERSION="0.5.3"

backupdir="/etc /root"
exclude="{.bash_history,.local/share/Trash,.thumbnails,/etc/fstab,/etc/hostname,*cache*,*Cache*,*tmp*,*.log*,*.old}"
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
    -q, --quiet                          keep quiet

Backup & Restore:
    -o, --output [/path/to/directory]    output files to the specified directory
    -r, --restore [/path/to/md5sumfile]  restore

Check:
    -c, --check [/path/to/md5sumfile]    check the file
    
Miscellaneous:
    -h, --help                           display this help and exit
    -V, --version                        print version information and exit

Written by Laurence Liu <liuxy6@gmail.com>
EOF
}

check_root() {
    if [ $UID != 0 ]
    then
        echo -e "Non root user. Please run as root." >&2
        exit 1
    fi
}

check() {
    cd `dirname $1`
    md5sum -c `basename $1`
    if [ $? != 0 ]; then exit 1; fi
}

backup() {
    check_root
    #TIME=`date +%F`
    TIME=`date +%F-%H-%M-%S`
    echo -e "[$TIME] $MYNAME $VERSION: Backup begins."
        cd $1
        eval tar -pa$quiet -cf $TIME.files.tar.$compressed_ext $backupdir --exclude=$exclude 2>/dev/null
        comm -23 <(pacman -Qeq|sort) <(pacman -Qmq|sort) >$TIME.packagelist.txt
        md5sum $TIME.files.tar.$compressed_ext $TIME.packagelist.txt >$TIME.md5sum.txt
        chown $owner:$owngrp $TIME.files.tar.$compressed_ext $TIME.packagelist.txt $TIME.md5sum.txt
    echo -e "[`date +%F-%H-%M-%S`] $MYNAME $VERSION: Complete."
}

restore() {
    check $1
    check_root
    cd `dirname $1`
    files_filename=`awk '/tar/ {print $2}' $1`
    packagelist_filename=`awk '/packagelist/ {print $2}' $1`
    pacman -S --needed `diff <(cat $packagelist_filename|sort) <(diff <(cat $packagelist_filename|sort) <(pacman -Slq|sort)|grep \<|cut -f2 -d' ')|grep \<|cut -f2 -d' '`
    eval tar -pa$quiet -xf $files_filename -C /
    echo -e "$MYNAME $VERSION: Complete."
}

####################

quiet="v"

if [ $# = 0 ]
then
    backup .
    exit 0
fi

ARGS=`getopt -n $MYNAME -o "qo:r:c:hV" -l "quiet,output:,restore:,check:,help,version" -- "$@"`
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
            while true
            do
                read -s -n1 -p "Are you sure to restore all files (It will be dangerous)? [y/N]"
                echo -e ""
                case $REPLY in
                    y | Y )
                        restore $1
                        exit 0
                        ;;
                    n | N )
                        exit 0
                        ;;
                    ""  )
                        exit 0
                        ;;
                esac
            done
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
            exit 0
            ;;
    esac
    shift
done
