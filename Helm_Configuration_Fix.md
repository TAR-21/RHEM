# 📄 Flightctl Restoration & Helm Configuration Fix Documentation

## 1. Database Persistent Volume Permission Fix

**[Issue]**  
After the Helm deployment, `flightctl-db` failed to start with a `Permission denied` error.

**[Cause]**  
The ownership of the PVC created by the Helm chart did not match the PostgreSQL execution user (UID 26), preventing the container from creating initial directories.

**[Permanent Fix (Helm Configuration)]**  
Set the `db.builtin.fsGroup` parameter in your `values.yaml` to ensure the volume is writable by the PostgreSQL group:

```yaml
db:
  builtin:
    fsGroup: 26  # Force volume ownership to the PostgreSQL group
```

This renders the following `securityContext` in the `flightctl-db` Deployment:

```yaml
spec:
  template:
    spec:
      securityContext:
        fsGroup: 26
```

**[Implemented Workaround]**  
Deployed a temporary root-privileged Pod to manually fix the directory ownership.

> **Note:** Running as root (UID 0) requires the `anyuid` or `privileged` SCC. Grant it to the default ServiceAccount before running the command:
> ```bash
> oc adm policy add-scc-to-user anyuid -z default -n <namespace>
> ```

```bash
oc run fix-db --image=busybox --restart=Never --overrides='{"spec":{"containers":[{"name":"fix","image":"busybox","command":["sh","-c","chown -R 26:26 /var/lib/pgsql/data"],"securityContext":{"runAsUser":0},"volumeMounts":[{"name":"data","mountPath":"/var/lib/pgsql/data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"flightctl-db"}}]}}'
```

> After confirming the fix, revoke the SCC and delete the temporary Pod:
> ```bash
> oc delete pod fix-db
> oc adm policy remove-scc-from-user anyuid -z default -n <namespace>
> ```

---

## 2. Resolving Pod Init-Loops (Dependency Management)

**[Issue]**  
Other Pods remained in `Init:CrashLoopBackOff` even after the DB was fixed.

**[Cause]**  
The Kubernetes exponential back-off timer caused a long delay (up to 5 minutes) before the next retry attempt.

**[Action]**  
Forced an immediate restart of all Flightctl deployments to trigger a clean startup sequence and database connection.

```bash
oc rollout restart deployment -l flightctl.service
```

---

## 3. Enabling OpenShift Console Plugin

**[Issue]**  
The `ConsolePlugin` resource was deployed by Helm, but the "Edge Management" menu did not appear in the OpenShift Web Console.

**[Cause]**  
The plugin `flightctl-plugin` was not registered in the cluster-wide console configuration (`consoles.operator.openshift.io/cluster`).

**[Fix]**  
Patched the cluster configuration to enable the plugin.

If no plugins have been enabled yet (the `spec.plugins` field does not exist):

```bash
oc patch consoles.operator.openshift.io cluster --type=json \
  -p '[{"op": "add", "path": "/spec/plugins", "value": ["flightctl-plugin"]}]'
```

If other plugins are already enabled (append to the existing list):

```bash
oc patch consoles.operator.openshift.io cluster --type=json \
  -p '[{"op": "add", "path": "/spec/plugins/-", "value": "flightctl-plugin"}]'
```
