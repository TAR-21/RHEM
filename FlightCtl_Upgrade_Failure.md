# FlightCtl Upgrade Failure from 1.1.2 to 1.2.0 Due to Registry Authentication Check

## Environment

* OS: RHEL 10
* FlightCtl Server Version: 1.1.2
* Target Version: 1.2.0
* Registry: registry.redhat.io

---

## Issue

Attempting to upgrade FlightCtl from 1.1.2 to 1.2.0 failed with the following error:

```bash
dnf -y update
```

```text
flightctl: not authenticated to registry.redhat.io.
Run 'sudo podman login registry.redhat.io' before upgrading.

error: %prein(flightctl-services-1.2.0-1.el10.x86_64) scriptlet failed, exit status 1

Error in PREIN scriptlet in rpm package flightctl-services
```

However, the system was already authenticated to the registry.

```bash
sudo podman login registry.redhat.io
```

Output:

```text
Authenticating with existing credentials for registry.redhat.io
Existing credentials are valid.
Already logged in.
```

---

## Investigation

### Verify Registry Authentication

```bash
podman login --get-login registry.redhat.io
```

Output:

```text
tmorisu@redhat.com
```

Authentication appeared to be valid.

---

### Verify Image Pull

```bash
podman pull registry.redhat.io/rhem/flightctl-api-rhel10:1.2.0
```

Result:

```text
Writing manifest to image destination
Storing signatures
...
```

The image pull succeeded.

---

### Verify Manifest Inspection

```bash
podman manifest inspect \
registry.redhat.io/rhem/flightctl-api-rhel10:1.2.0
```

Result:

```text
Error: reading image ...
unable to retrieve auth token:
invalid username/password
```

This operation failed despite successful authentication and image pulls.

---

## Analysis of RPM Pre-Install Script

The pre-install script of the FlightCtl 1.2.0 RPM package was inspected:

```bash
rpm -qp --scripts flightctl-services-1.2.0-1.el10.x86_64.rpm
```

The package performs a pre-upgrade validation using:

```bash
podman manifest inspect <image>
```

If this command fails, the RPM reports:

```text
flightctl: not authenticated to registry.redhat.io
```

and aborts the upgrade.

---

## Authentication File Investigation

Checking the authentication file used by Podman:

```bash
podman login --verbose registry.redhat.io
```

Output:

```text
Used: /run/user/0/containers/auth.json
Login Succeeded!
```

Authentication credentials were stored in:

```text
/run/user/0/containers/auth.json
```

However:

```bash
find /root -name auth.json
```

returned no results.

The standard root authentication file did not exist:

```text
/root/.config/containers/auth.json
```

---

## Resolution

Create the standard Podman authentication directory and copy the existing credentials:

```bash
mkdir -p /root/.config/containers

cp /run/user/0/containers/auth.json \
   /root/.config/containers/auth.json

chmod 600 /root/.config/containers/auth.json
```

---

## Verification

After copying the authentication file:

```bash
podman manifest inspect \
registry.redhat.io/rhem/flightctl-api-rhel10:1.2.0 >/dev/null && echo OK
```

Output:

```text
OK
```

The registry authentication check succeeded.

---

## Upgrade Retry

Re-running the upgrade:

```bash
dnf -y update
```

Result:

```text
Upgraded:
  flightctl-services-1.2.0-1.el10.x86_64
  flightctl-cli-1.2.0-1.el10.x86_64
```

The upgrade completed successfully.

---

## Version Verification

```bash
flightctl version
```

Output:

```text
Client Version: v1.2.0
Server Version: v1.2.0
```

---

## Root Cause

The FlightCtl 1.2.0 RPM pre-install script validates required container images using:

```bash
podman manifest inspect
```

The system was authenticated, but the credentials existed only in:

```text
/run/user/0/containers/auth.json
```

During RPM scriptlet execution, Podman did not appear to locate or use this authentication file, causing:

```bash
podman manifest inspect
```

to fail with:

```text
unable to retrieve auth token:
invalid username/password
```

As a result, the RPM incorrectly reported:

```text
flightctl: not authenticated to registry.redhat.io
```

and aborted the upgrade.

Copying the authentication file to:

```text
/root/.config/containers/auth.json
```

resolved the issue and allowed the upgrade to proceed successfully.

---

## Potential Product Issue

This behavior may indicate a bug or design issue in the FlightCtl 1.2.0 upgrade validation logic.

Specifically:

* `podman login` succeeds
* `podman pull` succeeds
* `podman manifest inspect` fails during RPM pre-install validation
* The RPM upgrade aborts despite valid registry credentials

The validation logic may not correctly handle authentication credentials stored only under:

```text
/run/user/<uid>/containers/auth.json
```

and may require support for alternate Podman credential locations.
