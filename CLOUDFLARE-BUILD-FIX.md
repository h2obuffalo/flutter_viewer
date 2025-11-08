# Cloudflare Pages Build Command Fix

## Current Issue
Cloudflare Pages is running `build-pages.sh` but it needs to be `bash build-pages.sh`

## Solution

Update your Cloudflare Pages build command to:

```bash
bash build-pages.sh
```

Or use the inline version (no script file needed):

```bash
flutter pub get && flutter build web --release --base-href "/" && (cp web/_redirects build/web/_redirects 2>/dev/null || echo "/*    /index.html   200" > build/web/_redirects)
```

## Steps to Fix:

1. Go to Cloudflare Dashboard → Pages → flutter-viewer
2. Go to **Settings** → **Builds & deployments**
3. Update **Build command** to: `bash build-pages.sh`
4. Ensure **Build output directory** is: `build/web`
5. Click **Save**
6. Go to **Deployments** tab and click **Retry deployment**

The script is already in the repository and executable, it just needs the `bash` prefix in the command.
