#!/bin/bash

export BASE_PATH=`pwd`

cd $(dirname $0)

set -e -x

# compile the cni binaries
cnidir=$(mktemp -d)
trap "rm -rf $cnidir" EXIT
git clone https://github.com/containernetworking/cni.git $cnidir/cni --branch v0.3.0
version=$(cd $cnidir/cni/.git && git describe --tags)
(cd $cnidir/cni && ./build)

# if we're running in TeamCity, then export the version information.
if [ -n "$TC_BUILD_NUMBER" ]; then
    set +x
    echo "##teamcity[buildNumber '$version']"
    set -x
fi

dir=$(mktemp -d)
trap "rm -rf $dir" EXIT
chmod 755 $dir

# copy in cni binaries
mkdir -p $dir/usr/bin
cp $cnidir/cni/bin/* $dir/usr/bin/
# except cnitool
rm $dir/usr/bin/cnitool

# copy in the networking script
mkdir -p $dir/opt/network
cp $BASE_PATH/bin/cni-netplugin-setup $dir/opt/network/setup
cp add.sh $dir/opt/network/add
cp del.sh $dir/opt/network/del
chmod a+x $dir/opt/network/*

# create a symlink so the console can access kernel modules from the host
mkdir -p $dir/lib
ln -s /host/proc/1/root/lib/firmware $dir/lib/firmware
ln -s /host/proc/1/root/lib/modules $dir/lib/modules

# generate the aci
go run ../build.go -manifest ./manifest.yaml -root $dir -version $version -output $BASE_PATH/$1
