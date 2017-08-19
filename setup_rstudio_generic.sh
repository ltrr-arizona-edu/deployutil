#!/bin/sh
#------------------------------------------------------------------------------
#
# setup_rstudio_generic.sh: set up R & RStudio Server on Ubuntu.
#
#------------------------------------------------------------------------------
set -eu

#------------------------------------------------------------------------------
# Environment variables and semi-constants.

# Our short, machine-intelligible name (don't trust $0)
: "${DEPLOYUTIL_OURNAME:=setup_rstudio_generic}"

# Label for this specific installation
: "${DEPLOYUTIL_LABEL:=generic R and RStudio}"

# Where to put our files within the filesystem
: "${DEPLOYUTIL_PREFIX:=/usr/local}"

# Permanent log for recording the setup progress
: "${DEPLOYUTIL_LOGPATH:=$DEPLOYUTIL_PREFIX/var/log/$DEPLOYUTIL_OURNAME.log}"

# Flag file to create on a successful run
: "${DEPLOYUTIL_STATUSPATH:=$DEPLOYUTIL_PREFIX/etc/$DEPLOYUTIL_OURNAME.status}"

# CRAN mirror URL
: "${DEPLOYUTIL_CRANMIRROR:=https://cloud.r-project.org/}"

# Base release codename
: "${DEPLOYUTIL_RELEASENAME:=xenial}"

# RStudio download URL
: "${DEPLOYUTIL_RSTUDIOURL:=https://download2.rstudio.org/}"

# RStudio Server apt package (.deb) filename
: "${DEPLOYUTIL_RSTUDIODEB:=rstudio-server-1.0.153-amd64.deb}"

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
touch "$DEPLOYUTIL_LOGPATH" \
  || die "Failed when writing the log file ${DEPLOYUTIL_LOGPATH}: error ${?}"
timestamp=$(date) \
  || errorexit "Couldn't get the current time to make log entries"
[ ! -e "$DEPLOYUTIL_STATUSPATH" ] \
  || normalexit "Re-run on ${timestamp}, but ${DEPLOYUTIL_OURNAME} has already run"

#------------------------------------------------------------------------------
# Ubuntu package installation and configuration.

logmessage "Started installing the ${DEPLOYUTIL_LABEL} at ${timestamp}"
newsource="deb ${DEPLOYUTIL_CRANMIRROR}/bin/linux/ubuntu ${DEPLOYUTIL_RELEASENAME}/"
echo "$newsource" > /etc/apt/sources.list.d/cran.list \
  || errorexit "Could not add the CRAN mirror to the apt sources as '${newsource}'"
logmessage "Permanently added the CRAN mirror to the apt sources as '${newsource}'"
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9 \
  || errorexit "Failed when adding the Ubuntu-specific signing key for CRAN deb packages"
logmessage "Permanently added the Ubuntu-specific signing key for CRAN deb packages"
apt-get update \
  || errorexit "Could not refresh the Ubuntu (apt) package information"
logmessage "Starting to install apt packages"
apt-get install -y \
  default-jdk \
  default-jre \
  freeglut3-dev \
  gdebi-core \
  libcurl4-openssl-dev \
  libgdal-dev \
  libglu1-mesa-dev \
  libgsl-dev \
  libproj-dev \
  libssl-dev \
  libx11-dev \
  libxml2-dev \
  mesa-common-dev \
  openjdk-7-* \
  r-base \
  r-base-dev \
  r-cran-plyr \
  r-cran-reshape \
  r-cran-reshape2 \
  r-cran-rgl \
  r-cran-rglpk \
  r-cran-rjava \
  r-cran-rmysql \
  r-cran-rsymphony \
  r-cran-xml \
  xml2
R CMD javareconf \
  || errorexit "Failed when trying to detect current the Java setup and update the corresponding configuration in R"
logmessage "Starting to download and install RStudio Server"
scratchdir=$(mktemp -d -t "deployutil_scratch_XXXXXX") \
  || errorexit "Couldn't make a scratch directory for the RStudio Server download"
trap 'rm -Rf "${scratchdir}"' EXIT TERM INT QUIT
cd "$scratchdir"
wget "${DEPLOYUTIL_RSTUDIOURL}${DEPLOYUTIL_RSTUDIODEB}" \
  || errorexit "Couldn't download the RStudio Server .deb file from ${DEPLOYUTIL_RSTUDIOURL}${DEPLOYUTIL_RSTUDIODEB} to ${scratchdir} (status: ${?})"
gdebi -n "$DEPLOYUTIL_RSTUDIODEB" \
  || errorexit "Failed when installing RStudio Server"
echo "OK" > "$DEPLOYUTIL_STATUSPATH" \
  || errorexit "You must manually create a ${DEPLOYUTIL_STATUSPATH} file to prevent repeated runs"
normalexit "Successfully set up ${DEPLOYUTIL_LABEL}"
