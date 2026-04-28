In `flightctl`, resources follow a strict hierarchy. You must first define the "container" (the **Catalog**) before you can add "content" (the **CatalogItem**) to it.

---

### Step 1: Create the Catalog
The Catalog resource acts as a logical grouping or repository.

1. **Create the file**: `catalog.yaml`
   ```yaml
   apiVersion: flightctl.io/v1alpha1
   kind: Catalog
   metadata:
     name: infrastructure
   spec:
     displayName: Infrastructure Services
   ```

2. **Apply the configuration**:
   ```bash
   flightctl apply -f catalog.yaml
   ```

---

### Step 2: Create the CatalogItem
Now that the `infrastructure` catalog exists, you can register the Keycloak item.

1. **Create the file**: `catalog-item.yaml`
   ```yaml
   apiVersion: flightctl.io/v1alpha1
   kind: CatalogItem
   metadata:
     name: keycloak
     catalog: infrastructure  # Must match the metadata.name in Step 1
     labels:
       category: security
   spec:
     type: container
     displayName: Keycloak
     shortDescription: Open source identity and access management
     artifacts:
       - type: container
         uri: quay.io/keycloak/keycloak
     versions:
       - version: "24.0.4"
         references:
           container: "24.0.4"
         channels:
           - stable
       - version: "25.0.1"
         references:
           container: "25.0.1"
         channels:
           - stable
           - candidate
         replaces: "24.0.4"
   ```

2. **Apply the configuration**:
   ```bash
   flightctl apply -f catalog-item.yaml
   ```

---

### Step 3: Verify the Registration
Check that both resources are correctly recognized by the system.

1. **List all Catalogs**:
   ```bash
   flightctl get catalogs
   ```

2. **List all CatalogItems**:
   ```bash
   flightctl get catalogitems
   ```

3. **Inspect specific details** (to see versioning and channels):
   ```bash
   flightctl get catalogitem keycloak -o yaml
   ```
