# How We Fixed the Docx AI Deployment

This document explains the technical challenges we faced getting the Docx AI panel to load in ChatGPT and how we solved them. It serves as a reference for future troubleshooting.

## 1. The "404 Not Found" Error
**Problem:**
When you tried to open the panel, the server returned a 404 error.
*   **Cause:** The Docker container was running the Python backend (`server.py`), but it was **missing the frontend files**. The `server.py` code expects to find `index.html` at `../frontend/dist/index.html`, but our original `Dockerfile.mcp` only copied the backend code.
*   **Fix:** We implemented a **Multi-Stage Docker Build**.
    *   **Stage 1 (Builder):** Uses a Node.js image to install dependencies and run `npm run build` to generate the static files.
    *   **Stage 2 (Runtime):** Uses a Python image. We explicitly COPY the built files from Stage 1 into the final image.

```dockerfile
# Stage 1: Build Frontend
FROM node:18-alpine AS builder
...
RUN pnpm run build

# Stage 2: Final Image
FROM python:3.10-slim
...
# COPY metadata from Stage 1 to Stage 2
COPY --from=builder /app/frontend/dist /frontend/dist
```

## 2. The "Blank Page" Issue
**Problem:**
After fixing the 404, the panel loaded but was completely blank.
*   **Cause:** Modern web frameworks like React/Vite generate an `index.html` that links to external JS and CSS files (e.g., `<script src="/assets/index.js">`).
*   **Constraint:** ChatGPT's interface is restrictive. Often, iframes or widgets inside AI responses struggle to load external relative resources due to security policies or network pathing issues relative to the `ngrok` tunnel.
*   **Fix:** **Asset Inlining**.
    *   We used a script (`inline_assets.py`) to take the content of the `.css` and `.js` files and inject them directly into `<style>` and `<script>` tags inside the `index.html` file.
    *   This results in a **Single File Component** (just one big `index.html` string) that requires no extra network requests to load styles or logic.

## 3. Deployment Reliability
**Problem:**
The environment sometimes failed to apply changes because old Docker containers were still running or holding onto ports.
*   **Fix:** We created a `deploy_fix.sh` script to:
    1.  Forcefully stop (`kill`) existing containers and processes.
    2.  Rebuild the image from scratch to ensure the latest code (and inlining) was applied.
    3.  Restart `ngrok` to get a fresh, valid tunnel URL.

## Summary Checklist for Future
If you encounter these issues again:
- **404?** -> Check if `dist/index.html` exists inside the container.
- **Blank Page?** -> Check if CSS/JS are inlined or if relative paths are broken.
- **Connection Refused?** -> Check if `ngrok` is running and pointing to the correct port (8787).
