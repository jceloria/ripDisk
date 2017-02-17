#!/usr/bin/env bash

SELF=${0##*/}; SDIR=${0%/*}
########################################################################################################################
# Identify inserted optical disk
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
source /opt/etc/ripDisk.conf
######################################################### subs #########################################################
# Print usage information
function help() {
cat << EOF
Usage: ${SELF} [OPTION]...
Identify inserted optical disk

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

req_progs=(logger)
for p in ${req_progs[@]}; do
    hash "$p" 2>&- || \
    { echo >&2 " Required program \"$p\" not found in \$PATH."; exit 1; }
done
######################################################### main #########################################################

function main() {
    [[ ${QUIET} -eq 1 ]] && exec >${LOGFILE:-/dev/null} 2>&1

    if [[ ${ID_CDROM_MEDIA_BD} -eq 1 ]]; then
        log "Detected Blu-ray disc inserted."
        echo bluray > ${STATE_FILE}
    elif [[ ${ID_CDROM_MEDIA_CD} -eq 1 ]]; then
        log "Detected CDROM disc inserted."
        echo cdrom > ${STATE_FILE}
    elif [[ ${ID_CDROM_MEDIA_DVD} -eq 1 ]]; then
        log "Detected DVD disc inserted."
        echo dvd > ${STATE_FILE}
    else
        log "Detected a change but unable to detect/read disc, was it ejected?"
        rm -f ${STATE_FILE}
    fi

    exit 0
}

main $@
########################################################################################################################
