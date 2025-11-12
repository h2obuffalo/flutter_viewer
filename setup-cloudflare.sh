#!/bin/bash
# Cloudflare Pages Setup Script
# This script helps set up Cloudflare Pages with custom domain flutter.danpage.uk

set -e

echo "🚀 Setting up Cloudflare Pages deployment for flutter.danpage.uk"
echo ""
echo "This script will help you configure Cloudflare Pages."
echo "You'll need:"
echo "  1. Cloudflare API Token (with Pages:Edit permissions)"
echo "  2. Cloudflare Account ID"
echo ""

# Check if API token is provided
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  echo "❌ Error: CLOUDFLARE_API_TOKEN environment variable not set"
  echo ""
  echo "To set it up:"
  echo "  export CLOUDFLARE_API_TOKEN='your-token-here'"
  echo "  export CLOUDFLARE_ACCOUNT_ID='your-account-id'"
  echo "  bash setup-cloudflare.sh"
  exit 1
fi

if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
  echo "❌ Error: CLOUDFLARE_ACCOUNT_ID environment variable not set"
  exit 1
fi

PROJECT_NAME="flutter-viewer"
CUSTOM_DOMAIN="flutter.danpage.uk"

echo "📋 Configuration:"
echo "  Project Name: $PROJECT_NAME"
echo "  Custom Domain: $CUSTOM_DOMAIN"
echo "  Account ID: $CLOUDFLARE_ACCOUNT_ID"
echo ""

# Check if curl/jq are available
if ! command -v curl &> /dev/null; then
  echo "❌ Error: curl is required but not installed"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "⚠️  Warning: jq is not installed. JSON parsing will be limited."
fi

echo "🔍 Checking if project exists..."
PROJECT_EXISTS=$(curl -s -X GET \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects/$PROJECT_NAME" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" | grep -o '"success":true' || echo "")

if [ -n "$PROJECT_EXISTS" ]; then
  echo "✅ Project '$PROJECT_NAME' already exists"
else
  echo "📦 Creating new Cloudflare Pages project..."
  # Note: Creating a project requires connecting to Git, which is better done via UI
  echo "⚠️  Note: Project creation via API requires Git connection."
  echo "   Please create the project in Cloudflare Dashboard first, then run this script again."
  echo ""
  echo "   Or use the Cloudflare Dashboard:"
  echo "   1. Go to Workers & Pages → Create application → Pages → Connect to Git"
  echo "   2. Select repository: h2obuffalo/webtorrent-livestream"
  echo "   3. Project name: $PROJECT_NAME"
  echo "   4. Build command: cd flutter_viewer && bash build.sh"
  echo "   5. Build output: flutter_viewer/build/web"
  exit 0
fi

echo ""
echo "🌐 Setting up custom domain: $CUSTOM_DOMAIN"
echo ""
echo "To add the custom domain:"
echo "  1. Go to Cloudflare Dashboard → Workers & Pages → $PROJECT_NAME"
echo "  2. Go to 'Custom domains' tab"
echo "  3. Click 'Set up a custom domain'"
echo "  4. Enter: $CUSTOM_DOMAIN"
echo "  5. Follow DNS setup instructions"
echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Add GitHub Secrets (if using GitHub Actions):"
echo "     - CLOUDFLARE_API_TOKEN"
echo "     - CLOUDFLARE_ACCOUNT_ID"
echo "  2. Push to main branch to trigger deployment"
echo "  3. Configure custom domain in Cloudflare Pages dashboard"




