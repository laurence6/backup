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
readonly VERSION="0.7.8"

backupdir="/etc /root"
exclude=".bash_history,.local/share/Trash,.thumbnails,/etc/fstab,/etc/hostname,*cache*,*Cache*,*tmp*,*.log*,*.old"
compressed_ext="gz"
pkgmgr="none"
owner="root:root"
source /etc/backuprc 2>/dev/null
source backuprc 2>/dev/null

print_help() {
    cat << EOF
$MYNAME $VERSION, backup and restore files on the computer.
Useage: $MYNAME [OPTION]...

Interface:
    -q, --quiet                 keep quiet

Backup & Restore:
        --file                  files or directories will be backed up
        --exclude               excluded files or directories
        --compression           compression type
        --pkgmgr                the package manager is used (dpkg, pacman, none)
        --owner                 owner of the backup files ("root:root")
    -o, --output                output files to the specified directory
    -r, --restore               restore ([/path/to/md5file])

Check:
    -c, --check                 check the file ([/path/to/md5file])

Miscellaneous:
    -h, --help                  display this help and exit
    -V, --version               print version information

Written by Laurence Liu <liuxy6@gmail.com>
EOF
}

check_root() {
    [ $UID != "0" ]\
        && echo -e "Non root user. Please run as root." >&2\
        && exit 1\
        || return 0
}

check() {
    set -e
    md5file_dirname=`dirname $1`
    md5file_filename=`basename $1`
    cd $md5file_dirname
    md5sum -c $md5file_filename || exit 1
}

backup() {
    set -e
    check_root
    local TIME=`date +%F`
#   TIME=`date +%F-%H-%M-%S`
    echo -e "[`date +%F-%H:%M:%S`] $MYNAME $VERSION: Backup begins."
        cd $1
        eval tar -pa$quiet -cf $TIME.files.tar.$compressed_ext $backupdir --exclude="{..,$exclude}" 2>/dev/null
        case "$pkgmgr" in
            pacman )
                comm -23 <(pacman -Qeq|sort) <(pacman -Qmq|sort) >$TIME.packagelist.txt
                ;;
            dpkg )
                dpkg --get-selections >$TIME.packagelist.txt
                ;;
            none )
                echo "Have no package manager"
                ;;
            * )
                echo "Unknown package manager type"
                ;;
        esac
        md5sum $TIME.files.tar.$compressed_ext $TIME.packagelist.txt >$TIME.md5
        chown $owner $TIME.files.tar.$compressed_ext $TIME.packagelist.txt $TIME.md5
    echo -e "[`date +%F-%H:%M:%S`] $MYNAME $VERSION: Complete."
}

restore() {
    set -e
    check_root
    check $1
    read -s -n1 -p "Are you sure to restore all files (It will be dangerous)? [y/N]"
    echo -e ""
    if [ "$REPLY" = "y" -o  "$REPLY" = "Y" ]
    then
        true
    else
        return 0
    fi
    files_filename=`awk '/files/ {print $2}' $md5file_filename`
    packagelist_filename=`awk '/packagelist/ {print $2}' $md5file_filename`
    case "$pkgmgr" in
        pacman )
            pacman -Syy
            pacman -S --needed \
                `diff <(cat $packagelist_filename|sort) <(diff <(cat $packagelist_filename|sort) <(pacman -Slq|sort)|grep \<|cut -f2 -d' ')|grep \<|cut -f2 -d' '`
            ;;
        dpkg )
            apt-get update
            if [ "x" = "x$(which dselect)" ]
            then
                echo "dselect is required" >&2
                read -s -n1 -p "Do you want to install dselect? [Y/n]"
                echo -e ""
                if [ "$REPLY" = "y" -o "$REPLY" = "Y" -o "$REPLY" = "" ]
                then
                    apt-get install dselect
                fi
                [ "x" != "x$(which dselect)" ]\
                    && true\
                    || echo -e "dselect is not installed" >&2 && exit 1
            fi
            dselect update
            dpkg --set-selections <$packagelist_filename
            apt-get --show-progress dselect-upgrade
            ;;
        none )
            echo "Have no package manager"
            ;;
        * )
            echo "Unknown package manager type"
            ;;
    esac
    eval tar -pa$quiet -xf $files_filename -C /
    echo -e "$MYNAME $VERSION: Complete."
}

main() {
    quiet="v"
    outputdir="."

    while true
    do
        case $1 in
            -q | --quiet )
                quiet=""
                ;;
            --file )
                shift
                backupdir=$1
                ;;
            --exclude )
                shift
                exclude=$1
                ;;
            --compression )
                shift
                compressed_ext=$1
                ;;
            --pkgmgr )
                shift
                pkgmgr=$1
                ;;
            --owner )
                shift
                owner=$1
                ;;
            -o | --output )
                shift
                outputdir=$1
                ;;
            -r | --restore )
                shift
                restore $1\
                    && exit 0
                ;;
            -c | --check )
                shift
                check $1\
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

    backup $outputdir
}

ARGS=`getopt -n $MYNAME -o "nq     o:r:c:hV" -l ",quiet,file:,exclude:,compression:,pkgmgr:,owner:,output:,restore:,check:,help,version" -- "$@"`\
    || exit 1
eval set -- "${ARGS}"

main $@
