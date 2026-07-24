# 🛠️ How to Use the Generated Client in a Web App

Using an auto-generated client (SDK) eliminates the need to manually construct URLs, headers, and types for `fetch` or `axios`. Instead, you can invoke API endpoints as **type-safe functions with full autocomplete support**.

Here is a step-by-step walkthrough using TypeScript (e.g., `typescript-fetch` generator).

---

## Step-by-Step Workflow

```
[1. Generate] ──► [2. Configure & Initialize] ──► [3. Call API Functions]
```

---

## Step 1: Generate the Client Code

First, run the generator CLI to output the client source code directly inside your project directory.

```bash
# Generate client into src/api/generated
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml \
  -g typescript-fetch \
  -o ./src/api/generated
```

This creates API classes (such as `DeviceApi` and `FleetApi`) along with TypeScript type definitions inside `./src/api/generated`.

---

## Step 2: Initialize a Shared Client Instance

Create a configuration file to set up the base URL, authentication tokens (JWT), and common headers for the generated API classes.

```typescript
// src/api/flightctlClient.ts
import { Configuration, DeviceApi, FleetApi } from './generated';

// 1. Create a configuration object
const config = new Configuration({
  // Base URL for the API
  basePath: 'https://your-rhem-api-server/api/v1',
  
  // Dynamic Bearer token provider
  accessToken: () => {
    return localStorage.getItem('jwt_token') || '';
  },
  
  // Custom headers (e.g., specifying API version)
  headers: {
    'Flightctl-API-Version': 'v1beta1',
  },
});

// 2. Instantiate and export API classes
export const deviceApi = new DeviceApi(config);
export const fleetApi = new FleetApi(config);
```

---

## Step 3: Call API Methods in UI Components

Now you can import the API instances directly into your UI components. Parameters and response types are automatically typed, enabling build-time error checking.

### 🔹 Fetching Data (GET)

```typescript
// src/components/DeviceList.tsx
import React, { useEffect, useState } from 'react';
import { deviceApi } from '../api/flightctlClient';
import { Device } from '../api/generated'; // Generated type interfaces

export const DeviceList = () => {
  const [devices, setDevices] = useState<Device[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchDevices() {
      try {
        // Full autocomplete for method names and query parameters
        const response = await deviceApi.listDevices({
          labelSelector: 'site=factory-a',
        });
        
        // TypeScript recognizes response.items as Device[]
        setDevices(response.items || []);
      } catch (error) {
        console.error('Failed to fetch devices:', error);
      } finally {
        setLoading(false);
      }
    }

    fetchDevices();
  }, []);

  if (loading) return <div>Loading...</div>;

  return (
    <div>
      <h2>Devices</h2>
      <ul>
        {devices.map((device) => (
          <li key={device.metadata?.name}>
            {device.metadata?.name} - Status: {device.status?.summary?.status}
          </li>
        ))}
      </ul>
    </div>
  );
};
```

### 🔹 Updating Data (PUT / POST)

```typescript
import { deviceApi } from '../api/flightctlClient';

// Function to update a device's OS image
async function updateDeviceImage(deviceName: string, newImage: string) {
  try {
    // 1. Fetch current object (type-safe)
    const device = await deviceApi.getDevice({ name: deviceName });

    // 2. Modify payload
    if (device.spec) {
      device.spec.os = { image: newImage };
    }

    // 3. Send update (Payload structure mismatch causes build-time errors)
    const updatedDevice = await deviceApi.replaceDevice({
      name: deviceName,
      device: device,
    });

    console.log('Successfully updated:', updatedDevice);
  } catch (error) {
    console.error('Update failed:', error);
  }
}
```

---

## 💡 Key Advantages

| Manual `fetch` / `axios` | Auto-Generated Client |
| --- | --- |
| Manual string URL concatenation (typo-prone) | Type-safe method calls (e.g., `deviceApi.listDevices()`) |
| Untyped or manually maintained interface types | **Complete TypeScript interfaces automatically generated** |
| Manual query parameter building (`URLSearchParams`) | Pass query parameters directly as JavaScript objects |
| Breaking API changes fail silently at runtime | Re-generating clients exposes breaking API changes as **build errors** |

---

## 🔄 Recommended Best Practice

In production applications, it is standard practice to wrap the generated client calls with data-fetching libraries like **TanStack Query (React Query)** or **SWR**:

```typescript
import { useQuery } from '@tanstack/react-query';
import { deviceApi } from '../api/flightctlClient';

export function useDevices(site: string) {
  return useQuery({
    queryKey: ['devices', site],
    queryFn: () => deviceApi.listDevices({ labelSelector: `site=${site}` }),
  });
}
```

This pattern combines **end-to-end type safety** with **caching, re-fetching, and state management**.

---
