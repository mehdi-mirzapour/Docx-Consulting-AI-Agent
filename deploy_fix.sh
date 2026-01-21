#!/bin/bash
echo "🚀 Starting DocxAI Fix & Deploy..."

# 1. Stop existing containers
echo "🛑 Stopping old containers..."
docker rm -f docx-mcp 2>/dev/null || true
pkill -f "python server.py" || true

# 2. Build the Docker image (with frontend assets)
echo "🔨 Building Docker image (this may take a minute)..."
docker build -f Dockerfile.mcp -t docx-mcp .

# 3. Run the new container
echo "▶️ Starting container..."
# Using the API key from your environment (Make sure OPENAI_API_KEY is set in your shell or .env)
# export OPENAI_API_KEY="your-key-here"

docker run -d \
  -p 8787:8787 \
  -e OPENAI_API_KEY=$OPENAI_API_KEY \
  --name docx-mcp \
  docx-mcp

# 4. Restart ngrok
echo "🌐 Restarting ngrok..."
pkill -f ngrok || true
ngrok http 8787 > ngrok.log 2>&1 &

echo "⏳ Waiting for services to stabilize..."
sleep 5

# 5. Show URL
echo "✅ DONE! Use this URL in ChatGPT:"
curl -s http://127.0.0.1:4040/api/tunnels | grep -o 'https://[^"]*'
echo ""
echo "If the URL is empty above, verify at http://localhost:4040"
