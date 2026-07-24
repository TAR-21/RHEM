## 🛠️ FlightCTL API Integration Guide

This guide summarizes how to integrate and consume the FlightCTL API from external web applications using the OpenAPI 3.0 specification.

---

### 1️⃣ OpenAPI Spec & Client Code Generation

FlightCTL provides an OpenAPI 3.0 specification file in its official repository. You can use it to auto-generate type-safe client SDKs for various programming languages and frameworks.

> **Specification URL:** [GitHub - openapi.yaml](https://github.com/flightctl/flightctl/blob/main/api/core/v1beta1/openapi.yaml)

```bash
# Generate JavaScript / TypeScript Client
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml \
  -g typescript-fetch \
  -o ./flightctl-client

# Generate Python Client
openapi-generator generate \
  -i openapi.yaml \
  -g python \
  -o ./flightctl-client-python

# Generate Go Client
openapi-generator generate \
  -i openapi.yaml \
  -g go \
  -o ./flightctl-client-go

```

---

### 2️⃣ Authentication Flow (JWT Bearer Token)

FlightCTL’s User-facing API uses **JWT Bearer Tokens** for authentication.

```
[1. Fetch Config]   GET /api/v1/auth/config  ──► Retrieve OIDC provider settings
[2. Obtain Token]   OAuth2 / OIDC Auth Flow  ──► Get JWT Access Token
[3. Exchange Token] POST /api/v1/auth/{provider}/token ──► (Optional) Exchange for FlightCTL Token

```

#### Supported Authentication Backends

* **OIDC (OpenID Connect)**: Compatible with any standard OIDC provider (**Recommended**)
* **OAuth2**: For non-OIDC OAuth2 providers
* **OpenShift OAuth**: Integrates directly with OpenShift OAuth server
* **AAP**: Via Ansible Automation Platform Gateway API
* **Kubernetes**: TokenReview verification for ServiceAccount tokens

#### Web Application Example (OIDC Authorization Code Flow)

```javascript
// 1. Redirect user to the OIDC provider's login page
const authUrl = `${oidcIssuerUrl}/authorize?` +
  `client_id=${clientId}&` +
  `response_type=code&` +
  `redirect_uri=${encodeURIComponent(redirectUri)}&` +
  `scope=openid profile email`;

window.location.href = authUrl;

// 2. Exchange authorization code for tokens (Executed server-side to protect client_secret)
const tokenResponse = await fetch(`${oidcIssuerUrl}/token`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    grant_type: 'authorization_code',
    code: authorizationCode,
    client_id: clientId,
    client_secret: clientSecret,
    redirect_uri: redirectUri,
  }),
});

const { access_token } = await tokenResponse.json();

```

---

### 3️⃣ Key REST Endpoints Overview

* **Base URL:** `/api/v1`

| Category | Description | Endpoint | HTTP Method |
| --- | --- | --- | --- |
| **Auth** | Get Auth Config | `/auth/config` | `GET` |
|  | Validate Token | `/auth/validate` | `GET` |
|  | Get Permissions | `/auth/permissions` | `GET` |
|  | Exchange Token | `/auth/{providername}/token` | `POST` |
|  | User Info | `/auth/userinfo` | `GET` |
| **Devices** | List Devices | `/devices` | `GET` |
|  | Create Device | `/devices` | `POST` |
|  | Get / Update / Delete | `/devices/{name}` | `GET` / `PUT` / `DELETE` |
|  | Status Update | `/devices/{name}/status` | `GET` / `PUT` |
|  | Decommission Device | `/devices/{name}/decommission` | `POST` |
|  | Get Rendered Spec | `/devices/{name}/rendered` | `GET` |
|  | Application Actions | `/devices/{name}/applications/{app}/actions/*` | `POST` |
|  | Terminal Console | `/ws/v1/devices/{name}/console` | `WebSocket` |
| **Fleets** | List / Create | `/fleets` | `GET` / `POST` |
|  | Get / Update / Delete | `/fleets/{name}` | `GET` / `PUT` / `DELETE` |
|  | Fleet Status | `/fleets/{name}/status` | `GET` / `PUT` |
|  | Template Versions | `/fleets/{fleet}/templateversions` | `GET` |
|  | Template Version Details | `/fleets/{fleet}/templateversions/{name}` | `GET` / `DELETE` |
| **Enrollment** | List / Get Request | `/enrollmentrequests` / `{name}` | `GET` |
|  | Approve Request | `/enrollmentrequests/{name}/approval` | `POST` |
| **Repositories** | List / Create | `/repositories` | `GET` / `POST` |
|  | Get / Update / Delete | `/repositories/{name}` | `GET` / `PUT` / `DELETE` |
| **Resource Syncs** | List / Create | `/resourcesyncs` | `GET` / `POST` |
|  | Get / Update / Delete | `/resourcesyncs/{name}` | `GET` / `PUT` / `DELETE` |
| **Misc** | Events / Labels / Orgs | `/events`, `/labels`, `/organizations` | `GET` |
|  | Auth Providers | `/authproviders` | `GET` / `POST` |
|  | API Version | `/version` | `GET` |

---

### 4️⃣ Code Examples

#### JavaScript (Fetch API)

```javascript
const FLIGHTCTL_API = 'https://your-rhem-api-server/api/v1';
const TOKEN = 'your-jwt-token';

const headers = {
  'Authorization': `Bearer ${TOKEN}`,
  'Accept': 'application/json',
  'Content-Type': 'application/json',
  'Flightctl-API-Version': 'v1beta1', // Recommended: explicit versioning
};

// List devices filtered by label
async function listDevicesBySite(site) {
  const params = new URLSearchParams({ labelSelector: `site=${site}` });
  const res = await fetch(`${FLIGHTCTL_API}/devices?${params}`, { headers });
  return res.json();
}

// Update device specification (PUT)
async function updateDevice(name, deviceSpec) {
  const resGet = await fetch(`${FLIGHTCTL_API}/devices/${name}`, { headers });
  const device = await resGet.json();

  device.spec = { ...device.spec, ...deviceSpec };

  const resPut = await fetch(`${FLIGHTCTL_API}/devices/${name}`, {
    method: 'PUT',
    headers,
    body: JSON.stringify(device),
  });
  return resPut.json();
}

// Approve enrollment request
async function approveEnrollment(name, labels) {
  const res = await fetch(`${FLIGHTCTL_API}/enrollmentrequests/${name}/approval`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ approved: true, labels }),
  });
  return res.json();
}

```

#### Python (requests)

```python
import requests

API_BASE = "https://your-rhem-api-server/api/v1"
TOKEN = "your-jwt-token"

session = requests.Session()
session.headers.update({
    "Authorization": f"Bearer {TOKEN}",
    "Accept": "application/json",
    "Content-Type": "application/json",
    "Flightctl-API-Version": "v1beta1",
})

# Create a new Fleet
fleet_payload = {
    "apiVersion": "flightctl.io/v1beta1",
    "kind": "Fleet",
    "metadata": {"name": "production-fleet"},
    "spec": {
        "selector": {"matchLabels": {"stage": "production"}},
        "template": {
            "spec": {
                "os": {"image": "quay.io/redhat/rhde:9.4"}
            }
        },
    },
}

response = session.post(f"{API_BASE}/fleets", json=fleet_payload)
print(response.json())

```

---

### 5️⃣ API Version Negotiation

FlightCTL uses **header-based version negotiation**. The URL path remains unchanged (`/api/v1`).

* **Request Header:** `Flightctl-API-Version: v1beta1`
* **If Header is Omitted:** The API server defaults to the most stable supported version.
* **If Unsupported Version Requested:** Returns `406 Not Acceptable`, listing valid versions in the `Flightctl-API-Versions-Supported` response header.

| Version | Status | Target Resources |
| --- | --- | --- |
| `v1beta1` | Stable (Guaranteed 1.x compatibility) | Device, Fleet, Repository, etc. |
| `v1alpha1` | Experimental (Subject to change) | ImageBuild, ImageExport |

---

### 6️⃣ Optimistic Concurrency Control

To prevent concurrent write conflicts, FlightCTL utilizes the `resourceVersion` field.

```javascript
// 1. Retrieve the resource (includes current resourceVersion)
const device = await getDevice('my-device');

// 2. Modify resource spec
device.spec.os.image = 'quay.io/redhat/rhde:9.4';

// 3. Send PUT request carrying the resourceVersion
const res = await fetch(`${FLIGHTCTL_API}/devices/my-device`, {
  method: 'PUT',
  headers,
  body: JSON.stringify(device),
});

// Returns 409 Conflict if another client updated the resource first
if (res.status === 409) {
  console.warn('Conflict detected. Refetching latest version...');
}

```

---

### 7️⃣ Architecture & Security Best Practices

```
┌──────────────────────────────────────┐
│  Frontend (React / Vue / Angular)    │
└──────────────────┬───────────────────┘
                   │ HTTPS (Session Cookie)
                   ▼
┌──────────────────────────────────────┐
│  BFF (Backend for Frontend)          │
│  ・Securely holds client_secret      │
│  ・Proxies requests to FlightCTL API │
└──────────────────┬───────────────────┘
                   │ HTTPS + Bearer JWT
                   ▼
┌──────────────────────────────────────┐
│  FlightCTL API Server                │
└──────────────────────────────────────┘

```

> ⚠️ **Security Checklist:**
> * **Use BFF Pattern:** Avoid calling the FlightCTL API directly from the browser. Store `client_secret` and manage access tokens securely in a backend service (BFF).
> * **CORS Configuration:** If direct browser calls are unavoidable, ensure CORS headers are properly configured on the FlightCTL API server or gateway.
> 
> 

---

### 8️⃣ Reference Links

* 📘 [OpenAPI Spec (v1beta1)](https://github.com/flightctl/flightctl/blob/main/api/core/v1beta1/openapi.yaml)
* 📘 [OpenAPI Spec (v1alpha1)](https://github.com/flightctl/flightctl/tree/main/api/core/v1alpha1)
* 📑 [API Resource Reference](https://github.com/flightctl/flightctl/blob/main/docs/user/references/api-resources.md)
* 🎨 [FlightCTL UI Repository](https://github.com/flightctl/flightctl-ui) — Official React UI implementation serving as a real-world integration example
