#!/bin/bash
# (c) 2014-2015 Freifunk Paderborn <maschinenraum@paderborn.freifunk.net>
#
# calls build.sh with information found in given version

MY_DIR=$(dirname $0)
MY_DIR=$(readlink -f "$MY_DIR")
pushd $MY_DIR > /dev/null

. functions.sh

version=$1
versionfile="${MY_DIR}/versions/${version}"
[ -r $versionfile ] || abort "Failed to find the version '$version'."

[ -n "${BROKEN}" ] || BROKEN=0
base=`awk 'BEGIN { FS="=" } /^GLUON=([a-f0-9]+)(\s*#.+)?$/ { print $2; }' $versionfile | awk 'BEGIN { FS="#" } { print $1; }'`
branch=`awk 'BEGIN { FS="=" } /^BRANCH=([a-z]+)$/ { print $2; }' $versionfile`
version=`awk 'BEGIN { FS="=" } /^VERSION=([0-9\.\-+~a-z]+)$/ { print $2; }' $versionfile`
site_repo=`awk 'BEGIN { FS="=" } /^SITE_REPO=([a-z]+)$/ { print $2; }' $versionfile`
site=`awk 'BEGIN { FS="=" } /^SITE=([a-f0-9]+)(\s*#.+)?$/ { print $2; }' $versionfile | awk 'BEGIN { FS="#" } { print $1; }'`
targets=`awk 'BEGIN { FS="=" } /^TARGETS=.+$/ { print $2; }' $versionfile`
ts=`awk 'BEGIN { FS="=" } /^TS=.+$/ { print $2; }' $versionfile`

[ -z "$base" ] && abort "Failed to parse Gluon base commit-id from version file."
[ -z "$branch" ] && abort "Failed to parse branch name from version file."
[ -z "$version" ] && abort "Failed to parse version from version file."
[ -z "$site_repo" ] && site_repo="ffpb"
[ -z "$site" ] && abort "Failed to parse site repo commit-id from version file."
[ -z "$ts" ] && abort "Failed to parse timestamp from version file."

# remove all spaces from git-commit-ids
base="${base// /}"
site="${site// /}"

info "Building $branch version '$version' again ..."
echo " * Gluon base = $base"
echo " * Site repo  = $site_repo"
echo " * Site commit= $site"
echo " * Timestamp  = $ts"
echo " * Targets    = $targets"
echo

# invoke build script
if [ "$NO_DOCKER" == "1" ]; then
	BASE="$base" BRANCH="$branch" SITE="$site_repo" SITE_ID="$site" VERSION="$version" BUILD_TS="$ts" TARGETS="$targets" BROKEN="$BROKEN" ./build.sh
else
	BASE="$base" BRANCH="$branch" SITE="$site_repo" SITE_ID="$site" VERSION="$version" BUILD_TS="$ts" TARGETS="$targets" BROKEN="$BROKEN" ./docker-build.sh
fi

