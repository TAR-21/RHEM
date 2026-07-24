## 🛠️ FlightCTL API 統合ガイド

OpenAPI 3.0 仕様に基づいて定義された FlightCTL API を、外部 Web アプリケーションから呼び出すためのまとめです。

---

### 1️⃣ OpenAPI 仕様の取得とクライアント自動生成

FlightCTL は OpenAPI 3.0 仕様を公開しています。以下の公式リポジトリから仕様ファイルを取得し、任意の言語で型安全な SDK クライアントを生成できます。

> **仕様ファイル URL:** [GitHub - openapi.yaml](https://github.com/flightctl/flightctl/blob/main/api/core/v1beta1/openapi.yaml)

```bash
# JavaScript / TypeScript クライアント生成
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml \
  -g typescript-fetch \
  -o ./flightctl-client

# Python クライアント生成
openapi-generator generate \
  -i openapi.yaml \
  -g python \
  -o ./flightctl-client-python

# Go クライアント生成
openapi-generator generate \
  -i openapi.yaml \
  -g go \
  -o ./flightctl-client-go

```

---

### 2️⃣ 認証フロー（JWT Bearer トークンの取得）

FlightCTL の User-facing API は **JWT Bearer トークン** で認証を行います。

```
[1. 設定取得]  GET /api/v1/auth/config  ──► OIDCプロバイダ等の認証情報を取得
[2. トークン取得] OAuth2 / OIDC Auth Code Flow ──► JWT Access Token を獲得
[3. トークン交換] POST /api/v1/auth/{provider}/token ──► (必要に応じて FlightCTL 用トークンへ変換)

```

#### サポートしている認証バックエンド

* **OIDC (OpenID Connect)**: 任意の OIDC プロバイダに対応（**推奨**）
* **OAuth2**: OIDC 非対応プロバイダ向け
* **OpenShift OAuth**: OpenShift OAuth サーバと統合
* **AAP**: Ansible Automation Platform Gateway API 経由
* **Kubernetes**: ServiceAccount トークンの TokenReview 検証

#### Web アプリの実装例 (OIDC Authorization Code Flow)

```javascript
// 1. ユーザーを OIDC プロバイダのログインページへリダイレクト
const authUrl = `${oidcIssuerUrl}/authorize?` +
  `client_id=${clientId}&` +
  `response_type=code&` +
  `redirect_uri=${encodeURIComponent(redirectUri)}&` +
  `scope=openid profile email`;

window.location.href = authUrl;

// 2. コールバックで認可コードを受け取り、トークンと交換（バックエンド等で実行）
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

### 3️⃣ 主要 REST エンドポイント一覧

* **ベース URL:** `/api/v1`

| カテゴリ | 機能 | エンドポイント | メソッド |
| --- | --- | --- | --- |
| **認証** | 認証設定取得 | `/auth/config` | `GET` |
|  | トークン検証 | `/auth/validate` | `GET` |
|  | 権限取得 | `/auth/permissions` | `GET` |
|  | トークン交換 | `/auth/{providername}/token` | `POST` |
|  | ユーザー情報 | `/auth/userinfo` | `GET` |
| **デバイス** | 一覧取得 | `/devices` | `GET` |
|  | 作成 | `/devices` | `POST` |
|  | 詳細取得 / 更新 / 削除 | `/devices/{name}` | `GET` / `PUT` / `DELETE` |
|  | ステータス更新 | `/devices/{name}/status` | `GET` / `PUT` |
|  | 廃止 (Decommission) | `/devices/{name}/decommission` | `POST` |
|  | レンダリング済み設定 | `/devices/{name}/rendered` | `GET` |
|  | アプリ操作 | `/devices/{name}/applications/{app}/actions/*` | `POST` |
|  | コンソール接続 | `/ws/v1/devices/{name}/console` | `WebSocket` |
| **フリート** | 一覧取得 / 作成 | `/fleets` | `GET` / `POST` |
|  | 詳細取得 / 更新 / 削除 | `/fleets/{name}` | `GET` / `PUT` / `DELETE` |
|  | ステータス | `/fleets/{name}/status` | `GET` / `PUT` |
|  | テンプレートバージョン | `/fleets/{fleet}/templateversions` | `GET` |
|  | テンプレートバージョン詳細 | `/fleets/{fleet}/templateversions/{name}` | `GET` / `DELETE` |
| **登録リクエスト** | 一覧取得 / 詳細取得 | `/enrollmentrequests` / `{name}` | `GET` |
|  | 承認 | `/enrollmentrequests/{name}/approval` | `POST` |
| **リポジトリ** | 一覧取得 / 作成 | `/repositories` | `GET` / `POST` |
|  | 詳細 / 更新 / 削除 | `/repositories/{name}` | `GET` / `PUT` / `DELETE` |
| **リソース同期** | 一覧取得 / 作成 | `/resourcesyncs` | `GET` / `POST` |
|  | 詳細 / 更新 / 削除 | `/resourcesyncs/{name}` | `GET` / `PUT` / `DELETE` |
| **その他** | イベント / ラベル / 組織 | `/events`, `/labels`, `/organizations` | `GET` |
|  | 認証プロバイダ管理 | `/authproviders` | `GET` / `POST` |
|  | API バージョン取得 | `/version` | `GET` |

---

### 4️⃣ API 呼び出しのコード例

#### JavaScript (Fetch API)

```javascript
const FLIGHTCTL_API = 'https://your-rhem-api-server/api/v1';
const TOKEN = 'your-jwt-token';

const headers = {
  'Authorization': `Bearer ${TOKEN}`,
  'Accept': 'application/json',
  'Content-Type': 'application/json',
  'Flightctl-API-Version': 'v1beta1', // バージョン明示（推奨）
};

// デバイス一覧取得（ラベルフィルタ付き）
async function listDevicesBySite(site) {
  const params = new URLSearchParams({ labelSelector: `site=${site}` });
  const res = await fetch(`${FLIGHTCTL_API}/devices?${params}`, { headers });
  return res.json();
}

// デバイスの設定更新 (PUT)
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

// デバイス登録リクエストの承認
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

# フリートの新規作成
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

### 5️⃣ API バージョンネゴシエーション

FlightCTL は **ヘッダーベース** のバージョン管理を行います（URL パスは固定です）。

* **リクエストヘッダー:** `Flightctl-API-Version: v1beta1`
* **ヘッダー未指定時:** サーバー側で最も安定したバージョンが適用されます。
* **未サポート指定時:** `406 Not Acceptable` が返り、利用可能バージョンが `Flightctl-API-Versions-Supported` ヘッダーで通知されます。

| バージョン | ステータス | 対象リソース例 |
| --- | --- | --- |
| `v1beta1` | 安定版 (1.x系で互換性保証) | Device, Fleet, Repository など |
| `v1alpha1` | 開発途上 (将来変更の可能性あり) | ImageBuild, ImageExport など |

---

### 6️⃣ 楽観的排他制御 (Concurrency Control)

更新処理時の競合を防ぐため、`resourceVersion` による楽観的排他制御が導入されています。

```javascript
// 1. 最新リソースを取得（レスポンスに含まれる resourceVersion を保持）
const device = await getDevice('my-device');

// 2. 値を変更
device.spec.os.image = 'quay.io/redhat/rhde:9.4';

// 3. resourceVersion を含めた状態で PUT 送信
const res = await fetch(`${FLIGHTCTL_API}/devices/my-device`, {
  method: 'PUT',
  headers,
  body: JSON.stringify(device),
});

// 他クライアントが先に更新していた場合は 409 が返るためリトライ処理を行う
if (res.status === 409) {
  console.warn('Conflict detected. Retrying...');
}

```

---

### 7️⃣ システム構成パターンとセキュリティ

```
┌──────────────────────────────────────┐
│  フロントエンド (React / Vue 等)      │
└──────────────────┬───────────────────┘
                   │ HTTPS (セッション cookie 等)
                   ▼
┌──────────────────────────────────────┐
│  BFF (Backend for Frontend)          │
│  ・Token のセキュア保管 (client_secret)│
│  ・FlightCTL API へのプロキシ        │
└──────────────────┬───────────────────┘
                   │ HTTPS + Bearer JWT
                   ▼
┌──────────────────────────────────────┐
│  FlightCTL API Server                │
└──────────────────────────────────────┘

```

> ⚠️ **セキュリティチェックポイント**
> * **BFF パターンの推奨:** `client_secret` や API トークンをブラウザ側に露出させないよう、バックエンド（BFF）経由での呼び出しを推奨します。
> * **CORS:** フロントエンドから直接呼び出す場合は、FlightCTL API 側（または API ゲートウェイ）で CORS 設定を調整する必要があります。
> 
> 

---

### 8️⃣ 参考リンク・リソース

* 📘 [OpenAPI 仕様 (v1beta1)](https://github.com/flightctl/flightctl/blob/main/api/core/v1beta1/openapi.yaml)
* 📘 [OpenAPI 仕様 (v1alpha1)](https://github.com/flightctl/flightctl/tree/main/api/core/v1alpha1)
* 📑 [API リソースリファレンス](https://github.com/flightctl/flightctl/blob/main/docs/user/references/api-resources.md)
* 🎨 [FlightCTL UI 参考実装 (GitHub)](https://github.com/flightctl/flightctl-ui) — React での実際の呼び出し実装例
