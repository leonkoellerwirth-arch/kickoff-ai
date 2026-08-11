# =============================================================================
# Brewfile — Core packages (everyday stack)
#
# Install via: brew bundle --file=Brewfile
# All packages verified in the inventory from 2026-08-10.
# Optional packages (security tools, ML, media) → Brewfile.optional
# =============================================================================

# =============================================================================
# Taps
# =============================================================================
tap "homebrew/services"
tap "keith/formulae"
tap "steipete/tap"

# =============================================================================
# Version control
# =============================================================================
brew "git"                  # brew git must take precedence over /usr/bin/git (PATH via zprofile)
brew "git-lfs"              # Git Large File Storage
brew "gh"                   # GitHub CLI
brew "gitleaks"             # Secret scanning (also as pre-commit hook)

# =============================================================================
# Shell / terminal tools
# =============================================================================
brew "tmux"                 # Terminal multiplexer
brew "tree"                 # Directory visualization
brew "watch"                # Run command periodically
brew "wget"                 # HTTP downloader
brew "ripgrep"              # Fast grep (rg)
brew "jq"                   # JSON processing
brew "shellcheck"           # Shell script linter

# =============================================================================
# Build / compilation
# =============================================================================
brew "cmake"                # Build system
brew "pkg-config"           # Compiler flags helper

# =============================================================================
# Python stack
# =============================================================================
brew "uv"                   # Fast Python package manager (primary)
brew "pipx"                 # Isolated CLI Python tools
# pipenv: present in inventory, fallback for older projects
brew "pipenv"

# =============================================================================
# Node stack
# =============================================================================
brew "pnpm"                 # Fast npm replacement with shared store
brew "deno"                 # TypeScript/JavaScript runtime

# =============================================================================
# Databases (services, no autostart)
# =============================================================================
brew "postgresql@17"        # PostgreSQL (newer than @14, backwards compatible)
brew "mysql@8.0"            # MySQL 8 (current installation)

# =============================================================================
# AI / ML (CLI tools)
# =============================================================================
brew "ollama"               # Local LLM execution
brew "gemini-cli"           # Google Gemini CLI

# =============================================================================
# Languages / runtimes
# =============================================================================
brew "go"                   # Go language
brew "rust"                 # Rust (incl. cargo)
brew "openjdk@17"           # Java 17 LTS (for Spring Boot, Maven, etc.)
brew "maven"                # Java build tool
brew "gradle"               # Java/Kotlin build tool
brew "php"                  # PHP (current, via brew)
brew "ruby"                 # Ruby (for CocoaPods etc.)

# =============================================================================
# Media / document processing
# =============================================================================
brew "ffmpeg"               # Audio/video conversion
brew "imagemagick"          # Image processing (convert, mogrify)
brew "graphviz"             # Graph rendering (dot)
brew "exiftool"             # Read/write EXIF metadata
brew "tesseract"            # OCR engine
brew "tesseract-lang"       # OCR language packs

# =============================================================================
# Document pipeline (PDF / OCR)
# =============================================================================
brew "poppler"              # PDF tools (pdftotext, pdftocairo)
brew "qpdf"                 # PDF transformation
brew "ocrmypdf"             # OCR for PDFs
brew "pdfgrep"              # Full-text search in PDFs

# =============================================================================
# Archiving
# =============================================================================
brew "p7zip"                # 7-Zip for macOS

# =============================================================================
# Protocol / API
# =============================================================================
brew "protobuf@21"          # Protocol Buffers (inventory: @21)

# =============================================================================
# Other useful tools
# =============================================================================
brew "iproute2mac"          # ip command for macOS
brew "util-linux"           # Linux utilities (column, rename, etc.)
brew "pcre"                 # Regular expressions (PCRE)

# =============================================================================
# CocoaPods (iOS/macOS dependencies)
# =============================================================================
brew "cocoapods"

# =============================================================================
# Casks — GUI applications
# =============================================================================
cask "iterm2"               # Terminal emulator (with cc-status hook)
cask "ghostty"              # Modern terminal emulator
cask "visual-studio-code"   # VS Code editor
cask "docker"               # Docker Desktop
cask "bitwarden-cli"        # Bitwarden CLI (bw) — secrets via Vaultwarden
cask "alt-tab"              # macOS Alt+Tab replacement
cask "raycast"              # Spotlight replacement
cask "postman"              # API test client
