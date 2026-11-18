# TinyUSB patches

Every `*.diff` here is applied by `tools/update-components.sh` right after TinyUSB
is cloned or pulled, with `git apply` from the root of
`components/arduino_tinyusb/tinyusb`.

These are fixes the Arduino core needs before they reach upstream TinyUSB. Drop a
file once the fix is available upstream and a normal update brings it in on its
own. Forgetting to is not fatal: a patch whose fix is already in the tree is
detected and skipped, while a patch that neither applies nor is present is stale
and does stop the build — refresh it by hand.

The clone is treated as build output: `update-components.sh` resets and cleans it
before pulling, so anything edited there by hand is lost on the next build. Change
the patch, not the clone. To refresh a patch that no longer applies:

```bash
cd components/arduino_tinyusb/tinyusb
git checkout -- . && git pull --ff-only
git apply --3way ../../../patches/tinyusb/<name>.diff   # resolve conflicts
git diff -- src > ../../../patches/tinyusb/<name>.diff
```

## Patches

None at the moment.
