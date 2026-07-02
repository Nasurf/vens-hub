#!/bin/bash
# Vens Hub API - Deployment Script
# Usage: ./deploy.sh [--remote]

set -e

WORKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/workers/api" && pwd)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "  Vens Hub API - Deploy to Cloudflare"
echo "============================================"
echo ""

# Check if wrangler is installed
if ! command -v npx &> /dev/null; then
    echo "❌ npx not found. Please install Node.js."
    exit 1
fi

# Check if CLOUDFLARE_API_TOKEN is set
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "⚠️  CLOUDFLARE_API_TOKEN not set."
    echo "   Set it with: export CLOUDFLARE_API_TOKEN=your_token_here"
    echo "   Or run: wrangler login"
    echo ""
fi

# Deploy worker
echo "📦 Deploying worker..."
cd "$WORKER_DIR"

if [ "$1" = "--remote" ]; then
    npx wrangler deploy --env=""
else
    npx wrangler deploy --env=""
fi

echo ""
echo "✅ Deployment complete!"
echo ""

# Health check
echo "🏥 Running health check..."
HEALTH=$(curl -s "https://vens-hub-api.nasurf25.workers.dev/health" 2>/dev/null)
if echo "$HEALTH" | grep -q '"ok"'; then
    echo "✅ Health check passed: $HEALTH"
else
    echo "⚠️  Health check failed or timed out"
fi

echo ""
echo "============================================"
echo "  Deployment Summary"
echo "============================================"
echo "  Worker: vens-hub-api"
echo "  URL: https://vens-hub-api.nasurf25.workers.dev"
echo "  Database: vens-hub-questions"
echo "============================================"
