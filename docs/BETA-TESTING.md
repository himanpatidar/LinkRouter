# LinkRouter beta testing

This developer preview is ad-hoc signed, not notarized, and intended for early feedback. The downloadable build supports Apple Silicon and requires macOS 14 or later. Browser/account data and normal link processing stay local; the app does not upload crash reports or browsing history.

## Quick test

1. Install the app in `/Applications` and finish setup. In General, use **Ask every time** for unmatched web links if you want to test the picker.
2. Click an existing web link in Slack, Mail, or Notes. Check the picker domain and choose the browser/profile you intend.
3. Confirm that the destination opens in the actual selected browser profile, not just that the app reports a successful launch.
4. Choose a number from 1–5 or navigate with arrows and Return. Check that Escape dismisses the picker and C copies the cleaned link.
5. Select Remember with a website scope. Click another link on that domain and verify that it routes automatically. Inspect or delete your test rule afterward.
6. Test a tracking URL such as `https://example.com/?utm_source=beta&utm_medium=email#keep`. Check that cleanup removes the tracking parameters and keeps `#keep`.
7. For email, use `mailto:hello@example.com?subject=LinkRouter%20test&body=Hello%0AWorld`. Check the recipient, subject, body, and Gmail sender. There is no need to send the email.

## Known issues and boundaries

- Option-click did not force the picker during an automated Slack test. Modifier state at URL delivery may differ from modifier state at the original click. Please report manual reproduction results.
- A Gmail account listed by LinkRouter may be signed out or have stale metadata. Confirm the sender inside Gmail before sending anything.
- macOS may not identify the original source application. This affects app rules, not website rules.
- Changing or deleting browser profiles can invalidate saved destinations. LinkRouter should offer another destination or Copy when launching fails.
- The app does not have automatic updates. Quit it before installing a newer build.

## Reporting a problem

Open a GitHub issue with:

- Your macOS version and whether the Mac is Apple Silicon or Intel.
- Browser name/version and the source app (for example, Slack).
- Whether the browser was already running.
- What you expected and what happened.
- Reproduction steps using a public, harmless URL whenever possible.

Do not attach your browser Preferences, Local State, SQLite settings file, private link contents, passwords, cookies, or tokens. Crop or redact account addresses and company information from screenshots. A report with a synthetic URL is usually enough.

## Returning to your previous setup

Choose another default browser in macOS System Settings before quitting or removing LinkRouter. If you enabled email routing, choose your preferred default email reader as well. Rules and preferences are stored in `~/Library/Application Support/LinkRouter/settings.sqlite`; moving the app to Trash does not delete those settings.
