# PSP–UDISE browser-only Web App

This branch contains a static, browser-only version of the student comparison UI for GitHub Pages. It does not require Termux, `npm start`, Express, or a hosted API.

## Data and privacy
- PSP and UDISE JSON files are processed in the browser; the app does not upload them to an API.
- Imported data and review remarks are saved in this browser's `localStorage`.
- Browser storage is device/browser-specific. It does not sync across devices and may be cleared by the browser.
- Use **Export Local Backup** before clearing browser data or changing devices.
- Do not commit student JSON files, SQLite databases, backups, or credentials to this repository.

## GitHub Pages
The `.github/workflows/npm-webapp-pages.yml` workflow deploys the `npm-webapp/` directory when changes are pushed to `npm-webapp`. The repository's Pages setting must allow deployment through GitHub Actions.

Expected URL:
https://techwithkaushik.github.io/student-comparison/

## Important implementation note
This is a client-side migration baseline. Its matching routine is implemented in the browser and should be validated against the previous Express/SQLite app using representative PSP/UDISE samples before relying on its results for official records. The previous server's matching thresholds and review behavior may not be identical yet.
