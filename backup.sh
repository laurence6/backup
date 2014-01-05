#! /bin/bash
#
# Backup my computer.
#
# Written by Laurence Liu <liuxy6@gmail.com>
#
# Requirements:
# - tar
# - md5sum
# 

MYNAME=$(basename "$0")
Version="0.1.1"

print_help() {
    cat << EOF
$MYNAME $Version, backup my computer.
Useage: $MYNAME [OPTION]

    -o, --output [/path/to/directory] output the file to the specified directory
    -c, --check [/path/to/file]       check the file
    -h, --help                        display this help and exit
    -V, --version                     print version information and exit

Written by Laurence Liu <liuxy6@gmail.com>
EOF
}

backup() {
    if [ $UID != 0 ]
    then
        echo "Non root user. Please run as root."
        exit 1
    else
        echo "Today is $(date +%Y-%m-%d). Backup begins."
        tar -cpvzf $1/$(date +%Y-%m-%d).backup.tgz /etc /home/liu --exclude=.config/google-chrome --exclude=.config/google-chrome-unstable --exclude=Desktop --exclude=Documents --exclude=Downloads --exclude=Dropbox --exclude=.dropbox* --exclude=.local/share/Trash --exclude=Pictures --exclude=Templates --exclude=Videos --exclude=.cache --exclude=.purple --exclude=.thumbnails --exclude=/etc/fstab --exclude=/etc/hostname
        comm -23 <(pacman -Qeq|sort) <(pacman -Qmq|sort) > $1/$(date +%Y-%m-%d).packagelist.txt
        md5sum $1/$(date +%Y-%m-%d).backup.tgz $1/$(date +%Y-%m-%d).packagelist.txt > $1/$(date +%Y-%m-%d).md5sum.txt
        chown liu $1/$(date +%Y-%m-%d).backup.tgz $1/$(date +%Y-%m-%d).packagelist.txt $1/$(date +%Y-%m-%d).md5sum.txt
        chgrp liu $1/$(date +%Y-%m-%d).backup.tgz $1/$(date +%Y-%m-%d).packagelist.txt $1/$(date +%Y-%m-%d).md5sum.txt
        echo "Done!"
    fi
}

check() {
    cd $(dirname $1)
    md5sum -c $1
    exit 0
}

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
            printf "$MYNAME $Version\n\nWritten by Laurence Liu <liuxy6@gmail.com>\n"
            exit 0
            ;;
        * )
            printf "$MYNAME: Invalid option \"$1\"\nTry \"$MYNAME --help\" for more information.\n"
            exit 1
            ;;
    esac
    shift
done
