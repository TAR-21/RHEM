# Building a Bare Metal ISO for Red Hat Edge Manager (RHEL 10 bootc)

This guide describes how to build a custom **RHEL 10 bootc** image with the **Red Hat Edge Manager (RHEM) Agent**, publish it to an OCI registry, and generate a bootable ISO for bare metal deployment.

---

# Prerequisites

- A RHEL 10 build host
- Podman installed
- Access to `registry.redhat.io`
- Access to an OCI registry (Quay.io is used in this example)
- A valid Red Hat subscription
- A valid `config.yaml` generated for the Flight Control Agent (Early Binding)

---

# Step 1. Configure Your OCI Registry

Replace `<your_quay_username>` with your own Quay.io username or organization name.

```bash
export VERSION=v1.0.0
export REGISTRY_USER="<your_quay_username>"
export OCI_IMAGE_REPO="quay.io/${REGISTRY_USER}/simple-bootc-rhel10"
```

---

# Step 2. Log in to the OCI Registry

```bash
sudo podman login quay.io
```

---

# Step 3. Create the Containerfile

Create a file named **Containerfile**.

```Dockerfile
FROM registry.redhat.io/rhel10/rhel-bootc:latest

#
# Enable the Red Hat Edge Manager repository
#
RUN dnf config-manager \
      --set-enabled edge-manager-1.2-for-rhel-10-$(uname -m)-rpms

#
# Install the Flight Control Agent
#
RUN dnf -y install flightctl-agent && \
    dnf clean all

#
# Enable the Flight Control Agent service
#
RUN systemctl enable flightctl-agent.service

#
# Create the Flight Control configuration directory
#
RUN mkdir -p /etc/flightctl

#
# Copy the Flight Control Agent configuration.
# A valid config.yaml must exist in the build directory.
#
ADD config.yaml /etc/flightctl/

LABEL \
    containers.bootc="1" \
    ostree.bootable="1" \
    redhat.id="rhel" \
    redhat.version-id="10.2" \
    description="RHEL 10 bootc with Red Hat Edge Manager Agent"

ENV container=oci

STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]
```

---

# Step 4. Build the bootc Container Image

```bash
sudo podman build \
    --platform=linux/amd64 \
    --security-opt=label=disable \
    --cap-add=all \
    --device=/dev/fuse \
    -t ${OCI_IMAGE_REPO}:${VERSION} .
```

---

# Step 5. Push the Image to the OCI Registry

```bash
sudo podman push ${OCI_IMAGE_REPO}:${VERSION}
```

---

# Step 6. Pull the bootc-image-builder Image

```bash
podman pull registry.redhat.io/rhel10/bootc-image-builder:latest
```

---

# Step 7. Create an Output Directory

```bash
mkdir -p output
```

---

# Step 8. Generate the Bare Metal ISO

```bash
sudo podman run --rm -it \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v ${PWD}/output:/output \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    registry.redhat.io/rhel10/bootc-image-builder:latest \
    --type iso \
    ${OCI_IMAGE_REPO}:${VERSION}
```

When the build completes, the generated ISO will be stored in the `output` directory.

Example:

```text
output/
└── iso/
    └── install.iso
```

> **Note:** Depending on the version of `bootc-image-builder`, the output directory name may differ slightly.

---

# Step 9. Create a Bootable USB Drive

Identify your USB device.

```bash
lsblk
```

Write the ISO image to the USB drive.

```bash
sudo dd if=output/iso/install.iso \
    of=/dev/sdX \
    bs=4M \
    status=progress \
    oflag=sync
```

Replace `/dev/sdX` with the correct USB device.

---

# Step 10. Install on Bare Metal

1. Boot the target machine from the USB drive.
2. Select **Install RHEL bootc**.
3. Complete the installation.
4. Reboot the system.

The installed operating system includes:

- RHEL 10 bootc
- Red Hat Edge Manager Agent (`flightctl-agent`)
- `/etc/flightctl/config.yaml`


---

# Architecture

```text
              +-----------------------------+
              |      Containerfile          |
              +--------------+--------------+
                             |
                             v
              +-----------------------------+
              | Custom RHEL 10 bootc Image  |
              | + flightctl-agent           |
              | + config.yaml               |
              +--------------+--------------+
                             |
                             v
              +-----------------------------+
              |      OCI Registry           |
              |     (e.g. Quay.io)          |
              +--------------+--------------+
                             |
                             v
              +-----------------------------+
              |    bootc-image-builder      |
              +--------------+--------------+
                             |
                             v
              +-----------------------------+
              |      Bare Metal ISO         |
              +--------------+--------------+
                             |
                             v
              +-----------------------------+
              |     Physical Hardware       |
              +--------------+--------------+
                             |
                             v
              +-----------------------------+
              |    flightctl-agent          |
              +--------------+--------------+
                             |
                             v
              +-----------------------------+
              | Red Hat Edge Manager (RHEM) |
              +-----------------------------+
```

---

# Summary

This workflow performs the following tasks:

1. Builds a custom RHEL 10 bootc container image.
2. Installs the Red Hat Edge Manager Agent.
3. Embeds the enrollment configuration (`config.yaml`) into the image using the **Early Binding** model.
4. Pushes the image to an OCI registry.
5. Uses `bootc-image-builder` to generate a bootable ISO.
6. Installs the customized operating system onto bare metal hardware.
7. Automatically registers the installed system with Red Hat Edge Manager.
