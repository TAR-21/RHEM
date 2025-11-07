# 🚀 Summary of RHEM Initial Setup and Operational Verification

This document summarizes the steps for FlightCtl initial setup, CLI installation, host configuration, and building and publishing a custom OS image containing the agent.

-----

## 💻 1. FlightCtl API Endpoint Verification

Verify the endpoints for various FlightCtl services.

### FlightCtl API Route Information

| Service | Hostname/URL | Port | Purpose |
| :--- | :--- | :--- | :--- |
| **FlightCtl API** | `https://api.apps.krm1027.krm.local` | `3443` | Used for `flightctl login` (Main API) |
| **FlightCtl Agent API** | `https://agent-api.apps.krm1027.krm.local` | `7443` | Agent communication (For device enrollment) |
| **CLI Artifacts** | `https://cli-artifacts.apps.krm1027.krm.local` | `8090` | Distribution of CLI binaries, etc. |

### Verification of Services and Routes on OpenShift

Use `oc get` commands to confirm that the services and routes are correctly deployed on the OpenShift cluster.

  * **Service (ClusterIP) Verification**
    ```bash
    oc get svc -n open-cluster-management | grep flightctl-api
    # flightctl-api ... 3443/TCP
    # flightctl-api-agent ... 7443/TCP
    ```
  * **Route Verification**
    ```bash
    oc get route flightctl-api-route -n open-cluster-management -o wide
    # NAME: flightctl-api-route, HOST/PORT: api.apps.krm1027.krm.local, PORT: 3443
    ```

-----

## 🛠️ 2. Client Host Preparation

Preparation steps on the host where the CLI will run.

### Enabling Repository and Installing the CLI

1.  **Search for the appropriate repository for the system**
    ```bash
    subscription-manager repos --list | grep rhacm
    ```
2.  **Enable the repository**
    ```bash
    subscription-manager repos --enable rhacm-2.14-for-rhel-9-x86_64-rpms
    ```
3.  **Install the `flightctl` CLI**
    ```bash
    sudo dnf install flightctl
    ```

### `/etc/hosts` Configuration

Add the following entries to `/etc/hosts` so the client host can resolve the FlightCtl API endpoints.

```text
192.168.3.127   api.apps.krm1027.krm.local
192.168.3.127   agent-api.apps.krm1027.krm.local
192.168.3.127   cli-artifacts.apps.krm1027.krm.local
```

-----

## 🔑 3. Login to FlightCtl and Credential Retrieval

### Login to FlightCtl

Log in to `flightctl` using the provided credentials.

```bash
flightctl login \
  --username=kubeadmin \
  --password=******** \
  --insecure-skip-tls-verify \
  https://api.apps.krm1027.krm.local
```

> **Note:** The actual password is **masked for security reasons**.

### Retrieve Agent Enrollment Credentials

Generate the configuration file required for the device to enroll with FlightCtl.

```bash
flightctl certificate request --signer=enrollment --expiration=365d --output=embedded > config.yaml
```

-----

## 📦 4. Building and Publishing Custom RHEL Bootc Image

Create a custom OS image containing the agent (`flightctl-agent`) and publish it to a registry.

### Working Directory Preparation

```bash
mkdir -p rhel9.5-imagemode
cd rhel9.5-imagemode
sudo cp /etc/yum.repos.d/redhat.repo .
```

### `Containerfile` Creation and Customization

The `Containerfile` integrates `flightctl-agent`, `NetworkManager`, and `openssh-server`, defines a specific user (`demo:redhat`) and hostname, and enables services (`sshd`, `flightctl-agent`).

  * **Key Configuration Points**
      * Include the host's `redhat.repo` to enable installation of the `flightctl-agent` package.
      * Install `flightctl-agent`, `NetworkManager`, and `openssh-server`.
      * Create a demo user (`demo:redhat`) and configure `sudo` access.
      * Enable `sshd.service` and `flightctl-agent.service`.
      * **Mask** `bootc-fetch-apply-updates.timer` to delegate update management to Edge Manager.
      * Set image metadata like `bootc-image="true"`.

### Container Image Build and Publication

1.  **Set Environment Variables**
    ```bash
    export OCI_IMAGE_REPO="quay.io/*********/custom-rhel95-bootc"
    export OCI_IMAGE_TAG="1.0.0"
    ```
    > **Note:** The username is **masked**.
2.  **Build the Image**
    ```bash
    sudo podman build -t ${OCI_IMAGE_REPO}:${OCI_IMAGE_TAG} .
    ```
3.  **Login and Push to Registry (Quay.io)**
    ```bash
    sudo podman login quay.io # Skip if already logged in
    sudo podman push ${OCI_IMAGE_REPO}:${OCI_IMAGE_TAG}
    ```

### ISO Image Generation

Convert the built container image into an ISO file suitable for deployment on physical devices.

```bash
mkdir -p output
sudo podman run --rm -it --privileged \
    --security-opt label=type:unconfined_t \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v "${PWD}/output":/output \
    registry.redhat.io/rhel9/bootc-image-builder:latest \
    --type iso \
    --output /output \
    --progress=verbose \
    ${OCI_IMAGE_REPO}:${OCI_IMAGE_TAG}
```

The generated ISO image is saved in the `output` directory.
