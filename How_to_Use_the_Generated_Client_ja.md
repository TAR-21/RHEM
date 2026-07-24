# 🛠️ 生成クライアントを Web アプリで使う方法

自動生成クライアント（SDK）を使用すると、`fetch` や `axios` で URL・ヘッダー・型を手動で構築する必要がなくなります。代わりに、API エンドポイントを**オートコンプリート付きの型安全な関数**として呼び出すことができます。

以下は TypeScript（`typescript-fetch` ジェネレーター）を使用したステップバイステップの解説です。

---

## ワークフロー概要

```
[1. 生成] ──► [2. 設定と初期化] ──► [3. API 関数の呼び出し]
```

---

## ステップ 1: クライアントコードの生成

まず、ジェネレーター CLI を実行して、プロジェクトディレクトリ内にクライアントのソースコードを出力します。

```bash
# src/api/generated にクライアントを生成
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml \
  -g typescript-fetch \
  -o ./src/api/generated
```

これにより、`./src/api/generated` 内に API クラス（`DeviceApi`、`FleetApi` など）と TypeScript の型定義が作成されます。

---

## ステップ 2: 共有クライアントインスタンスの初期化

ベース URL、認証トークン（JWT）、共通ヘッダーを設定するための構成ファイルを作成します。

```typescript
// src/api/flightctlClient.ts
import { Configuration, DeviceApi, FleetApi } from './generated';

// 1. 設定オブジェクトを作成
const config = new Configuration({
  // API のベース URL
  basePath: 'https://your-rhem-api-server/api/v1',
  
  // 動的な Bearer トークンプロバイダー
  accessToken: () => {
    return localStorage.getItem('jwt_token') || '';
  },
  
  // カスタムヘッダー（API バージョンの指定など）
  headers: {
    'Flightctl-API-Version': 'v1beta1',
  },
});

// 2. API クラスをインスタンス化してエクスポート
export const deviceApi = new DeviceApi(config);
export const fleetApi = new FleetApi(config);
```

---

## ステップ 3: UI コンポーネントで API メソッドを呼び出す

API インスタンスを UI コンポーネントに直接インポートして使用できます。パラメータとレスポンスの型は自動的に付与され、ビルド時のエラーチェックが有効になります。

### 🔹 データの取得（GET）

```typescript
// src/components/DeviceList.tsx
import React, { useEffect, useState } from 'react';
import { deviceApi } from '../api/flightctlClient';
import { Device } from '../api/generated'; // 生成された型インターフェース

export const DeviceList = () => {
  const [devices, setDevices] = useState<Device[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchDevices() {
      try {
        // メソッド名やクエリパラメータの完全なオートコンプリート
        const response = await deviceApi.listDevices({
          labelSelector: 'site=factory-a',
        });
        
        // TypeScript が response.items を Device[] として認識
        setDevices(response.items || []);
      } catch (error) {
        console.error('デバイスの取得に失敗しました:', error);
      } finally {
        setLoading(false);
      }
    }

    fetchDevices();
  }, []);

  if (loading) return <div>読み込み中...</div>;

  return (
    <div>
      <h2>デバイス一覧</h2>
      <ul>
        {devices.map((device) => (
          <li key={device.metadata?.name}>
            {device.metadata?.name} - ステータス: {device.status?.summary?.status}
          </li>
        ))}
      </ul>
    </div>
  );
};
```

### 🔹 データの更新（PUT / POST）

```typescript
import { deviceApi } from '../api/flightctlClient';

// デバイスの OS イメージを更新する関数
async function updateDeviceImage(deviceName: string, newImage: string) {
  try {
    // 1. 現在のオブジェクトを取得（型安全）
    const device = await deviceApi.getDevice({ name: deviceName });

    // 2. ペイロードを変更
    if (device.spec) {
      device.spec.os = { image: newImage };
    }

    // 3. 更新を送信（ペイロードの構造が不一致の場合、ビルドエラーが発生）
    const updatedDevice = await deviceApi.replaceDevice({
      name: deviceName,
      device: device,
    });

    console.log('更新に成功しました:', updatedDevice);
  } catch (error) {
    console.error('更新に失敗しました:', error);
  }
}
```

---

## 💡 主なメリット

| 手動の `fetch` / `axios` | 自動生成クライアント |
| --- | --- |
| 手動での URL 文字列結合（タイプミスのリスク） | 型安全なメソッド呼び出し（例: `deviceApi.listDevices()`） |
| 型なし、または手動で管理するインターフェース型 | **TypeScript インターフェースが自動生成で完全に提供** |
| 手動でのクエリパラメータ構築（`URLSearchParams`） | クエリパラメータを JavaScript オブジェクトとして直接渡せる |
| API の破壊的変更が実行時にサイレントに失敗 | クライアントを再生成すると破壊的変更が**ビルドエラー**として検出される |

---

## 🔄 推奨ベストプラクティス

本番アプリケーションでは、生成されたクライアント呼び出しを **TanStack Query（React Query）** や **SWR** などのデータフェッチライブラリでラップするのが標準的です：

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

このパターンにより、**エンドツーエンドの型安全性**と**キャッシュ、再フェッチ、状態管理**を組み合わせることができます。

---
