#!/bin/bash -x

# Usage:
# backup.sh /etc /var/www /home

# remote ssh host
REMOTE_HOST="somehost.ua";
REMOTE_BACKUP_PATH="/backup/files"

#**********************************************************************

STORAGE_DIR=$(date +%Y_%B_%d);
SSH_CMD="ssh -c arcfour";

function raiseError {
    case "$1" in
        "501" ) echo "Directory is not specified";;
        "502" ) echo "Not enough arguments for remoteRun()";;
        "503" ) echo "Error creating new directory";;
        "504" ) echo "Specified directory already exists";;
        *     ) echo "Can't complete task: Unknown error occured";;
    esac;
    exit 1;
}

function checkCreateDir {
    if [ ! -d "$1" ]; then
        mkdir -p $1;
        if [ "$?" != "0" ]; then
            raiseError 503;
        fi;
    else
        raiseError 504;
    fi;
}

function remoteRun {
    if [ -z "$1" ]; then
        raiseError 502;
    fi;
    $SSH_CMD ${REMOTE_HOST} $1;
}

# $1 - Dir to backup
# $2 - Remote directory
function makeBackup {
    BASEDIR="$2/incremental-basedir";
    TMP_DIR="$2/_tmp";

    BASEDIR_EXISTS=$( ${SSH_CMD} ${REMOTE_HOST} "if [ -L \"${BASEDIR}\" ]; then echo YES; fi;" );
    remoteRun "mkdir -p $2";

    if [ "${BASEDIR_EXISTS}" == "YES" ]; then
        # Remote basedir exists. Make incremental copy.
        remoteRun "mkdir -p ${TMP_DIR}";
        rsync -ae "${SSH_CMD}" $1 "${REMOTE_HOST}:$TMP_DIR/"
        remoteRun "rsync -a --link-dest=$BASEDIR $TMP_DIR $2/$STORAGE_DIR/";
        remoteRun "rm -rf $TMP_DIR";
    else
        # Remote basedir does not exist. Create full copy.
        remoteRun "ln -s $2/${STORAGE_DIR} ${BASEDIR}"
        rsync -ae "${SSH_CMD}" $1 "${REMOTE_HOST}:$2/$STORAGE_DIR/"
    fi;
}

for DIR in "$@"; do
    REMOTE_DIR="$REMOTE_BACKUP_PATH/$(echo $DIR | sed 's/[/]/_/g')";
    makeBackup "${DIR}" "${REMOTE_DIR}"
done

exit 0;