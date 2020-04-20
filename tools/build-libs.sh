#!/bin/bash

#remove previous build
rm -rf ./out ./build

# ensure proper settings
$SED -i '/CONFIG_FLASHMODE_QIO/c\CONFIG_FLASHMODE_QIO=' ./sdkconfig
$SED -i '/CONFIG_FLASHMODE_QOUT/c\CONFIG_FLASHMODE_QOUT=' ./sdkconfig
$SED -i '/CONFIG_FLASHMODE_DIO/c\CONFIG_FLASHMODE_DIO=y' ./sdkconfig
$SED -i '/CONFIG_FLASHMODE_DOUT/c\CONFIG_FLASHMODE_DOUT=' ./sdkconfig

$SED -i '/CONFIG_ESP32_DEFAULT_CPU_FREQ_80/c\CONFIG_ESP32_DEFAULT_CPU_FREQ_80=' ./sdkconfig
$SED -i '/CONFIG_ESP32_DEFAULT_CPU_FREQ_160/c\CONFIG_ESP32_DEFAULT_CPU_FREQ_160=' ./sdkconfig
$SED -i '/CONFIG_ESP32_DEFAULT_CPU_FREQ_240/c\CONFIG_ESP32_DEFAULT_CPU_FREQ_240=y' ./sdkconfig
$SED -i '/CONFIG_ESP32_DEFAULT_CPU_FREQ_MHZ/c\CONFIG_ESP32_DEFAULT_CPU_FREQ_MHZ=240' ./sdkconfig

# make the example
make defconfig
make -j8 #fixes make issue where build fails in arduino core subfolder
make -j8 idf-libs || exit 1
