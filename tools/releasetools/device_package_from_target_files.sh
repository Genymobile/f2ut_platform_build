#!/bin/bash
#
# Copyright 2014 Canonical Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Create Ubuntu device package with all binary blobs needed for factory images
# Script should have defined following global variables
#   SOURCE_ROOT: path to the root of the source tree
#   PRODUCT_OUT: product outpus relative path to SOURCE_ROOT (out/targer/product/<product>/)
#   PACKAGING_INTERMEDIATES: relative path to dir to use for intermediate files (out/targer/product/<product>/obj/PACKAGING/devicepackage_intermediates)
#   DEVICE_PACKAGE_TARGET: collection of pairs of targer update package file relative to SOURCE_ROOT and target name in update package
#                  eg: out/targer/product/<product>/boot.img:boot.img
#   IGNORE_BLOBS: blobs not to be included in the device package. eg: system.img cache.img
#   DEVICE_BUILD_ID: flag if to include device build ID, "true" if included
#   PACKAGE_ANDROID_IMG: if defined as no, then android image will be extracted and included as device/ instead
#   KEYPATH: optional path to gpg signign keys
#   DEVICE_PACKAGE_OVERLAY: overlay to be added to device package

echo "Creating Device update package"
DEVICE_PACKAGE_PARTITIONS=$PACKAGING_INTERMEDIATES/partitions
DEVICE_PACKAGE_BLOBS=$PACKAGING_INTERMEDIATES/blobs
PRODUCT_SYSTEM=$PRODUCT_OUT/system
DEVICE_PACKAGE_CONTENT="blobs partitions"
# clean old files
rm -rf $PACKAGING_INTERMEDIATES
mkdir -p $PACKAGING_INTERMEDIATES

# determing all needed blobs to be included in the package
BLOBS_TO_FLASH=$(grep "file_name" $PRODUCT_OUT/*Android_scatter.txt | awk '{ print $2}' | grep -v "NONE")
HAS_ROOTFS=$(grep "ubunturootfs.img" $PRODUCT_OUT/*Android_scatter.txt)

# copy all device blobs for update
mkdir -p $DEVICE_PACKAGE_BLOBS
cp $PRODUCT_OUT/*Android_scatter.txt $DEVICE_PACKAGE_BLOBS
for BLOB in $BLOBS_TO_FLASH
do
    IGNORE=0
    for name in $IGNORE_BLOBS
    do
        if [ $name == $BLOB ]; then
            IGNORE=1
        fi
    done
    if [ $IGNORE -eq 0 ]; then
        if [ -e $PRODUCT_OUT/$BLOB ]; then
            cp $PRODUCT_OUT/$BLOB $DEVICE_PACKAGE_BLOBS
        fi
    fi
done

# copy supporting files if presented
if [ -n "$PRE_UPDATE_SCRIPT" -a -f $PRODUCT_OUT/$PRE_UPDATE_SCRIPT ]; then
    cp $PRODUCT_OUT/$PRE_UPDATE_SCRIPT $PACKAGING_INTERMEDIATES
    DEVICE_PACKAGE_CONTENT="$PRE_UPDATE_SCRIPT $DEVICE_PACKAGE_CONTENT"
fi

if [ -n "$POST_UPDATE_SCRIPT" -a -f $PRODUCT_OUT/$POST_UPDATE_SCRIPT ]; then
    cp $PRODUCT_OUT/$POST_UPDATE_SCRIPT $PACKAGING_INTERMEDIATES
    DEVICE_PACKAGE_CONTENT="$POST_UPDATE_SCRIPT $DEVICE_PACKAGE_CONTENT"
fi

# copy all device raw partitions images to update
mkdir -p $DEVICE_PACKAGE_PARTITIONS
for pair in $RAW_PARTITIONS
do
    IFS=':' read src dest <<< $pair
    if [ -f "$src" ]; then
        echo -e "Including raw partition image $src as $dest"
        cp $src $DEVICE_PACKAGE_PARTITIONS/$dest
    else
        echo -e "Skipping missing partition file $src"
    fi
    shift
done

# Optionally generate a build ID based on the date and latest git
# commit
if [ "$DEVICE_BUILD_ID" == "true" ]; then
    DEVICE_BUILD="device-build"
    pushd .repo/manifests
    SERIAL="$(date +%Y%m%d)-$(git describe  --tags --dirty --always)"
    popd
    echo "$DEVICE_BUILD: $SERIAL"
    echo $SERIAL >> $PACKAGING_INTERMEDIATES/$DEVICE_BUILD
    DEVICE_PACKAGE_CONTENT="$DEVICE_PACKAGE_CONTENT $DEVICE_BUILD"
fi

if [[ "$PACKAGE_ANDROID_IMG" == "no" ]]; then
    # copy content of android system to device folder for packaging
    echo "Packaging constent of Android system"
    cp -r $PRODUCT_SYSTEM $PACKAGING_INTERMEDIATES/device
    DEVICE_PACKAGE_CONTENT="$DEVICE_PACKAGE_CONTENT device"
else
    echo "Packaging Android system.img for loop mounting"
    # create Android system image
    DEVICE_PACKAGE_LXC=$PACKAGING_INTERMEDIATES/system/var/lib/lxc/android
    if [ -n "$BUILT_SYSTEMIMAGE" ]; then
        mkdir -p $DEVICE_PACKAGE_LXC
        cp $BUILT_SYSTEMIMAGE $DEVICE_PACKAGE_LXC
        DEVICE_PACKAGE_CONTENT="$DEVICE_PACKAGE_CONTENT system"
    fi
fi

# copy file file_context
cp $PRODUCT_OUT/root/file_contexts $DEVICE_PACKAGE_BLOBS

# copy overlay files if defined
if [ ! -z $DEVICE_PACKAGE_OVERLAY ]; then
    echo "Adding overlay to the device package"
    mkdir -p $PACKAGING_INTERMEDIATES/system
    cp -r $DEVICE_PACKAGE_OVERLAY/. $PACKAGING_INTERMEDIATES/system/
    if [[ "$PACKAGE_ANDROID_IMG" == "no" ]]; then
        DEVICE_PACKAGE_CONTENT="$DEVICE_PACKAGE_CONTENT system"
    fi
fi

# determine packing tool
if which pxz >/dev/null;then
    XZ=pxz
    echo "Using parallel XZ compression"
else
    echo "Using single threaded XZ compression, you may want to install pxz"
    XZ=xz
fi

# if we are on OS X ignore ownership
if [ -z $(uname | grep Darwin) ]; then
    TAR_OWNER_OPT=" --owner=0 --group=0 "
fi

# create device update package
tar -C $PACKAGING_INTERMEDIATES $TAR_OWNER_OPT --use-compress-program=$XZ -cf $DEVICE_PACKAGE_TARGET $DEVICE_PACKAGE_CONTENT

# Optionally create ASCII armored detached GPG signature for the tarball
# KEYPATH should hold the signing keys.
if [ -d "$KEYPATH" ]; then
        echo "Creating GPG signature for the device tarball"
        gpg  --yes --homedir $KEYPATH -sba $DEVICE_PACKAGE_TARGET
fi
