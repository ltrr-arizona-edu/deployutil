#!/bin/sh
#------------------------------------------------------------------------------
#
# fetch_r_code_fagments.sh: fetch files containing R code from a Git repository.
#
#
#------------------------------------------------------------------------------
set -eu

#------------------------------------------------------------------------------
# Environment variables and semi-constants.

# Our short, machine-intelligible name (don't trust $0)
: "${DEPLOYUTIL_OURNAME:=fetch_r_code_fagments}"

# Label for this specific installation
: "${DEPLOYUTIL_LABEL:=R code fragment retrieval}"

# Source Git repository
: "${DEPLOYUTIL_SOURCEREPO:=https://github.com/mekevans/pecan.git}"

# Source Git branch
: "${DEPLOYUTIL_SOURCEBRANCH:=working}"

# Source subdirectory to copy
: "${DEPLOYUTIL_SOURCEDIR:=pecan/modules/data.land/R}"

# Absolute destination directory path
: "${DEPLOYUTIL_DESTDIR:=/usr/local/src/R}"

# Where to put our log files within the filesystem
: "${DEPLOYUTIL_LOGDIR:=/var/local/log}"

# Permanent log for recording the setup progress
: "${DEPLOYUTIL_LOGPATH:=$DEPLOYUTIL_LOGDIR/$DEPLOYUTIL_OURNAME.log}"

# Where to put our configuration files within the filesystem
: "${DEPLOYUTIL_CONFIGDIR:=/usr/local/etc}"

# Flag file to create on a successful run
: "${DEPLOYUTIL_STATUSPATH:=$DEPLOYUTIL_CONFIGDIR/$DEPLOYUTIL_OURNAME.status}"

#------------------------------------------------------------------------------
# Utility functions definitions.

die () {
  echo "** $1." >&2
  exit 1
}
errorexit () {
  mess="** $1."
  echo "$mess" >&2
  echo "$mess" >> "$DEPLOYUTIL_LOGPATH"
  exit 1
}
logmessage () {
  mess="$1..."
  echo "$mess" >&2
  echo "$mess" >> "$DEPLOYUTIL_LOGPATH"
}
normalexit () {
  mess="$1."
  echo "$mess" >&2
  echo "$mess" >> "$DEPLOYUTIL_LOGPATH"
  exit 0
}

#------------------------------------------------------------------------------
# Logging/rerun sanity check.

[ -d "$DEPLOYUTIL_LOGDIR" ] \
  || mkdir -p "$DEPLOYUTIL_LOGDIR" \
     || die "No directory ${DEPLOYUTIL_LOGDIR} for log files"
touch "$DEPLOYUTIL_LOGPATH" \
  || die "Failed when writing the log file ${DEPLOYUTIL_LOGPATH}: error ${?}"
timestamp=$(date) \
  || errorexit "Couldn't get the current time to make log entries"
[ -d "$DEPLOYUTIL_CONFIGDIR" ] \
  || mkdir -p "$DEPLOYUTIL_CONFIGDIR" \
     || errorexit "No directory ${DEPLOYUTIL_CONFIGDIR} for config files"
[ ! -e "$DEPLOYUTIL_STATUSPATH" ] \
  || normalexit "Re-run on ${timestamp}, but ${DEPLOYUTIL_OURNAME} has already run"

#------------------------------------------------------------------------------
# Ubuntu package installation and configuration.

logmessage "Started the ${DEPLOYUTIL_LABEL} at ${timestamp}"
scratchdir=$(mktemp -d -t "${DEPLOYUTIL_OURNAME}_XXXXXX") \
  || errorexit "Couldn't make a scratch directory for the ${DEPLOYUTIL_LABEL}"
trap 'rm -Rf "${scratchdir}"' EXIT TERM INT QUIT
cd "$scratchdir"
git clone --depth 1 --branch "$DEPLOYUTIL_SOURCEBRANCH" "$DEPLOYUTIL_SOURCEREPO" \
  || errorexit "Failed making a local clone of the ${DEPLOYUTIL_SOURCEBRANCH} branch from the ${DEPLOYUTIL_SOURCEREPO} Git repository"
[ -d "$DEPLOYUTIL_SOURCEDIR" ] \
  || errorexit "Couldn't find the ${DEPLOYUTIL_SOURCEDIR} directory to copy"
logmessage "Made a local shallow clone of the ${DEPLOYUTIL_SOURCEBRANCH} branch from the ${DEPLOYUTIL_SOURCEREPO} Git repository"
[ -d "$(dirname ${DEPLOYUTIL_DESTDIR})" ] \
  || mkdir -p "$(dirname ${DEPLOYUTIL_DESTDIR})" \
     || errorexit "Failed when finding the destination directory for ${DEPLOYUTIL_DESTDIR}"
[ ! -e "$DEPLOYUTIL_DESTDIR" ] \
  || errorexit "The destination ${DEPLOYUTIL_DESTDIR} already exists"
cp -R "$DEPLOYUTIL_SOURCEDIR" "$DEPLOYUTIL_DESTDIR" \
  || errorexit "Couldn't copy from ${DEPLOYUTIL_SOURCEDIR} to ${DEPLOYUTIL_DESTDIR}"
echo "OK" > "$DEPLOYUTIL_STATUSPATH" \
  || errorexit "You must manually create a ${DEPLOYUTIL_STATUSPATH} file to prevent repeated runs"
normalexit "Successfully set up ${DEPLOYUTIL_LABEL}"
