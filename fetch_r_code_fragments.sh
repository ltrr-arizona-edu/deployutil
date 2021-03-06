#!/bin/sh
#------------------------------------------------------------------------------
#
# fetch_r_code_fagments.sh: fetch files containing R code from a Git repository.
#
# This extracts a subdirectory containing code fragments from a Git repository
# and makes it available to all users on the system through a symlink in their
# home directories. It should run non-interacively, and will record most of the
# errors that prevent installation in a permanent log file. If the installation
# succeeds it creates a status flag file, and avoids unneccesary re-installation
# attempts if it detects this on subsequent runs. It expects full access to the
# filesystem to create the copy, so must run as root or through sudo; you can
# re-assign the environment variables it uses to override many defaults.
#
#------------------------------------------------------------------------------
set -eu

#------------------------------------------------------------------------------
# Environment variables and semi-constants.

# Our short, machine-intelligible name (don't trust $0)
ourname="fetch_r_code_fagments"

# Label for this specific installation
ourlabel="R code fragment retrieval"

# Source Git repository
: "${DEPLOYUTIL_SOURCEREPO:=https://github.com/mekevans/pecan.git}"

# Source Git branch
: "${DEPLOYUTIL_SOURCEBRANCH:=working}"

# Source subdirectory to copy
: "${DEPLOYUTIL_SOURCEDIR:=pecan/modules/data.land/R}"

# Absolute destination directory path
: "${DEPLOYUTIL_DESTDIR:=/usr/local/src/R}"

# Destination alias link
: "${DEPLOYUTIL_DESTLINK:=code}"

# Where to put our log files within the filesystem
: "${DEPLOYUTIL_LOGDIR:=/var/local/log}"

# Permanent log for recording the setup progress
: "${DEPLOYUTIL_LOGPATH:=$DEPLOYUTIL_LOGDIR/$ourname.log}"

# Where to put our configuration files within the filesystem
: "${DEPLOYUTIL_CONFIGDIR:=/usr/local/etc}"

# Flag file to create on a successful run
: "${DEPLOYUTIL_STATUSPATH:=$DEPLOYUTIL_CONFIGDIR/$ourname.status}"

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
  || normalexit "Re-run on ${timestamp}, but ${ourname} has already run"

#------------------------------------------------------------------------------
# Git repository subdirectory copy.

logmessage "Started the ${ourlabel} at ${timestamp}"
scratchdir=$(mktemp -d -t "${ourname}_XXXXXX") \
  || errorexit "Couldn't make a scratch directory for the ${ourlabel}"
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
logmessage "Copied from ${DEPLOYUTIL_SOURCEDIR} to ${DEPLOYUTIL_DESTDIR}"

#------------------------------------------------------------------------------
# Symlink the copy into all home directories.

. /etc/adduser.conf \
  || errorexit "Can't pick up the default user account settings"
[ -n "$DHOME" ] \
  || errorexit "Can't find the default user home directory location"
for home in "$DHOME"/* ; do
  if { echo "$home" | grep -q -v 'lost+found'; } ; then
    symlink="${home}/${DEPLOYUTIL_DESTLINK}"
    ln -s "$DEPLOYUTIL_DESTDIR" "$symlink" \
      || errorexit "Couldn't make a symbolic link ${symlink} for ${DEPLOYUTIL_DESTDIR}"
    logmessage "Symlinked ${DEPLOYUTIL_DESTDIR} as ${symlink}"
  fi
done

#------------------------------------------------------------------------------
# Mark completion.

echo "OK" > "$DEPLOYUTIL_STATUSPATH" \
  || errorexit "You must manually create a ${DEPLOYUTIL_STATUSPATH} file to prevent repeated runs"
normalexit "Successfully completed ${ourlabel}"
