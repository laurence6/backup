#! /bin/bash
#
# Backup and restore files on the computer.
#
# Copyright (C) 2014-2015  Laurence Liu <liuxy6@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Requirements:
# - tar
# - md5sum
# - awk
# - dpkg (debian)
# - dselect (debian)
# - apt (debian)
# - pacman (arch)
#
# TODO: options
#

readonly MYNAME=`basename "$0"`
readonly VERSION="0.9.9"

source /etc/backuprc 2>/dev/null
source backuprc 2>/dev/null

err_exit() {
    [ "x" = "x$1" ]\
        && exit_code=1\
        || exit_code=$1
    echo -ne "${NORM}"\
        && exit $exit_code
}

colors() {
    [ "x" = "x`echo $* | awk '/--nocolor/'`" ]\
        && true\
        || return 0

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
echo -e "${BOLD}"$MYNAME" "$VERSION"${NORM}, backup and restore files on the computer.
Usage: "$MYNAME" [OPTION]...

Interface:
    -q, --quiet            keep quiet
        --nocolor          disable colors

Backup & Restore:
        --files            files or directories will be backed up (\"/dir1 /dir2 /file1 ...\")
        --exclude          excluded files or directories (\"/file1 /file2 /dir1...\")
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

Written by Laurence Liu <liuxy6@gmail.com>"
}

check_root() {
    [ $UID != "0" ]\
        && echo -e "${RED}Non root user. Please run as root.${NORM}" >&2\
        && err_exit\
        || return 0
}

check_args() {
    [ "x" = "x$files" -o "x" = "x$exclude" -o "x" = "x$compression" -o "x" = "x$pkgmgr" -o "x" = "x$owner" ]\
        && echo -e "${RED}One or more arguments are empty.${NORM}" >&2\
        && err_exit
    exclude=`echo "$exclude" | tr " " ","`

    case $compression in
        gzip | gnuzip | gz )
            compression="gz"
            ;;
        xz )
            true
            ;;
        bzip2 | bz2 )
            compression="bz2"
            ;;
        * )
            echo -e "${RED}Unknown compression format "$compression"${NORM}" >&2\
                && err_exit
            ;;
    esac

    case $pkgmgr in
        dpkg | apt | apt-get | dselect )
            pkgmgr="dpkg"
            ;;
        pacman | none)
            true
            ;;
        * )
            echo -e "${RED}Unknown package manager "$pkgmgr"${NORM}" >&2\
                && err_exit
            ;;
    esac
}

check() {
    echo -ne "${RED}"
    set -e
    md5file_dirname=`dirname "$1"` || err_exit
    md5file_filename=`basename "$1"` || err_exit
    cd "$md5file_dirname" || err_exit
    md5sum --quiet -c "$md5file_filename" || err_exit
    echo -ne "${NORM}"
    echo -e "${GREEN}md5sum check: PASS${NORM}"
}

backup() {
    check_root
    check_args
    TIME=`date +%F`
    echo -ne "${RED}" && cd "$1" && echo -ne "${NORM}" || err_exit
    echo -e "${GREEN}[`date +%F-%H:%M:%S`] $MYNAME $VERSION: Backup begins.${NORM}"

    eval tar -pa$quiet -cf $TIME.files.tar.$compression "$files" --exclude="{..,$exclude}" 2>/dev/null
    case "$pkgmgr" in
        pacman )
            comm -23 <(pacman -Qeq|sort) <(pacman -Qmq|sort) >$TIME.packagelist.txt
            ;;
        dpkg )
            dpkg --get-selections >$TIME.packagelist.txt
            ;;
        none )
            echo -e "${YELLOW}Have no package manager${NORM}"
            ;;
    esac

    md5sum $TIME.files.tar.$compression $TIME.packagelist.txt >$TIME.md5 2>/dev/null

    chown "$owner" $TIME.files.tar.$compression $TIME.packagelist.txt $TIME.md5 2>/dev/null

    echo -e "${GREEN}[`date +%F-%H:%M:%S`] $MYNAME $VERSION: Complete.${NORM}"
}

restore() {
    set -e
    check_root
    check_args
    check "$1"

    echo -ne "${YELLOW}Are you sure to restore all files (It will be dangerous)?${NORM} [y/N]"\
        && read -s -n1
    echo -e ""
    if [ "$REPLY" = "y" -o "$REPLY" = "Y" ]
    then
        true
    else
        return 0
    fi

    echo -ne "${RED}"
    files_filename="`awk '$2 ~ /^[1-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].files.tar.(gz)$|(xz)$|(bz2)$/ {print $2}' "$md5file_filename"`" || err_exit
    packagelist_filename="`awk '$2 ~ /^[1-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].packagelist.txt$/ {print $2}' "$md5file_filename"`" || err_exit
    [ "$files_filename" != "" -o "$packagelist_filename" != "" ]\
        && true\
        || { echo -e "Cannot find backup files" >&2 && err_exit; }
    echo -ne "${NORM}"

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
            if [ "x" = "x$(which dselect)" ]
            then
                echo -e "${RED}dselect is required${NORM}" >&2
                echo -ne "${YELLOW}Do you want to install dselect?${NORM} [Y/n]"\
                    && read -s -n1
                echo -e ""
                if [ "$REPLY" = "y" -o "$REPLY" = "Y" -o "$REPLY" = "" ]
                then
                    apt-get update\
                        && apt-get -y install dselect
                fi
                [ "x" != "x$(which dselect)" ]\
                    && true\
                    || { echo -e "${RED}dselect was not installed${NORM}" >&2 && err_exit; }
            fi
            dselect update
            dpkg --set-selections <"$packagelist_filename" 2>/dev/null || err_exit
            apt-get -y dselect-upgrade
            ;;
        none )
            echo -e "${YELLOW}Have no package manager${NORM}"
            ;;
    esac

    eval tar -pa$quiet -xf "$files_filename" -C /

    echo -e "${GREEN}$MYNAME $VERSION: Complete.${NORM}"
}

main() {
    for dep in tar md5sum awk
    do
        [ "x" = "x$(which $dep)" ]\
            && echo "$dep was not installed!" >&2\
            && err_exit
    done
    quiet="v"
    outputdir="."

    colors "$*"

    echo -ne "${RED}"
    ARGS=`getopt -n "$MYNAME" -o "q      o:r:c:hV" -l "quiet,nocolor,files:,exclude:,compression:,pkgmgr:,owner:,output:,restore:,check:,help,version" -- "$@"`\
        || err_exit
    eval set -- "${ARGS}"
    echo -ne "${NORM}"

    while true
    do
        case "$1" in
            -q | --quiet )
                quiet=""
                ;;
            --nocolor )
                true
                ;;
            --files )
                shift
                files="$1"
                ;;
            --exclude )
                shift
                exclude="$1"
                ;;
            --compression )
                shift
                compression="$1"
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
                echo -e "${BOLD}$MYNAME $VERSION${NORM}\nWritten by Laurence Liu <liuxy6@gmail.com>"\
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

trap err_exit SIGINT SIGTERM
main "$@"
