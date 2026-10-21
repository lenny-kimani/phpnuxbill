# Production deployment — configuration checklist

Repo: PHPNuxBill (Rofatech) — Docker + FreeRADIUS REST + MikroTik hotspot.

This is the ordered list to take the current setup to production on **Dockploy**
(deploy from GitHub) and on the MikroTik. Every item marked ✅ has been verified
in this session; 🔲 needs to be done by hand on the target system.

---

## 1. Docker / Dockploy

- ✅ `Dockerfile.production` (repo root) — production image: same proven PHP
  extension set, nginx config with stdout/stderr logging, PHP error logging to
  stderr, dev artifacts stripped (`staging-export`, `tests`, deploy scripts),
  `HEALTHCHECK`.
- ✅ `docker/phpnuxbill/nginx.production.conf` — prod site config.
- ✅ `docker/phpnuxbill/php.production.ini` — PHP overrides.
- 🔲 In Dockploy, set the **Dockerfile path** to `Dockerfile.production`
  (the root `Dockerfile` is the outdated upstream PHP 7.4/Apache artifact —
  do not use it; it has no cron and no `radclient`, so deauth and expiry
  sweeps silently never run).
- 🔲 Provide these **environment variables / secrets** (values from the local
  `.env` — never commit `.env`; it is gitignored):

  | Variable | Used by |
  |---|---|
  | `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` | `rofa-mysql` |
  | `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | `rofa-phpnuxbill` (config.php generated at boot) |
  | `RADIUS_DB_HOST/NAME/USER/PASSWORD` | `rofa-phpnuxbill`, optional (default to DB_*) |
  | `RADIUS_SECRET` | `rofa-freeradius` (clients.conf), `rofa-phpnuxbill` (PoD kicks), `rofa-coa` |
  | `PHPNUXBILL_URL` | `rofa-freeradius` REST `connect_uri` |
  | `TZ` | all (currently `Africa/Nairobi`) |

- 🔲 Verify `PHPNUXBILL_URL` is reachable **from the freeradius container**
  (it runs on the host network, so compose DNS names like `rofa-phpnuxbill`
  do not resolve there):
  `docker exec rofa-freeradius wget -qO- "$PHPNUXBILL_URL/radius.php"` must
  answer HTTP 401 with `Invalid Command` JSON.
- 🔲 `docker logs rofa-phpnuxbill` must show nginx access/error lines after
  the production build (log-to-stdout is a prod-only feature).

## 2. Secrets hygiene

- ✅ `.env` is gitignored / untracked — no secrets in GitHub.
- ✅ `config.php` is generated from environment variables by the entrypoint at
  boot and is gitignored — never hand-edit it inside the container (rebuilds
  wipe it).
- 🔲 On key rotation: update `RADIUS_SECRET` in Dockploy **and** on the
  MikroTik (`/radius` secret) at the same time, then redeploy.

## 3. Cloudflare tunnel / domain

- ✅ Callback forced to `https://` and `APP_URL` honors `X-Forwarded-Proto` /
  `CF-Visitor` (the original tunnel 301 bug is fixed).
- 🔲 Confirm Safaricom can reach
  `https://rofatech.sovika.xyz/?_route=callback/mpesa` (test from an external
  network: `curl https://rofatech.sovika.xyz/?_route=callback/mpesa` — expect
  HTTP 400 `INVALID CALLBACK`, which proves the endpoint is alive).

## 4. MikroTik (manual — nothing in this repo reaches the router)

- 🔲 **Upload `hotspot/`** to the router (README: *"put all File inside
  hotspot folder in Mikrotik, overwrite all"*) — `login.html` (bigger fonts,
  10 s M-Pesa redirect), `alogin.html` (persistent session status for
  authenticated users), `status.html`.
- 🔲 **`/radius incoming` enabled**, port `3799`, same secret — without it,
  Disconnect-Requests are ignored by the NAS (verified: packets are now sent
  to `192.168.1.2:3799` every cron run for stale sessions).
- 🔲 **Interim-Update** on the MikroTik RADIUS client (e.g. `00:01:00`) —
  makes `rad_acct` usage/sessiontime live, which drives the status-page data
  countdown, the data-cap enforcement, and the online list. If you leave it
  off, set `frrest_interim_update = 0` in admin settings (the stale-guard
  then marks rows Stop after 1 min with no packet, which only affects the
  online-status display).
- 🔲 Walled garden allows `rofatech.sovika.xyz` (and the hotspot host).
- 🔲 Hotspot server profile: HTTP PAP ✅ (already enabled), HTTP CHAP on.

## 5. Application settings (admin UI)

- 🔲 **Timezone is `Asia/Jakarta`** while PHP/MySQL run UTC and the host is
  EAT — set it to `Africa/Nairobi` (or the value you actually want displayed);
  the status page and invoice times render through it.
- M-Pesa: `mpesa_mode` (sandbox for tests → **production** for go-live),
  consumer key/secret, passkey, shortcode, business type, allowed IPs (only
  if you want to allow-list Safaricom callback IPs).
- Notifications: `user_notification_expired = none` (as set); Telegram
  webhook for system errors if desired.

## 6. Known good behaviors (verified)

- ✅ Callback URL is forced to `https://` (tunnel 301 fixed).
- ✅ Wait-page poll: "being processed" is **pending**, not failed — no more
  failure before the PIN is finished.
- ✅ Terminal failures carry the real cause (1037 timeout / 1032 cancelled /
  2001 wrong PIN) into the failed panel.
- ✅ Get-code re-checks Daraja for failed rows and falls back to any recently
  paid transaction for the phone.
- ✅ Cron auto-deauth sweep sends real Disconnect-Requests (verified live:
  `Sent Disconnect-Request … to 192.168.1.2:3799` for three stale sessions).
- ✅ Status countdown starts at router-session start, not at purchase.
- ✅ Session status persists on `alogin.html` for already-authenticated
  visitors (needs the MikroTik upload above).
- ✅ Unit suite: 35 tests / 83 assertions.

## 7. Monitoring / gotchas

- `cron.php` prints **PHP Time** and **MYSQL Time** every run — keep an eye on
  `/var/log/phpnuxbill-cron.log` if timestamps ever drift again (they were in
  sync at last check).
- Recurring `M-Pesa access token failed: Invalid JSON…` bursts = outbound
  DNS/curl blips, not credentials. The wait-page poll and cron re-try naturally;
  a token cache was prototyped and reverted — reintroduce only if the bursts
  grow persistent.
- The MySQL `NOW()` clock and the PHP clock are both UTC today; if they ever
  disagree, prefer comparisons written in PHP (`date()`) — the deauth sweep
  already does.
