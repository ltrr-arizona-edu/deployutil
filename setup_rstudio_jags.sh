#!/bin/sh
#------------------------------------------------------------------------------
#
# setup_rstudio_jags.sh: set up JAGS, R & RStudio Server on Ubuntu.
#
# This should install R from a CRAN mirror and RStudio Server from rstudio.org
# for AMD64 Ubuntu, permanently adding CRAN to the sources apt-get uses
# and explicitly trusting the package maintainer's signing key. It should
# run non-interacively, and will record most of the errors that prevent
# installation in a permanent log file. If the installation succeeds it creates
# a status flag file, and avoids unneccesary re-installation attempts if it
# detects this on subsequent runs. It expects full access to the filesystem
# and apt configuration, so must run as root or through sudo; you can re-assign
# the environment variables it uses to override many defaults. It is based on
# https://msperlin.github.io/2017-06-01-Instaling-R-in-Linux/
# although it includes some extra packages, most importantly `r-cran-rjags`,
# which should bring in the Ubuntu-packaged version of JAGS itself as a
# dependency. It also specifies `r-cran-coda`, although this should get
# installed in any case (as another dependency).
#
#------------------------------------------------------------------------------
set -eu

#------------------------------------------------------------------------------
# Environment variables and semi-constants.

# Our short, machine-intelligible name (don't trust $0)
: "${DEPLOYUTIL_OURNAME:=setup_rstudio_jags}"

# Label for this specific installation
: "${DEPLOYUTIL_LABEL:=JAGS R and RStudio}"

# CRAN mirror URL
: "${DEPLOYUTIL_CRANMIRROR:=https://cloud.r-project.org/}"

# Base release codename
: "${DEPLOYUTIL_RELEASENAME:=xenial}"

# RStudio download URL
: "${DEPLOYUTIL_RSTUDIOURL:=https://download2.rstudio.org/}"

# RStudio Server apt package (.deb) filename
: "${DEPLOYUTIL_RSTUDIODEB:=rstudio-server-1.0.153-amd64.deb}"

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
  r-cran-coda \
  r-cran-littler \
  r-cran-plyr \
  r-cran-reshape \
  r-cran-reshape2 \
  r-cran-rgl \
  r-cran-rglpk \
  r-cran-rjags \
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
