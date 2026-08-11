#!/usr/bin/env bash
# =============================================================================
# scripts/06-containers.sh — Container toolchain
#
# Purpose:  Check/install Docker Desktop, Compose check,
#           check kubectl. DBs are NOT started automatically.
# Changes:  /Applications/Docker.app (cask installation)
# Requires: Homebrew (module 02)
# Usage:    ./scripts/06-containers.sh [--dry-run] [--yes]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

parse_module_args "${BASH_SOURCE[0]}" "$@"

step "06 · Container toolchain"

# =============================================================================
# Docker Desktop
# =============================================================================
info "Checking Docker Desktop..."

DOCKER_APP="/Applications/Docker.app"

if [ -d "$DOCKER_APP" ]; then
    DOCKER_VERSION=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || echo "?")
    ok "Docker Desktop present (Docker $DOCKER_VERSION)"
else
    info "Docker Desktop not found."
    if confirm "Install Docker Desktop? (~800 MB, requires macOS authorization)"; then
        info "Installing Docker Desktop via brew cask..."
        run brew install --cask docker
        info "Docker Desktop installed. Please start the app and complete the setup wizard."
        warn "IMPORTANT: Docker Desktop requires manual authorization on first launch."
    else
        warn "Docker Desktop will not be installed."
        warn "Manual installation: https://www.docker.com/products/docker-desktop/"
    fi
fi

# =============================================================================
# Docker running? (non-blocking)
# =============================================================================
info "Checking Docker daemon..."
if docker info >/dev/null 2>&1; then
    DOCKER_CONTEXT=$(docker context show 2>/dev/null || echo "default")
    ok "Docker daemon running (context: $DOCKER_CONTEXT)"
else
    warn "Docker daemon not running."
    warn "Please start Docker Desktop: open -a Docker"
    warn "Setup can continue — Docker will be needed later."
fi

# =============================================================================
# Docker Compose
# =============================================================================
info "Checking Docker Compose..."
if docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "?")
    ok "Docker Compose v$COMPOSE_VERSION (plugin)"
elif have docker-compose; then
    COMPOSE_VERSION=$(docker-compose --version | awk '{print $3}' | tr -d ',')
    warn "docker-compose (standalone) $COMPOSE_VERSION — recommended: 'docker compose' plugin"
else
    warn "Docker Compose not found"
fi

# =============================================================================
# kubectl
# =============================================================================
info "Checking kubectl..."
if have kubectl; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | awk '{print $3}' || echo "?")
    ok "kubectl $KUBECTL_VERSION present"
    # Check context
    KUBE_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
    if [ "$KUBE_CONTEXT" = "none" ]; then
        info "No Kubernetes cluster context configured (normal for development)"
    else
        info "Active k8s context: $KUBE_CONTEXT"
    fi
else
    info "kubectl not installed — for local k8s work: brew install kubectl"
fi

# =============================================================================
# Note: no automatic DB starts
# =============================================================================
info "Note: databases are NOT started automatically."
info "Each project has its own docker-compose.yml."
info "Start with: docker compose -f ~/dev/<project>/docker-compose.yml up -d"

# Check running brew services
if have brew; then
    MYSQL_STATUS=$(brew services info mysql@8.0 2>/dev/null | grep "Status:" | awk '{print $2}' || echo "?")
    if [ "$MYSQL_STATUS" = "started" ]; then
        warn "mysql@8.0 is running as a brew service (autostart)."
        warn "If only Docker MySQL is used: brew services stop mysql@8.0"
    fi
fi

# =============================================================================
# Available Docker images (overview)
# =============================================================================
if docker info >/dev/null 2>&1; then
    info "Locally available Docker images:"
    docker images --format "  {{.Repository}}:{{.Tag}} ({{.Size}})" 2>/dev/null | head -15 || true
fi

ok "Module 06 (Containers) complete."
