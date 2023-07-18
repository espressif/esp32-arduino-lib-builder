/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2019 Ha Thach (tinyusb.org),
 * Additions Copyright (c) 2020, Espressif Systems (Shanghai) PTE LTD
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#pragma once
#include "tusb_option.h"
#include "sdkconfig.h"

#ifdef __cplusplus
extern "C" {
#endif

/*         */
/* KCONFIG */
/*         */

#ifndef CONFIG_TINYUSB_CDC_ENABLED
#   define CONFIG_TINYUSB_CDC_ENABLED 0
#endif

#ifndef CONFIG_TINYUSB_MSC_ENABLED
#   define CONFIG_TINYUSB_MSC_ENABLED 0
#endif

#ifndef CONFIG_TINYUSB_HID_ENABLED
#   define CONFIG_TINYUSB_HID_ENABLED 0
#endif

#ifndef CONFIG_TINYUSB_MIDI_ENABLED
#   define CONFIG_TINYUSB_MIDI_ENABLED 0
#endif

#ifndef CONFIG_TINYUSB_VIDEO_ENABLED
#   define CONFIG_TINYUSB_VIDEO_ENABLED 0
#endif

#ifndef CONFIG_TINYUSB_CUSTOM_CLASS_ENABLED
#   define CONFIG_TINYUSB_CUSTOM_CLASS_ENABLED 0
#endif

#ifndef CONFIG_TINYUSB_DFU_RT_ENABLED
#   define CONFIG_TINYUSB_DFU_RT_ENABLED 0
#endif

#ifndef CONFIG_TINYUSB_DFU_ENABLED
#   define CONFIG_TINYUSB_DFU_ENABLED 0
#endif

#ifndef CONFIG_TINYUSB_VENDOR_ENABLED
#   define CONFIG_TINYUSB_VENDOR_ENABLED 0
#endif

/*                      */
/* COMMON CONFIGURATION */
/*                      */

#define CFG_TUSB_MCU				OPT_MCU_ESP32S2
#define CFG_TUSB_RHPORT0_MODE       OPT_MODE_DEVICE
#define CFG_TUSB_OS                 OPT_OS_FREERTOS

/* USB DMA on some MCUs can only access a specific SRAM region with restriction on alignment.
 * Tinyusb use follows macros to declare transferring memory so that they can be put
 * into those specific section.
 * e.g
 * - CFG_TUSB_MEM SECTION : __attribute__ (( section(".usb_ram") ))
 * - CFG_TUSB_MEM_ALIGN   : __attribute__ ((aligned(4)))
 */
#ifndef CFG_TUSB_MEM_SECTION
#   define CFG_TUSB_MEM_SECTION
#endif

#ifndef CFG_TUSB_MEM_ALIGN
#   define CFG_TUSB_MEM_ALIGN       TU_ATTR_ALIGNED(4)
#endif

/*                      */
/* DRIVER CONFIGURATION */
/*                      */

#define CFG_TUD_MAINTASK_SIZE 		4096
#define CFG_TUD_ENDOINT0_SIZE 		64

// Enabled Drivers
#define CFG_TUD_CDC 				CONFIG_TINYUSB_CDC_ENABLED
#define CFG_TUD_MSC 				CONFIG_TINYUSB_MSC_ENABLED
#define CFG_TUD_HID 				CONFIG_TINYUSB_HID_ENABLED
#define CFG_TUD_MIDI 				CONFIG_TINYUSB_MIDI_ENABLED
#define CFG_TUD_VIDEO               CONFIG_TINYUSB_VIDEO_ENABLED
#define CFG_TUD_CUSTOM_CLASS 		CONFIG_TINYUSB_CUSTOM_CLASS_ENABLED
#define CFG_TUD_DFU_RUNTIME			CONFIG_TINYUSB_DFU_RT_ENABLED
#define CFG_TUD_DFU					CONFIG_TINYUSB_DFU_ENABLED
#define CFG_TUD_VENDOR 				CONFIG_TINYUSB_VENDOR_ENABLED

// CDC FIFO size of TX and RX
#define CFG_TUD_CDC_RX_BUFSIZE 		CONFIG_TINYUSB_CDC_RX_BUFSIZE
#define CFG_TUD_CDC_TX_BUFSIZE 		CONFIG_TINYUSB_CDC_TX_BUFSIZE

// MSC Buffer size of Device Mass storage:
#define CFG_TUD_MSC_BUFSIZE 		CONFIG_TINYUSB_MSC_BUFSIZE

// HID buffer size Should be sufficient to hold ID (if any) + Data
#define CFG_TUD_HID_BUFSIZE 		CONFIG_TINYUSB_HID_BUFSIZE

// MIDI FIFO size of TX and RX
#define CFG_TUD_MIDI_RX_BUFSIZE		CONFIG_TINYUSB_MIDI_RX_BUFSIZE
#define CFG_TUD_MIDI_TX_BUFSIZE		CONFIG_TINYUSB_MIDI_TX_BUFSIZE

// The number of video streaming interfaces and  endpoint size
#define CFG_TUD_VIDEO_STREAMING     CONFIG_TINYUSB_VIDEO_STREAMING_IFS
#define CFG_TUD_VIDEO_STREAMING_EP_BUFSIZE  CONFIG_TINYUSB_VIDEO_STREAMING_BUFSIZE

// DFU buffer size
#define CFG_TUD_DFU_XFER_BUFSIZE	CONFIG_TINYUSB_DFU_BUFSIZE

// VENDOR FIFO size of TX and RX
#define CFG_TUD_VENDOR_RX_BUFSIZE 	CONFIG_TINYUSB_VENDOR_RX_BUFSIZE
#define CFG_TUD_VENDOR_TX_BUFSIZE 	CONFIG_TINYUSB_VENDOR_TX_BUFSIZE

#ifdef __cplusplus
}
#endif
