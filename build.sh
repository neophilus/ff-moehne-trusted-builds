#!/bin/bash
# (c) 2014-2015 Freifunk Paderborn <maschinenraum@paderborn.freifunk.net>
#
# This script builds the firmware by the environment variables given, the
# first two being mandatory:
#
# BASE      = Gluon Version (tag or commit, i.e. v2014.4)
# BRANCH    = Firmware Branch (stable/testing/experimental)
# SITE      = site repository to use
# SITE_ID   = specific site repository commit-id (leave blank to use HEAD)
# VERSION   = the version tag (can only be empty if BRANCH=experimental)
# BUILD_TS  = build timestamp (format: %Y-%m-%d %H:%M:%S)
# BROKEN    = 0 (default) or 1, build the untested hardware model firmwares, too
# MAKEJOBS  = number of compiler processes running in parallel (default: number of CPUs/Cores)
# TARGETS   = a space separated list of target platforms (if unset, all platforms will be build)
# PRIORITY  = determines the number of day a rollout phase should last at most
# VERBOSE   = 0 (default) or 1, call the make commands with 'V=s' to see actual errors better
# SITE_REPO_FETCH_METHOD = http, everything except "git" will use the HTTP method for fetchting site repo
#

function get_all_supported_platforms()
{
	local buffer;
	for val in $(ls ${1}) ; do
		[ -d "./${1}/${val}" ] || continue
	buffer="${buffer} ${val}"
	done
	echo ${buffer}
}


if [ "_$BRANCH" == "_" ]; then
	echo "Please specify BRANCH environment variable." >&2
	exit 1
fi

if [ "_$BASE" == "_" ]; then
	echo "Please specify BASE environment variable (Gluon, i.e. 'v2014.3' or commit-id)." >&2
	exit 1
fi

if [ "${BRANCH}" != "experimental" -a "${BASE}" == "HEAD" ] ; then
	echo "HEAD is not an allowed BASE-identifier for non-experimental builds." >&2
	echo "Either use a tagged commit or the commit-SHA itself." >&2
	exit 1
fi

if [ "_$VERSION" == "_" -a "$BRANCH" != "experimental" ]; then
	echo "Please specify VERSION environment variable (not necessary for experimental branch)." >&2
	exit 1
fi

MY_DIR=$(dirname $0)
MY_DIR=$(readlink -f "$MY_DIR")
CODE_DIR="src"
PATCH_DIR="site/patches"
OUTPUT_DIR="${MY_DIR}/output"
BUILD_INFO_FILENAME="build-info.txt"
VERSIONS_INFO_DIR="versions"
LANG=C

pushd $MY_DIR > /dev/null
[ "_$BUILD_TS" == "_" ] && export BUILD_TS=$(date +"%Y-%m-%d %H:%M:%S")

. functions.sh

### CHECK THAT VERSION DOES NOT YET EXISTS
[ -n "$VERSION" -a -x "${VERSIONS_INFO_DIR}/${VERSION}" ] && abort "There exists a version file for '$VERSION' ... you are trying to do something really stupid, aren't you?"

### INIT /src IF NECESSARY
if [ ! -d "$CODE_DIR" ]; then
	info "Code directory does not exist yet - fetching Gluon ..."
	git clone https://github.com/freifunk-gluon/gluon.git "$CODE_DIR"
fi

if [ "_${SITE_REPO_FETCH_METHOD}" != "_git" ]; then
	SITE_REPO_URL="https://git.c3pb.de/freifunk-pb/site-${SITE}.git"
else
	SITE_REPO_URL="git@git.c3pb.de:freifunk-pb/site-${SITE}.git"
fi

### INIT /src/site IF NECESSARY
if [ -d "$CODE_DIR/site" ]; then
	# verify the site-repo is the correct one ($SITE), otherwise delete the repo
	pushd "$CODE_DIR/site"
	url=$(git remote show origin | awk '/Fetch URL/ { print $3; }')
	if [ "$SITE_REPO_URL" != "$url" ]; then
		info "The site repository is not the correct one."
		if ! git diff-index --quiet HEAD --; then
			popd > /dev/null
			abort "The site repo is the wrong one but has local modifications, please fix this manually."
		fi
		# check on the actual branch, not the target one given as parameter
		local_branch=$(git branch --list --no-color | awk '/^*/ { print $2; }')
		commits=$(git log origin/${local_branch}..HEAD)
		if [ -n "$commits" ]; then
			popd > /dev/null
			abort "The site repo is the wrong one but has unpushed commits, please fix this manually."
		fi

		# remove the directory without asking further questions
		popd > /dev/null
		rm -Rf "$CODE_DIR/site" || abort "Failed to remove wrong site-repository."
		success "Removed old site directory in order to be able to clone the correct one."
	else
		popd > /dev/null
	fi
fi

if [ ! -d "$CODE_DIR/site" ]; then
	info "Site repository does not exist, fetching it ..."
	git clone "$SITE_REPO_URL" "$CODE_DIR/site" || abort "Failed to fetch SITE repository."
fi

### CHECKOUT GLUON
progress "Checking out GLUON '$BASE' ..."
cd $CODE_DIR
# TODO: check if gluon got modified and bail out if necessary
git fetch
if [ "$BASE" = "master" ]; then
	git checkout -q origin/master
else
	git checkout -q $BASE
fi
[ "$?" -eq "0" ] || abort "Failed to checkout '$BASE' gluon base version, mimimi." >&2
GLUON_COMMIT=$(git rev-list --max-count=1 HEAD)

### CHECKOUT SITE REPO
progress "Checking out SITE REPO ..."
cd site
# TODO: check if site got modified locally and bail out if necessary
if [ "_${SITE_ID}" == "_" ]; then
	# no specific site given - get the most current one
	git checkout -q $BRANCH ; git pull
	[ "$?" -eq "0" ] || abort "Failed to get newest '$BRANCH' in site repository, mimimi."
else
	# fetch site repo updates
	git fetch || true
	# commit given - use this one
	git checkout -q ${SITE_ID} || abort "Failed to checkout requested site commit, mimimi."
fi
SITE_COMMIT=$(git rev-list --max-count=1 HEAD)

cd ..

### APPLY PATCHES TO GLUON
if [ -d "$PATCH_DIR" ]; then
	progress "Applying Patches ..."
	git am $PATCH_DIR/*.patch
	[ "$?" -eq "0" ] || abort "Failed to apply patches, mimimi."
fi


### CLEAN
if [ -d "./build/" -a "$BRANCH" != "experimental" ]; then
	progress "Cleaning your build environment ..."
	make dirclean
fi

### PREPARE
progress "Preparing the build environment (make update) ..."
make update
[ "$?" -eq "0" ] || abort "Failed to update the build environment, mimimi."

# determine VERSION for BRANCH=experimental if it is not set
if [ "${BRANCH}" == "experimental" -a -z "${VERSION}" ] ; then
	default_release_pattern=$( awk -F" := " '/^DEFAULT_GLUON_RELEASE/ { gsub("shell ", "", $2); print $2; }' ./site/site.mk )
	VERSION=$(eval echo ${default_release_pattern})

	info "EXPERIMENTAL FIRMWARE: using version tag '$VERSION'"
fi

# set reasonable defaults for unset environment variables
[ -n "${BROKEN}" ] || BROKEN=0
[ -n "${MAKEJOBS}" ] || MAKEJOBS=$(grep -c "^processor" /proc/cpuinfo)
[ -n "${TARGETS}" ] || TARGETS=$(get_all_supported_platforms "./targets")
[ -n "${PRIORITY}" ] || PRIORITY=0
MAKE_PARAM=""
[ "_$VERBOSE" = "_1" ] && MAKE_PARAM="${MAKE_PARAM} V=s"

# we are now ready to produke the firmware images, so let's "save" our state
build_info_path="${OUTPUT_DIR}/${BRANCH}/${BUILD_INFO_FILENAME}"
progress "Saving build information to: ${build_info_path}"
[ -n "${build_info_path}" -a -f "${build_info_path}" ] && rm -f ${build_info_path}
mkdir -p $(dirname ${build_info_path})
[ "$?" -eq "0" ] || abort "Unable to create output directory: $(dirname ${build_info_path})"
touch $(dirname ${build_info_path})
[ "$?" -eq "0" ] || abort "Cannot create build information file: ${build_info_path}"
echo "VERSION=${VERSION}" >> ${build_info_path}
echo "GLUON=${GLUON_COMMIT} # ${BASE}" >> ${build_info_path}
echo "BRANCH=${BRANCH}" >> ${build_info_path}
echo "SITE_REPO=${SITE}" >> ${build_info_path}
echo "SITE=${SITE_COMMIT} # ${VERSION}" >> ${build_info_path}
echo "TARGETS=${TARGETS}" >> ${build_info_path}
echo "TS=${BUILD_TS}" >> ${build_info_path}

### BUILD FIRMWARE
progress "Building the firmware - please stand by!"

for target in ${TARGETS} ; do
	# configure build environment for our current target
	export GLUON_TARGET="${target}"
	gluon_build_env_vars="GLUON_TARGET=\"${target}\" GLUON_BRANCH=\"${BRANCH}\" GLUON_RELEASE=\"${VERSION}\" BROKEN=\"${BROKEN}\""

	# prepare build environment for our current target
	progress "Preparing build environment for target ${target}."
	[ "${BRANCH}" == "experimental" ] || make clean
	make -j ${MAKEJOBS} prepare-target${MAKE_PARAM}

	# need to have a toolchain for the particular target 
	progress "Building toolchain for target ${target}."
	make -j ${MAKEJOBS} toolchain/install${MAKE_PARAM}
	[ "$?" -eq "0" ] || abort "Unable to build toolchain for target. Aborting."

	# now we can start building the images for the target platform
	progress "Building FFPB-flavoured Gluon firmware for target ${target}. You'd better go and fetch some c0ffee!"
	make_targets="prepare"
	eval "${gluon_build_env_vars} faketime \"$BUILD_TS\" make -j ${MAKEJOBS} ${make_targets}${MAKE_PARAM}"
	[ "$?" -eq "0" ] || abort "Failed to build firmware for target-platform ${target}."

	# finally compile the firmware binaries
	progress "Compiling binary firmware images."
	faketime "$BUILD_TS" make images${MAKE_PARAM}
	[ "$?" -eq "0" ] || abort "Failed to assemble images for target-platform ${target}."
done

cd ..

# compress all binaries into 7z archive
progress "Assembling images.7z ..."
[ -e "${OUTPUT_DIR}/${BRANCH}/images.7z" ] && rm "${OUTPUT_DIR}/${BRANCH}/images.7z"
if [ ${BRANCH} == "experimental" ]; then
        7z a -xr!*.manifest "${OUTPUT_DIR}/${BRANCH}/images.7z" ${CODE_DIR}/output/images/sysupgrade/* ${CODE_DIR}/output/images/factory/* || abort "Failed to assemble images (did you install p7zip-full?)."
else
        7z a -xr!*.manifest "${OUTPUT_DIR}/${BRANCH}/images.7z" ${CODE_DIR}/images/sysupgrade/* ${CODE_DIR}/images/factory/* || abort "Failed to assemble images (did you install p7zip-full?)."
fi

# generate, franken-merge, and copy manifests
progress "Generating and copying manifest ..."
pushd $CODE_DIR
GLUON_TARGET="ar71xx-generic" GLUON_BRANCH=$BRANCH make manifest || abort "Failed to generate the manifest, try running 'make manifest' in '$CODE_DIR' directory manually."
popd
cp "${CODE_DIR}/images/sysupgrade/${BRANCH}.manifest" "${OUTPUT_DIR}/${BRANCH}/"

# Saving a copy of the build info file as reference
progress "Building a greater and brighter firmware finished successfully. Saving build information at: ${VERSIONS_INFO_DIR}/${VERSION}"
cp -p "${build_info_path}" "${VERSIONS_INFO_DIR}/${VERSION}"

# The end. Finally.
success "We're done, go and enjoy your new firmware in ${OUTPUT_DIR}/${BRANCH}!"
popd > /dev/null