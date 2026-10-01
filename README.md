# Student Comparison — PSP vs UDISE

Native Android Flutter app for comparing PSP and UDISE student records.

## Android

- Import PSP and UDISE JSON data.
- Compare and filter student records.
- Review mismatches and add remarks.
- Export comparison data and use the native SQLite database features.
- Student data stays in the app's configured local database; it is not uploaded to a web server.

The Flutter Web app, legacy web implementation, browser database adapter, and GitHub Pages deployment workflow have been removed. Android builds continue through `.github/workflows/android.yml`.
