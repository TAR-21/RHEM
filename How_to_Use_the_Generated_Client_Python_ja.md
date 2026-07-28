# 生成クライアントを Python アプリで使う方法

自動生成クライアント（SDK）を使用すると、`requests` や `urllib` で URL・ヘッダー・型を手動で構築する必要がなくなります。代わりに、API エンドポイントを**型ヒント付きの Python メソッド**として呼び出すことができます。

以下は Python（`python` ジェネレーター）を使用したステップバイステップの解説です。

---

## ワークフロー概要

```
[1. 生成] ──► [2. 設定と初期化] ──► [3. API メソッドの呼び出し]
```

---

## ステップ 1: クライアントコードの生成

まず、ジェネレーター CLI を実行して、プロジェクトディレクトリ内にクライアントのソースコードを出力します。

```bash
# rhem_client ディレクトリにクライアントを生成
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml \
  -g python \
  -o ./rhem_client \
  --additional-properties=packageName=rhem_client
```

これにより、`./rhem_client` 内に API クラス（`DeviceApi`、`FleetApi` など）と Python の型定義（モデル）が作成されます。

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
import rhem_client

def get_api_client() -> rhem_client.ApiClient:
    """設定済みの API クライアントを生成して返す"""

    # 1. 設定オブジェクトを作成
    config = rhem_client.Configuration(
        # API のベース URL
        host="https://your-rhem-api-server/api/v1",
    )

    # 動的な Bearer トークンを設定
    config.access_token = get_jwt_token()

    # 2. API クライアントをインスタンス化
    client = rhem_client.ApiClient(config)

    # カスタムヘッダー（API バージョンの指定など）
    client.default_headers["Flightctl-API-Version"] = "v1beta1"

    return client


def get_jwt_token() -> str:
    """保存済みの JWT トークンを取得する"""
    # 実際のアプリでは、セッションや環境変数から取得
    import os
    return os.environ.get("RHEM_API_TOKEN", "")


# API インスタンスをエクスポート
_client = get_api_client()
device_api = rhem_client.DeviceApi(_client)
fleet_api = rhem_client.FleetApi(_client)
```

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
        print(f"デバイスの取得に失敗しました: {e}")
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
        print(f"更新に失敗しました: {e}")
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
    site = request.args.get("site", "factory-a")

    try:
        response = device_api.list_devices(
            label_selector=f"site={site}",
        )
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

config = rhem_client.Configuration(host="https://your-rhem-api-server/api/v1")

with rhem_client.ApiClient(config) as client:
    device_api = rhem_client.DeviceApi(client)
    devices = device_api.list_devices()
    print(devices)
# クライアントが自動的にクローズされる
```
