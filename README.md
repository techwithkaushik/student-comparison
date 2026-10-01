# Student Comparison — PSP vs UDISE

Flutter app for comparing PSP and UDISE student records.

## Web app

The web build is deployed automatically to GitHub Pages from `main` by
`.github/workflows/pages.yml`.

- Select **Import PSP JSON** and **Import UDISE JSON** from the app menu.
- Compare and filter records, add remarks, and export comparison CSV or source JSON.
- On the web, student records are stored in the current browser using IndexedDB.
- JSON files are processed in the browser; the app does not upload them to GitHub or a backend server.
- Browser data is device/browser-specific. Clearing site data or using another browser/device can remove or make that data unavailable, so keep secure backups of your source files.

SQLite database-file import/export remains available in the Android app. On the web, use JSON and CSV export instead.

## Android

The Android build continues to use the native SQLite database implementation.
