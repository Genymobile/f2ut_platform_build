#
# Copyright (C) 2013 The Android Open Source Project
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
# Note that components added here will be also shared in PDK. Components
# that should not be in PDK should be added in lower level like core.mk.

PRODUCT_PACKAGES += \
    ContactsProvider \
    DefaultContainerService \
    TelephonyProvider \
    UserDictionaryProvider \
    atrace \
    libandroidfw \
    libaudiopreprocessing \
    libaudioutils \
    libfilterpack_imageproc \
    libgabi++ \
    libinput \
    libmdnssd \
    libnfc_ndef \
    libpowermanager \
    libspeexresampler \
    libstagefright_soft_aacdec \
    libstagefright_soft_aacenc \
    libstagefright_soft_amrdec \
    libstagefright_soft_amrnbenc \
    libstagefright_soft_amrwbenc \
    libstagefright_soft_flacenc \
    libstagefright_soft_g711dec \
    libstagefright_soft_gsmdec \
    libstagefright_soft_h264dec \
    libstagefright_soft_h264enc \
    libstagefright_soft_hevcdec \
    libstagefright_soft_mp3dec \
    libstagefright_soft_mpeg4dec \
    libstagefright_soft_mpeg4enc \
    libstagefright_soft_opusdec \
    libstagefright_soft_rawdec \
    libstagefright_soft_vorbisdec \
    libstagefright_soft_vpxdec \
    libstagefright_soft_vpxenc \
    libstagefright_soft_dtsdec \
    libvariablespeed \
    libwebrtc_audio_preprocessing \
    mdnsd \
    recovery_resize2fs \
    requestsync \
    libadf \
    libutils \
    libz \
    libpng \
    libsuspend \
    libbatteryservice \
    libbinder \
    libminui \
    healthd

# for Ubuntu Touch (hybris, platform-api, utils, etc)
PRODUCT_PACKAGES += \
    apns-conf.xml \
    libcamera_compat_layer \
    camera_service \
    libis_compat_layer \
    libmedia_compat_layer \
    libsf_compat_layer \
    libui_compat_layer \
    libubuntu_application_api \
    upstart-property-watcher

# for testing
PRODUCT_PACKAGES += \
    autopilot-finger.idc \
    direct_camera_test \
    direct_input_test \
    direct_media_test \
    direct_sf_test \
    direct_ubuntu_application_sensors_c_api_for_hybris_test \
    direct_ubuntu_application_sensors_for_hybris_test \
    direct_ubuntu_application_gps_c_api_for_hybris_test

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_minimal.mk)
