### 1. Make setup-press-vm.sh Executable & Run

```bash
chmod +x ~/setup/setup-press-vm.sh
sudo ~/setup/setup-press-vm.sh
```

Wait for it to complete — it may take 5–10 minutes depending on network speed.

---

### 2. Reboot (Optional but Recommended)

```bash
sudo reboot
```

After reboot, log back in as `frappe`:

```bash
ssh frappe@192.168.182.133
```

## ✅ Fix: Install `frappe-bench` Correctly (as `frappe` user)

### 🛠️ Step-by-Step

#### 1. **Uninstall the root-installed bench**
```bash
sudo pip3 uninstall frappe-bench honcho -y
```

#### 2. **Install bench for `frappe` user (no sudo!)**
```bash
# Switch to frappe user (if not already)
whoami  # should say "frappe"

# Install bench locally
pip3 install --user frappe-bench

# Add ~/.local/bin to PATH (persistent)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify
which bench
# Should return: /home/frappe/.local/bin/bench

bench --version
# Should return: 5.27.0
```

