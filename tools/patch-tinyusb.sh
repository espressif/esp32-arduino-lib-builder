#!/bin/bash
mv components/arduino_tinyusb/src/dcd_dwc2.c components/arduino_tinyusb/src/dcd_dwc2.c.prev
cp components/arduino_tinyusb/tinyusb/src/portable/synopsys/dwc2/dcd_dwc2.c components/arduino_tinyusb/src/dcd_dwc2.c
patch -p1 -N -i components/arduino_tinyusb/patches/dcd_dwc2.patch
