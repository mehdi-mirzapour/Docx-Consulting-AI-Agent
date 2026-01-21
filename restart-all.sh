#!/bin/bash

echo "==================================="
echo "DocxAI Complete Restart Script"
echo "==================================="

# Stop everything
echo ""
echo "1. Stopping all processes..."
killall ngrok python3 2>/dev/null
docker stop $(docker ps -q) 2>/dev/null
sleep 2
echo "✓ All processes stopped"

# Rebuild frontend
echo ""
echo "2. Rebuilding frontend..."
cd frontend
pnpm run build
cd ..
echo "✓ Frontend built"

# Inline assets
echo ""
echo "3. Inlining assets into server..."
python3 inline_assets.py
echo "✓ Assets inlined"

# Start MCP server
echo ""
echo "4. Starting MCP server on port 8787..."
cd backend
.venv/bin/python server.py &
MCP_PID=$!
cd ..
sleep 3
echo "✓ MCP Server started (PID: $MCP_PID)"

# Start ngrok
echo ""
echo "5. Starting ngrok tunnel..."
ngrok http 8787 > /dev/null 2>&1 &
NGROK_PID=$!
sleep 3
echo "✓ Ngrok started (PID: $NGROK_PID)"

# Get ngrok URL
echo ""
echo "6. Getting ngrok URL..."
sleep 2
NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['tunnels'][0]['public_url'] if d.get('tunnels') else '')" 2>/dev/null)

if [ -n "$NGROK_URL" ]; then
    echo "✓ Ngrok URL: $NGROK_URL"
    echo ""
    echo "==================================="
    echo "✅ EVERYTHING IS READY!"
    echo "==================================="
    echo ""
    echo "Use this URL in ChatGPT:"
    echo "$NGROK_URL/sse"
    echo ""
    echo "Ngrok Web Interface:"
    echo "http://127.0.0.1:4040"
    echo ""
    echo "To stop everything:"
    echo "kill $MCP_PID $NGROK_PID"
else
    echo "⚠️  Could not get ngrok URL"
    echo "Check manually at: http://127.0.0.1:4040"
fi

echo ""
echo "==================================="
