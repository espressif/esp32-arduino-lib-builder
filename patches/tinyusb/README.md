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
mouse and keyboard, say — sit behind one full-speed hub. Written against `64d952c02`
(v0.21.0-289), upstream at hathach/tinyusb#3864, where it is four commits in this order.
Only the first is specific to these chips; the rest are missing recovery paths that leave
any host deaf after one failed transfer. This file also carries the fixes that came out of
review on that PR, which are not yet folded into its commits. Six changes:

- **`hcd_dwc2.c`** — the core cannot run two preamble transactions in the same 1 ms
  frame; it clears `HPRT.PENA` and the whole bus goes down. Low-speed channel starts are
  now spaced one per frame, on every path that enables such a channel: IN tokens,
  the DMA OUT branch, and the slave-mode OUT branch, which is what these builds take
  since host DMA is off by default. Periodic INs armed from the SOF interrupt are deferred
  a frame rather than spun on. ESP-IDF's own DWC host driver handles the same limit by
  applying an extra delay for low-speed devices from the ISR (espressif/esp-idf#15683).
  A port the core disables on its own — a babble or other port error — stops SOF, so no
  transfer on that bus can ever complete again; that case reached a commented-out
  `TU_ASSERT(false, )` and was silently ignored. It now posts an attach if something is
  still connected, so the port is reset and enumerated again, and a remove if not.
- **`usbh.c`** — nothing retries enumeration of the root port, so one failed attach left
  the host dead until reboot. Re-post the attach up to three times while the port still
  reports a connection, with the retry budget belonging to one port at a time and handed
  back as soon as that attachment ends, however it ended. dev0 is closed before each
  retry: the attach handler only does so while dev0 is the one enumerating, which is no
  longer true by then, and `hcd_edpt_open()` allocates rather than reuses, so every retry
  of an attempt that never reached `SET_ADDRESS` would otherwise leak an endpoint entry.
- **`usbh.c`** — a removal event for the whole roothub port did not close dev0 when the
  device was enumerating behind a downstream hub, leaving `enumerating_daddr` at 0 and
  every later attach deferred forever.
- **`hub.c` / `hub.h`** — *(temporary: drop this hunk once hathach/tinyusb#3815 merges,
  see below)* every re-arm of a hub's status endpoint is one-shot, so a
  single failure makes the hub deaf to attach and detach for good. Added a watchdog that
  re-arms an idle status endpoint, gated on an otherwise quiet bus because the hub
  answers a status IN with a control chain that would collide with enumeration. The
  removal path aborts a pending status transfer without re-arming it in the same breath:
  `hcd_edpt_abort_xfer()` only requests the halt, and the channel is released later from
  the interrupt. The watchdog also caps how long the host task may block, since
  `tuh_task()` otherwise waits forever and a deaf hub is exactly the case where no event
  arrives to wake it — but only while some hub's status endpoint is actually idle, so a
  healthy bus still sleeps as before.
- **`usbh.c`** — `tuh_umount_cb()` is now only called for a device that reached
  `tuh_mounted()`. Enumeration marks a device connected as soon as it has an address, so
  a failure after that point — or a retry of one — reported an unmount for a device the
  application had never been told about.
- **`usbh.c`** — an attach event tears down whatever was on its port first, which fails
  any in-flight enumeration, and that failure asked for a retry of the attach being
  handled right then: the retry later restarted a healthy enumeration and spent a budget
  entry. The teardown is flagged so it is treated as a fresh start instead. The host task
  also caps its wait only while the watchdog is allowed to run, since the deadline stays
  expired while the watchdog is gated and the cap would otherwise be zero every pass,
  spinning the task for as long as the bus stays busy.

### The hub watchdog goes away with hathach/tinyusb#3815

That PR reworks channel teardown and abort in `hcd_dwc2.c`, and with it the hub's status
transfer is no longer lost when a device is removed — which is the only thing the watchdog
recovers from. Tested by building #3815 with this patch rebased on top and the watchdog
compiled out: 15 connect/disconnect events on an S3, including three removals of a flash
drive and one after minutes of an idle bus, all reported. So the transfer was jammed by
the teardown rather than never re-armed, and the watchdog is worth carrying only for as
long as the patch is applied to a master that does not have #3815.

It stays here until then, because that is the tree this patch applies to. When #3815 lands,
drop the `hub.c` / `hub.h` hunks, the two call sites in `usbh.c`, and the wait cap that
exists to serve them.
