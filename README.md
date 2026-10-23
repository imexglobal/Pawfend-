# PetNeighbor

Neighborhood pet care (멍냥이웃). The brand package is Pawfend. Publisher: IMEX Global.

The app is a static web app in this folder, plus Capacitor projects in `ios/` and `android/` (app id `com.imexglobalintl.petneighbor`).

- `SETUP.md` — connect Supabase so accounts, pets and chat leave demo mode.
- `LAUNCH.md` — store builds, signing, and the App Store / Play listing text.
- `privacy.html`, `terms.html`, `support.html` — what the app collects, the terms, and how to delete an account.
- `LEGAL_NOTES.md` — draft research for a Korean lawyer. Not legal advice. Review it before the next store binary.

`config.js` is empty on purpose. Until it has a Supabase URL and anon key, the app runs as a demo on the device. Do not commit service-role keys, VAPID private keys, or Android keystores.
