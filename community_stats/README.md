# ShiaVerse — Community Stats (privacy-safe)

This folder lives on the **main** branch and is the public record behind the
counters shown at the end of **Settings** in the ShiaVerse app:

- `stats.json` — aggregate public counters every user can see in the app:
  `total_installs` (how many devices ever installed ShiaVerse),
  `active_users` (devices that have not uninstalled / are still active),
  `global_zikr_total` (total zikr counted through the app's Tasbeeh by all users),
  and `updated_at`.
- `installs/` — one tiny anonymous line/file per install, in the form:
  `SV-XXXXXX | installed: YYYY-MM-DD | last_active: YYYY-MM-DD | status: active`
  Nothing else. **No** name, phone number, email, location, IP or device model
  is ever recorded — privacy is not harmed.

## How it works without a server
1. On first launch the app creates one random anonymous ID (e.g. `SV-8F3K2Q`)
   and stores only that ID + install date + last-active date **on the device**.
2. Whenever the device is online (for example when downloading books), the app
   reads this public `stats.json` and shows the totals in Settings.
3. Maintainers periodically add the anonymous install receipts to `installs/`,
   recount `active` vs total lines, add reported lifetime zikr totals to
   `global_zikr_total`, and commit the updated `stats.json` to `main`.
   The app then shows the new public totals to every user.

Use `python3 scripts/update_community_stats.py` to recount this folder and
rewrite `stats.json` automatically.
