# Docker Multi-Project DB Management & Live Sync Template

### _PostgreSQL & MongoDB Per-Project Isolation Tool_

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Postgres](https://img.shields.io/badge/postgres-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![MongoDB](https://img.shields.io/badge/MongoDB-%234ea94b.svg?style=for-the-badge&logo=mongodb&logoColor=white)](https://www.mongodb.com/)

![Alt text](./ascii-art-text.png)

A powerful, reusable template for developers to spawn isolated database environments instantly. No more manual `docker-compose` editing or port conflicts.

---

## Key Features

- **Isolated Environments** — Spawn unique PostgreSQL + MongoDB stacks per project.
- **Smart Port Mapping** — Automatically finds and assigns free ports for new projects.
- **Live-to-Local Sync** — One-command sync from live servers using Connection URIs.
- **Visual Progress** — Real-time backup/restore progress with accurate percentage bars.
- **Auto-Detection** — Smart scripts detect local container names and root credentials automatically.
- **Role Safety** — Automatically handles "Owner" mismatch errors during Postgres restores.
- **Easy Cleanup** — Remove stacks completely or keep data volumes for later use.

---

## Prerequisites & Installation

The only thing you need to install manually is **Docker** & **Docker Compose V2**.

> [!TIP]
> **Client tools are installed automatically!** When you run `sync-db.sh` or `backup-live.sh`, the scripts will detect if `mongodump`, `mongosh`, `pv`, or `pg_dump` are missing and install them for you using your system's package manager (`apt`, `dnf`, `pacman`, or `brew`).

Supported auto-install platforms:

| Platform | Package Manager |
| :--- | :--- |
| Ubuntu / Debian / WSL2 | `apt` |
| Fedora / RHEL / CentOS | `dnf` / `yum` |
| Arch Linux | `pacman` (+ `yay`/`paru` for MongoDB) |
| macOS | `brew` |

---

## Project Structure

```text
.
├── lib.sh          # Shared library: auto-install tools
├── create-db.sh    # Create & Start a new DB stack
├── list-db.sh      # View all running stacks & ports
├── sync-db.sh      # Sync data from LIVE to LOCAL
├── backup-db.sh    # Backup local data
├── backup-live.sh  # Backup from remote server
├── restore-db.sh   # Restore local data
├── remove-db.sh    # Remove project stack
├── data/           # Persistent DB files
└── backup/         # SQL/Gzip archive files
```

---

## 🎮 The Easiest Way: Management Menu

Don't want to remember all the commands? Use the **Interactive Menu**. It provides a user-friendly interface to access all features (Create, Sync, List, Remove, etc.) in one place.

```bash
chmod +x *.sh
./menu.sh
```

**What's inside:**

- **Create New Project** — Guided setup for new database stacks.
- **Sync from LIVE** — Interactive prompts for syncing data from Production.
- **List Projects** — Overview of all active project containers and their ports.
- **Backup/Restore** — Manage your local snapshots easily.
- **Remove Project** — Safely stop or purge project data.

---

## Usage

### 1. Create a New Project

Spawns a fresh Postgres + Mongo stack.

```bash
./create-db.sh project_name
```

> Port will be auto-assigned (e.g., `5432` or `5433` if `5432` is busy).

### 2. Sync Data from LIVE (The "Magic" Script)

Fetch data from your production or staging server directly into your local Docker.

```bash
./sync-db.sh project_name postgres
# OR
./sync-db.sh project_name mongo
```

> Supports full Connection URIs (e.g., `postgresql://user:pass@host:port/db`).

### 3. Management Commands

| Action | Command |
| :--- | :--- |
| **List** Running Stacks | `./list-db.sh` |
| **Backup** Local DB | `./backup-db.sh project_name postgres` |
| **Stop & Remove** Stack | `./remove-db.sh project_name` |
| **Purge** Everything | `./remove-db.sh project_name --delete-data` |

---

## 🔐 Database Credentials

Credentials are generated based on the **project name** by default.

| Field | Value |
| :--- | :--- |
| **Username** | `project_name` |
| **Password** | `project_name` |
| **Database** | `project_name` |

> [!NOTE]
> The `sync-db.sh` script is smart — it automatically detects if your local container uses different credentials (like `fikri`, `root`, or `admin`) and uses them accordingly.

---

## ❓ Troubleshooting

**Q: Permission Denied on `pg_filenode.map`?**
A: This tool is already fixed! It forces connections via `127.0.0.1` instead of Unix sockets to bypass Docker permission issues.

**Q: Role "admin" does not exist during restore?**
A: The sync script uses `--no-owner` and `--no-privileges` automatically, so data from _any_ live user can be restored to your local user without errors.

---

## License

Feel free to use this template for all your internal project developments. Happy Coding! 🚀