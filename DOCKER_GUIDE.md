# 🐳 Docker Local Development Guide

Complete reference for building and running DocxAI containers locally.

---

## 📋 Prerequisites

- Docker Desktop installed and running
- Project files in `/Users/mehdi/work/Docx-Consulting-AI-Agent`

---

## 🏗️ Building Docker Images

### Build All Images

```bash
# Navigate to project root
cd /Users/mehdi/work/Docx-Consulting-AI-Agent

# Build Frontend (React + Nginx)
docker build -f Dockerfile.frontend -t docxai-frontend:latest .

# Build Backend (Python + FastAPI)
docker build -f Dockerfile.backend -t docxai-backend:latest .

# Build MCP Server (Python + MCP)
docker build -f Dockerfile.mcp -t docxai-mcp:latest .
```

### Build with Specific Tags

```bash
# Build with version tags
docker build -f Dockerfile.frontend -t docxai-frontend:v1.0.0 .
docker build -f Dockerfile.backend -t docxai-backend:v1.0.0 .
docker build -f Dockerfile.mcp -t docxai-mcp:v1.0.0 .
```

### Verify Built Images

```bash
# List all docxai images
docker images | grep docxai

# Or with formatted output
docker images --filter "reference=docxai-*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
```

---

## 🚀 Running Containers

### Option 1: Run Individual Containers

#### Frontend Container
```bash
docker run -d \
  --name docxai-frontend \
  -p 3000:80 \
  docxai-frontend:latest
```

**Access:** http://localhost:3000

#### Backend Container
```bash
docker run -d \
  --name docxai-backend \
  -p 8787:8787 \
  -e OPENAI_API_KEY="your-openai-api-key" \
  -e PYTHONUNBUFFERED=1 \
  -e LOG_LEVEL=INFO \
  docxai-backend:latest
```

**Access:** http://localhost:8787

#### MCP Container
```bash
docker run -d \
  --name docxai-mcp \
  -p 8788:8787 \
  -e OPENAI_API_KEY="your-openai-api-key" \
  -e PYTHONUNBUFFERED=1 \
  -e LOG_LEVEL=INFO \
  docxai-mcp:latest
```

**Access:** http://localhost:8788

### Option 2: Run All with Docker Compose

Create `docker-compose.yml` in project root:

```yaml
version: '3.8'

services:
  frontend:
    image: docxai-frontend:latest
    container_name: docxai-frontend
    ports:
      - "3000:80"
    restart: unless-stopped

  backend:
    image: docxai-backend:latest
    container_name: docxai-backend
    ports:
      - "8787:8787"
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - PYTHONUNBUFFERED=1
      - LOG_LEVEL=INFO
    restart: unless-stopped

  mcp:
    image: docxai-mcp:latest
    container_name: docxai-mcp
    ports:
      - "8788:8787"
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - PYTHONUNBUFFERED=1
      - LOG_LEVEL=INFO
    restart: unless-stopped
```

Then run:

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f
```

---

## 🧪 Testing Containers

### Health Checks

```bash
# Check if containers are running
docker ps --filter "name=docxai-"

# Test frontend (should return 200)
curl -I http://localhost:3000

# Test backend SSE endpoint
curl http://localhost:8787/sse

# Test MCP SSE endpoint
curl http://localhost:8788/sse
```

### View Logs

```bash
# View logs for specific container
docker logs docxai-frontend
docker logs docxai-backend
docker logs docxai-mcp

# Follow logs in real-time
docker logs -f docxai-backend

# View last 50 lines
docker logs --tail 50 docxai-backend
```

### Interactive Shell Access

```bash
# Access frontend container (Alpine Linux)
docker exec -it docxai-frontend sh

# Access backend container (Debian)
docker exec -it docxai-backend bash

# Access MCP container (Debian)
docker exec -it docxai-mcp bash
```

---

## 🔄 Container Management

### Stop Containers

```bash
# Stop individual container
docker stop docxai-frontend

# Stop all docxai containers
docker stop $(docker ps -q --filter "name=docxai-")
```

### Start Containers

```bash
# Start individual container
docker start docxai-frontend

# Start all docxai containers
docker start docxai-frontend docxai-backend docxai-mcp
```

### Restart Containers

```bash
# Restart individual container
docker restart docxai-backend

# Restart all docxai containers
docker restart $(docker ps -aq --filter "name=docxai-")
```

### Remove Containers

```bash
# Remove individual container (must be stopped first)
docker rm docxai-frontend

# Force remove running container
docker rm -f docxai-frontend

# Remove all docxai containers
docker rm -f $(docker ps -aq --filter "name=docxai-")
```

---

## 🗑️ Cleanup

### Remove Images

```bash
# Remove specific image
docker rmi docxai-frontend:latest

# Remove all docxai images
docker rmi $(docker images -q "docxai-*")

# Remove unused images
docker image prune -a
```

### Complete Cleanup

```bash
# Stop and remove all docxai containers
docker stop $(docker ps -aq --filter "name=docxai-") 2>/dev/null
docker rm $(docker ps -aq --filter "name=docxai-") 2>/dev/null

# Remove all docxai images
docker rmi $(docker images -q "docxai-*") 2>/dev/null

# Clean up unused resources
docker system prune -a --volumes
```

---

## 🔍 Troubleshooting

### Container Won't Start

```bash
# Check container status
docker ps -a --filter "name=docxai-"

# View container logs
docker logs docxai-backend

# Inspect container configuration
docker inspect docxai-backend
```

### Port Already in Use

```bash
# Find process using port 8787
lsof -i :8787

# Kill process (replace PID)
kill -9 <PID>

# Or use different port
docker run -p 8888:8787 docxai-backend:latest
```

### Rebuild After Code Changes

```bash
# Rebuild without cache
docker build --no-cache -f Dockerfile.backend -t docxai-backend:latest .

# Stop old container and start new one
docker stop docxai-backend
docker rm docxai-backend
docker run -d --name docxai-backend -p 8787:8787 docxai-backend:latest
```

---

## 📊 Monitoring

### Resource Usage

```bash
# View container resource usage
docker stats

# View specific container stats
docker stats docxai-backend

# One-time stats snapshot
docker stats --no-stream
```

### Disk Usage

```bash
# View Docker disk usage
docker system df

# Detailed breakdown
docker system df -v
```

---

## 🚢 Pushing to Azure Container Registry

### Login to ACR

```bash
# Login to Azure
az login

# Login to ACR
az acr login --name docxaiacr
```

### Tag Images for ACR

```bash
# Tag images with ACR registry
docker tag docxai-frontend:latest docxaiacr.azurecr.io/docxai-frontend:latest
docker tag docxai-backend:latest docxaiacr.azurecr.io/docxai-backend:latest
docker tag docxai-mcp:latest docxaiacr.azurecr.io/docxai-mcp:latest

# Tag with version
docker tag docxai-frontend:latest docxaiacr.azurecr.io/docxai-frontend:v1.0.0
```

### Push to ACR

```bash
# Push latest tags
docker push docxaiacr.azurecr.io/docxai-frontend:latest
docker push docxaiacr.azurecr.io/docxai-backend:latest
docker push docxaiacr.azurecr.io/docxai-mcp:latest

# Push version tags
docker push docxaiacr.azurecr.io/docxai-frontend:v1.0.0
```

### Verify Images in ACR

```bash
# List repositories
az acr repository list --name docxaiacr --output table

# List tags for specific repository
az acr repository show-tags --name docxaiacr --repository docxai-frontend --output table
```

---

## 📝 Quick Reference

### Common Commands

| Task | Command |
|------|---------|
| Build all images | `docker build -f Dockerfile.frontend -t docxai-frontend:latest .` |
| Run frontend | `docker run -d --name docxai-frontend -p 3000:80 docxai-frontend:latest` |
| View logs | `docker logs -f docxai-backend` |
| Stop all | `docker stop $(docker ps -q --filter "name=docxai-")` |
| Remove all | `docker rm -f $(docker ps -aq --filter "name=docxai-")` |
| Clean up | `docker system prune -a` |

### Access URLs

| Service | Local URL |
|---------|-----------|
| Frontend | http://localhost:3000 |
| Backend | http://localhost:8787 |
| Backend SSE | http://localhost:8787/sse |
| MCP | http://localhost:8788 |
| MCP SSE | http://localhost:8788/sse |

---

**Last Updated:** January 2026  
**Version:** 1.0.0
