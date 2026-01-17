# Frappe Cloud Local Replica — Changelog

## Goal
Build a local, multi-VM replica of Frappe Cloud infrastructure using Frappe Press (v15-compatible), mimicking production architecture:
- `press` (control plane)
- `build`
- `database`
- `proxy`
- `worker`

Target: Fully functional, scriptable deployment pipeline — to later scale to bare metal & SaaS.

> ✅ **Current Scope (v1)**: Single `press` VM (NAT mode) with base OS + dependencies  
> 🔄 Next: Install Frappe Bench, Press app, and MariaDB (local DB for now)

---

## Status
⚠️ **Only `press` VM is active** — using NAT (`192.168.182.133`)  
✅ Bench dependencies installed  
❌ MariaDB not installed yet  
❌ Press app not cloned  
❌ `press.local` site not created

| Step | Status | Notes |
|------|--------|-------|
| ✅ Step 0: Changelog initialized | Done | v0.1–v2.1 maintained |
| ✅ Step 1: VM provisioning (press only) | Done | NAT mode, no LVM, `frappe` user |
| ✅ Step 2: Base OS hardening | Done | Swap, SSH, UFW, Node.js 20, Redis, Docker |
| ⚠️ Step 3: Press dependencies installed | Partial | `bench` ✅, but **MariaDB missing** |
| ❌ Step 4: Press app deployed | Not started | Requires `bench init` → `get-app press` |
| ❌ Step 5–9 | Not started | Will follow after Press UI is up |

---

## Completed Steps

### ✅ Step 0: Changelog Initialized  
- **When**: 2025-11-20 12:00 UTC  
- **What**: Created foundational `changelog.md`.  
- **Pain Points**: None.

### ✅ Step 1: Press VM Provisioning (NAT Mode)  
- **When**: 2025-11-20 14:30–2025-11-21 02:30 UTC  
- **What**:
  - Created single Ubuntu 22.04 VM (`press`) in VMware Workstation.
  - **Switched to NAT mode** (host-only failed due to gateway issue).
  - Assigned DHCP IP: `192.168.182.133`.
  - Skipped LVM (unnecessary for control plane).
  - Created `frappe` user (non-root).
- **Pain Points**:
  - Host-only networking failed repeatedly (`192.168.10.x`), even after `vmnetcfg.exe /reset`, adapter re-enable, and gateway config.
  - **Root cause**: Host-only has no NAT → no internet → no `apt install`.
  - **Resolution**: Use NAT for initial install → switch to host-only later (after Press UI is up).

### ⚠️ Step 2: Base OS Hardening & Dependency Setup  
- **When**: 2025-11-21 03:00–05:30 UTC  
- **What**:
  - Ran `setup-press-vm.sh v2.0` to:
    - Set timezone (`UTC`), locale (`en_US.UTF-8`)
    - Skip redundant swap creation (already exists)
    - Harden SSH (`PasswordAuthentication no`, `PermitRootLogin no`)
    - Install: Git, Wget, UFW, Redis, Docker, Python 3.10
    - ✅ Install **Node.js 20 LTS** (replacing deprecated Node.js 18)
    - Configure UFW (ports 22, 80, 443, 8000, 9000)
    - Set hostname + `/etc/hosts`: `press.local` → `192.168.182.133`
    - Ensure `frappe` user has passwordless sudo
  - Fixed `bench` install path (was in `/root/.local/bin` due to `sudo pip`).
  - Added `~/.local/bin` to `PATH`, verified `bench --version == 5.27.0`.
- **Pain Points**:
  - `fallocate: Text file busy` → swap already active → added conditional check.
  - Node.js 18 EOL warning → upgraded to **Node.js 20** (confirmed compatible with Frappe v15.21+ [[Frappe GitHub]]).
  - `pip install --user` under `sudo` → scripts in `/root/` → reinstalled as `frappe` user.
  - `dpkg` service restart dialogs → manually selected all services → safe.
- **Validation**:
  ```bash
  node --version   # v20.18.0 ✅
  bench --version  # 5.27.0 ✅
  systemctl is-active redis-server  # active ✅
  ufw status       # Status: active ✅
  ```
### ✅ Step 3: Installed & Secured MariaDB (Root Password = `123`)
- **When**: 2025-11-21 06:45 UTC
- **What**:
  - Installed MariaDB server/client:
    ```bash
    sudo apt install mariadb-server mariadb-client
    ```
  - Ran `sudo mysql_secure_installation` with:
    - Current password: `Enter` (none)
    - Switch to unix_socket: `n`
    - Set root password: `Y` → `123`
    - Remove anonymous users: `Y`
    - Disallow root login remotely: `Y`
    - Remove test DB: `Y`
    - Reload privileges: `Y`
  - Verified login:
    ```bash
    mysql -u root -p123  # ✅ Success
    ```
- **Pain Points / Notes**:
  - Initially failed due to password not taking — resolved via safe-mode reset.
  - Using `123` for dev avoids confusion with default Frappe `admin` site password.
  - **Critical**: Always verify `mysql -u root -p<password>` before proceeding to `bench init`.

### ⚠️ Step 4: Initialized Frappe Bench + Installed Press App
- **When**: 2025-11-21 07:00 UTC
- **What**:
  - Installed build deps: `libmariadb-dev-compat`, `node-gyp`, image libs.
  - Ran:
    ```bash
    bench init --frappe-branch version-15 frappe-bench
    cd frappe-bench
    bench get-app press https://github.com/frappe/press
    bench new-site press.local --mariadb-root-password 123 --admin-password admin --no-mariadb-socket
    bench --site press.local install-app press
    bench start
    ```
  - Accessed `http://192.168.182.133:8000` → Press login UI ✅
- **Pain Points / Notes**:
  - Critical to use `--no-mariadb-socket` to avoid permission issues with `/var/run/mysqld/mysqld.sock`.
  - Memory pressure during `Building assets` — 4 GB RAM is minimum; consider adding swap if hangs.
  - Always run `bench` as `frappe` user (never `sudo`).

### ⚠️ Step 4.1: Fixed Missing Yarn Dependency
- **When**: 2025-11-21 07:30 UTC
- **What**:
  - Encountered `FileNotFoundError: [Errno 2] No such file or directory: 'yarn'` during `bench get-app`.
  - Installed Yarn via official Debian repo:
    ```bash
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    sudo apt update && sudo apt install yarn
    ```
  - Verified: `yarn --version` → `1.22.19`
  - Retried `bench get-app press` → successful.
- **Pain Points / Notes**:
  - Frappe v15 requires Yarn (not npm) for asset building.
  - Always install Yarn before `bench init` or `get-app`.
  - Never run `npm install -g yarn` — use system package manager for stability.

### ⚠️ Step 4.2: Fixed Press App Branch Name
- **When**: 2025-11-21 08:00 UTC
- **What**:
  - Encountered error: `fatal: Remote branch version-15 not found` during `bench get-app press`.
  - Diagnosed that `frappe/press` has no `version-15` branch.
  - Cloned using `--branch develop` instead:
    ```bash
    bench get-app press https://github.com/frappe/press --branch develop
    ```
  - Successfully cloned and installed Press app.
- **Pain Points / Notes**:
  - Frappe apps often use `develop` for active development — never assume `version-X` branches exist unless documented.
  - Always check `https://github.com/frappe/press/branches` before cloning.
  - `bench get-app` without `--branch` uses the default branch (usually safe).

### ✅ Step 4.3: Verified Frappe & Press Apps in Bench
- **When**: 2025-11-21 08:30 UTC
- **What**:
  - Confirmed `~/frappe-bench/apps/` contains:
    - `frappe` (v15)
    - `press` (from `develop` branch)
  - Ready for site creation.
- **Pain Points / Notes**:
  - Branch naming (`develop` vs `version-15`) is consistently confusing — always check repo branches first.
  - Press is a full Vue SPA — `bench build` takes longer than ERPNext (~2–3 min).

### ✅ Step 4.4: Created `press.local` Site Successfully
- **When**: 2025-11-21 09:00 UTC
- **What**:
  - Ran:
    ```bash
    bench new-site press.local \
      --mariadb-root-password 123 \
      --admin-password admin \
      --no-mariadb-socket
    ```
  - Site created ✅ at `sites/press.local/`
  - Received deprecation warning for `--no-mariadb-socket`:
    > *“use --mariadb-user-host-login-scope='%' instead”*
  - Ignored for now (works in dev); will use new flag in production.
- **Pain Points / Notes**:
  - Deprecation warnings are common in evolving CLI tools — as long as it works, proceed.
  - Scheduler is disabled by default — we’ll enable it later for backups/updates.

### ✅ Step 4.6: Logged into Frappe Framework UI (Not Press Yet)
- **When**: 2025-11-21 10:00 UTC
- **What**:
  - Ran `bench use press.local` → set current site.
  - Accessed `http://192.168.182.133:8000` → saw “Login to Frappe” screen.
  - Diagnosed that Press app was not installed on site.
  - Ran `bench --site press.local install-app press` → installed Press app.
  - Restarted server: `bench restart`
  - Will re-access URL to see Press UI.
- **Pain Points / Notes**:
  - Common confusion: Frappe Framework UI vs Press app UI.
  - Always run `install-app press` after `new-site` if you want the Press dashboard.
  - Press is a separate app — not part of Frappe core.

