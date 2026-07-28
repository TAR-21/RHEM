# How to Use the Generated Client in a Python Application

Using an auto-generated client (SDK) eliminates the need to manually construct URLs, headers, and types with `requests` or `urllib`. Instead, you can call API endpoints as **type-hinted Python methods**.

Below is a step-by-step guide using the Python (`python`) generator.

---

## Workflow Overview

```
[1. Generate] ──► [2. Configure & Initialize] ──► [3. Call API Methods]
```

---

## Step 1: Generate the Client Code

First, prepare the OpenAPI spec file. If you don't have `openapi.yaml` locally, you can download it from the official repository:

```bash
curl -o openapi.yaml https://raw.githubusercontent.com/flightctl/flightctl/main/api/core/v1beta1/openapi.yaml
```

Then, run the generator CLI to output the client source code into your project directory.

```bash
# Generate the client into the rhem_client directory
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml \
  -g python \
  -o ./rhem_client \
  --additional-properties=packageName=rhem_client \
  --skip-validate-spec
```

> **Note**: `--skip-validate-spec` is required when the OpenAPI spec contains validation errors (e.g., `requestBody` type mismatch). If you can fix the spec, running without this option is recommended.

This creates the following API classes and Python type definitions (models) in `./rhem_client`:

| API Class | Primary Purpose |
| --- | --- |
| `AuthenticationApi` | Auth configuration, tokens, and permissions |
| `AuthproviderApi` | CRUD for authentication providers |
| `CertificatesigningrequestApi` | Certificate signing request management |
| `DeviceApi` | Device CRUD, status management, app operations |
| `DeviceactionsApi` | Bulk device actions (resume, etc.) |
| `EnrollmentrequestApi` | Device enrollment request management |
| `EventApi` | Event listing |
| `FleetApi` | Fleet CRUD, template version management |
| `LabelApi` | Label listing |
| `OrganizationApi` | Organization listing |
| `RepositoryApi` | Repository CRUD, OCI image checks |
| `ResourcesyncApi` | Resource sync CRUD |
| `VersionApi` | API version information |

After generation, install the client:

```bash
cd rhem_client
pip install .
```

---

## Step 2: Initialize a Shared Client Instance

Create a configuration file to set the base URL, authentication token (JWT), and common headers.

```python
# api/flightctl_client.py
import urllib3
import urllib.parse
import json
import rhem_client

urllib3.disable_warnings()

OIDC_TOKEN_URL = "https://rhem01/_/pam-issuer/api/v1/auth/token"
OIDC_CLIENT_ID = "flightctl-client"


def get_access_token(username: str, password: str) -> str:
    """Obtain a Bearer token via OIDC password grant"""
    http = urllib3.PoolManager(cert_reqs="CERT_NONE")
    body = urllib.parse.urlencode({
        "grant_type": "password",
        "client_id": OIDC_CLIENT_ID,
        "username": username,
        "password": password,
        "scope": "openid profile email roles offline_access",
    })
    r = http.request(
        "POST",
        OIDC_TOKEN_URL,
        body=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    data = json.loads(r.data)
    if r.status != 200:
        raise RuntimeError(f"Failed to obtain token: {data}")
    return data["access_token"]


def get_api_client() -> rhem_client.ApiClient:
    """Create and return a configured API client"""
    config = rhem_client.Configuration(
        host="https://rhem01/api/v1",
    )

    # Disable SSL verification for self-signed certificates
    config.verify_ssl = False

    # Obtain OIDC token and set it in the Authorization header
    token = get_access_token("kikyou", "redhat")
    client = rhem_client.ApiClient(config)
    client.default_headers["Authorization"] = f"Bearer {token}"

    return client


# Export API instances
_client = get_api_client()
device_api = rhem_client.DeviceApi(_client)
fleet_api = rhem_client.FleetApi(_client)
```

> **Note**: The generated code's `_auth_settings` is an empty list `[]`, so setting `config.access_token` will not send the Authorization header. You must set it directly via `client.default_headers["Authorization"]`.

---

## Step 3: Call API Methods in Your Application

Import the API instances and use them directly. Parameters and response types are automatically provided, enabling IDE autocompletion.

### Fetching Data (GET)

```python
# app/device_list.py
from api.flightctl_client import device_api
from rhem_client.models import Device


def fetch_devices(site: str = "factory-a") -> list[Device]:
    """Fetch a list of devices"""
    try:
        # Full autocompletion for method names and parameters
        response = device_api.list_devices(
            label_selector=f"site={site}",
        )

        # response.items is typed as a list of Device
        return response.items or []

    except rhem_client.ApiException as e:
        print(f"Failed to fetch devices: {e.status} {e.reason}")
        return []


def display_devices():
    """Display the device list"""
    devices = fetch_devices()

    print("Device List")
    print("-" * 40)

    for device in devices:
        name = device.metadata.name if device.metadata else "Unknown"
        status = (
            device.status.summary.status
            if device.status and device.status.summary
            else "Unknown"
        )
        print(f"  {name} - Status: {status}")


if __name__ == "__main__":
    display_devices()
```

### Updating Data (PUT / POST)

```python
# app/device_update.py
from api.flightctl_client import device_api


def update_device_image(device_name: str, new_image: str):
    """Update a device's OS image"""
    try:
        # 1. Fetch the current object (type-safe)
        device = device_api.get_device(name=device_name)

        # 2. Modify the payload
        if device.spec:
            device.spec.os = {"image": new_image}

        # 3. Submit the update
        updated_device = device_api.replace_device(
            name=device_name,
            device=device,
        )

        print(f"Update successful: {updated_device.metadata.name}")

    except rhem_client.ApiException as e:
        print(f"Update failed: {e.status} {e.reason}")
```

### Deleting Data (DELETE)

```python
# app/device_delete.py
from api.flightctl_client import device_api
import rhem_client


def delete_device(device_name: str):
    """Delete a device"""
    try:
        device_api.delete_device(name=device_name)
        print(f"Device '{device_name}' deleted")

    except rhem_client.ApiException as e:
        print(f"Deletion failed: {e.status} {e.reason}")
```

### Fleet Management Example

```python
# app/fleet_management.py
from api.flightctl_client import fleet_api
import rhem_client


def list_fleets():
    """Fetch a list of fleets"""
    try:
        response = fleet_api.list_fleets()
        for fleet in (response.items or []):
            name = fleet.metadata.name if fleet.metadata else "Unknown"
            print(f"  Fleet: {name}")

    except rhem_client.ApiException as e:
        print(f"Failed to fetch fleets: {e.status} {e.reason}")
```

---

### Flask Web Application Example

```python
# app.py
from flask import Flask, jsonify, request
from api.flightctl_client import device_api, fleet_api
import rhem_client

app = Flask(__name__)


@app.route("/devices")
def list_devices():
    """Return device list as JSON"""
    site = request.args.get("site")

    try:
        kwargs = {}
        if site:
            kwargs["label_selector"] = f"site={site}"
        response = device_api.list_devices(**kwargs)
        return jsonify([
            {
                "name": d.metadata.name,
                "status": d.status.summary.status if d.status and d.status.summary else None,
            }
            for d in (response.items or [])
        ])

    except rhem_client.ApiException as e:
        return jsonify({"error": str(e)}), e.status


@app.route("/devices/<name>/image", methods=["PUT"])
def update_image(name: str):
    """Update a device's OS image"""
    new_image = request.json.get("image")

    try:
        device = device_api.get_device(name=name)
        if device.spec:
            device.spec.os = {"image": new_image}

        updated = device_api.replace_device(name=name, device=device)
        return jsonify({"name": updated.metadata.name, "image": new_image})

    except rhem_client.ApiException as e:
        return jsonify({"error": str(e)}), e.status


if __name__ == "__main__":
    app.run(debug=True)
```

---

## Key Benefits

| Manual `requests` | Auto-generated Client |
| --- | --- |
| Manual URL concatenation (risk of typos) | Type-safe method calls (e.g., `device_api.list_devices()`) |
| No types, or manually maintained dataclasses | **Python model classes fully provided by auto-generation** |
| Manual query parameter construction | Query parameters passed directly as keyword arguments |
| Breaking API changes fail silently at runtime | Regenerating the client detects breaking changes via **mypy / pyright type checking** |

---

## Recommended Best Practices

### Leveraging Type Checking

Combine the generated client with `mypy` or `pyright` to detect API changes before build time:

```bash
# Run type checking
mypy app/ --strict
```

### Async Support

For async web frameworks (e.g., FastAPI), you can use the async version of the generated client:

```python
# FastAPI + async client example
from fastapi import FastAPI
from api.flightctl_client import device_api

app = FastAPI()


@app.get("/devices")
async def list_devices(site: str = "factory-a"):
    response = await device_api.list_devices(
        label_selector=f"site={site}",
        async_req=True,
    )
    return [
        {
            "name": d.metadata.name,
            "status": d.status.summary.status if d.status and d.status.summary else None,
        }
        for d in (response.items or [])
    ]
```

### Using Context Managers

Use context managers to properly manage API client resources:

```python
import rhem_client

config = rhem_client.Configuration(host="https://rhem01/api/v1")

with rhem_client.ApiClient(config) as client:
    device_api = rhem_client.DeviceApi(client)
    devices = device_api.list_devices()
    print(devices)
# Client is automatically closed
```

---

## Generated Directory Structure

```
rhem_client/
├── rhem_client/          # Python package
│   ├── __init__.py       # Exports all API classes and models
│   ├── api_client.py     # HTTP communication base class
│   ├── configuration.py  # Connection settings (host, auth, proxy, etc.)
│   ├── exceptions.py     # Exception classes (ApiException, etc.)
│   ├── rest.py           # REST client (urllib3-based)
│   ├── api/              # API classes (one per endpoint group)
│   └── models/           # Data models (request/response types)
├── docs/                 # API documentation (Markdown)
├── test/                 # Test code
├── pyproject.toml        # Package configuration
├── setup.py              # Setup script
└── requirements.txt      # Dependencies
```

---

## Troubleshooting

### SSL Certificate Error

When using self-signed certificates:

```python
config = rhem_client.Configuration(
    host="https://rhem01/api/v1",
)
config.verify_ssl = False  # Development only. Use proper certificates in production.
```

### Proxy Configuration

```python
config = rhem_client.Configuration(
    host="https://rhem01/api/v1",
)
config.proxy = "http://proxy.example.com:8080"
```

### `failed to get auth token` Error (Authentication)

The RHEM API uses OIDC authentication. Basic authentication (`config.username` / `config.password`) will not work.
Additionally, the generated code's `_auth_settings` is empty, so setting `config.access_token` will not send the Authorization header.

**Solution**: Obtain a token from the OIDC token endpoint via password grant and set it directly in `default_headers` (see the code in Step 2).

You can check the OIDC configuration with:

```bash
# Check authentication provider
curl -k https://rhem01/api/v1/auth/config

# Check OIDC well-known configuration
curl -k https://rhem01/_/pam-issuer/api/v1/auth/.well-known/openid-configuration
```

### `ApplicationProviderSpec` oneOf Deserialization Error

The following error may occur when fetching the device list:

```
ValueError: Multiple matches found when deserializing the JSON string
into ApplicationProviderSpec with oneOf schemas: ComposeApplication,
ContainerApplication, HelmApplication, QuadletApplication, VmApplication.
```

This happens because the generated `from_json` tries each oneOf schema by brute force, and multiple schemas match.

**Solution**: Modify the `from_json` method in `models/application_provider_spec.py` to use the `appType` field as a discriminator.

```python
# Add to the beginning of the from_json method in models/application_provider_spec.py
@classmethod
def from_json(cls, json_str: str) -> Self:
    instance = cls.model_construct()
    data = json.loads(json_str)

    # Use appType to directly select the schema (discriminator)
    apptype_class_map = {
        "compose": ComposeApplication,
        "quadlet": QuadletApplication,
        "container": ContainerApplication,
        "helm": HelmApplication,
        "vm": VmApplication,
    }
    app_type = data.get("appType") if isinstance(data, dict) else None
    if app_type and app_type in apptype_class_map:
        target_cls = apptype_class_map[app_type]
        instance.actual_instance = target_cls.from_dict(data)
        return instance

    # Fallback to brute-force matching if appType is absent
    ...
```

> **Note**: Defining the map as a class variable `_APPTYPE_CLASS_MAP` will cause Pydantic to treat it as a `ModelPrivateAttr`, resulting in `TypeError: argument of type 'ModelPrivateAttr' is not iterable`. Always define it as a local variable inside the method.

### `AttributeError` on `import rhem_client`

The generated code may reference enum values with a `NUMBER_` prefix that doesn't exist in the actual enum definition. This is an openapi-generator bug.

```
AttributeError: type object 'ImagePullPolicy' has no attribute 'NUMBER_PullIfNotPresent'.
Did you mean: 'PullIfNotPresent'?
```

**Solution**: Remove the `NUMBER_` prefix from the affected files.

```bash
# Search for problematic references
grep -rn 'NUMBER_' rhem_client/rhem_client/models/

# Files that required fixes (actual examples from this project):
# - models/image_volume_source.py
#     NUMBER_PullIfNotPresent → PullIfNotPresent
# - models/resource_sync_spec.py
#     NUMBER_ResourceSyncTypeFleet → ResourceSyncTypeFleet
```

After fixing, reinstall:

```bash
cd rhem_client
pip install .
```

### Regenerating the Client

When the API specification (`openapi.yaml`) is updated, regenerate and reinstall the client:

```bash
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml \
  -g python \
  -o ./rhem_client \
  --additional-properties=packageName=rhem_client \
  --skip-validate-spec

cd rhem_client
pip install .
```

> **Note**: Regeneration may reintroduce the `NUMBER_` prefix bug. After regeneration, verify with `grep -rn 'NUMBER_' rhem_client/rhem_client/models/`.
