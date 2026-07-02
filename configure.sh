#!/bin/bash
# Vens Hub API - Configure Environment Variables
# Usage: ./configure.sh

set -e

WORKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/workers/api" && pwd)"

echo "============================================"
echo "  Vens Hub API - Configure Environment"
echo "============================================"
echo ""

# Check if wrangler is available
if ! command -v npx &> /dev/null; then
    echo "❌ npx not found. Please install Node.js."
    exit 1
fi

cd "$WORKER_DIR"

echo "📋 Current Configuration:"
echo ""
echo "  D1 Database: vens-hub-questions"
echo "  R2 Bucket: vens-hub-study-materials"
echo "  Worker URL: https://vens-hub-api.nasurf25.workers.dev"
echo ""

# Check if secrets exist
echo "🔐 Checking secrets..."
SECRETS=$(npx wrangler secret list 2>/dev/null | grep -c "name" || echo "0")
echo "  Configured secrets: $SECRETS"
echo ""

# Prompt for secrets
echo "📝 Configure secrets (press Enter to skip):"
echo ""

read -p "  Gemini API Key (for AI assistant): " GEMINI_KEY
if [ -n "$GEMINI_KEY" ]; then
    echo "$GEMINI_KEY" | npx wrangler secret put GEMINI_API_KEY
    echo "  ✅ GEMINI_API_KEY configured"
fi

read -p "  Upload Signing Secret (for file uploads): " UPLOAD_SECRET
if [ -n "$UPLOAD_SECRET" ]; then
    echo "$UPLOAD_SECRET" | npx wrangler secret put UPLOAD_SIGNING_SECRET
    echo "  ✅ UPLOAD_SIGNING_SECRET configured"
fi

echo ""
echo "============================================"
echo "  Configuration Complete"
echo "============================================"
echo ""
echo "  Next steps:"
echo "  1. Deploy: ./deploy.sh"
echo "  2. Verify: curl https://vens-hub-api.nasurf25.workers.dev/health"
echo "============================================"
