# ESP-IDF patches

Every `*.diff` here is applied by `build.sh` right after the ESP-IDF tree is
resolved, with `git apply --3way` from the root of `$IDF_PATH`. This covers both
normal builds and `-s` builds (which skip `install-esp-idf.sh`).

These are fixes the Arduino core needs before they reach the pinned ESP-IDF. Drop
a file once the fix is merged and the pin moves; forgetting to is not fatal,
because `git apply --3way` treats a patch that is already in the tree as a no-op.

## Patches

| File | Why it is here |
| --- | --- |
| `bluedroid_le_audio_iso_gatt.diff` | Bluedroid LE Audio: publish the ACL to the ISO host at GATTC connect, complete CIS channels when the ACL is lost, wait for service deletion, serve GATTS requests from the adapter-created table, and report a clean end of discovery for a characteristic without descriptors. |
| `nimble_le_audio_lifecycle_discovery.diff` | NimBLE LE Audio: teardown ordering for callbacks and the host mutex, service and subscription state reset between sessions, host-lock guarding, ISO callback cleanup on failure, errno preservation in the PACS API, and clean end of discovery without descriptors. |
| `protocomm_nimble_ext_adv.diff` | NimBLE protocomm: use the extended advertising APIs when `CONFIG_BT_NIMBLE_EXT_ADV` is enabled. The legacy `ble_gap_adv_set_fields()` is compiled out in that configuration, so WiFiProv/network provisioning previously failed with `Error setting advertisement data; rc = 8` (`BLE_HS_ENOTSUP`). |

To refresh a patch that no longer applies:

```bash
cd "$IDF_PATH"
git checkout -- . && git status
git apply --3way ../../../patches/idf/<name>.diff   # resolve conflicts
git diff > ../../../patches/idf/<name>.diff
```

The patches are generated against the pinned commit, so they apply cleanly there.
On a drifted tree they fall back to a three-way merge.
