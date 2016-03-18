###########################################################
## Standard rules for copying files that are prebuilt
##
## Additional inputs from base_rules.make:
## None.
##
###########################################################

ifneq ($(LOCAL_PREBUILT_LIBS),)
$(error dont use LOCAL_PREBUILT_LIBS anymore LOCAL_PATH=$(LOCAL_PATH))
endif
ifneq ($(LOCAL_PREBUILT_EXECUTABLES),)
$(error dont use LOCAL_PREBUILT_EXECUTABLES anymore LOCAL_PATH=$(LOCAL_PATH))
endif
ifneq ($(LOCAL_PREBUILT_JAVA_LIBRARIES),)
$(error dont use LOCAL_PREBUILT_JAVA_LIBRARIES anymore LOCAL_PATH=$(LOCAL_PATH))
endif

# Not much sense to check build prebuilts
LOCAL_DONT_CHECK_MODULE := true

my_32_64_bit_suffix := $(if $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)IS_64_BIT),64,32)

ifdef LOCAL_PREBUILT_MODULE_FILE
  my_prebuilt_src_file := $(LOCAL_PREBUILT_MODULE_FILE)
else
  ifdef LOCAL_SRC_FILES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)
    my_prebuilt_src_file := $(LOCAL_PATH)/$(LOCAL_SRC_FILES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH))
  else
    ifdef LOCAL_SRC_FILES_$(my_32_64_bit_suffix)
      my_prebuilt_src_file := $(LOCAL_PATH)/$(LOCAL_SRC_FILES_$(my_32_64_bit_suffix))
    else
      my_prebuilt_src_file := $(LOCAL_PATH)/$(LOCAL_SRC_FILES)
    endif
  endif
endif

ifeq (SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS))
  # Put the built targets of all shared libraries in a common directory
  # to simplify the link line.
  OVERRIDE_BUILT_MODULE_PATH := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)OUT_INTERMEDIATE_LIBRARIES)
endif

ifneq ($(filter STATIC_LIBRARIES SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
  prebuilt_module_is_a_library := true
else
  prebuilt_module_is_a_library :=
endif

# Don't install static libraries by default.
ifndef LOCAL_UNINSTALLABLE_MODULE
ifeq (STATIC_LIBRARIES,$(LOCAL_MODULE_CLASS))
  LOCAL_UNINSTALLABLE_MODULE := true
endif
endif

ifeq ($(LOCAL_MODULE_CLASS),APPS)
LOCAL_BUILT_MODULE_STEM := package.apk
LOCAL_INSTALLED_MODULE_STEM := $(LOCAL_MODULE).apk
endif

ifeq ($(LOCAL_STRIP_MODULE),true)
  ifdef LOCAL_IS_HOST_MODULE
    $(error Cannot strip host module LOCAL_PATH=$(LOCAL_PATH))
  endif
  ifeq ($(filter SHARED_LIBRARIES EXECUTABLES,$(LOCAL_MODULE_CLASS)),)
    $(error Can strip only shared libraries or executables LOCAL_PATH=$(LOCAL_PATH))
  endif
  ifneq ($(LOCAL_PREBUILT_STRIP_COMMENTS),)
    $(error Cannot strip scripts LOCAL_PATH=$(LOCAL_PATH))
  endif
  include $(BUILD_SYSTEM)/dynamic_binary.mk
  built_module := $(linked_module)
else  # LOCAL_STRIP_MODULE not true
  include $(BUILD_SYSTEM)/base_rules.mk
  built_module := $(LOCAL_BUILT_MODULE)

ifdef prebuilt_module_is_a_library
export_includes := $(intermediates)/export_includes
$(export_includes): PRIVATE_EXPORT_C_INCLUDE_DIRS := $(LOCAL_EXPORT_C_INCLUDE_DIRS)
$(export_includes) : $(LOCAL_MODULE_MAKEFILE)
	@echo Export includes file: $< -- $@
	$(hide) mkdir -p $(dir $@) && rm -f $@
ifdef LOCAL_EXPORT_C_INCLUDE_DIRS
	$(hide) for d in $(PRIVATE_EXPORT_C_INCLUDE_DIRS); do \
	        echo "-I $$d" >> $@; \
	        done
else
	$(hide) touch $@
endif

$(LOCAL_BUILT_MODULE) : | $(intermediates)/export_includes
endif  # prebuilt_module_is_a_library

# The real dependency will be added after all Android.mks are loaded and the install paths
# of the shared libraries are determined.
ifdef LOCAL_INSTALLED_MODULE
ifdef LOCAL_SHARED_LIBRARIES
$(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)DEPENDENCIES_ON_SHARED_LIBRARIES += \
  $(my_register_name):$(LOCAL_INSTALLED_MODULE):$(subst $(space),$(comma),$(LOCAL_SHARED_LIBRARIES))

# We also need the LOCAL_BUILT_MODULE dependency,
# since we use -rpath-link which points to the built module's path.
built_shared_libraries := \
    $(addprefix $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)OUT_INTERMEDIATE_LIBRARIES)/, \
    $(addsuffix $($(my_prefix)SHLIB_SUFFIX), \
        $(LOCAL_SHARED_LIBRARIES)))
$(LOCAL_BUILT_MODULE) : $(built_shared_libraries)
endif
endif

endif  # LOCAL_STRIP_MODULE not true

ifeq ($(LOCAL_MODULE_CLASS),APPS_)


else # LOCAL_MODULE_CLASS != APPS
ifneq ($(LOCAL_PREBUILT_STRIP_COMMENTS),)
$(built_module) : $(my_prebuilt_src_file)
	$(transform-prebuilt-to-target-strip-comments)
else
$(built_module) : $(my_prebuilt_src_file) | $(ACP)
	$(transform-prebuilt-to-target)
ifneq ($(prebuilt_module_is_a_library),)
  ifneq ($(LOCAL_IS_HOST_MODULE),)
	$(transform-host-ranlib-copy-hack)
  else
	$(transform-ranlib-copy-hack)
  endif
endif
endif
endif # LOCAL_MODULE_CLASS != APPS

ifeq ($(LOCAL_IS_HOST_MODULE)$(LOCAL_MODULE_CLASS),JAVA_LIBRARIES)
# for target java libraries, the LOCAL_BUILT_MODULE is in a product-specific dir,
# while the deps should be in the common dir, so we make a copy in the common dir.
# For nonstatic library, $(common_javalib_jar) is the dependency file,
# while $(common_classes_jar) is used to link.
common_classes_jar := $(intermediates.COMMON)/classes.jar
common_javalib_jar := $(intermediates.COMMON)/javalib.jar

$(common_classes_jar) $(common_javalib_jar): PRIVATE_MODULE := $(LOCAL_MODULE)

ifneq ($(filter %.aar, $(my_prebuilt_src_file)),)
# This is .aar file, archive of classes.jar and Android resources.
my_src_jar := $(intermediates.COMMON)/aar/classes.jar

$(my_src_jar) : $(my_prebuilt_src_file)
	$(hide) rm -rf $(dir $@) && mkdir -p $(dir $@)
	$(hide) unzip -qo -d $(dir $@) $<
	# Make sure the extracted classes.jar has a new timestamp.
	$(hide) touch $@

else
# This is jar file.
my_src_jar := $(my_prebuilt_src_file)
endif
$(common_classes_jar) : $(my_src_jar) | $(ACP)
	$(transform-prebuilt-to-target)

$(common_javalib_jar) : $(common_classes_jar) | $(ACP)
	$(transform-prebuilt-to-target)

# make sure the classes.jar and javalib.jar are built before $(LOCAL_BUILT_MODULE)
$(built_module) : $(common_javalib_jar)
endif # TARGET JAVA_LIBRARIES

$(built_module) : $(LOCAL_ADDITIONAL_DEPENDENCIES)

my_prebuilt_src_file :=
