# Flutter Web Deployment Guide

This guide covers deploying the Flutter web viewer to Cloudflare Pages (free hosting).

## Option 1: Cloudflare Pages Direct Integration (Recommended - Easiest)

Cloudflare Pages can build directly from your GitHub repository without needing GitHub Actions.

### Setup Steps:

1. **Go to Cloudflare Dashboard**
   - Navigate to [Cloudflare Dashboard](https://dash.cloudflare.com/)
   - Go to "Workers & Pages" → "Create application" → "Pages" → "Connect to Git"

2. **Connect GitHub Repository**
   - Select your repository: `h2obuffalo/webtorrent-livestream`
   - Authorize Cloudflare to access your repository

3. **Configure Build Settings**
   - **Project name**: `flutter-viewer` (or your preferred name)
   - **Production branch**: `main` (or `master`)
   - **Framework preset**: `None` (we'll use custom build)
   - **Build command**: 
     ```bash
     cd flutter_viewer && bash build.sh
     ```
     Or manually:
     ```bash
     cd flutter_viewer && flutter pub get && flutter build web --release --base-href "/" && cp web/_redirects build/web/_redirects || echo "/*    /index.html   200" > build/web/_redirects
     ```
   - **Build output directory**: `flutter_viewer/build/web`
   - **Root directory**: `/` (leave as default)

4. **Environment Variables** (if needed)
   - Add any environment variables your app needs
   - For now, none are required as the app uses runtime configuration

5. **Save and Deploy**
   - Click "Save and Deploy"
   - Cloudflare will build and deploy your app automatically
   - You'll get a URL like: `https://flutter-viewer.pages.dev`

### Custom Domain (Optional)

1. In Cloudflare Pages project settings, go to "Custom domains"
2. Add your domain (e.g., `viewer.yourdomain.com`)
3. Follow DNS setup instructions
4. Cloudflare will automatically provision SSL certificates

## Option 2: GitHub Actions Deployment (More Control)

If you prefer using GitHub Actions (already configured):

1. **Get Cloudflare API Token**
   - Go to Cloudflare Dashboard → "My Profile" → "API Tokens"
   - Click "Create Token"
   - Use "Edit Cloudflare Workers" template
   - Add permissions: Account → Cloudflare Pages → Edit
   - Copy the token

2. **Get Cloudflare Account ID**
   - Go to Cloudflare Dashboard → Right sidebar → "Account ID"
   - Copy the Account ID

3. **Add GitHub Secrets**
   - Go to your GitHub repository → Settings → Secrets and variables → Actions
   - Add secret: `CLOUDFLARE_API_TOKEN` (value from step 1)
   - Add secret: `CLOUDFLARE_ACCOUNT_ID` (value from step 2)

4. **Push to GitHub**
   - The workflow will automatically build and deploy on push to `main`/`master`
   - Check Actions tab to see deployment status

## Testing the Deployment

After deployment, your Flutter web app will be available at:
- Cloudflare Pages URL: `https://flutter-viewer.pages.dev` (or your custom domain)

The app should work exactly as it does locally, including:
- HLS video playback
- Chromecast support
- Navigation between screens
- Authentication flow

## Troubleshooting

### Build Fails
- Check Cloudflare Pages build logs
- Ensure Flutter version is compatible (currently using 3.35.7)
- Verify all dependencies are in `pubspec.yaml`

### Routing Issues
- The `_redirects` file ensures all routes go to `index.html` (SPA routing)
- This works with Flutter's `usePathUrlStrategy()` configuration

### CORS Issues
- If your API endpoints have CORS restrictions, ensure they allow your Cloudflare Pages domain
- Check `flutter_viewer/web/index.html` for any hardcoded URLs

## Updating the Deployment

Simply push changes to your `main`/`master` branch:
- Cloudflare Pages will automatically rebuild and redeploy
- No manual steps required

## Cost

**Cloudflare Pages is completely free** for:
- Unlimited requests
- Unlimited bandwidth
- Unlimited builds
- Custom domains
- SSL certificates

Perfect for hosting static Flutter web apps!

