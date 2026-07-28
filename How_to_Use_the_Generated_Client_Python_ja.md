# 生成クライアントを Python アプリで使う方法

自動生成クライアント（SDK）を使用すると、`requests` や `urllib` で URL・ヘッダー・型を手動で構築する必要がなくなります。代わりに、API エンドポイントを**型ヒント付きの Python メソッド**として呼び出すことができます。

以下は Python（`python` ジェネレーター）を使用したステップバイステップの解説です。

---

> 本ドキュメント内の `<RHEM_HOST>` は Red Hat Edge Manager のホスト名に置き換えてください（例: `rhem01.example.com`）。

## ワークフロー概要

```
[1. 生成] ──► [2. 設定と初期化] ──► [3. API メソッドの呼び出し]
```

---

## ステップ 1: クライアントコードの生成

まず、OpenAPI スペックファイルを用意します。ローカルに `openapi.yaml` がない場合は、公式リポジトリから取得できます：

```bash
curl -o openapi.yaml https://raw.githubusercontent.com/flightctl/flightctl/main/api/core/v1beta1/openapi.yaml
```

次に、ジェネレーター CLI を実行して、プロジェクトディレクトリ内にクライアントのソースコードを出力します。

```bash
# rhem_client ディレクトリにクライアントを生成
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml \
  -g python \
  -o ./rhem_client \
  --additional-properties=packageName=rhem_client \
  --skip-validate-spec
```

> **注意**: `--skip-validate-spec` は、OpenAPI スペックにバリデーションエラー（例: `requestBody` の型不一致）がある場合に必要です。スペックを修正できる場合は、このオプションなしで実行することを推奨します。

これにより、`./rhem_client` 内に以下の API クラスと Python の型定義（モデル）が作成されます：

| API クラス | 主な用途 |
| --- | --- |
| `AuthenticationApi` | 認証設定・トークン・権限の取得 |
| `AuthproviderApi` | 認証プロバイダーの CRUD |
| `CertificatesigningrequestApi` | 証明書署名リクエストの管理 |
| `DeviceApi` | デバイスの CRUD・ステータス管理・アプリ操作 |
| `DeviceactionsApi` | デバイスの一括アクション（レジューム等） |
| `EnrollmentrequestApi` | デバイス登録リクエストの管理 |
| `EventApi` | イベントの一覧取得 |
| `FleetApi` | フリートの CRUD・テンプレートバージョン管理 |
| `LabelApi` | ラベルの一覧取得 |
| `OrganizationApi` | 組織の一覧取得 |
| `RepositoryApi` | リポジトリの CRUD・OCI イメージチェック |
| `ResourcesyncApi` | リソース同期の CRUD |
| `VersionApi` | API バージョン情報の取得 |

生成後、クライアントをインストールします：

```bash
cd rhem_client
pip install .
```

---

## ステップ 2: 共有クライアントインスタンスの初期化

ベース URL、認証トークン（JWT）、共通ヘッダーを設定するための構成ファイルを作成します。

```python
# api/flightctl_client.py
import urllib3
import urllib.parse
import json
import rhem_client

urllib3.disable_warnings()

OIDC_TOKEN_URL = "https://<RHEM_HOST>/_/pam-issuer/api/v1/auth/token"
OIDC_CLIENT_ID = "flightctl-client"


def get_access_token(username: str, password: str) -> str:
    """OIDC パスワードグラントで Bearer トークンを取得する"""
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
        raise RuntimeError(f"トークン取得に失敗: {data}")
    return data["access_token"]


def get_api_client() -> rhem_client.ApiClient:
    """設定済みの API クライアントを生成して返す"""
    config = rhem_client.Configuration(
        host="https://<RHEM_HOST>/api/v1",
    )

    # 自己署名証明書を使用する場合は SSL 検証を無効化
    config.verify_ssl = False

    # OIDC トークンを取得して Authorization ヘッダーに設定
    token = get_access_token("kikyou", "redhat")
    client = rhem_client.ApiClient(config)
    client.default_headers["Authorization"] = f"Bearer {token}"

    return client


# API インスタンスをエクスポート
_client = get_api_client()
device_api = rhem_client.DeviceApi(_client)
fleet_api = rhem_client.FleetApi(_client)
```

> **注意**: 生成コードの `_auth_settings` が空リスト `[]` になっているため、`config.access_token` を設定しても Authorization ヘッダーが送信されません。`client.default_headers["Authorization"]` に直接設定する必要があります。

---

## ステップ 3: アプリケーションで API メソッドを呼び出す

API インスタンスをインポートして直接使用できます。パラメータとレスポンスの型は自動的に付与され、IDE のオートコンプリートが有効になります。

### データの取得（GET）

```python
# app/device_list.py
from api.flightctl_client import device_api
from rhem_client.models import Device


def fetch_devices(site: str = "factory-a") -> list[Device]:
    """デバイス一覧を取得する"""
    try:
        # メソッド名やパラメータの完全なオートコンプリート
        response = device_api.list_devices(
            label_selector=f"site={site}",
        )

        # response.items が Device のリストとして型付けされている
        return response.items or []

    except rhem_client.ApiException as e:
        print(f"デバイスの取得に失敗しました: {e.status} {e.reason}")
        return []


def display_devices():
    """デバイス一覧を表示する"""
    devices = fetch_devices()

    print("デバイス一覧")
    print("-" * 40)

    for device in devices:
        name = device.metadata.name if device.metadata else "不明"
        status = (
            device.status.summary.status
            if device.status and device.status.summary
            else "不明"
        )
        print(f"  {name} - ステータス: {status}")


if __name__ == "__main__":
    display_devices()
```

### データの更新（PUT / POST）

```python
# app/device_update.py
from api.flightctl_client import device_api


def update_device_image(device_name: str, new_image: str):
    """デバイスの OS イメージを更新する"""
    try:
        # 1. 現在のオブジェクトを取得（型安全）
        device = device_api.get_device(name=device_name)

        # 2. ペイロードを変更
        if device.spec:
            device.spec.os = {"image": new_image}

        # 3. 更新を送信
        updated_device = device_api.replace_device(
            name=device_name,
            device=device,
        )

        print(f"更新に成功しました: {updated_device.metadata.name}")

    except rhem_client.ApiException as e:
        print(f"更新に失敗しました: {e.status} {e.reason}")
```

### データの削除（DELETE）

```python
# app/device_delete.py
from api.flightctl_client import device_api
import rhem_client


def delete_device(device_name: str):
    """デバイスを削除する"""
    try:
        device_api.delete_device(name=device_name)
        print(f"デバイス '{device_name}' を削除しました")

    except rhem_client.ApiException as e:
        print(f"削除に失敗しました: {e.status} {e.reason}")
```

### フリート管理の例

```python
# app/fleet_management.py
from api.flightctl_client import fleet_api
import rhem_client


def list_fleets():
    """フリート一覧を取得する"""
    try:
        response = fleet_api.list_fleets()
        for fleet in (response.items or []):
            name = fleet.metadata.name if fleet.metadata else "不明"
            print(f"  フリート: {name}")

    except rhem_client.ApiException as e:
        print(f"フリート取得に失敗しました: {e.status} {e.reason}")
```

---

### Flask Web アプリでの使用例

```python
# app.py
from flask import Flask, jsonify, request
from api.flightctl_client import device_api, fleet_api
import rhem_client

app = Flask(__name__)


@app.route("/devices")
def list_devices():
    """デバイス一覧を JSON で返す"""
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
    """デバイスの OS イメージを更新する"""
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

## 主なメリット

| 手動の `requests` | 自動生成クライアント |
| --- | --- |
| 手動での URL 文字列結合（タイプミスのリスク） | 型安全なメソッド呼び出し（例: `device_api.list_devices()`） |
| 型なし、または手動で管理するデータクラス | **Python モデルクラスが自動生成で完全に提供** |
| 手動でのクエリパラメータ構築 | クエリパラメータをキーワード引数として直接渡せる |
| API の破壊的変更が実行時にサイレントに失敗 | クライアントを再生成すると破壊的変更が **mypy / pyright の型チェック**で検出される |

---

## 推奨ベストプラクティス

### 型チェックの活用

生成クライアントと `mypy` や `pyright` を組み合わせることで、API の変更をビルド前に検出できます：

```bash
# 型チェックを実行
mypy app/ --strict
```

### 非同期（async）対応

非同期 Web フレームワーク（FastAPI など）では、生成クライアントの非同期版を使用できます：

```python
# FastAPI + 非同期クライアントの例
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

### コンテキストマネージャーの活用

API クライアントのリソースを適切に管理するために、コンテキストマネージャーを使用します：

```python
import rhem_client

config = rhem_client.Configuration(host="https://<RHEM_HOST>/api/v1")

with rhem_client.ApiClient(config) as client:
    device_api = rhem_client.DeviceApi(client)
    devices = device_api.list_devices()
    print(devices)
# クライアントが自動的にクローズされる
```

---

## 生成されたディレクトリ構成

```
rhem_client/
├── rhem_client/          # Python パッケージ本体
│   ├── __init__.py       # 全 API クラス・モデルのエクスポート
│   ├── api_client.py     # HTTP 通信の基盤クラス
│   ├── configuration.py  # 接続設定（ホスト、認証、プロキシ等）
│   ├── exceptions.py     # ApiException 等の例外クラス
│   ├── rest.py           # REST クライアント（urllib3 ベース）
│   ├── api/              # API クラス（エンドポイントごと）
│   └── models/           # データモデル（リクエスト・レスポンスの型）
├── docs/                 # API ドキュメント（Markdown）
├── test/                 # テストコード
├── pyproject.toml        # パッケージ設定
├── setup.py              # セットアップスクリプト
└── requirements.txt      # 依存パッケージ
```

---

## トラブルシューティング

### SSL 証明書エラー

自己署名証明書を使用している場合：

```python
config = rhem_client.Configuration(
    host="https://<RHEM_HOST>/api/v1",
)
config.verify_ssl = False  # 開発環境のみ。本番では適切な証明書を使用すること
```

### プロキシ設定

```python
config = rhem_client.Configuration(
    host="https://<RHEM_HOST>/api/v1",
)
config.proxy = "http://proxy.example.com:8080"
```

### `failed to get auth token` エラー（認証）

RHEM API は OIDC 認証を使用しており、ベーシック認証（`config.username` / `config.password`）では認証できません。
また、生成コードの `_auth_settings` が空のため、`config.access_token` を設定しても Authorization ヘッダーが送信されません。

**対処法**: OIDC トークンエンドポイントからパスワードグラントでトークンを取得し、`default_headers` に直接設定します（ステップ2のコード参照）。

OIDC 設定は以下で確認できます：

```bash
# 認証プロバイダーの確認
curl -k https://<RHEM_HOST>/api/v1/auth/config

# OIDC well-known 設定の確認
curl -k https://<RHEM_HOST>/_/pam-issuer/api/v1/auth/.well-known/openid-configuration
```

### `ApplicationProviderSpec` の oneOf デシリアライズエラー

デバイス一覧取得時に以下のエラーが発生する場合があります：

```
ValueError: Multiple matches found when deserializing the JSON string
into ApplicationProviderSpec with oneOf schemas: ComposeApplication,
ContainerApplication, HelmApplication, QuadletApplication, VmApplication.
```

これは生成コードの `from_json` が oneOf の各スキーマを総当たりで試し、複数がマッチしてしまうためです。

**対処法**: `models/application_provider_spec.py` の `from_json` メソッドを修正し、`appType` フィールドをディスクリミネーターとして使用します。

```python
# models/application_provider_spec.py の from_json メソッドの先頭に追加
@classmethod
def from_json(cls, json_str: str) -> Self:
    instance = cls.model_construct()
    data = json.loads(json_str)

    # appType でスキーマを直接選択（ディスクリミネーター）
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

    # appType がない場合はフォールバック（従来の総当たり）
    ...
```

> **注意**: マップをクラス変数 `_APPTYPE_CLASS_MAP` として定義すると、Pydantic が `ModelPrivateAttr` として扱い `TypeError: argument of type 'ModelPrivateAttr' is not iterable` が発生します。必ずメソッド内のローカル変数として定義してください。

### `import rhem_client` で `AttributeError` が発生する

生成されたコードで `NUMBER_` プレフィックス付きの enum 値を参照しているが、実際の enum 定義にはそのプレフィックスがないケースがあります。これは openapi-generator のバグです。

```
AttributeError: type object 'ImagePullPolicy' has no attribute 'NUMBER_PullIfNotPresent'.
Did you mean: 'PullIfNotPresent'?
```

**対処法**: 該当ファイルの `NUMBER_` プレフィックスを削除します。

```bash
# 問題のある箇所を検索
grep -rn 'NUMBER_' rhem_client/rhem_client/models/

# 修正が必要だったファイル（本プロジェクトでの実例）:
# - models/image_volume_source.py
#     NUMBER_PullIfNotPresent → PullIfNotPresent
# - models/resource_sync_spec.py
#     NUMBER_ResourceSyncTypeFleet → ResourceSyncTypeFleet
```

修正後、再インストールします：

```bash
cd rhem_client
pip install .
```

### クライアントの再生成

API 仕様（`openapi.yaml`）が更新された場合、クライアントを再生成して再インストールします：

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
