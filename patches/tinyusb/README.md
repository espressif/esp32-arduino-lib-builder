# TinyUSB patches

Every `*.diff` here is applied by `tools/update-components.sh` right after TinyUSB is
cloned or pulled, with `git apply` from the root of `components/arduino_tinyusb/tinyusb`.

These are fixes the Arduino core needs before they reach TinyUSB master. Each one should
have an upstream pull request open; delete the file once that PR is merged and the next
pull brings the change in on its own. Forgetting to is not fatal: a patch whose fix is
already in the tree is detected and skipped. A patch that neither applies nor is present
is a stale one, and that does stop the build — it has to be refreshed by hand, since
guessing at a half-landed fix is worse than saying so.

The clone is treated as build output — `update-components.sh` resets and cleans it before
pulling, so anything edited there by hand is lost on the next build. Change the patch, not
the clone. To refresh a patch that no longer applies:

```bash
cd components/arduino_tinyusb/tinyusb
git checkout -- . && git pull --ff-only
git apply --3way ../../../patches/tinyusb/<name>.diff   # resolve conflicts
git diff -- src > ../../../patches/tinyusb/<name>.diff
```

## 0001-host-esp32s2s3-lowspeed-hub.diff

USB host on ESP32-S2/S3 (full-speed DWC2) dies when two low-speed devices — a wired
mouse and keyboard, say — sit behind one full-speed hub. This file is the four commits
of hathach/tinyusb#3864 at `9db4010ed`, applied on top of current TinyUSB master
(which already includes #3815). Only the DWC2 change is specific to these chips; the
`usbh.c` pieces are missing recovery paths that leave any host deaf after one failed
transfer. Delete this file once #3864 merges.

- **`hcd_dwc2.c`** — the core cannot run two preamble transactions in the same 1 ms
  frame; it clears `HPRT.PENA` and the whole bus goes down. Low-speed channel starts are
  now spaced one per frame (`ls_frame_reserve`), on every path that enables such a
  channel: IN tokens, the DMA OUT branch, and the slave-mode OUT branch, which is what
  these builds take since host DMA is off by default. Periodic INs armed from the SOF
  interrupt are deferred a frame rather than spun on. ESP-IDF's own DWC host driver
  handles the same limit by applying an extra delay for low-speed devices from the ISR
  (espressif/esp-idf#15683). A port the core disables on its own — a babble or other
  port error — stops SOF, so no transfer on that bus can ever complete again. If the
  port is still connected and this IRQ is not already an attach detect, post attach so
  the existing handler tears down the stale tree and enumerates again.
- **`usbh.c`** — nothing retries enumeration of the root port, so one failed attach left
  the host dead until reboot. Re-post the attach up to three times while the port still
  reports a connection, with the retry budget belonging to one port at a time and handed
  back as soon as that attachment ends, however it ended. An attach that is tearing down
  what was already on the port is treated as a fresh start, not a retry of itself.
  `tuh_umount_cb()` is only called for a device that reached `tuh_mounted()`.
- **`usbh.c`** — a removal event for the whole roothub port did not close dev0 when the
  device was enumerating behind a downstream hub, leaving `enumerating_daddr` at 0 and
  every later attach deferred forever.

hathach/tinyusb#3815 is already on the tree this patch applies to, so there is no hub
watchdog here. That PR unjams the hub status transfer on device removal.
