#!/bin/bash
# lib.sh — Shared helper functions for DB management scripts

# ────────────────────────────────────────────────────────────────
#  Detect OS / package manager
# ────────────────────────────────────────────────────────────────
_detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then echo "apt"
    elif command -v dnf &>/dev/null;   then echo "dnf"
    elif command -v yum &>/dev/null;   then echo "yum"
    elif command -v pacman &>/dev/null; then echo "pacman"
    elif command -v brew &>/dev/null;  then echo "brew"
    else echo "unknown"; fi
}

# ────────────────────────────────────────────────────────────────
#  Setup MongoDB APT repo (handles Ubuntu version compatibility)
#  MongoDB 8.0 supports: noble (24.04), jammy (22.04)
#  MongoDB 7.0 supports: jammy (22.04), focal (20.04)
#  For unsupported codenames, fallback to nearest supported one.
# ────────────────────────────────────────────────────────────────
_setup_mongodb_apt_repo() {
    local codename
    codename=$(lsb_release -cs 2>/dev/null || echo "jammy")

    local mongo_version repo_codename
    case "$codename" in
        noble|oracular|plucky)
            # Ubuntu 24.04+ → MongoDB 8.0 (supports noble)
            mongo_version="8.0"
            repo_codename="noble"
            ;;
        jammy)
            # Ubuntu 22.04 → MongoDB 8.0 (supports jammy)
            mongo_version="8.0"
            repo_codename="jammy"
            ;;
        focal)
            # Ubuntu 20.04 → MongoDB 7.0 (supports focal)
            mongo_version="7.0"
            repo_codename="focal"
            ;;
        *)
            # Default fallback: use jammy + 8.0
            mongo_version="8.0"
            repo_codename="jammy"
            ;;
    esac

    echo "  🔑 Setting up MongoDB ${mongo_version} repository (${repo_codename})..."

    # Remove any old/broken MongoDB repo files first
    sudo rm -f /etc/apt/sources.list.d/mongodb-org-*.list 2>/dev/null

    # Add GPG key
    wget -qO- "https://www.mongodb.org/static/pgp/server-${mongo_version}.asc" \
        | sudo tee "/etc/apt/trusted.gpg.d/server-${mongo_version}.asc" >/dev/null

    # Add repo
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu ${repo_codename}/mongodb-org/${mongo_version} multiverse" \
        | sudo tee "/etc/apt/sources.list.d/mongodb-org-${mongo_version}.list" >/dev/null

    sudo apt-get update -qq
}

# ────────────────────────────────────────────────────────────────
#  Install PV (pipe viewer)
# ────────────────────────────────────────────────────────────────
_install_pv() {
    local pm=$(_detect_pkg_manager)
    echo "  📦 Installing pv..."
    case "$pm" in
        apt)    sudo apt-get install -y pv ;;
        dnf|yum) sudo "$pm" install -y pv ;;
        pacman) sudo pacman -S --noconfirm pv ;;
        brew)   brew install pv ;;
        *)      echo "  ⚠️  Cannot auto-install pv. Please install it manually."; return 1 ;;
    esac
}

# ────────────────────────────────────────────────────────────────
#  Install MongoDB Database Tools (mongodump, mongorestore, etc.)
# ────────────────────────────────────────────────────────────────
_install_mongodb_tools() {
    local pm=$(_detect_pkg_manager)
    echo "  📦 Installing MongoDB Database Tools (mongodump, mongorestore)..."
    case "$pm" in
        apt)
            _setup_mongodb_apt_repo
            sudo apt-get install -y mongodb-database-tools
            ;;
        dnf|yum)
            if [ ! -f /etc/yum.repos.d/mongodb-org-8.0.repo ]; then
                echo "  🔑 Adding MongoDB 8.0 repository..."
                sudo tee /etc/yum.repos.d/mongodb-org-8.0.repo >/dev/null <<'REPO'
[mongodb-org-8.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/8.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-8.0.asc
REPO
            fi
            sudo "$pm" install -y mongodb-database-tools
            ;;
        pacman)
            if command -v yay &>/dev/null; then
                yay -S --noconfirm mongodb-tools-bin
            elif command -v paru &>/dev/null; then
                paru -S --noconfirm mongodb-tools-bin
            else
                echo "  ⚠️  AUR helper not found. Install mongodb-tools-bin manually."; return 1
            fi
            ;;
        brew)   brew install mongodb-database-tools ;;
        *)      echo "  ⚠️  Cannot auto-install mongodb-database-tools. Please install manually."; return 1 ;;
    esac
}

# ────────────────────────────────────────────────────────────────
#  Install mongosh
# ────────────────────────────────────────────────────────────────
_install_mongosh() {
    local pm=$(_detect_pkg_manager)
    echo "  📦 Installing mongosh..."
    case "$pm" in
        apt)
            # Reuse MongoDB repo (setup if not present or broken)
            if ! apt-cache show mongodb-mongosh &>/dev/null; then
                _setup_mongodb_apt_repo
            fi
            sudo apt-get install -y mongodb-mongosh
            ;;
        dnf|yum)
            if [ ! -f /etc/yum.repos.d/mongodb-org-8.0.repo ]; then
                echo "  🔑 Adding MongoDB 8.0 repository..."
                sudo tee /etc/yum.repos.d/mongodb-org-8.0.repo >/dev/null <<'REPO'
[mongodb-org-8.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/8.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-8.0.asc
REPO
            fi
            sudo "$pm" install -y mongodb-mongosh
            ;;
        pacman)
            if command -v yay &>/dev/null; then
                yay -S --noconfirm mongosh-bin
            elif command -v paru &>/dev/null; then
                paru -S --noconfirm mongosh-bin
            else
                echo "  ⚠️  AUR helper not found. Install mongosh-bin manually."; return 1
            fi
            ;;
        brew)   brew install mongosh ;;
        *)      echo "  ⚠️  Cannot auto-install mongosh. Please install manually."; return 1 ;;
    esac
}

# ────────────────────────────────────────────────────────────────
#  Install postgresql-client
# ────────────────────────────────────────────────────────────────
_install_pg_client() {
    local pm=$(_detect_pkg_manager)
    echo "  📦 Installing postgresql-client..."
    case "$pm" in
        apt)    sudo apt-get install -y postgresql-client ;;
        dnf|yum) sudo "$pm" install -y postgresql ;;
        pacman) sudo pacman -S --noconfirm postgresql-libs ;;
        brew)   brew install postgresql ;;
        *)      echo "  ⚠️  Cannot auto-install postgresql-client. Please install manually."; return 1 ;;
    esac
}

# ────────────────────────────────────────────────────────────────
#  Main: ensure_tools <tool1> [tool2] ...
#  Call this at the start of any script that needs host tools.
#  Example: ensure_tools mongodump mongosh pv
# ────────────────────────────────────────────────────────────────
ensure_tools() {
    local missing=()
    for tool in "$@"; do
        command -v "$tool" &>/dev/null || missing+=("$tool")
    done

    if [ ${#missing[@]} -eq 0 ]; then
        return 0  # All tools present — nothing to do
    fi

    echo ""
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│  🔧 Missing tools detected — Auto-installing…           │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo "  Tools not found: ${missing[*]}"
    echo ""

    for tool in "${missing[@]}"; do
        case "$tool" in
            mongodump|mongorestore) _install_mongodb_tools || exit 1 ;;
            mongosh)                _install_mongosh       || exit 1 ;;
            pv)                     _install_pv            || exit 1 ;;
            psql|pg_dump|pg_restore) _install_pg_client   || exit 1 ;;
            *)
                echo "  ⚠️  Unknown tool '$tool'. Please install manually."
                exit 1
                ;;
        esac
    done

    echo ""
    echo "  ✅ All tools installed successfully!"
    echo ""
}
