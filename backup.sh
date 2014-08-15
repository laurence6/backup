#! /bin/bash
#
# Backup and restore files on the computer.
#
# Written by Laurence Liu <liuxy6@gmail.com>
# GNU General Public License
#
# Requirements:
# - tar
# - md5sum
# - dpkg (debian)
# - dselect (debian)
# - apt (debian)
# - pacman (arch)
#
# TODO: options
#

readonly MYNAME=`basename "$0"`
readonly VERSION="0.8.1"

backupdir="/etc /root"
exclude=".bash_history,.local/share/Trash,.thumbnails,/etc/fstab,/etc/hostname,*cache*,*Cache*,*tmp*,*.log*,*.old"
compressed_ext="gz"
pkgmgr="none"
owner="root:root"
source /etc/backuprc 2>/dev/null
source backuprc 2>/dev/null

colors() {
    NORM='\e[00m'
    RED='\e[01;31m'
    GREEN='\e[01;32m'
    YELLOW='\e[01;33m'
    BLUE='\e[01;34m'
    MAGENTA='\e[01;35m'
    CYAN='\e[01;36m'
    BOLD='\033[01m'
}

print_help() {
echo -e ""$MYNAME" "$VERSION", backup and restore files on the computer.
Useage: "$MYNAME" [OPTION]...

Interface:
    -q, --quiet            keep quiet
        --nocolor          disable colors

Backup & Restore:
        --file             files or directories will be backed up
        --exclude          excluded files or directories
        --compression      compression type
        --pkgmgr           the package manager is used (dpkg, pacman, none)
        --owner            owner of the backup files (owner:group)
    -o, --output           output files to the specified directory
    -r, --restore          restore (/path/to/md5file)

Check:
    -c, --check            check the file (/path/to/md5file)

Miscellaneous:
    -h, --help             display this help and exit
    -V, --version          print version information

Written by Laurence Liu <liuxy6@gmail.com>"
}

check_root() {
    [ $UID != "0" ]\
        && echo -e "Non root user. Please run as root." >&2\
        && exit 1\
        || return 0
}

check() {
    set -e
    md5file_dirname=`dirname "$1"` || exit 1
    md5file_filename=`basename "$1"` || exit 1
    cd "$md5file_dirname" || exit 1
    md5sum -c "$md5file_filename" || exit 1
}

backup() {
    set -e
    check_root
    local TIME=`date +%F`
#   TIME=`date +%F-%H-%M-%S`
    cd "$1" || exit 1
    echo -e "[`date +%F-%H:%M:%S`] $MYNAME $VERSION: Backup begins."
        eval tar -pa$quiet -cf $TIME.files.tar.$compressed_ext "$backupdir" --exclude="{..,$exclude}" 2>/dev/null
        case "$pkgmgr" in
            pacman )
                comm -23 <(pacman -Qeq|sort) <(pacman -Qmq|sort) >$TIME.packagelist.txt
                ;;
            dpkg )
                dpkg --get-selections >$TIME.packagelist.txt
                ;;
            none )
                echo -e "Have no package manager"
                ;;
            * )
                echo -e "Unknown package manager type"
                ;;
        esac
        md5sum $TIME.files.tar.$compressed_ext $TIME.packagelist.txt >$TIME.md5
        chown "$owner" $TIME.files.tar.$compressed_ext $TIME.packagelist.txt $TIME.md5
    echo -e "[`date +%F-%H:%M:%S`] $MYNAME $VERSION: Complete."
}

restore() {
    set -e
    check_root
    check "$1"
    echo -ne "Are you sure to restore all files (It will be dangerous)? [y/N]"\
        && read -s -n1
    echo -e ""
    if [ "$REPLY" = "y" -o  "$REPLY" = "Y" ]
    then
        true
    else
        return 0
    fi
    files_filename=`awk '/[1-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].files.tar.[gz,xz,bz2]/ {print $2}' "$md5file_filename"` || exit 1
    packagelist_filename=`awk '/[1-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].packagelist.txt/ {print $2}' "$md5file_filename"` || exit 1
    [ "$files_filename" = "" -o "$packagelist_filename" = "" ]\
        && echo "Cannot find backup files"\
        && exit 1\
        || true
    case "$pkgmgr" in
        pacman )
            pacman -Syy
            pacman -S --needed \
                `diff <(cat "$packagelist_filename"|sort)\
                <(diff <(cat "$packagelist_filename"|sort)\
                <(pacman -Slq|sort)\
                |grep \<|cut -f2 -d' ')\
                |grep \<|cut -f2 -d' '`
            ;;
        dpkg )
            apt-get update
            if [ "x" = "x$(which dselect)" ]
            then
                echo -e "dselect is required" >&2
                echo -e "Do you want to install dselect? [Y/n]"\
                    && read -s -n1
                echo -e ""
                if [ "$REPLY" = "y" -o "$REPLY" = "Y" -o "$REPLY" = "" ]
                then
                    apt-get install dselect
                fi
                [ "x" != "x$(which dselect)" ]\
                    && true\
                    || echo -e "dselect was not installed" >&2 && exit 1
            fi
            dselect update
            dpkg --set-selections <"$packagelist_filename" || exit 1
            apt-get --show-progress dselect-upgrade
            ;;
        none )
            echo -e "Have no package manager"
            ;;
        * )
            echo -e "Unknown package manager type"
            ;;
    esac
    eval tar -pa$quiet -xf "$files_filename" -C /
    echo -e "$MYNAME $VERSION: Complete."
}

main() {
    quiet="v"
    outputdir="."
    colors

    while true
    do
        case "$1" in
            -q | --quiet )
                quiet=""
                ;;
            --nocolor )
                unset NORM RED GREEN YELLOW BLUE MAGENTA CYAN BOLD
                ;;
            --file )
                shift
                backupdir="$1"
                ;;
            --exclude )
                shift
                exclude="$1"
                ;;
            --compression )
                shift
                compressed_ext="$1"
                ;;
            --pkgmgr )
                shift
                pkgmgr="$1"
                ;;
            --owner )
                shift
                owner="$1"
                ;;
            -o | --output )
                shift
                outputdir="$1"
                ;;
            -r | --restore )
                shift
                restore "$1"\
                    && exit 0
                ;;
            -c | --check )
                shift
                check "$1"\
                    && exit 0
                ;;
            -h | --help )
                print_help\
                    && exit 0
                ;;
            -V | --version )
                echo -e "$MYNAME $VERSION\nWritten by Laurence Liu <liuxy6@gmail.com>"\
                    && exit 0
                ;;
            -- )
                shift
                break
                ;;
        esac
        shift
    done

    backup "$outputdir"
}

ARGS=`getopt -n "$MYNAME" -o "q      o:r:c:hV" -l "quiet,nocolor,file:,exclude:,compression:,pkgmgr:,owner:,output:,restore:,check:,help,version" -- "$@"`\
    || exit 1
eval set -- "${ARGS}"

main "$@"
