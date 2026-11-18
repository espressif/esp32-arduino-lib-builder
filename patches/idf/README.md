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
| `bluedroid_le_audio_iso_gatt.diff` | Bluedroid LE Audio: publish the ACL to the ISO host at GATTC connect, complete CIS channels when the ACL is lost, wait for service deletion, serve GATTS requests from the adapter-created table, report a clean end of discovery for a characteristic without descriptors, expose `bt_iso_big_tail_cb()` for BIG callback re-arming, check `BTM_GetNumAclLinks()` before `iso_disable_cis()` on deinit, downgrade `gatt_sr_find_i_rcb_by_app_id()`'s success trace from `ERROR` to `DEBUG`, silence the `ble_host_register_rx_iso_data_cb(NULL)` unregister printf, and mark `bluedroid/server.h` UUID string helpers `const char *`. |
| `le_audio_api_fixes.diff` | Shared `esp_ble_audio`: normalize TBS/CCP URI-scheme lists with an internal trailing `','` for `libble_audio`'s `uri_scheme_in_list()` while stripping it on ATT Read/Notify of `0x2BB6` per TBS v1.0 sec. 3.4; clean up registered profile callbacks on `esp_ble_audio_common_deinit()` (keeping duplicate registration in an active session an error, using mutable static callback slots for non-unregisterable profiles, and re-arming `bap_broadcast_sink`'s ISO BIG callback across re-init); and fix `const char *` `-Wdiscarded-qualifiers` warnings in `audio.h` and `init.c`. |
| `nimble_le_audio_lifecycle_discovery.diff` | NimBLE LE Audio: reset NimBLE's GATTS table in `bt_le_nimble_audio_init()` and propagate `-EBUSY` on active GAP/GATT state (logged at `WRN`: the Busy-guard probe is control flow, not a fault), teardown ordering for callbacks and the host mutex, service and subscription state reset between sessions, host-lock guarding, ISO callback cleanup on failure, errno preservation in the PACS API, clean end of discovery without descriptors, and idempotent GATT NRP remove after disconnect (duplicate complete is a no-op instead of `GattNrpNotFound`). |
| `protocomm_nimble_ext_adv.diff` | NimBLE protocomm: use the extended advertising APIs when `CONFIG_BT_NIMBLE_EXT_ADV` is enabled. The legacy `ble_gap_adv_set_fields()` is compiled out in that configuration, so WiFiProv/network provisioning previously failed with `Error setting advertisement data; rc = 8` (`BLE_HS_ENOTSUP`). |
| `bluedroid_btm_sec_free_dev_mitm.diff` | Bluedroid: clear `security_required` in `btm_sec_free_dev()`. `btm_ble_io_capabilities_req()` ORs `BTM_SEC_IN_MITM` from that field into every pairing request/response, so a record reused for the same peer (deferred bond delete racing a fast reconnect, or a lingering record the list removal skipped) would otherwise force MITM on a re-pairing whose application explicitly asked for none. `btm_ble_set_encryption()` re-arms whatever each new pairing or encryption actually needs. |

To refresh a patch that no longer applies:

```bash
cd "$IDF_PATH"
git checkout -- . && git status
git apply --3way ../../../patches/idf/<name>.diff   # resolve conflicts
git diff > ../../../patches/idf/<name>.diff
```

The patches are generated against the pinned commit, so they apply cleanly there.
On a drifted tree they fall back to a three-way merge.

## Error-propagation contract (for upstream review)

`esp_err_t` is `int`, and these wrappers propagate the underlying negative
errno instead of flattening to `ESP_FAIL` — but only where a caller must
branch on it:

- `esp_ble_audio_common_init()` returns `-EBUSY` when GAP/ACL state forbids
  the GATT reset, so callers can retry later instead of treating a busy host
  as a dead one. `ESP_OK` (0) still means success everywhere.
- The PACS setters return raw `err` so `-EALREADY` stays distinguishable
  (first-value-wins re-commit), instead of collapsing every failure mode.
- `*_register_cb()` keeps the old contract: any lib error (including a
  duplicate within an active session) surfaces as `ESP_FAIL`. The tracking
  tables only decide *deinit cleanup*, never success masking — a full table
  refuses with `-ENOMEM` before touching the lib, so no untracked
  registration can leak past deinit. Duplicate registration stays an error;
  idempotent teardown (e.g. NRP remove after disconnect) returns 0.
