# TinyUSB patches

Every `*.diff` here is applied by `tools/update-components.sh` right after TinyUSB is
cloned or pulled, with `git apply` from the root of `components/arduino_tinyusb/tinyusb`.

These are fixes the Arduino core needs before they reach TinyUSB master. Each one should
have an upstream pull request open; delete the file once that PR is merged and the next
pull brings the change in on its own.

The clone is treated as build output — `update-components.sh` runs `git checkout -- .`
in it before pulling, so anything edited there by hand is lost on the next build. Change
the patch, not the clone. To refresh a patch that no longer applies:

```bash
cd components/arduino_tinyusb/tinyusb
git checkout -- . && git pull --ff-only
git apply --3way ../../../patches/tinyusb/<name>.diff   # resolve conflicts
git diff -- src > ../../../patches/tinyusb/<name>.diff
```

## 0001-host-esp32s2s3-lowspeed-hub.diff

USB host on ESP32-S2/S3 (full-speed DWC2) dies when two low-speed devices — a wired
mouse and keyboard, say — sit behind one full-speed hub. Written against `1eb216ed0`
(v0.21.0-165). Three changes:

- **`hcd_dwc2.c`** — the core cannot run two preamble transactions in the same 1 ms
  frame; it clears `HPRT.PENA` and the whole bus goes down. Low-speed channel starts are
  now spaced one per frame, on every path that enables such a channel: IN tokens,
  the DMA OUT branch, and the slave-mode OUT branch that S2/S3 actually take, since
  those parts have no host DMA. Periodic INs armed from the SOF interrupt are deferred
  a frame rather than spun on. ESP-IDF works around the same limit by padding every
  low-speed control stage with `esp_rom_delay_us(1000)` (espressif/esp-idf#15683).
- **`usbh.c`** — nothing retries enumeration of the root port, so one failed attach left
  the host dead until reboot. Re-post the attach up to three times while the port still
  reports a connection.
- **`hub.c` / `hub.h`** — every re-arm of a hub's status endpoint is one-shot, so a
  single failure makes the hub deaf to attach and detach for good. Added a watchdog that
  re-arms an idle status endpoint, gated on an otherwise quiet bus because the hub
  answers a status IN with a control chain that would collide with enumeration. The
  removal path aborts a pending status transfer without re-arming it in the same breath:
  `hcd_edpt_abort_xfer()` only requests the halt, and the channel is released later from
  the interrupt.
