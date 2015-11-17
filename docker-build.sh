#!/bin/bash
# (c) 2014-2015 Freifunk Hochstift <maschinenraum@hochstift.freifunk.net>

# check if we're in the container
running_in_docker() {
  awk -F/ '$2 == "docker"' /proc/self/cgroup | read
}

# when called within the container, just call build.sh after ensuring git config is set
if [ running_in_docker -a "$(id -un)" == "build" ]; then

	# ensure that we have a valid git config
	git config --global user.name "docker-based build"
	git config --global user.email build@hochstift.freifunk.net

	# invoke the actual build
	./build.sh $@
	exit
fi

MYDIR="$(dirname $0)"
MYDIR="$(readlink -f $MYDIR)"
pushd "$MYDIR" > /dev/null

# run the container with fixed hostname and mapped /code directory
docker run -ti -h ffho-build -v "$MYDIR:/code" \
    --env BUILD_TS="$BUILD_TS" \
    --env BASE="$BASE" \
    --env BRANCH="$BRANCH" \
    --env BROKEN="$BROKEN" \
    --env MAKEJOBS="$MAKEJOBS" \
    --env VERBOSE="$VERBOSE" \
    --env VERSION="$VERSION" \
    --env TARGETS="$TARGETS" \
    --env SITE="$SITE" \
    --env SITE_ID="$SITE_ID" \
    ffpb/build

popd > /dev/null