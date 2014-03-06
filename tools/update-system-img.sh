#!/bin/sh -e
#
# Copyright (C) 2013 Canonical, Ltd.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

MNTPATH="/tmp/update-img"
USYSIMG="/data/ubuntu.img"
SYSTEM="/system"
ANDROID="/var/lib/lxc/android/system.img"
SERIAL=$ANDROID_SERIAL

do_shell()
{
    adb $ADBOPTS shell "$@"
}

do_push()
{
    adb $ADBOPTS push $@
}

convert_android_img()
{
    simg2img $SYSIMG $SYSRAW
    resize2fs -M $SYSRAW >/dev/null
}

cleanup()
{
    [ -f $SYSRAW ] && rm -f $SYSRAW
}

print_usage() {
    cat << EOF
usage: $(basename $0) [-s SERIAL] <path to android system.img>

  Update the android system image on a Ubuntu Touch device (from recovery) using the
  system image format.

  -s SERIAL        Device serial number
  -h               This message
EOF
}

trap cleanup 1 2 3 9 15

while getopts s:h opt; do
    case $opt in
    h)
        print_usage
        exit 0
        ;;
    s)
        SERIAL="$OPTARG"
        ;;
  esac
done

if [ -n "$SERIAL" ]; then
    ADBOPTS="-s $SERIAL"
fi

# Also check if there is a default image in the build output path
shift $((OPTIND - 1))
SYSIMG=$@
if [ -z "$SYSIMG" ]; then
    if [ -z "$OUT" ]; then
        SYSIMG=out/target/product/*/system.img
    else
        SYSIMG=$OUT/system.img
    fi
fi
SYSRAW=${SYSIMG}.raw

if [ ! -f "$SYSIMG" ]; then
    echo "Need a valid Android system image path"
    exit 1
fi

echo "Pushing android image available at $SYSIMG"

if ! do_shell "ls /sbin/recovery" | grep -q "^/sbin/recovery"; then
    echo "Please make sure the device is attached via USB and in recovery mode"
    exit 1
fi

echo "Mounting system and data partitions"
do_shell "mount /data"
do_shell "mount /system"

echo "Checking first for the ubuntu.img bind-mounted solution"
if do_shell "ls $USYSIMG" | grep -q "^$USYSIMG"; then
    do_shell "mkdir -p $MNTPATH"
    do_shell "mount $USYSIMG $MNTPATH"
    ANDROIDIMG="$MNTPATH/$ANDROID"
else
    echo "Bind mounted ubuntu image not found, looking for the system partition"
    ANDROIDIMG="$SYSTEM/$ANDROID"
fi

if ! do_shell "ls $ANDROIDIMG" | grep -q "^$ANDROIDIMG"; then
    echo "Couldn't find the Android image file ($ANDROIDIMG), aborting"
    exit 1
fi

echo "Converting android system.img to a valid image format"
convert_android_img

echo "Copying $SYSRAW to the ubuntu system image"
do_push $SYSRAW $ANDROIDIMG

if do_shell "ls $MNTPATH" | grep -q "^$MNTPATH"; then
    do_shell "umount $MNTPATH"
fi

do_shell "umount /data"
do_shell "umount /system"

echo "Rebooting device"
adb $ADBOPTS reboot
