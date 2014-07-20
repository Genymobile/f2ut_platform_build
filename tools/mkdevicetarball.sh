#!/bin/bash
#
# Copyright (C) 2014, Canonical Ltd.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# See file /usr/share/common-licenses/GPL for more details.
#
# Make a device tarball from the Android build image, to be flashed
# with ubuntu-device-flash (--device-tarball)

TMPDEVICEDIR=$(mktemp -d)
IMGDIR=${OUT}
DEVICETARBALL=${IMGDIR}/device_${TARGET_PRODUCT}.tar.xz
LXCPATH=${TMPDEVICEDIR}/system/var/lib/lxc/android

function onExit() {
    rm -Rf $TMPDEVICEDIR
}

trap onExit EXIT

[ -f $IMGDIR/system.img ] || {
	echo $IMGDIR does not seem to contain the required Android img files
	exit -1
}

mkdir -p ${LXCPATH}

if file $IMGDIR/system.img | grep ": data" >/dev/null; then
	echo "Copying system.img into a proper EXT4 filesystem"
	simg2img $IMGDIR/system.img tmp.img >/dev/null
	resize2fs -M tmp.img >/dev/null 2>&1
	mv tmp.img $LXCPATH/system.img
else
	echo "Copying system.img which is already an EXT4 filesystem"
	cp $IMGDIR/system.img /$LXCPATH
fi

PDIR=${TMPDEVICEDIR}/partitions
mkdir -p $PDIR
cp ${IMGDIR}/boot.img $PDIR
cp ${IMGDIR}/recovery.img $PDIR

echo "Creating the tarball"

if which pxz >/dev/null;then
	XZ=pxz
	echo "Using parallel XZ compression"
else
	echo "Using single threaded XZ compression, you may want to install pxz"
	XZ=xz
fi

pushd $TMPDEVICEDIR >/dev/null
tar --use-compress-program=$XZ -cf $DEVICETARBALL $(find . -type f) --owner=0 --group=0
popd >/dev/null
