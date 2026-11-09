# LinkRouter v1.0.0-beta.1

First public developer preview of LinkRouter, a native macOS menu-bar link handoff utility.

## Download and install

- [Download `LinkRouter-macOS-arm64.zip`](https://github.com/himanpatidar/LinkRouter/raw/refs/heads/main/downloads/LinkRouter-macOS-arm64.zip), unzip, and move `LinkRouter.app` to `/Applications`. A SHA-256 checksum is provided in `downloads/SHA256SUMS`.
- Requires an Apple Silicon Mac and macOS 14 or later.
- This build is ad-hoc signed, **not notarized by Apple**. macOS may block first launch. Review [Apple's guidance](https://support.apple.com/en-us/102445) before deciding whether to allow the specific app; managed Macs may not allow this.
- No Apple Developer membership is needed to try building from source.

## Included

- Floating link picker with number shortcuts, arrows, Return, Escape, and Copy.
- Chrome, Brave, Edge, and Chromium profile discovery, plus supported whole-browser destinations.
- Conservative local URL cleanup for known redirect wrappers and common tracking parameters.
- Gmail compose destinations, supported mail apps, and Copy email address.
- Explicitly remembered website, email-domain, and available source-app rules.
- Onboarding, settings, SQLite configuration, and an in-memory demo workspace.

## Known limitations

- Gmail discovery uses local account hints, not live session verification. Check the sender in Gmail.
- Option-click did not force the picker in an automated Slack test. Use Ask every time or the clipboard-routing command for dependable picker testing.
- Source-app identification depends on metadata supplied by macOS and the sending app.
- Safari/Firefox internal profile selection, automatic updates, and opaque redirect expansion are not included.
- Intel and wider macOS/browser compatibility testing remain outstanding.

Core validation: 27 automated core tests and 11 native UI smoke checks passed on the development Mac. These do not replace testing on other Macs or browser/account combinations.

Please use GitHub Issues for feedback. See `docs/BETA-TESTING.md` for test steps and information to omit from reports.
