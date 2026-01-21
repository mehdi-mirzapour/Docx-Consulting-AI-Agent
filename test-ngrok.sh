#!/bin/bash

echo "=== Testing Local Server ==="
echo "Testing http://localhost:8787..."
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:8787/

echo ""
echo "Testing http://localhost:8787/sse..."
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:8787/sse

echo ""
echo "=== Checking Server Process ==="
lsof -i :8787 2>/dev/null || echo "No process listening on port 8787"

echo ""
echo "=== Checking Ngrok ==="
if pgrep -f ngrok > /dev/null; then
    echo "Ngrok is running"
    echo "Ngrok web interface: http://127.0.0.1:4040"
    echo ""
    echo "Getting ngrok URL..."
    curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('tunnels'):
        url = data['tunnels'][0]['public_url']
        print(f'Public URL: {url}')
        print(f'SSE Endpoint: {url}/sse')
    else:
        print('No tunnels found')
except:
    print('Could not parse ngrok data')
"
else
    echo "Ngrok is NOT running"
    echo "Please run: ngrok http 8787"
fi
