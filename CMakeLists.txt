# The following lines of boilerplate have to be in your project's
# CMakeLists in this exact order for cmake to work correctly
cmake_minimum_required(VERSION 3.5)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(arduino-lib-builder)

idf_build_get_property(elf EXECUTABLE GENERATOR_EXPRESSION)

add_custom_command(
	OUTPUT "idf_libs" 
	COMMAND ${CMAKE_SOURCE_DIR}/tools/copy-libs.sh ${IDF_TARGET} "$ENV{CHIP_VARIANT}" "${CONFIG_LIB_BUILDER_FLASHMODE}" "${CONFIG_SPIRAM_MODE_OCT}" "${CONFIG_IDF_TARGET_ARCH_XTENSA}"
	DEPENDS ${elf}
	WORKING_DIRECTORY ${CMAKE_SOURCE_DIR} 
	VERBATIM
)
add_custom_target(idf-libs DEPENDS "idf_libs")

add_custom_command(
	OUTPUT "copy_bootloader" 
	COMMAND ${CMAKE_SOURCE_DIR}/tools/copy-bootloader.sh ${IDF_TARGET} "$ENV{CHIP_VARIANT}" "${CONFIG_LIB_BUILDER_FLASHMODE}" "${CONFIG_LIB_BUILDER_FLASHFREQ}"
	DEPENDS bootloader 
	WORKING_DIRECTORY ${CMAKE_SOURCE_DIR} 
	VERBATIM
)
add_custom_target(copy-bootloader DEPENDS "copy_bootloader")

add_custom_command(
	OUTPUT "mem_variant" 
	COMMAND ${CMAKE_SOURCE_DIR}/tools/copy-mem-variant.sh ${IDF_TARGET} "$ENV{CHIP_VARIANT}" "${CONFIG_LIB_BUILDER_FLASHMODE}" "${CONFIG_SPIRAM_MODE_OCT}" "${CONFIG_IDF_TARGET_ARCH_XTENSA}"
	DEPENDS ${elf}
	WORKING_DIRECTORY ${CMAKE_SOURCE_DIR} 
	VERBATIM
)
add_custom_target(mem-variant DEPENDS "mem_variant")

add_custom_command(
	OUTPUT "bt_variant"
	COMMAND ${CMAKE_SOURCE_DIR}/tools/copy-bt-variant.sh ${IDF_TARGET} "$ENV{CHIP_VARIANT}" "${CONFIG_LIB_BUILDER_FLASHMODE}" "${CONFIG_SPIRAM_MODE_OCT}" "${CONFIG_IDF_TARGET_ARCH_XTENSA}"
	DEPENDS ${elf}
	WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
	VERBATIM
)
add_custom_target(bt-variant DEPENDS "bt_variant")

idf_build_set_property(COMPILE_DEFINITIONS "-DESP32_ARDUINO_LIB_BUILDER" APPEND)

##################
### ESP Matter ###
##################
idf_build_set_property(CXX_COMPILE_OPTIONS "-std=gnu++2a;-DCHIP_HAVE_CONFIG_H" APPEND)

# esp_matter is not pulled in for all targets (see main/idf_component.yml rules).
idf_build_get_property(build_components BUILD_COMPONENTS)
if("espressif__esp_matter" IN_LIST build_components)
  # GCC 14 + C++20: ClosureControl structs need same-type operator== for std::optional.
  file(TO_CMAKE_PATH "${CMAKE_SOURCE_DIR}/patches/matter_closure_patch.h" MATTER_CLOSURE_PATCH_H)
  string(REPLACE "\\" "/" MATTER_CLOSURE_PATCH_H "${MATTER_CLOSURE_PATCH_H}")
  idf_component_get_property(esp_matter_lib espressif__esp_matter COMPONENT_LIB)
  target_compile_options(${esp_matter_lib} PRIVATE
      "SHELL:-include \"${MATTER_CLOSURE_PATCH_H}\"")
endif()
