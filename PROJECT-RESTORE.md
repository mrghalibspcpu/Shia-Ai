# Restoring the ShiaVerse project archive

`deliverables/ShiaVerse-project-1.17.0.zip` is a source-and-data archive, not an APK and not a copy of the Git history. It contains the Flutter app, Android/native configuration, GitHub Actions workflows, scripts and tests, bundled visual/audio assets, and the checked-in SQLite databases and database bundle.

## Restore and build

1. Extract the ZIP into a new folder; it creates a `Shia-Ai/` directory.
2. Install Flutter (3.27 or newer), Java 17, and the Android SDK.
3. From `Shia-Ai/app/`, run `flutter pub get`.
4. The app can download its SQLite databases on demand. To build an APK with the databases embedded instead, return to `Shia-Ai/` and run:

   ```sh
   python3 scripts/prepare_databases.py --output app/assets/databases
   ```

5. Build from `Shia-Ai/app/` with `flutter build apk --release`.

The ZIP intentionally excludes `.git`, machine-specific Flutter/Gradle caches, generated build outputs, and owner-specific signing secrets. The repository's public CI signing key and its documentation are included; a production release key must be supplied separately through the documented Android signing environment variables.
