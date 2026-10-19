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
mouse and keyboard, say — sit behind one full-speed hub. This file is the source changes
from [hathach/tinyusb#3864](https://github.com/hathach/tinyusb/pull/3864) at `ca49b6346`,
rebased onto current TinyUSB master. Only the DWC2 change is specific to these chips; the
`usbh.c` / `hid_host.c` pieces are missing recovery paths that leave any host deaf after
one failed transfer. Delete this file once #3864 merges (see
[espressif/esp32-arduino-lib-builder#404](https://github.com/espressif/esp32-arduino-lib-builder/pull/404)).

- **`hcd_dwc2.c`** — the core cannot run two preamble transactions in the same 1 ms
  frame; it clears `HPRT.PENA` and the whole bus goes down. Low-speed channel starts are
  spaced one per frame without busy-waiting in ISR context: a busy frame parks the channel
  and SOF replays the start. ESP-IDF's own DWC host driver handles the same limit with an
  extra delay for low-speed devices from the ISR (espressif/esp-idf#15683). A port the core
  disables on its own posts attach so the existing handler tears down the stale tree and
  enumerates again.
- **`usbh.c`** — nothing retries enumeration of the root port, so one failed attach left
  the host dead until reboot. Re-post the attach up to three times while the port still
  reports a connection. `tuh_umount_cb()` runs only after `tuh_mount_cb()`. A whole
  roothub-port removal closes mid-enumeration `dev0`.
- **`hid_host.c`** — `tuh_hid_umount_cb()` only for an interface that reached
  `tuh_hid_mount_cb()`.
