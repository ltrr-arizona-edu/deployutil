#!/bin/sh
#------------------------------------------------------------------------------
#
# setup_rstudio_generic.sh: set up R & RStudio Server on Ubuntu.
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
# and in particular presents the same list of packages to `apt-get install`.
# An installation script using the littler utility, copied from
# http://dirk.eddelbuettel.com/code/littler.examples.html
# adds CRAN packages which are not available through `apt-get install`.
#
#------------------------------------------------------------------------------
set -eu

#------------------------------------------------------------------------------
# Environment variables and semi-constants.

# Our short, machine-intelligible name (don't trust $0)
ourname="setup_rstudio_generic"

# Label for this specific installation
ourlabel="generic R and RStudio"

# CRAN mirror URL
: "${DEPLOYUTIL_CRANMIRROR:=https://cloud.r-project.org/}"

# Base release codename
: "${DEPLOYUTIL_RELEASENAME:=xenial}"

# RStudio download URL
: "${DEPLOYUTIL_RSTUDIOURL:=https://download2.rstudio.org/}"

# RStudio Server apt package (.deb) filename
: "${DEPLOYUTIL_RSTUDIODEB:=rstudio-server-1.1.453-amd64.deb}"

# Where to put our log files within the filesystem
: "${DEPLOYUTIL_LOGDIR:=/var/local/log}"

# Permanent log for recording the setup progress
: "${DEPLOYUTIL_LOGPATH:=$DEPLOYUTIL_LOGDIR/$ourname.log}"

# Where to put our configuration files within the filesystem
: "${DEPLOYUTIL_CONFIGDIR:=/usr/local/etc}"

# Flag file to create on a successful run
: "${DEPLOYUTIL_STATUSPATH:=$DEPLOYUTIL_CONFIGDIR/$ourname.status}"

# R library directory
: "${DEPLOYUTIL_LIBDIR:=/usr/local/lib/R/site-library}"

# Local executable directory
: "${DEPLOYUTIL_BINDIR:=/usr/local/bin}"

# Littler CRAN package installation script
: "${DEPLOYUTIL_INSTALLER:=install.r}"

# Path to the littler CRAN package installation script
: "${DEPLOYUTIL_INSTALLERPATH:=$DEPLOYUTIL_BINDIR/$DEPLOYUTIL_INSTALLER}"

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
# Ubuntu package installation and configuration.

logmessage "Started installing the ${ourlabel} at ${timestamp}"
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
  r-cran-littler \
  r-cran-mass \
  r-cran-mgcv \
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
logmessage "Setting up the ${DEPLOYUTIL_INSTALLER} installation script"
cat >> "$DEPLOYUTIL_INSTALLERPATH" << _EOF_
#!/usr/bin/env r
if (is.null(argv) | length(argv)<1) {
  cat("Usage: ${DEPLOYUTIL_INSTALLER} pkg1 [pkg2 pkg3 ...]\n")
  q()
}
repos <- "${DEPLOYUTIL_CRANMIRROR}"
lib.loc <- "${DEPLOYUTIL_LIBDIR}"
install.packages(argv, lib.loc, repos)
_EOF_
chmod 755 "$DEPLOYUTIL_INSTALLERPATH" \
  || errorexit "Could not make an executable package install script at ${DEPLOYUTIL_INSTALLERPATH}"
logmessage "Installing extra R packages"
${DEPLOYUTIL_INSTALLER} lme4 MuMIn \
  || errorexit "Failed when installing additional R packages"
logmessage "Starting to download and install RStudio Server"
scratchdir=$(mktemp -d -t "${ourname}_XXXXXX") \
  || errorexit "Couldn't make a scratch directory for the ${ourlabel}"
trap 'rm -Rf "${scratchdir}"' EXIT TERM INT QUIT
cd "$scratchdir"
wget "${DEPLOYUTIL_RSTUDIOURL}${DEPLOYUTIL_RSTUDIODEB}" \
  || errorexit "Couldn't download the RStudio Server .deb file from ${DEPLOYUTIL_RSTUDIOURL}${DEPLOYUTIL_RSTUDIODEB} to ${scratchdir} (status: ${?})"
gdebi -n "$DEPLOYUTIL_RSTUDIODEB" \
  || errorexit "Failed when installing RStudio Server"
echo "OK" > "$DEPLOYUTIL_STATUSPATH" \
  || errorexit "You must manually create a ${DEPLOYUTIL_STATUSPATH} file to prevent repeated runs"
normalexit "Successfully set up ${ourlabel}"
