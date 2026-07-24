FlightCTL API を他の Web アプリケーションから利用する方法をまとめます。API は OpenAPI 3.0 仕様 で定義されており、任意の言語・フレームワークからクライアントコードを自動生成できます。

:one: OpenAPI 仕様の取得（クライアント自動生成）

FlightCTL は OpenAPI 3.0 仕様を公開しています:

https://github.com/flightctl/flightctl/blob/main/api/core/v1beta1/openapi.yaml




この仕様ファイルを使って、各種ツールでクライアントコードを自動生成できます:

bash
# JavaScript/TypeScript クライアント生成
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml -g typescript-fetch -o ./flightctl-client

# Python クライアント生成
openapi-generator generate \
  -i openapi.yaml -g python -o ./flightctl-client-python

# Go クライアント生成
openapi-generator generate \
  -i openapi.yaml -g go -o ./flightctl-client-go




:bulb: 自動生成したクライアントを使えば、型安全に全エンドポイントを呼び出せます。



:two: 認証フロー — Web アプリからの JWT 取得

FlightCTL の User-facing API は JWT Bearer トークン で認証されます。Web アプリからは以下のフローで認証します。

Step 1: 認証設定の取得GET /api/v1/auth/config
このエンドポイントは認証不要で、OIDC プロバイダの URL やクライアント ID など、認証に必要な情報を返します。

Step 2: OIDC / OAuth2 でトークンを取得

FlightCTL がサポートする認証バックエンド:
- OIDC (OpenID Connect) — 任意の OIDC プロバイダに対応（推奨）
- OAuth2 — OIDC 非対応プロバイダ向け
- OpenShift OAuth — OpenShift OAuth サーバと統合
- AAP (Ansible Automation Platform) — AAP Gateway API 経由
- Kubernetes — ServiceAccount トークンの TokenReview 検証

Web アプリの場合、通常は OIDC Authorization Code Flow を使用します:

javascript
// 1. ユーザをOIDCプロバイダのログインページへリダイレクト
const authUrl = `${oidcIssuerUrl}/authorize?` +
  `client_id=${clientId}&` +
  `response_type=code&` +
  `redirect_uri=${encodeURIComponent(redirectUri)}&` +
  `scope=openid profile email`;
window.location.href = authUrl;

// 2. コールバックで認可コードを受け取り、トークンと交換
// サーバサイドで実行（client_secret の保護のため）
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




Step 3: FlightCTL API 固有のトークン交換（必要な場合）POST /api/v1/auth/{providername}/token
OIDC プロバイダから取得したトークンを FlightCTL API のトークンと交換するエンドポイントも用意されています。

:three: 主要 REST エンドポイント一覧

ベース URL: /api/v1

```
カテゴリ            エンドポイント                              メソッド
─────────────────────────────────────────────────────────────────────
認証
  認証設定取得       /auth/config                                GET
  トークン検証       /auth/validate                              GET
  権限取得          /auth/permissions                           GET
  トークン交換       /auth/{providername}/token                   POST
  ユーザ情報        /auth/userinfo                              GET

デバイス
  一覧取得          /devices                                    GET
  作成             /devices                                    POST
  詳細取得          /devices/{name}                             GET
  更新             /devices/{name}                             PUT
  削除             /devices/{name}                             DELETE
  ステータス更新     /devices/{name}/status                      GET/PUT
  廃止             /devices/{name}/decommission                POST
  レンダリング済     /devices/{name}/rendered                    GET
  アプリ操作        /devices/{name}/applications/{app}/actions/* POST
  コンソール(WS)    /ws/v1/devices/{name}/console               WebSocket[5:56 AM]フリート
  一覧取得          /fleets                                     GET
  作成             /fleets                                     POST
  詳細取得          /fleets/{name}                              GET
  更新             /fleets/{name}                              PUT
  削除             /fleets/{name}                              DELETE
  ステータス        /fleets/{name}/status                       GET/PUT
  テンプレート版     /fleets/{fleet}/templateversions             GET
  テンプレート版詳細  /fleets/{fleet}/templateversions/{name}      GET/DELETE

登録リクエスト
  一覧取得          /enrollmentrequests                         GET
  詳細取得          /enrollmentrequests/{name}                  GET
  承認             /enrollmentrequests/{name}/approval          POST

リポジトリ
  一覧取得          /repositories                               GET
  作成             /repositories                               POST
  詳細・更新・削除   /repositories/{name}                        GET/PUT/DELETE

リソース同期
  一覧取得          /resourcesyncs                              GET
  作成             /resourcesyncs                              POST
  詳細・更新・削除   /resourcesyncs/{name}                       GET/PUT/DELETE

その他
  イベント          /events                                     GET
  ラベル           /labels                                     GET
  組織             /organizations                              GET
  認証プロバイダ     /authproviders                              GET/POST
  バージョン        /version                                    GET
*:four: Web アプリからの具体的な呼び出し例*

*JavaScript (fetch API)*

```javascript
const FLIGHTCTL_API = 'https://your-rhem-api-server/api/v1';
const TOKEN = 'your-jwt-token';

const headers = {
  'Authorization': `Bearer ${TOKEN}`,
  'Accept': 'application/json',
  'Content-Type': 'application/json',
  'Flightctl-API-Version': 'v1beta1',  // APIバージョン指定（推奨）
};

// デバイス一覧取得
async function listDevices() {
  const res = await fetch(`${FLIGHTCTL_API}/devices`, { headers });
  return res.json();
}

// ラベルセレクタによるフィルタリング
async function listDevicesBySite(site) {
  const params = new URLSearchParams({
    labelSelector: `site=${site}`,
  });
  const res = await fetch(`${FLIGHTCTL_API}/devices?${params}`, { headers });
  return res.json();
}

// 特定デバイスの詳細取得
async function getDevice(name) {
  const res = await fetch(`${FLIGHTCTL_API}/devices/${name}`, { headers });
  return res.json();
}

// デバイスの設定更新（PUT）
async function updateDevice(name, deviceSpec) {
  const device = await getDevice(name);
  device.spec = { ...device.spec, ...deviceSpec };
  const res = await fetch(`${FLIGHTCTL_API}/devices/${name}`, {
    method: 'PUT',
    headers,
    body: JSON.stringify(device),
  });
  return res.json();
}

// フリート作成
async function createFleet(fleetDef) {
  const res = await fetch(`${FLIGHTCTL_API}/fleets`, {
    method: 'POST',
    headers,
    body: JSON.stringify(fleetDef),
  });
  return res.json();
}

// デバイス登録承認
async function approveEnrollment(name, labels) {
  const res = await fetch(
    `${FLIGHTCTL_API}/enrollmentrequests/${name}/approval`,
    {
      method: 'POST',
      headers,
      body: JSON.stringify({ approved: true, labels }),
    }
  );
  return res.json();
}




Python (requests)

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
session.verify = True  # 自己証明書の場合は False

# デバイス一覧
devices = session.get(f"{API_BASE}/devices").json()

# ラベルフィルタ
factory_devices = session.get(
    f"{API_BASE}/devices",
    params={"labelSelector": "site=factory-a"}
).json()

# フリート作成
fleet = {
    "apiVersion": "flightctl.io/v1beta1",
    "kind": "Fleet",
    "metadata": {"name": "production-fleet"},
    "spec": {
        "selector": {"matchLabels": {"stage": "production"}},
        "template": {
            "spec": {[5:56 AM]"os": {"image": "quay.io/redhat/rhde:9.4"},
            }
        },
    },
}
result = session.post(f"{API_BASE}/fleets", json=fleet)
*:five: API バージョンネゴシエーション*

FlightCTL は *ヘッダベースのバージョンネゴシエーション* を採用しています。URL パスは変わりません。

Flightctl-API-Version: v1beta1
- ヘッダを送信しない場合 → 最も安定したバージョンが使用されます
- 未サポートのバージョンを要求した場合 → `406 Not Acceptable` が返り、`Flightctl-API-Versions-Supported` ヘッダに利用可能バージョン一覧が含まれます
- レスポンスの `Flightctl-API-Version` ヘッダで、実際に使用されたバージョンを確認できます

現在のバージョン:
v1beta1  — Device, Fleet, Repository 等（1.x.x でサポート保証）
v1alpha1 — ImageBuild, ImageExport（将来変更の可能性あり）
*:six: 楽観的排他制御（Concurrency Control）*

FlightCTL は `resourceVersion` フィールドによる楽観的排他制御を採用しています。Web アプリで更新する際は以下のパターンに従ってください:

```javascript
// 1. 最新のリソースを取得（resourceVersion を含む）
const device = await getDevice('my-device');

// 2. 変更を加える
device.spec.os.image = 'quay.io/redhat/rhde:9.4';

// 3. resourceVersion を含めて PUT
// → 他のクライアントが先に更新していた場合は 409 Conflict が返る
const res = await fetch(`${FLIGHTCTL_API}/devices/my-device`, {
  method: 'PUT',
  headers,
  body: JSON.stringify(device),  // resourceVersion が自動的に含まれる
});

if (res.status === 409) {
  // 競合発生 → 再取得してリトライ
  console.log('Conflict detected, refetching...');
}




:seven: Web アプリ統合のアーキテクチャパターン

┌──────────────────────────────────┐
│  Web アプリ (React/Vue/Angular)  │
│  ┌──────────────────────────┐    │
│  │ FlightCTL API Client     │    │
│  │ (OpenAPI 自動生成)        │    │
│  └─────────┬────────────────┘    │
└────────────┼─────────────────────┘
             │ HTTPS + Bearer JWT
             ▼
┌──────────────────────────────────┐
│  バックエンド (BFF / API Gateway)│
│  ┌────────────┐ ┌─────────────┐ │
│  │ OIDC Token │ │ FlightCTL   │ │
│  │ 管理       │ │ API Proxy   │ │
│  └────────────┘ └─────────────┘ │
└────────────┬─────────────────────┘
             │ HTTPS + Bearer JWT
             ▼
┌──────────────────────────────────┐
│  FlightCTL API Server            │
│  (RHEM / OpenShift 上)           │
└──────────────────────────────────┘




:warning: セキュリティ上の推奨事項:
 - フロントエンドから直接 API を呼ばず、*BFF（Backend for Frontend）パターン* を使用してバックエンド経由でトークン管理と API 呼び出しを行うことを推奨します
 - client_secret は必ずサーバサイドに保持してください
 - CORS が必要な場合は、FlightCTL API サーバまたは API Gateway 側で適切に設定してください



:eight: 参考リソース

- OpenAPI 仕様 (v1beta1): https://github.com/flightctl/flightctl/blob/main/api/core/v1beta1/openapi.yaml
- OpenAPI 仕様 (v1alpha1): https://github.com/flightctl/flightctl/tree/main/api/core/v1alpha1（ImageBuild / ImageExport 用）
- API リソースリファレンス: https://github.com/flightctl/flightctl/blob/main/docs/user/references/api-resources.md
- 公式ドキュメント: https://docs.redhat.com で「Red Hat Edge Manager」を検索
- FlightCTL UI 参考実装: https://github.com/flightctl/flightctl-ui（React ベースの Web UI。API 呼び出しパターンの参考になります）
