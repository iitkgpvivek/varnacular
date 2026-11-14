#!/bin/bash
# Start local static server on port 3005 and expose via Cloudflare Tunnel
PORT=3005
cd /Users/vivek/.gemini/antigravity/scratch/varnacular

# Kill any existing server on this port
lsof -ti :$PORT | xargs kill -9 2>/dev/null

echo "Starting local web server on port $PORT..."
npx -y serve . -l $PORT > /private/tmp/varnacular_serve.log 2>&1 &
sleep 2

echo "Starting Cloudflare tunnel for port $PORT..."
cloudflared tunnel --url http://localhost:$PORT > /private/tmp/varnacular_cloudflared.log 2>&1 &
sleep 5

URL=$(grep -o 'https://[-a-z0-9]*\.trycloudflare\.com' /private/tmp/varnacular_cloudflared.log | tail -n 1)
if [ -n "$URL" ]; then
  echo "============================================="
  echo "🎉 Varnacular is LIVE on Cloudflare Tunnel:"
  echo "$URL"
  echo "============================================="
else
  echo "Checking log:"
  tail -n 15 /private/tmp/varnacular_cloudflared.log
fi
