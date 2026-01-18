# Docx-Consulting-AI-Agent

Consulting Report Reviewer is an AI-powered document review agent designed for high-stakes consulting deliverables, operating directly inside the ChatGPT app.

It ingests uploaded Microsoft Word reports and performs an in-depth review against predefined criteria—such as numerical consistency, adherence to a consulting style guide (e.g. accuracy and clarity), grammar, and spelling—then suggests improvements directly within the document using Track Changes or inline comments.


## Getting Started

Follow these instructions to set up and run the application.

### Prerequisites

- **Python 3.10+**: We recommend using [uv](https://github.com/astral-sh/uv) or standard `pip`.
- **Node.js & pnpm**: Required for the frontend widget.

### Installation

1.  **Frontend**:
    ```bash
    cd frontend
    pnpm install
    pnpm build
    ```

2.  **Backend**:
    ```bash
    cd backend
    # Install dependencies (using uv)
    uv pip install -r requirements.txt
    # OR using standard pip
    pip install -r requirements.txt
    ```

### Running the Server

Start the backend MCP server (which serves the frontend widget):

```bash
cd backend
uv run server.py
# OR
python server.py
```

The server will start at `http://0.0.0.0:8787`.

### Connecting to ChatGPT

The MCP server exposes an SSE endpoint for connection:

- **SSE URL**: `https://<your-public-url>/sse`
- **Messages URL**: `https://<your-public-url>/sse/messages`

**Note for Local Development**:
To connect your local server to ChatGPT, you need to expose it to the internet using a tool like `ngrok` or `cloudflared`.

```bash
ngrok http 8787
```

Use the generated https URL from ngrok as your backend URL in the ChatGPT MCP configuration.
