# Trustify (trustd-pm) Installation Guide on RHEL 10

This guide outlines the steps to install **Trustify** in Personal Machine mode (`trustd-pm`) on RHEL 10 and configure it for external network access.

---

## 1. Prerequisites

### 1.1 Install Required Packages
Install `curl` for downloading the binary and `file` for verifying the file type (run as root).

```bash
sudo dnf install -y curl file

```

### 1.2 Verify IPv6 Enablement

Trustify relies on the IPv6 loopback interface (`::1`) for its internal microservices communication. Verify that IPv6 is enabled.

```bash
ip addr show lo

```

*Note: Ensure that `inet6 ::1/128 scope host` is present in the output.*

---

## 2. Create and Configure a Non-Root User

For security reasons, Trustify’s embedded PostgreSQL database **is strictly prohibited from running as the root user**. You must create a dedicated unprivileged user.

```bash
# Create a new user (e.g., trustuser)
sudo useradd trustuser

# Set a password for the user
sudo passwd trustuser

# (Optional) Grant sudo privileges
sudo usermod -aG wheel trustuser

```

---

## 3. Download and Install the Trustify Binary

Fetch the Linux x86_64 archive from the official GitHub releases (this guide uses the verified stable version v0.4.12) and place it into the system path.

```bash
# Download the archive
curl -L -O [https://github.com/guacsec/trustify/releases/download/v0.4.12/trustd-0.4.12-x86_64-unknown-linux-gnu.tar.gz](https://github.com/guacsec/trustify/releases/download/v0.4.12/trustd-0.4.12-x86_64-unknown-linux-gnu.tar.gz)

# Extract the archive
tar -xvf trustd-0.4.12-x86_64-unknown-linux-gnu.tar.gz

# Grant execution permissions to the binary
chmod +x trustd-0.4.12-x86_64-unknown-linux-gnu/trustd

# Move and rename the binary to a global system path
sudo mv trustd-0.4.12-x86_64-unknown-linux-gnu/trustd /usr/local/bin/trustd-pm

# (Verification) Check if it is a valid executable
file /usr/local/bin/trustd-pm
# Expected output: ELF 64-bit LSB executable, x86-64...

```

---

## 4. Firewall (Firewalld) Configuration

By default, RHEL blocks external incoming traffic. Open port `8080` to allow access to the Trustify Web UI from other machines.

```bash
# Permanently allow port 8080/tcp
sudo firewall-cmd --permanent --add-port=8080/tcp

# Reload the firewall configuration
sudo firewall-cmd --reload

# Verify the opened ports
sudo firewall-cmd --list-ports

```

---

## 5. Launch Trustify with External Access

Switch to the newly created non-root user and launch `trustd-pm` using environment variables to bind the service to all available network interfaces (`0.0.0.0`).

```bash
# Switch to the non-root user
su - trustuser

# Start Trustify listening on all interfaces
HTTP_BIND_ADDR=0.0.0.0 INFRASTRUCTURE_BIND_ADDR=0.0.0.0 trustd-pm

```

> **💡 Run in Background (Persistent Execution):**
> To keep Trustify running even after closing your terminal session, use `nohup`:
> ```bash
> HTTP_BIND_ADDR=0.0.0.0 INFRASTRUCTURE_BIND_ADDR=0.0.0.0 nohup trustd-pm > ~/trustify.log 2>&1 &
> 
> ```
> 
> 

---

## 6. Accessing the Web UI

Once started, open a web browser on any machine within the same network and navigate to your RHEL server's IP address:

* **Web UI (Dashboard):** `http://<RHEL_SERVER_IP>:8080`
* **REST API Documentation:** `http://<RHEL_SERVER_IP>:8080/openapi/`

```

```
