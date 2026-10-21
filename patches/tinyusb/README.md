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

No patches are carried at the moment. The low-speed hub workaround for ESP32-S2/S3 was
dropped after [hathach/tinyusb#3864](https://github.com/hathach/tinyusb/pull/3864) landed
on TinyUSB master.
