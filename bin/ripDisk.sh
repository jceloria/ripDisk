#!/usr/bin/env bash

SELF=${0##*/}; SDIR=${0%/*}
########################################################################################################################
# Rip inserted optical disk
#
# Copyright © 2017 by John Celoria <john@celoria.net>.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
######################################################## config ########################################################
# Set some defaults
VERSION=0.1

# Read configuration file
source /opt/ripDisk/etc/ripDisk.conf
######################################################### subs #########################################################
# Print usage information
function help() {
cat << EOF
Usage: ${SELF} [OPTION]...
Rip inserted optical disk

  -h    Display this help message and exit
  -q    Quiet output

EOF
    return
}
########################################################################################################################
# Logging function
function log() {
    local level levels=(notice warning crit)
    level="+($(IFS='|';echo "${levels[*]}"))"

    shopt -s extglob; case ${1} in
        ${level}) level=${1}; shift ;;
        *) level=notice ;;
    esac; shopt -u extglob

    [[ -z ${RETVAL} ]] && { for RETVAL in "${!levels[@]}"; do
        [[ ${levels[${RETVAL}]} = "${level}" ]] && break
    done }

    logger -s -p ${level} -t "[${SELF}:${FUNCNAME[1]}()]" -- $@;
}
########################################################################################################################
# Log and then exit
function die() { local retval=${RETVAL:-$?}; log "$@"; exit ${retval}; }
########################################################################################################################
# Sanity checks
while getopts ":hq" opt; do
    case ${opt} in
        h)  help >&2; exit 1                                            ;;
        q)  QUIET=1                                                     ;;
        \?) echo "Invalid option: -${OPTARG}" >&2                       ;;
        :)  echo "Option -${OPTARG} requires an argument." >&2; exit 1  ;;
    esac
done; shift $((${OPTIND} - 1))

req_progs=(logger inotifywait rsync)
for p in ${req_progs[@]}; do
    hash "$p" 2>&- || \
    { echo >&2 " Required program \"$p\" not found in \$PATH."; exit 1; }
done
######################################################### main #########################################################

function main() {
    [[ ${QUIET} -eq 1 ]] && exec >${LOGFILE:-/dev/null} 2>&1

    if [[ ! -e ${STATE_FILE} ]]; then
        log "Waiting for ${STATE_FILE}"
        inotifywait -q -e close_write ${STATE_FILE}
    fi

    if [[ ! -e ${TMPDIR} ]]; then
        mkdir -p ${TMPDIR} 2>&1 || RETVAL=99 die "Unable to create temporary directory: ${TMPDIR}"
    fi

    WORKDIR=$(mktemp -d ${TMPDIR}/ripDisk.XXXXX)

    DISK_TYPE=$(<${STATE_FILE})
    case ${DISK_TYPE} in
        cdrom)
            OUTPUTDIR+="/${MUSIC_DIR}"
            log "Ripping music from ${DEVICE} to ${OUTPUTDIR}"
            pushd ${WORKDIR} >/dev/null 2>&1
            abcde -V -G -o flac -d ${DEVICE} 2>&1; rm -rf abcde.* 2>&1
            (tar -cf - . | tar -xf - -C ${OUTPUTDIR}) && rm -rf ${WORKDIR}
            popd >/dev/null 2>&1
            ;;
        *) log warn "Not implemented yet"
    esac

    rm -f ${STATE_FILE}

    exit 0
}

main $@
########################################################################################################################
