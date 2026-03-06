# Docker Multi-Project DB Management & Live Sync Template

### _PostgreSQL & MongoDB Per-Project Isolation Tool_

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Postgres](https://img.shields.io/badge/postgres-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![MongoDB](https://img.shields.io/badge/MongoDB-%234ea94b.svg?style=for-the-badge&logo=mongodb&logoColor=white)](https://www.mongodb.com/)

A powerful, reusable template for developers to spawn isolated database environments instantly. No more manual `docker-compose` editing or port conflicts.

---

## Key Features

- **Isolated Environments**: Spawn unique PostgreSQL + MongoDB stacks per project.
- **Smart Port Mapping**: Automatically finds and assigns free ports for new projects.
- **Live-to-Local Sync**: One-command sync from live servers using Connection URIs.
- **Visual Progress**: Real-time backup/restore progress with accurate percentage bars.
- **Auto-Detection**: Smart scripts detect local container names and root credentials automatically.
- **Role Safety**: Automatically handles "Owner" mismatch errors during Postgres restores.
- **Easy Cleanup**: Remove stacks completely or keep data volumes for later use.

---

## Prerequisites & Installation

Before running the scripts, ensure you have the necessary tools installed on your host machine.

### 1. Essential Core

- **Docker** & **Docker Compose V2**

### 2. Client Tools (Required for Sync/Backup)

You need the database clients installed locally to perform dump/restore operations.

#### **Ubuntu / Debian / WSL2**

```bash
# Update repositories
sudo apt update

# Install PV (Pipe Viewer) for progress bars
sudo apt install -y pv

# Install Postgres Client
sudo apt install -y postgresql-client

# Install MongoDB Tools (mongosh, mongodump, mongorestore)
wget -qO- https://www.mongodb.org/static/pgp/server-7.0.asc | sudo tee /etc/apt/trusted.gpg.d/server-7.0.asc
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt update
sudo apt install -y mongodb-mongosh mongodb-database-tools
```

#### **Arch Linux**

```bash
sudo pacman -S docker docker-compose pv postgresql-libs mongodb-bin mongodb-tools-bin
```

#### **MacOS (Homebrew)**

```bash
brew install pv postgresql mongodb-community@7.0 mongosh mongodb-database-tools
```

#### **Windows**

**Option A: Using WSL2 (Recommended)**
Simply follow the **Ubuntu / Debian / WSL2** guide above inside your WSL2 terminal.

**Option B: Native Windows (Git Bash + Chocolatey)**

1. Install [Git Bash](https://gitforwindows.org/).
2. Install [Chocolatey](https://chocolatey.org/install).
3. Open PowerShell as Administrator and run:

```powershell
# Install PV, Postgres Client, and MongoDB Tools
choco install -y pv postgresql17-client mongodb-database-tools mongosh
```

4. You can now run the `.sh` scripts directly from **Git Bash**.

---

## Project Structure

```text
.
├── create-db.sh    # Create & Start a new DB stack
├── list-db.sh      # View all running stacks & ports
├── sync-db.sh      # Sync data from LIVE to LOCAL
├── backup-db.sh    # Backup local data
├── restore-db.sh   # Restore local data
├── remove-db.sh    # Remove project stack
├── data/           # Persistent DB files
└── backup/         # SQL/Gzip archive files
```

---

## Usage Guide

### 1. Create a New Project

Spawns a fresh Postgres + Mongo stack.

```bash
./create-db.sh project_name
```

_Port will be auto-assigned (e.g., 5432 or 5433 if 5432 is busy)._

### 2. Sync Data from LIVE (The "Magic" Script)

Fetch data from your production or staging server directly into your local Docker.

```bash
./sync-db.sh project_name postgres
# OR
./sync-db.sh project_name mongo
```

_Supports full Connection URIs (e.g., `postgresql://user:pass@host:port/db`)._

### 3. Management Commands

| Action                  | Command                                     |
| :---------------------- | :------------------------------------------ |
| **List** Running Stacks | `./list-db.sh`                              |
| **Backup** Local DB     | `./backup-db.sh project_name postgres`      |
| **Stop & Remove** Stack | `./remove-db.sh project_name`               |
| **Purge** Everything    | `./remove-db.sh project_name --delete-data` |

---

## 🔐 Database Credentials

Credentials are generated based on the **project name** by default.

### Standard Format:

- **Username**: `project_name`
- **Password**: `project_name`
- **Database**: `project_name`

> [!NOTE]
> The `sync-db.sh` script is smart—it automatically detects if your local container uses different credentials (like `fikri`, `root`, or `admin`) and uses them accordingly.

---

## ❓ Troubleshooting

**Q: Permission Denied on `pg_filenode.map`?**
A: This tool is already fixed! It forces connections via `127.0.0.1` instead of Unix sockets to bypass Docker permission issues.

**Q: Role "admin" does not exist during restore?**
A: The sync script uses `--no-owner` and `--no-privileges` automatically, so data from _any_ live user can be restored to your local user without errors.

---

### License

Feel free to use this template for all your internal project developments. Happy Coding! 🚀
