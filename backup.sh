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

MYNAME=`basename "$0"`
VERSION="0.7.1"

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
    TIME=`date +%F`
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
    check $1
    check_root
    cd `dirname $1`
    files_filename=`awk '/tar/ {print $2}' $1`
    packagelist_filename=`awk '/packagelist/ {print $2}' $1`
    case "$pkgmgr" in
        pacman )
            pacman -Syy
            pacman -S --needed `diff <(cat $packagelist_filename|sort) <(diff <(cat $packagelist_filename|sort) <(pacman -Slq|sort)|grep \<|cut -f2 -d' ')|grep \<|cut -f2 -d' '`
            ;;
        dpkg )
            apt-get update
            if [ !-x `which dselect` ]; then apt-get install dselect; fi
            dselect update
            dpkg --set-selections <$packagelist_filename
            apt-get dselect-upgrade
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
                        n | N | "" )
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
                break
                ;;
        esac
        shift
    done

    backup .
}

ARGS=`getopt -n $MYNAME -o "nq     o:r:c:hV" -l ",quiet,file:,exclude:,compression:,pkgmgr:,owner:,output:,restore:,check:,help,version" -- "$@"`
eval set -- "${ARGS}"

main $@
