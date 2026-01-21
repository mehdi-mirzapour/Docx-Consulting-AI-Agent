# 🚀 Azure Deployment Guide - DocxAI

This document provides a comprehensive guide for deploying the DocxAI application to Azure using a modern CI/CD pipeline with Docker containers and Azure App Services.

---

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Azure Infrastructure Setup](#azure-infrastructure-setup)
- [Docker Configuration](#docker-configuration)
- [GitHub Actions CI/CD Pipeline](#github-actions-cicd-pipeline)
- [Azure Front Door Configuration](#azure-front-door-configuration)
- [Environment Variables & Secrets](#environment-variables--secrets)
- [Deployment Process](#deployment-process)
- [Monitoring & Troubleshooting](#monitoring--troubleshooting)
- [Cost Optimization](#cost-optimization)

---

## 🏗️ Architecture Overview

```
GitHub (push to main)
   ↓
GitHub Actions (CI/CD)
   ↓
Build 3 Docker images (FE, BE, MCP)
   ↓
Push images to Azure Container Registry (ACR)
   ↓
Deploy to Azure App Services (Linux, containers)
   │
   ├─ Frontend App Service
   ├─ Backend App Service
   └─ MCP App Service
   │
Internet
   ↓
Azure Front Door (HTTPS, routing, optional WAF)
   │
   ├─ /api/*  ─────────▶ Backend App Service
   │                    https://be.azurewebsites.net
   │
   ├─ /mcp/*  ─────────▶ MCP App Service
   │                    https://mcp.azurewebsites.net
   │
   └─ /*      ─────────▶ Frontend App Service
                        https://fe.azurewebsites.net
```

### Components

1. **Frontend App Service**: Serves the React-based document editor widget
2. **Backend App Service**: Handles REST API endpoints for document processing
3. **MCP App Service**: Manages Model Context Protocol (MCP) communication with ChatGPT via SSE
4. **Azure Container Registry (ACR)**: Stores Docker images
5. **Azure Front Door**: Provides global load balancing, HTTPS termination, and routing

---

## ✅ Prerequisites

### Local Development Tools
- **Azure CLI** (v2.50+): `brew install azure-cli`
- **Docker Desktop**: For building and testing containers locally
- **Git**: For version control
- **Node.js** (v18+) and **pnpm**: For frontend builds
- **Python** (v3.10+) and **uv**: For backend dependencies

### Azure Account Requirements
- Active Azure subscription
- Contributor or Owner role on the subscription
- GitHub account with repository access

### Required Secrets & Credentials
- OpenAI API Key (for GPT-4o integration)
- Azure Service Principal credentials (for GitHub Actions)

---

## 🔧 Azure Infrastructure Setup

Each step below provides **three deployment methods**:
1. **Azure Portal** (GUI-based)
2. **Azure CLI** (Command-line)
3. **Terraform** (Infrastructure as Code)

Choose the method that best fits your workflow.

---

### Step 1: Login to Azure

#### Azure Portal
1. Navigate to [https://portal.azure.com](https://portal.azure.com)
2. Sign in with your Azure account credentials

#### Azure CLI
```bash
az login
az account set --subscription "<your-subscription-id>"
```

#### Terraform
```hcl
# Configure Azure provider in main.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "<your-subscription-id>"
}
```

---

### Step 2: Create Resource Group

#### Azure Portal
1. Go to **Resource groups** in the Azure Portal
2. Click **+ Create**
3. Fill in the details:
   - **Subscription**: Select your subscription
   - **Resource group**: `docxai-rg`
   - **Region**: `West Europe`
4. Click **Review + create** → **Create**

#### Azure CLI
```bash
az group create \
  --name docxai-rg \
  --location westeurope
```

#### Terraform
```hcl
# resource_group.tf
resource "azurerm_resource_group" "docxai" {
  name     = "docxai-rg"
  location = "West Europe"
}
```

---

### Step 3: Create Azure Container Registry (ACR)

> **💡 Note**: ACR name must be globally unique, lowercase alphanumeric only (no hyphens). Change `docxaiacr` to something unique if needed.

#### Azure Portal
1. Search for **Container registries** in the Azure Portal
2. Click **+ Create**
3. Fill in the details:
   - **Subscription**: Select your subscription
   - **Resource group**: `docxai-rg`
   - **Registry name**: `docxaiacr` (must be globally unique)
   - **Location**: `West Europe`
   - **SKU**: `Basic`
4. Go to **Networking** tab → Enable **Admin user**
5. Click **Review + create** → **Create**

#### Azure CLI
```bash
az acr create \
  --resource-group docxai-rg \
  --name docxaiacr \
  --sku Basic \
  --admin-enabled true \
  --location westeurope
```

#### Terraform
```hcl
# acr.tf
resource "azurerm_container_registry" "docxai" {
  name                = "docxaiacr"
  resource_group_name = azurerm_resource_group.docxai.name
  location            = azurerm_resource_group.docxai.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Output ACR credentials
output "acr_login_server" {
  value = azurerm_container_registry.docxai.login_server
}

output "acr_admin_username" {
  value     = azurerm_container_registry.docxai.admin_username
  sensitive = true
}

output "acr_admin_password" {
  value     = azurerm_container_registry.docxai.admin_password
  sensitive = true
}
```

> **💡 Tip**: For production, use Standard or Premium SKU for better performance and geo-replication.

---

### Step 4: Create App Service Plan

> **💰 Cost Note**: B1 tier costs ~$13/month. For production workloads, consider P1V2 (~$73/month) for better performance.

#### Azure Portal
1. Search for **App Service plans** in the Azure Portal
2. Click **+ Create**
3. Fill in the details:
   - **Subscription**: Select your subscription
   - **Resource group**: `docxai-rg`
   - **Name**: `docxai-plan`
   - **Operating System**: `Linux`
   - **Region**: `West Europe`
   - **Pricing tier**: Click **Change size** → Select **B1** (Basic)
4. Click **Review + create** → **Create**

#### Azure CLI
```bash
az appservice plan create \
  --name docxai-plan \
  --resource-group docxai-rg \
  --is-linux \
  --sku B1 \
  --location westeurope
```

#### Terraform
```hcl
# app_service_plan.tf
resource "azurerm_service_plan" "docxai" {
  name                = "docxai-plan"
  resource_group_name = azurerm_resource_group.docxai.name
  location            = azurerm_resource_group.docxai.location
  os_type             = "Linux"
  sku_name            = "B1"
}
```

---

### Step 5: Create Three App Services

> **⚠️ Important**: App Service names must be globally unique. If names are taken, add a suffix like `docxai-frontend-xyz123`.

#### Azure Portal

**For Frontend App Service:**
1. Search for **App Services** in the Azure Portal
2. Click **+ Create** → **Web App**
3. Fill in the details:
   - **Subscription**: Select your subscription
   - **Resource group**: `docxai-rg`
   - **Name**: `docxai-frontend`
   - **Publish**: `Container`
   - **Operating System**: `Linux`
   - **Region**: `West Europe`
   - **App Service Plan**: Select `docxai-plan`
4. Go to **Container** tab:
   - **Image Source**: `Docker Hub or other registries`
   - **Image and tag**: `nginx:alpine`
5. Click **Review + create** → **Create**

**Repeat for Backend and MCP:**
- Backend: Name = `docxai-backend`, Image = `python:3.10-slim`
- MCP: Name = `docxai-mcp`, Image = `python:3.10-slim`

#### Azure CLI
```bash
# Frontend App Service
az webapp create \
  --resource-group docxai-rg \
  --plan docxai-plan \
  --name docxai-frontend \
  --deployment-container-image-name nginx:alpine

# Backend App Service
az webapp create \
  --resource-group docxai-rg \
  --plan docxai-plan \
  --name docxai-backend \
  --deployment-container-image-name python:3.10-slim

# MCP App Service
az webapp create \
  --resource-group docxai-rg \
  --plan docxai-plan \
  --name docxai-mcp \
  --deployment-container-image-name python:3.10-slim
```

#### Terraform
```hcl
# app_services.tf
resource "azurerm_linux_web_app" "frontend" {
  name                = "docxai-frontend"
  resource_group_name = azurerm_resource_group.docxai.name
  location            = azurerm_resource_group.docxai.location
  service_plan_id     = azurerm_service_plan.docxai.id

  site_config {
    application_stack {
      docker_image_name   = "nginx:alpine"
      docker_registry_url = "https://index.docker.io"
    }
  }
}

resource "azurerm_linux_web_app" "backend" {
  name                = "docxai-backend"
  resource_group_name = azurerm_resource_group.docxai.name
  location            = azurerm_resource_group.docxai.location
  service_plan_id     = azurerm_service_plan.docxai.id

  site_config {
    application_stack {
      docker_image_name   = "python:3.10-slim"
      docker_registry_url = "https://index.docker.io"
    }
  }
}

resource "azurerm_linux_web_app" "mcp" {
  name                = "docxai-mcp"
  resource_group_name = azurerm_resource_group.docxai.name
  location            = azurerm_resource_group.docxai.location
  service_plan_id     = azurerm_service_plan.docxai.id

  site_config {
    application_stack {
      docker_image_name   = "python:3.10-slim"
      docker_registry_url = "https://index.docker.io"
    }
  }
}
```

---

### Step 6: Configure App Services for ACR

This step connects your App Services to pull images from your private Azure Container Registry.

#### Azure Portal

**For each App Service (Frontend, Backend, MCP):**
1. Go to the App Service (e.g., `docxai-frontend`)
2. Navigate to **Deployment Center** in the left menu
3. Select **Container settings**:
   - **Registry source**: `Azure Container Registry`
   - **Registry**: `docxaiacr`
   - **Image**: Will be set later (e.g., `docxai-frontend`)
   - **Tag**: `latest`
4. Click **Save**

#### Azure CLI
```bash
# Get ACR credentials
az acr credential show --name docxaiacr --query username -o tsv
# Output: docxaiacr

az acr credential show --name docxaiacr --query passwords[0].value -o tsv
# Output: <password> (save this)

# Configure Frontend
az webapp config container set \
  --name docxai-frontend \
  --resource-group docxai-rg \
  --docker-registry-server-url https://docxaiacr.azurecr.io \
  --docker-registry-server-user docxaiacr \
  --docker-registry-server-password "<password-from-above>"

# Configure Backend
az webapp config container set \
  --name docxai-backend \
  --resource-group docxai-rg \
  --docker-registry-server-url https://docxaiacr.azurecr.io \
  --docker-registry-server-user docxaiacr \
  --docker-registry-server-password "<password-from-above>"

# Configure MCP
az webapp config container set \
  --name docxai-mcp \
  --resource-group docxai-rg \
  --docker-registry-server-url https://docxaiacr.azurecr.io \
  --docker-registry-server-user docxaiacr \
  --docker-registry-server-password "<password-from-above>"
```

#### Terraform
```hcl
# Update app_services.tf with ACR configuration
resource "azurerm_linux_web_app" "frontend" {
  name                = "docxai-frontend"
  resource_group_name = azurerm_resource_group.docxai.name
  location            = azurerm_resource_group.docxai.location
  service_plan_id     = azurerm_service_plan.docxai.id

  site_config {
    application_stack {
      docker_image_name   = "docxaiacr.azurecr.io/docxai-frontend:latest"
      docker_registry_url = "https://docxaiacr.azurecr.io"
    }
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL      = "https://docxaiacr.azurecr.io"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.docxai.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.docxai.admin_password
  }
}

resource "azurerm_linux_web_app" "backend" {
  name                = "docxai-backend"
  resource_group_name = azurerm_resource_group.docxai.name
  location            = azurerm_resource_group.docxai.location
  service_plan_id     = azurerm_service_plan.docxai.id

  site_config {
    application_stack {
      docker_image_name   = "docxaiacr.azurecr.io/docxai-backend:latest"
      docker_registry_url = "https://docxaiacr.azurecr.io"
    }
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL      = "https://docxaiacr.azurecr.io"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.docxai.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.docxai.admin_password
  }
}

resource "azurerm_linux_web_app" "mcp" {
  name                = "docxai-mcp"
  resource_group_name = azurerm_resource_group.docxai.name
  location            = azurerm_resource_group.docxai.location
  service_plan_id     = azurerm_service_plan.docxai.id

  site_config {
    application_stack {
      docker_image_name   = "docxaiacr.azurecr.io/docxai-mcp:latest"
      docker_registry_url = "https://docxaiacr.azurecr.io"
    }
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL      = "https://docxaiacr.azurecr.io"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.docxai.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.docxai.admin_password
  }
}
```

---

### Step 7: Enable HTTPS and Configure Ports

#### Azure Portal

**For each App Service:**
1. Go to the App Service (e.g., `docxai-frontend`)
2. Navigate to **Configuration** → **General settings**
3. Set **HTTPS Only**: `On`
4. Click **Save**

**For Backend and MCP (set custom port):**
1. Go to **Configuration** → **Application settings**
2. Click **+ New application setting**
3. Add:
   - **Name**: `WEBSITES_PORT`
   - **Value**: `8787`
4. Click **OK** → **Save**

#### Azure CLI
```bash
# Enable HTTPS only for all apps
az webapp update \
  --name docxai-frontend \
  --resource-group docxai-rg \
  --https-only true

az webapp update \
  --name docxai-backend \
  --resource-group docxai-rg \
  --https-only true

az webapp update \
  --name docxai-mcp \
  --resource-group docxai-rg \
  --https-only true

# Set custom ports for Backend and MCP
az webapp config appsettings set \
  --name docxai-backend \
  --resource-group docxai-rg \
  --settings WEBSITES_PORT=8787

az webapp config appsettings set \
  --name docxai-mcp \
  --resource-group docxai-rg \
  --settings WEBSITES_PORT=8787
```

#### Terraform
```hcl
# Update app_services.tf to add HTTPS and port settings
resource "azurerm_linux_web_app" "frontend" {
  # ... previous configuration ...
  
  https_only = true
}

resource "azurerm_linux_web_app" "backend" {
  # ... previous configuration ...
  
  https_only = true

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL      = "https://docxaiacr.azurecr.io"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.docxai.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.docxai.admin_password
    WEBSITES_PORT                   = "8787"
  }
}

resource "azurerm_linux_web_app" "mcp" {
  # ... previous configuration ...
  
  https_only = true

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL      = "https://docxaiacr.azurecr.io"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.docxai.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.docxai.admin_password
    WEBSITES_PORT                   = "8787"
  }
}
```

---

### Step 8: Create Azure Front Door

#### Azure Portal
1. Search for **Front Door and CDN profiles** in the Azure Portal
2. Click **+ Create**
3. Select **Azure Front Door** → **Custom create**
4. Fill in the basics:
   - **Subscription**: Select your subscription
   - **Resource group**: `docxai-rg`
   - **Name**: `docxai-fd`
   - **Tier**: `Standard`
5. Click **Next: Endpoint**
6. Click **+ Add an endpoint**:
   - **Endpoint name**: `docxai-endpoint`
7. Click **+ Add a route** (repeat for each service):

   **Route 1 - Frontend (default):**
   - **Name**: `default-route`
   - **Domains**: Select the default domain
   - **Patterns to match**: `/*`
   - **Origin group**: Create new → `frontend-origins`
   - **Origin**: `docxai-frontend.azurewebsites.net`
   - **HTTPS**: Enabled

   **Route 2 - Backend API:**
   - **Name**: `api-route`
   - **Patterns to match**: `/api/*`
   - **Origin group**: Create new → `backend-origins`
   - **Origin**: `docxai-backend.azurewebsites.net`

   **Route 3 - MCP:**
   - **Name**: `mcp-route`
   - **Patterns to match**: `/mcp/*`
   - **Origin group**: Create new → `mcp-origins`
   - **Origin**: `docxai-mcp.azurewebsites.net`

8. Click **Review + create** → **Create**

#### Azure CLI
```bash
# Create Front Door profile
az afd profile create \
  --profile-name docxai-fd \
  --resource-group docxai-rg \
  --sku Standard_AzureFrontDoor

# Create endpoint
az afd endpoint create \
  --resource-group docxai-rg \
  --profile-name docxai-fd \
  --endpoint-name docxai-endpoint

# Create origin group for frontend
az afd origin-group create \
  --resource-group docxai-rg \
  --profile-name docxai-fd \
  --origin-group-name frontend-origins \
  --probe-request-type GET \
  --probe-protocol Https \
  --probe-interval-in-seconds 30 \
  --probe-path / \
  --sample-size 4 \
  --successful-samples-required 3 \
  --additional-latency-in-milliseconds 50

# Add frontend origin
az afd origin create \
  --resource-group docxai-rg \
  --profile-name docxai-fd \
  --origin-group-name frontend-origins \
  --origin-name frontend-origin \
  --host-name docxai-frontend.azurewebsites.net \
  --origin-host-header docxai-frontend.azurewebsites.net \
  --priority 1 \
  --weight 1000 \
  --enabled-state Enabled \
  --http-port 80 \
  --https-port 443

# Create origin group for backend
az afd origin-group create \
  --resource-group docxai-rg \
  --profile-name docxai-fd \
  --origin-group-name backend-origins \
  --probe-request-type GET \
  --probe-protocol Https \
  --probe-interval-in-seconds 30 \
  --probe-path /health \
  --sample-size 4 \
  --successful-samples-required 3

# Add backend origin
az afd origin create \
  --resource-group docxai-rg \
  --profile-name docxai-fd \
  --origin-group-name backend-origins \
  --origin-name backend-origin \
  --host-name docxai-backend.azurewebsites.net \
  --origin-host-header docxai-backend.azurewebsites.net \
  --priority 1 \
  --weight 1000 \
  --enabled-state Enabled \
  --http-port 80 \
  --https-port 443

# Create origin group for MCP
az afd origin-group create \
  --resource-group docxai-rg \
  --profile-name docxai-fd \
  --origin-group-name mcp-origins \
  --probe-request-type GET \
  --probe-protocol Https \
  --probe-interval-in-seconds 30 \
  --probe-path /sse \
  --sample-size 4 \
  --successful-samples-required 3

# Add MCP origin
az afd origin create \
  --resource-group docxai-rg \
  --profile-name docxai-fd \
  --origin-group-name mcp-origins \
  --origin-name mcp-origin \
  --host-name docxai-mcp.azurewebsites.net \
  --origin-host-header docxai-mcp.azurewebsites.net \
  --priority 1 \
  --weight 1000 \
  --enabled-state Enabled \
  --http-port 80 \
  --https-port 443

# Create routes
az afd route create \
  --resource-group docxai-rg \
  --profile-name docxai-fd \
  --endpoint-name docxai-endpoint \
  --route-name api-route \
  --origin-group backend-origins \
  --supported-protocols Https \
  --patterns-to-match "/api/*" \
  --forwarding-protocol HttpsOnly \
  --https-redirect Enabled

az afd route create \
  --resource-group docxai-rg \
  --profile-name docxai-fd \
  --endpoint-name docxai-endpoint \
  --route-name mcp-route \
  --origin-group mcp-origins \
  --supported-protocols Https \
  --patterns-to-match "/mcp/*" \
  --forwarding-protocol HttpsOnly \
  --https-redirect Enabled

az afd route create \
  --resource-group docxai-rg \
  --profile-name docxai-fd \
  --endpoint-name docxai-endpoint \
  --route-name default-route \
  --origin-group frontend-origins \
  --supported-protocols Https \
  --patterns-to-match "/*" \
  --forwarding-protocol HttpsOnly \
  --https-redirect Enabled
```

#### Terraform
```hcl
# front_door.tf
resource "azurerm_cdn_frontdoor_profile" "docxai" {
  name                = "docxai-fd"
  resource_group_name = azurerm_resource_group.docxai.name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "docxai" {
  name                     = "docxai-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.docxai.id
}

# Frontend Origin Group
resource "azurerm_cdn_frontdoor_origin_group" "frontend" {
  name                     = "frontend-origins"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.docxai.id

  health_probe {
    interval_in_seconds = 30
    path                = "/"
    protocol            = "Https"
    request_type        = "GET"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "frontend" {
  name                          = "frontend-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.frontend.id
  host_name                     = "docxai-frontend.azurewebsites.net"
  origin_host_header            = "docxai-frontend.azurewebsites.net"
  priority                      = 1
  weight                        = 1000
  enabled                       = true
  http_port                     = 80
  https_port                    = 443
}

# Backend Origin Group
resource "azurerm_cdn_frontdoor_origin_group" "backend" {
  name                     = "backend-origins"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.docxai.id

  health_probe {
    interval_in_seconds = 30
    path                = "/health"
    protocol            = "Https"
    request_type        = "GET"
  }

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "backend" {
  name                          = "backend-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.backend.id
  host_name                     = "docxai-backend.azurewebsites.net"
  origin_host_header            = "docxai-backend.azurewebsites.net"
  priority                      = 1
  weight                        = 1000
  enabled                       = true
  http_port                     = 80
  https_port                    = 443
}

# MCP Origin Group
resource "azurerm_cdn_frontdoor_origin_group" "mcp" {
  name                     = "mcp-origins"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.docxai.id

  health_probe {
    interval_in_seconds = 30
    path                = "/sse"
    protocol            = "Https"
    request_type        = "GET"
  }

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "mcp" {
  name                          = "mcp-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.mcp.id
  host_name                     = "docxai-mcp.azurewebsites.net"
  origin_host_header            = "docxai-mcp.azurewebsites.net"
  priority                      = 1
  weight                        = 1000
  enabled                       = true
  http_port                     = 80
  https_port                    = 443
}

# Routes
resource "azurerm_cdn_frontdoor_route" "api" {
  name                          = "api-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.docxai.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.backend.id
  patterns_to_match             = ["/api/*"]
  supported_protocols           = ["Https"]
  forwarding_protocol           = "HttpsOnly"
  https_redirect_enabled        = true
  link_to_default_domain        = true
}

resource "azurerm_cdn_frontdoor_route" "mcp" {
  name                          = "mcp-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.docxai.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.mcp.id
  patterns_to_match             = ["/mcp/*"]
  supported_protocols           = ["Https"]
  forwarding_protocol           = "HttpsOnly"
  https_redirect_enabled        = true
  link_to_default_domain        = true
}

resource "azurerm_cdn_frontdoor_route" "default" {
  name                          = "default-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.docxai.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.frontend.id
  patterns_to_match             = ["/*"]
  supported_protocols           = ["Https"]
  forwarding_protocol           = "HttpsOnly"
  https_redirect_enabled        = true
  link_to_default_domain        = true
}

# Output Front Door endpoint
output "frontdoor_endpoint_url" {
  value = azurerm_cdn_frontdoor_endpoint.docxai.host_name
}
```

---

## 🐳 Docker Configuration

### Directory Structure

Create the following Dockerfiles in your project:

```
.
├── Dockerfile.frontend
├── Dockerfile.backend
├── Dockerfile.mcp
├── .dockerignore
└── docker-compose.yml (optional, for local testing)
```

### Dockerfile.frontend

```dockerfile
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY frontend/package.json frontend/pnpm-lock.yaml ./

# Install pnpm and dependencies
RUN npm install -g pnpm && pnpm install --frozen-lockfile

# Copy source code
COPY frontend/ ./

# Build the application
RUN pnpm run build

# Production stage
FROM nginx:alpine

# Copy built assets
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy custom nginx config (if needed)
# COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### Dockerfile.backend

```dockerfile
FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv for faster package management
RUN pip install uv

# Copy requirements
COPY backend/requirements.txt .

# Install Python dependencies
RUN uv pip install --system -r requirements.txt

# Copy application code
COPY backend/ .

# Create uploads directory
RUN mkdir -p uploads

# Expose port
EXPOSE 8787

# Run the server
CMD ["python", "server.py"]
```

### Dockerfile.mcp

```dockerfile
FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install uv

# Copy requirements
COPY backend/requirements.txt .

# Install dependencies
RUN uv pip install --system -r requirements.txt

# Copy MCP server code
COPY backend/ .

# Create uploads directory
RUN mkdir -p uploads

EXPOSE 8787

# Run MCP server
CMD ["python", "server.py"]
```

### .dockerignore

```
# Node modules
**/node_modules
**/dist
**/.vite

# Python
**/__pycache__
**/*.pyc
**/.venv
**/venv

# Environment files
.env
.env.local

# Git
.git
.gitignore

# IDE
.vscode
.idea

# Logs
**/*.log
**/server.log

# Uploads
**/uploads/*

# OS files
.DS_Store
```

---

## ⚙️ GitHub Actions CI/CD Pipeline

### Step 1: Create Service Principal for GitHub

```bash
# Create service principal
az ad sp create-for-rbac \
  --name "docxai-github-actions" \
  --role contributor \
  --scopes /subscriptions/<subscription-id>/resourceGroups/docxai-rg \
  --sdk-auth
```

> **📝 Note**: Save the JSON output - you'll need it for GitHub Secrets.

### Step 2: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AZURE_CREDENTIALS` | JSON from service principal | Azure authentication |
| `ACR_LOGIN_SERVER` | `docxaiacr.azurecr.io` | ACR login server |
| `ACR_USERNAME` | From ACR credentials | ACR username |
| `ACR_PASSWORD` | From ACR credentials | ACR password |
| `OPENAI_API_KEY` | Your OpenAI API key | For GPT-4o integration |

### Step 3: Create GitHub Actions Workflow

Create `.github/workflows/azure-deploy.yml`:

```yaml
name: Deploy to Azure

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Login to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Login to ACR
        run: |
          echo ${{ secrets.ACR_PASSWORD }} | docker login ${{ secrets.ACR_LOGIN_SERVER }} \
            --username ${{ secrets.ACR_USERNAME }} \
            --password-stdin

      - name: Build and push Frontend image
        run: |
          docker build -f Dockerfile.frontend -t ${{ secrets.ACR_LOGIN_SERVER }}/docxai-frontend:${{ github.sha }} .
          docker tag ${{ secrets.ACR_LOGIN_SERVER }}/docxai-frontend:${{ github.sha }} ${{ secrets.ACR_LOGIN_SERVER }}/docxai-frontend:latest
          docker push ${{ secrets.ACR_LOGIN_SERVER }}/docxai-frontend:${{ github.sha }}
          docker push ${{ secrets.ACR_LOGIN_SERVER }}/docxai-frontend:latest

      - name: Build and push Backend image
        run: |
          docker build -f Dockerfile.backend -t ${{ secrets.ACR_LOGIN_SERVER }}/docxai-backend:${{ github.sha }} .
          docker tag ${{ secrets.ACR_LOGIN_SERVER }}/docxai-backend:${{ github.sha }} ${{ secrets.ACR_LOGIN_SERVER }}/docxai-backend:latest
          docker push ${{ secrets.ACR_LOGIN_SERVER }}/docxai-backend:${{ github.sha }}
          docker push ${{ secrets.ACR_LOGIN_SERVER }}/docxai-backend:latest

      - name: Build and push MCP image
        run: |
          docker build -f Dockerfile.mcp -t ${{ secrets.ACR_LOGIN_SERVER }}/docxai-mcp:${{ github.sha }} .
          docker tag ${{ secrets.ACR_LOGIN_SERVER }}/docxai-mcp:${{ github.sha }} ${{ secrets.ACR_LOGIN_SERVER }}/docxai-mcp:latest
          docker push ${{ secrets.ACR_LOGIN_SERVER }}/docxai-mcp:${{ github.sha }}
          docker push ${{ secrets.ACR_LOGIN_SERVER }}/docxai-mcp:latest

      - name: Deploy Frontend to App Service
        run: |
          az webapp config container set \
            --name docxai-frontend \
            --resource-group docxai-rg \
            --docker-custom-image-name ${{ secrets.ACR_LOGIN_SERVER }}/docxai-frontend:${{ github.sha }}
          
          az webapp restart --name docxai-frontend --resource-group docxai-rg

      - name: Deploy Backend to App Service
        run: |
          az webapp config appsettings set \
            --name docxai-backend \
            --resource-group docxai-rg \
            --settings OPENAI_API_KEY="${{ secrets.OPENAI_API_KEY }}"
          
          az webapp config container set \
            --name docxai-backend \
            --resource-group docxai-rg \
            --docker-custom-image-name ${{ secrets.ACR_LOGIN_SERVER }}/docxai-backend:${{ github.sha }}
          
          az webapp restart --name docxai-backend --resource-group docxai-rg

      - name: Deploy MCP to App Service
        run: |
          az webapp config appsettings set \
            --name docxai-mcp \
            --resource-group docxai-rg \
            --settings OPENAI_API_KEY="${{ secrets.OPENAI_API_KEY }}"
          
          az webapp config container set \
            --name docxai-mcp \
            --resource-group docxai-rg \
            --docker-custom-image-name ${{ secrets.ACR_LOGIN_SERVER }}/docxai-mcp:${{ github.sha }}
          
          az webapp restart --name docxai-mcp --resource-group docxai-rg

      - name: Logout from Azure
        run: az logout
```

---

## 🌐 Azure Front Door Configuration

> **✅ Already Configured**: Azure Front Door setup is covered in [Step 8](#step-8-create-azure-front-door) above, including origin groups, origins, and routing configuration for all three deployment methods (Portal, CLI, and Terraform).

---

## 🔐 Environment Variables & Secrets

### Backend App Service Environment Variables

#### Azure Portal
1. Go to **docxai-backend** App Service
2. Navigate to **Configuration** → **Application settings**
3. Click **+ New application setting** for each:
   - **Name**: `OPENAI_API_KEY`, **Value**: `<your-openai-api-key>`
   - **Name**: `WEBSITES_PORT`, **Value**: `8787`
   - **Name**: `PYTHONUNBUFFERED`, **Value**: `1`
   - **Name**: `LOG_LEVEL`, **Value**: `INFO`
4. Click **Save**

#### Azure CLI
```bash
az webapp config appsettings set \
  --name docxai-backend \
  --resource-group docxai-rg \
  --settings \
    OPENAI_API_KEY="<your-openai-api-key>" \
    WEBSITES_PORT=8787 \
    PYTHONUNBUFFERED=1 \
    LOG_LEVEL=INFO
```

#### Terraform
```hcl
# Update backend app service in app_services.tf
resource "azurerm_linux_web_app" "backend" {
  name                = "docxai-backend"
  resource_group_name = azurerm_resource_group.docxai.name
  location            = azurerm_resource_group.docxai.location
  service_plan_id     = azurerm_service_plan.docxai.id
  https_only          = true

  site_config {
    application_stack {
      docker_image_name   = "docxaiacr.azurecr.io/docxai-backend:latest"
      docker_registry_url = "https://docxaiacr.azurecr.io"
    }
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL      = "https://docxaiacr.azurecr.io"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.docxai.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.docxai.admin_password
    WEBSITES_PORT                   = "8787"
    OPENAI_API_KEY                  = var.openai_api_key
    PYTHONUNBUFFERED                = "1"
    LOG_LEVEL                       = "INFO"
  }
}

# Add variable in variables.tf
variable "openai_api_key" {
  description = "OpenAI API Key"
  type        = string
  sensitive   = true
}
```

---

### MCP App Service Environment Variables

#### Azure Portal
1. Go to **docxai-mcp** App Service
2. Navigate to **Configuration** → **Application settings**
3. Click **+ New application setting** for each:
   - **Name**: `OPENAI_API_KEY`, **Value**: `<your-openai-api-key>`
   - **Name**: `WEBSITES_PORT`, **Value**: `8787`
   - **Name**: `PYTHONUNBUFFERED`, **Value**: `1`
   - **Name**: `LOG_LEVEL`, **Value**: `INFO`
4. Click **Save**

#### Azure CLI
```bash
az webapp config appsettings set \
  --name docxai-mcp \
  --resource-group docxai-rg \
  --settings \
    OPENAI_API_KEY="<your-openai-api-key>" \
    WEBSITES_PORT=8787 \
    PYTHONUNBUFFERED=1 \
    LOG_LEVEL=INFO
```

#### Terraform
```hcl
# Update MCP app service in app_services.tf
resource "azurerm_linux_web_app" "mcp" {
  name                = "docxai-mcp"
  resource_group_name = azurerm_resource_group.docxai.name
  location            = azurerm_resource_group.docxai.location
  service_plan_id     = azurerm_service_plan.docxai.id
  https_only          = true

  site_config {
    application_stack {
      docker_image_name   = "docxaiacr.azurecr.io/docxai-mcp:latest"
      docker_registry_url = "https://docxaiacr.azurecr.io"
    }
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL      = "https://docxaiacr.azurecr.io"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.docxai.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.docxai.admin_password
    WEBSITES_PORT                   = "8787"
    OPENAI_API_KEY                  = var.openai_api_key
    PYTHONUNBUFFERED                = "1"
    LOG_LEVEL                       = "INFO"
  }
}
```

---

## 🚀 Deployment Process

### Manual Deployment (First Time)

1. **Build Docker images locally** (optional, for testing):
   ```bash
   docker build -f Dockerfile.frontend -t docxai-frontend .
   docker build -f Dockerfile.backend -t docxai-backend .
   docker build -f Dockerfile.mcp -t docxai-mcp .
   ```

2. **Push to main branch**:
   ```bash
   git add .
   git commit -m "Initial Azure deployment setup"
   git push origin main
   ```

3. **Monitor GitHub Actions**:
   - Go to your repository → Actions tab
   - Watch the deployment workflow progress
   - Check for any errors in the logs

4. **Verify deployments**:
   ```bash
   # Check app service status
   az webapp show --name docxai-frontend --resource-group docxai-rg --query state
   az webapp show --name docxai-backend --resource-group docxai-rg --query state
   az webapp show --name docxai-mcp --resource-group docxai-rg --query state
   ```

### Automated Deployment (Continuous)

Every push to the `main` branch will automatically:
1. Build three Docker images
2. Push images to ACR
3. Deploy to respective App Services
4. Restart services with new images

---

## 📊 Monitoring & Troubleshooting

### View Application Logs

```bash
# Stream logs from backend
az webapp log tail --name docxai-backend --resource-group docxai-rg

# Stream logs from MCP
az webapp log tail --name docxai-mcp --resource-group docxai-rg

# Stream logs from frontend
az webapp log tail --name docxai-frontend --resource-group docxai-rg
```

### Enable Application Insights (Recommended)

#### Azure Portal
1. Search for **Application Insights** in the Azure Portal
2. Click **+ Create**
3. Fill in the details:
   - **Subscription**: Select your subscription
   - **Resource group**: `docxai-rg`
   - **Name**: `docxai-insights`
   - **Region**: `West Europe`
4. Click **Review + create** → **Create**
5. After creation, go to **Overview** and copy the **Instrumentation Key**
6. For each App Service (frontend, backend, mcp):
   - Go to the App Service
   - Navigate to **Configuration** → **Application settings**
   - Add: **Name**: `APPINSIGHTS_INSTRUMENTATIONKEY`, **Value**: `<instrumentation-key>`
   - Click **Save**

#### Azure CLI
```bash
# Create Application Insights
az monitor app-insights component create \
  --app docxai-insights \
  --location westeurope \
  --resource-group docxai-rg

# Get instrumentation key
az monitor app-insights component show \
  --app docxai-insights \
  --resource-group docxai-rg \
  --query instrumentationKey -o tsv
# Output: <instrumentation-key> (save this)

# Configure Frontend
az webapp config appsettings set \
  --name docxai-frontend \
  --resource-group docxai-rg \
  --settings APPINSIGHTS_INSTRUMENTATIONKEY="<instrumentation-key>"

# Configure Backend
az webapp config appsettings set \
  --name docxai-backend \
  --resource-group docxai-rg \
  --settings APPINSIGHTS_INSTRUMENTATIONKEY="<instrumentation-key>"

# Configure MCP
az webapp config appsettings set \
  --name docxai-mcp \
  --resource-group docxai-rg \
  --settings APPINSIGHTS_INSTRUMENTATIONKEY="<instrumentation-key>"
```

#### Terraform
```hcl
# application_insights.tf
resource "azurerm_application_insights" "docxai" {
  name                = "docxai-insights"
  location            = azurerm_resource_group.docxai.location
  resource_group_name = azurerm_resource_group.docxai.name
  application_type    = "web"
}

# Update each app service to include Application Insights
# Add to app_settings in each azurerm_linux_web_app resource:
resource "azurerm_linux_web_app" "frontend" {
  # ... existing configuration ...
  
  app_settings = {
    # ... existing settings ...
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.docxai.instrumentation_key
  }
}

resource "azurerm_linux_web_app" "backend" {
  # ... existing configuration ...
  
  app_settings = {
    # ... existing settings ...
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.docxai.instrumentation_key
  }
}

resource "azurerm_linux_web_app" "mcp" {
  # ... existing configuration ...
  
  app_settings = {
    # ... existing settings ...
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.docxai.instrumentation_key
  }
}

output "application_insights_key" {
  value     = azurerm_application_insights.docxai.instrumentation_key
  sensitive = true
}
```

---

### Common Issues & Solutions

#### Issue: Container fails to start

**Solution**: Check logs and ensure:
- Dockerfile exposes the correct port
- `WEBSITES_PORT` matches the application port
- All dependencies are installed

```bash
az webapp log tail --name docxai-backend --resource-group docxai-rg
```

#### Issue: 502 Bad Gateway

**Solution**: 
- Verify the app is listening on the correct port
- Check health probe endpoints
- Increase startup timeout:

```bash
az webapp config set \
  --name docxai-backend \
  --resource-group docxai-rg \
  --startup-time 600
```

#### Issue: MCP SSE connection fails

**Solution**:
- Ensure WebSocket support is enabled
- Check CORS configuration
- Verify Front Door routing for `/mcp/*`

```bash
az webapp config set \
  --name docxai-mcp \
  --resource-group docxai-rg \
  --web-sockets-enabled true
```

---

## 💰 Cost Optimization

### Estimated Monthly Costs (Basic Tier)

| Resource | SKU | Quantity | Monthly Cost (USD) |
|----------|-----|----------|-------------------|
| App Service Plan | B1 | 1 | ~$13 |
| App Services | - | 3 | Included in plan |
| Container Registry | Basic | 1 | ~$5 |
| Front Door | Standard | 1 | ~$35 + data transfer |
| **Total** | | | **~$53/month** |

> **💡 Note**: Costs vary by region and usage. Add ~$10-20 for data transfer and storage.

### Cost Reduction Tips

1. **Use a single App Service Plan** for all three apps (already configured)
2. **Disable apps during non-business hours** (if not 24/7):
   ```bash
   az webapp stop --name docxai-backend --resource-group docxai-rg
   ```
3. **Use Azure DevTest subscription** for development (50% discount)
4. **Monitor with Azure Cost Management** to track spending
5. **Consider Azure Container Instances** for MCP service (pay-per-second billing)

### Production Scaling Recommendations

For production workloads:
- **App Service Plan**: Upgrade to P1V2 or P2V2 for auto-scaling
- **ACR**: Use Standard or Premium for geo-replication
- **Front Door**: Add WAF for security (~$35/month extra)
- **Application Insights**: Enable for monitoring and diagnostics

---

## 🎯 Next Steps

1. **Configure Custom Domain**:
   ```bash
   az webapp config hostname add \
     --webapp-name docxai-frontend \
     --resource-group docxai-rg \
     --hostname yourdomain.com
   ```

2. **Enable SSL Certificate**:
   ```bash
   az webapp config ssl bind \
     --name docxai-frontend \
     --resource-group docxai-rg \
     --certificate-thumbprint <thumbprint> \
     --ssl-type SNI
   ```

3. **Set up Staging Slots** (requires Standard tier or higher):
   ```bash
   az webapp deployment slot create \
     --name docxai-backend \
     --resource-group docxai-rg \
     --slot staging
   ```

4. **Configure ChatGPT Integration**:
   - Update ChatGPT GPT Builder with your Front Door URL
   - Use: `https://<frontdoor-endpoint>.azurefd.net/mcp/sse`

---

## 📚 Additional Resources

- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [Azure Container Registry](https://docs.microsoft.com/azure/container-registry/)
- [Azure Front Door](https://docs.microsoft.com/azure/frontdoor/)
- [GitHub Actions for Azure](https://github.com/Azure/actions)

---

## 🆘 Support

For issues or questions:
1. Check Azure App Service logs
2. Review GitHub Actions workflow logs
3. Verify all environment variables are set correctly
4. Ensure OpenAI API key is valid and has sufficient credits

---

**Last Updated**: January 2026  
**Version**: 1.0.0
