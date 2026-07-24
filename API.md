# 🛠️ FlightCTL API 統合ガイド

本ガイドでは、OpenAPI 3.0 仕様を使用して外部Webアプリケーションから FlightCTL API を統合・利用する方法をまとめています。

---

## 1️⃣ OpenAPI 仕様とクライアントコード生成

FlightCTL は公式リポジトリに OpenAPI 3.0 仕様ファイルを提供しています。これを使用して、各種プログラミング言語やフレームワーク向けの型安全なクライアント SDK を自動生成できます。

> **仕様ファイル URL:** [GitHub - openapi.yaml](https://github.com/flightctl/flightctl/blob/main/api/core/v1beta1/openapi.yaml)

```bash
# JavaScript / TypeScript クライアントの生成
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml \
  -g typescript-fetch \
  -o ./flightctl-client

# Python クライアントの生成
openapi-generator generate \
  -i openapi.yaml \
  -g python \
  -o ./flightctl-client-python

# Go クライアントの生成
openapi-generator generate \
  -i openapi.yaml \
  -g go \
  -o ./flightctl-client-go
```

---

## 2️⃣ 認証フロー（JWT Bearer トークン）

FlightCTL のユーザー向け API は、認証に **JWT Bearer トークン** を使用します。

```
[1. 設定取得]       GET /api/v1/auth/config  ──► OIDC プロバイダー設定を取得
[2. トークン取得]   OAuth2 / OIDC 認証フロー  ──► JWT アクセストークンを取得
[3. トークン交換]   POST /api/v1/auth/{providername}/token ──► (任意) FlightCTL トークンへ交換
```

### 対応する認証バックエンド

- **OIDC (OpenID Connect)**: 標準的な OIDC プロバイダーと互換（**推奨**）
- **OAuth2**: OIDC 非対応の OAuth2 プロバイダー向け
- **OpenShift OAuth**: OpenShift OAuth サーバーと直接統合
- **AAP**: Ansible Automation Platform Gateway API 経由
- **Kubernetes**: ServiceAccount トークンの TokenReview 検証

### Web アプリケーションの例（OIDC 認可コードフロー）

```javascript
// 1. ユーザーを OIDC プロバイダーのログインページにリダイレクト
const authUrl = `${oidcIssuerUrl}/authorize?` +
  `client_id=${clientId}&` +
  `response_type=code&` +
  `redirect_uri=${encodeURIComponent(redirectUri)}&` +
  `scope=openid profile email`;

window.location.href = authUrl;

// 2. 認可コードをトークンに交換（client_secret 保護のためサーバーサイドで実行）
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

## 3️⃣ 主要 REST エンドポイント一覧

- **ベース URL:** `/api/v1`

| カテゴリ | 説明 | エンドポイント | HTTP メソッド |
|----------|------|----------------|---------------|
| **認証** | 認証設定の取得 | `/auth/config` | `GET` |
| | トークン検証 | `/auth/validate` | `GET` |
| | 権限の取得 | `/auth/permissions` | `GET` |
| | トークン交換 | `/auth/{providername}/token` | `POST` |
| | ユーザー情報 | `/auth/userinfo` | `GET` |
| **デバイス** | デバイス一覧 | `/devices` | `GET` |
| | デバイス作成 | `/devices` | `POST` |
| | 取得 / 更新 / パッチ / 削除 | `/devices/{name}` | `GET` / `PUT` / `PATCH` / `DELETE` |
| | ステータス | `/devices/{name}/status` | `GET` / `PUT` / `PATCH` |
| | デバイスの廃止 | `/devices/{name}/decommission` | `PUT` |
| | レンダリング済み仕様の取得 | `/devices/{name}/rendered` | `GET` |
| | アプリケーション停止 | `/devices/{name}/applications/{appname}/actions/stop` | `POST` |
| | アプリケーション開始 | `/devices/{name}/applications/{appname}/actions/start` | `POST` |
| | アプリケーション再起動 | `/devices/{name}/applications/{appname}/actions/restart` | `POST` |
| | ターミナルコンソール | `/ws/v1/devices/{name}/console` | `WebSocket` |
| **フリート** | 一覧 / 作成 | `/fleets` | `GET` / `POST` |
| | 取得 / 更新 / 削除 | `/fleets/{name}` | `GET` / `PUT` / `DELETE` |
| | フリートステータス | `/fleets/{name}/status` | `GET` / `PUT` |
| | テンプレートバージョン一覧 | `/fleets/{fleet}/templateversions` | `GET` |
| | テンプレートバージョン詳細 | `/fleets/{fleet}/templateversions/{name}` | `GET` / `DELETE` |
| **登録** | 登録リクエスト一覧 | `/enrollmentrequests` | `GET` |
| | 取得 / パッチ | `/enrollmentrequests/{name}` | `GET` / `PATCH` |
| | 登録ステータス | `/enrollmentrequests/{name}/status` | `PATCH` |
| | 登録リクエストの承認 | `/enrollmentrequests/{name}/approval` | `PUT` |
| **CSR** | 一覧 / 作成 | `/certificatesigningrequests` | `GET` / `POST` |
| | CSR のパッチ | `/certificatesigningrequests/{name}` | `PATCH` |
| **リポジトリ** | 一覧 / 作成 | `/repositories` | `GET` / `POST` |
| | 取得 / 更新 / パッチ / 削除 | `/repositories/{name}` | `GET` / `PUT` / `PATCH` / `DELETE` |
| **リソース同期** | 一覧 / 作成 | `/resourcesyncs` | `GET` / `POST` |
| | 取得 / 更新 / パッチ / 削除 | `/resourcesyncs/{name}` | `GET` / `PUT` / `PATCH` / `DELETE` |
| **その他** | イベント / ラベル / 組織 | `/events`, `/labels`, `/organizations` | `GET` |
| | 認証プロバイダー | `/authproviders` | `GET` / `POST` |
| | API バージョン | `/version` | `GET` |

---

## 4️⃣ コード例

### JavaScript (Fetch API)

```javascript
const FLIGHTCTL_API = 'https://your-rhem-api-server/api/v1';
const TOKEN = 'your-jwt-token';

const headers = {
  'Authorization': `Bearer ${TOKEN}`,
  'Accept': 'application/json',
  'Content-Type': 'application/json',
  'Flightctl-API-Version': 'v1beta1', // 推奨: 明示的なバージョン指定
};

// ラベルでフィルタリングしたデバイス一覧の取得
async function listDevicesBySite(site) {
  const params = new URLSearchParams({ labelSelector: `site=${site}` });
  const res = await fetch(`${FLIGHTCTL_API}/devices?${params}`, { headers });
  return res.json();
}

// デバイス仕様の更新 (PUT)
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

// 登録リクエストの承認
async function approveEnrollment(name, labels) {
  const res = await fetch(`${FLIGHTCTL_API}/enrollmentrequests/${name}/approval`, {
    method: 'PUT',
    headers,
    body: JSON.stringify({ approved: true, labels }),
  });
  return res.json();
}
```

### Python (requests)

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

# 新しいフリートの作成
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

## 5️⃣ API バージョンネゴシエーション

FlightCTL は**ヘッダーベースのバージョンネゴシエーション**を採用しています。URL パスは変わらず `/api/v1` のままです。

- **リクエストヘッダー:** `Flightctl-API-Version: v1beta1`
- **レスポンスヘッダー:** `Flightctl-API-Version`（使用されたバージョン）、`Deprecation`（RFC 9651/9745 形式）、`Vary: Flightctl-API-Version`
- **ヘッダー省略時:** API サーバーは最も安定したサポート済みバージョンをデフォルトで使用します。
- **未サポートバージョン指定時:** `406 Not Acceptable` を返します。

| バージョン | ステータス | 対象リソース |
|------------|------------|--------------|
| `v1beta1` | Stable | Device, Fleet, Repository, EnrollmentRequest, TemplateVersion, ResourceSync, CertificateSigningRequest, Event, AuthProvider, AuthConfig, Organization |
| `v1alpha1` | Alpha（変更の可能性あり） | ImageBuild, ImageExport |

---

## 6️⃣ 楽観的並行制御

書き込みの競合を防止するため、FlightCTL は `resourceVersion` フィールドを使用しています。

```javascript
// 1. リソースを取得（現在の resourceVersion を含む）
const device = await getDevice('my-device');

// 2. リソースの仕様を変更
device.spec.os.image = 'quay.io/redhat/rhde:9.4';

// 3. resourceVersion を含めて PUT リクエストを送信
const res = await fetch(`${FLIGHTCTL_API}/devices/my-device`, {
  method: 'PUT',
  headers,
  body: JSON.stringify(device),
});

// 他のクライアントが先にリソースを更新した場合、409 Conflict を返す
if (res.status === 409) {
  console.warn('競合を検出しました。最新バージョンを再取得します...');
}
```

---

## 7️⃣ アーキテクチャとセキュリティのベストプラクティス

```
┌──────────────────────────────────────┐
│  フロントエンド (React / Vue / Angular) │
└──────────────────┬───────────────────┘
                   │ HTTPS (セッション Cookie)
                   ▼
┌──────────────────────────────────────┐
│  BFF (Backend for Frontend)          │
│  ・client_secret を安全に保持         │
│  ・FlightCTL API へのリクエストを代理  │
└──────────────────┬───────────────────┘
                   │ HTTPS + Bearer JWT
                   ▼
┌──────────────────────────────────────┐
│  FlightCTL API サーバー               │
└──────────────────────────────────────┘
```

> ⚠️ **セキュリティチェックリスト:**
>
> - **BFF パターンを使用:** ブラウザから FlightCTL API を直接呼び出すことは避けてください。`client_secret` の保管とアクセストークンの管理は、バックエンドサービス（BFF）で安全に行ってください。
> - **CORS 設定:** ブラウザからの直接呼び出しが避けられない場合は、FlightCTL API サーバーまたはゲートウェイで CORS ヘッダーを適切に設定してください。

---

## 8️⃣ 参考リンク

- 📘 [OpenAPI 仕様 (v1beta1)](https://github.com/flightctl/flightctl/blob/main/api/core/v1beta1/openapi.yaml)
- 📘 [OpenAPI 仕様 (v1alpha1)](https://github.com/flightctl/flightctl/tree/main/api/core/v1alpha1)
- 📑 [API リソースリファレンス](https://github.com/flightctl/flightctl/blob/main/docs/user/references/api-resources.md)
- 🎨 [FlightCTL UI リポジトリ](https://github.com/flightctl/flightctl-ui) — 実際の統合例として参考になる公式 React UI 実装
