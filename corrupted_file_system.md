Summary of the Troubleshooting and Recovery Procedure
1. Issue Overview

An unexpected power outage (forced shutdown) occurred while an OS/container update was in progress on a Flightctl-managed Edge device running a bootc-based RHEL 10 environment.

After the device powered back on, the update process became stuck with a prefetch failed error and could no longer proceed.

2. Root Cause

The sudden power loss interrupted the container image download and extraction process, resulting in logical corruption within the Podman/OverlayFS container storage.

Specifically, the symbolic link structure (OverlayFS index metadata) became inconsistent, causing the following persistent error:

readlink /var/lib/containers/storage/overlay/l: invalid argument

Standard cleanup operations such as podman system prune were insufficient because they could not remove the corrupted OverlayFS metadata itself.

As a result:

Image download attempts repeatedly failed at the same point
Flightctl continuously retried the prefetch operation
The update workflow remained permanently stuck
3. Established Recovery Procedure

If a similar issue occurs due to a power outage or unexpected shutdown during an update, the device can be safely recovered using the following procedure.

Step 1. Stop the Flightctl Agent

First, stop the Flightctl Agent to prevent further writes to the corrupted container storage.

sudo systemctl stop flightctl-agent
Step 2. Fully Reset the Podman Storage

Completely reset the local container storage, including all OverlayFS metadata.

sudo podman system reset

If prompted for confirmation, enter y to continue.

This operation fully clears /var/lib/containers/storage and removes the corrupted OverlayFS structures.

Step 3. Restart the Flightctl Agent

After the storage has been cleaned, restart the Flightctl Agent.

sudo systemctl start flightctl-agent

The agent will begin downloading and processing the container image again from the beginning.

Step 4. Monitor the Recovery Progress

Monitor the agent logs to confirm that the image pull operation proceeds normally.

sudo journalctl -u flightctl-agent -f

Verify that the Pulling image... process continues without repeating the previous error.
