## 💾 ODF Installation Preparation and Cleanup Procedure

### 1\. 🛠️ ODF Pre-Installation Setup

Prior to installing RHEM (Red Hat Enterprise Migration Toolkit for Virtualization), the following components need to be prepared:

  * **OpenShift (OCP)**
  * **OpenShift Data Foundation (ODF)**
  * **Advanced Cluster Management for Kubernetes (ACM)**

During this process, the creation of the **`Storage System` resource**, which occurs after installing the **ODF operator**, can sometimes **fail**. If a failure occurs, it is necessary to **fully clean up the environment** and perform a **reinstallation**.

-----

### 2\. ❌ Cleanup Procedure After `Storage System` Creation Failure

If the ODF installation fails midway, you must execute the **official uninstallation procedure** and then **completely erase any residual data** on the nodes.

#### 2.1. 📝 Execute the Official ODF Uninstallation Procedure

First, perform the **official ODF uninstallation** following the steps in the Red Hat Customer Portal documentation below:

> **🔗 Red Hat Customer Portal**
> [Uninstalling OpenShift Data Foundation in Internal mode](https://access.redhat.com/articles/6525111)

#### 2.2. 💻 Thorough Data Erasure on Nodes

Sometimes, data remnants persist after the official uninstallation, which can prevent a successful reinstallation. In this case, SSH into the ODF nodes (the nodes providing storage functionality) and **manually and completely erase the storage-related data.**

> **⚠️ Note**
> This procedure involves **destructively deleting existing data and configuration** on the nodes. **Always confirm that the target device and paths are exclusively allocated for ODF** before execution. Specifically, confirm that **`/dev/sdb`** is the disk allocated for ODF.

1.  **Remove the Rook and Local Storage directories.**

    ```bash
    rm -rf /var/lib/rook
    rm -rf /mnt/local-storage/
    ```

2.  **Thoroughly erase information from the disk used by ODF (Example: `/dev/sdb`).**

      * Confirm that the device was previously used by `ceph-osd` before proceeding.
      * The following commands write zeros to the **beginning and end** of the disk, **aggressively erasing any traces** of partition tables or file systems.

    <!-- end list -->

    ```bash
    # Overwrite the first 100MB of the disk with zeros
    dd if=/dev/zero of=/dev/sdb bs=1M count=100

    # Get the disk size and overwrite the last 1000 blocks with zeros (erasing metadata areas)
    DISK_SIZE=$(blockdev --getsz /dev/sdb)
    dd if=/dev/zero of=/dev/sdb bs=512 seek=$(($DISK_SIZE - 1000)) count=1000

    # Erase all partition tables (GPT/MBR, etc.)
    sgdisk --zap-all /dev/sdb

    # Erase all file system, RAID, and LVM signatures
    wipefs -a /dev/sdb
    ```

Performing this **thorough erasure** returns the node to a clean state, significantly increasing the probability of a successful reinstallation of **ODF (verified with version 4.19.6)**.
