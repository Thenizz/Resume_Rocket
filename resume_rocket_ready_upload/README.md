# ResumeRocket — Ready-to-upload Starter (no-cost)

This repo contains a minimal Flutter starter app for **ResumeRocket** (local resume editor + PDF export).
To ensure GitHub Actions can build the APK without a full Android folder included, the workflow will run `flutter create .` before the build.

## Steps to use (no coding required)

1. Download this zip and extract all files.
2. Create a new GitHub repository and upload **all extracted files and folders** (including `.github`).
3. In your repo on GitHub: Actions → select `flutter-build` → Run workflow (or push to `main` branch).
4. Wait ~5-8 minutes; the workflow will produce an artifact named `app-release.apk`.
5. Download the artifact and install on your Android device.

## Notes
- Everything in this starter is free to use locally. Real subscriptions or AI APIs require external accounts if you enable them later.
- If the Actions workflow fails, open the run logs and copy the error text here — I'll help debug.

