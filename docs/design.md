# Webmail Android Client — Design

**Date:** 2026-08-07 · **Status:** Design approved-pending-Ibukun · **Owner:** ibukun_thedatadruid

## Problem

Customers on cPanel-hosted email can't reliably use the Gmail app to fetch their
mail. They need a simple Android client: new-mail notifications, read, compose,
send — pre-configured so a non-technical customer just enters email + password.

## Feasibility

Fully possible. cPanel email is standard Dovecot (IMAP) + Exim (SMTP):

- **IMAP:** `mail.<domain>` port 993, SSL — read, folders, search, sent-folder append
- **SMTP:** `mail.<domain>` port 587 STARTTLS (fall back 465 SSL) — send
- cPanel's naming conventions make **auto-discovery** easy: user types
  `name@domain.com`, app tries `mail.domain.com` → done. No OAuth, no API keys.

## Architecture — three components

```
[Flutter Android app] ←IMAP/SMTP→ [customer's cPanel server]
        ↑ FCM push
[Push bridge on Hetzner] ←IMAP IDLE→ [customer's cPanel server]
```

### 1. Flutter app (the client)

- **Stack:** Flutter + `enough_mail` (IMAP/SMTP/MIME in pure Dart, maintained),
  `drift` (offline message cache), `flutter_secure_storage` (credentials in
  Android Keystore), `firebase_messaging` + `flutter_local_notifications`,
  `flutter_widget_from_html` for HTML mail bodies.
- Multi-account. Credentials never leave the device except to the push bridge
  (see below).
- Light default + complete dark-mode toggle (house HARD rule).

### 2. Push bridge (the hard part, solved server-side)

IMAP has no mobile push. Three options considered:

| Option | Verdict |
|---|---|
| IMAP IDLE in a foreground service on-device | Rejected — Tecno/Infinix/itel/Xiaomi battery killers murder it; this is exactly why K-9/FairEmail notifications are flaky on Nigerian devices |
| WorkManager polling | Fallback only — 15-min minimum interval, "notifications" up to 15 min late |
| **Server-side push bridge → FCM** | **Chosen** — small daemon on the Hetzner box holds one IMAP IDLE connection per registered mailbox; on new mail it fires a **data-only FCM ping** ("check account X"). App wakes, fetches over IMAP, shows the notification locally. |

Key property: **no mail content ever passes through FCM/Google** — the push is
just a wake-up signal. Message bodies go device↔cPanel directly.

- **Implementation:** Python `asyncio` + `aioimaplib`, supervisor-managed on
  46.62.175.112, small Django admin for account/device registry.
- **Threat surface (named up front):** the bridge stores IMAP credentials for
  every registered mailbox. Controls: field-level encryption at rest (Fernet,
  key in env), HTTPS-only registration API, per-device revocation, audit log of
  registrations/removals, no credential ever logged. This is the riskiest
  component — it gets the security budget.
- Bridge outage degrades gracefully: app falls back to WorkManager polling, so
  mail still arrives, just slower.

### 3. Onboarding / provisioning

- v1: auto-discovery from the email domain (cPanel conventions), manual
  override screen for edge cases.
- Later: per-customer preload (QR code or config link) for zero-typing setup.

## Scope

**MVP (phase 1):** add account (auto-discover) · inbox list + read ·
compose/reply/forward · attachments (view + send) · new-mail notifications via
bridge · multi-account · sent-folder append · light/dark themes.

**Phase 2:** full folder tree, drafts sync, search (server-side IMAP SEARCH),
signatures, swipe actions, per-customer branding.

**Not building:** iOS (later, Flutter makes it cheap), PGP/S-MIME, calendar/
contacts sync, webmail UI.

## Effort (count-the-cost)

- Flutter MVP: ~3–4 weeks of sessions. Email clients are deceptively big —
  MIME edge cases, HTML rendering, encodings — `enough_mail` absorbs most of it.
- Push bridge: 3–4 days including hardening.
- Ongoing: bridge is a new always-on service on the box — monitoring + one more
  supervisor entry.

## Commercial posture

One branded app ("all customers, one app"), paid — bundled into hosting/support
plans or a flat per-mailbox fee. No free tier. White-label per-client builds are
a phase-3 upsell, not MVP.

## Honest alternative (rejected, but on record)

FairEmail / Thunderbird Android already speak IMAP to cPanel. Rejected because:
generic setup confuses non-technical customers, no branding, notifications
unreliable on the cheap-Android battery killers our customers actually own, and
zero revenue. The push bridge + zero-config onboarding is the actual product.

## Open decisions for Ibukun

1. App name/brand (Data Druid Mail? per your product line?)
2. Distribution: Play Store vs direct APK to customers (Play recommended;
   needs data-safety form)
3. Project location — `Desktop\apps\webmail` violates the no-Desktop-writes
   rule; propose `C:\Users\USER\projects\webmail` or similar before scaffolding.
