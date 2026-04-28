`flightctl` でカタログアイテムを正常に登録・管理するための全手順をまとめます。

---

### ステップ1：カタログ（Catalog）の作成
まず、`infrastructure` という名前のカタログ本体を作成します。

1. **ファイル作成**: `catalog.yaml`
   ```yaml
   apiVersion: flightctl.io/v1alpha1
   kind: Catalog
   metadata:
     name: infrastructure
   spec:
     displayName: Infrastructure Services
   ```

2. **実行**:
   ```bash
   flightctl apply -f catalog.yaml
   ```

---

### ステップ2：カタログアイテム（CatalogItem）の作成
カタログが存在している状態で、Keycloak の定義を登録します。

1. **ファイル作成**: `catalog-item.yaml`（すでにあるファイルを使用）
   ```yaml
   apiVersion: flightctl.io/v1alpha1
   kind: CatalogItem
   metadata:
     name: keycloak
     catalog: infrastructure # ここがステップ1の名称と一致している必要があります
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

2. **実行**:
   ```bash
   flightctl apply -f catalog-item.yaml
   ```

---

### ステップ3：登録状況の確認
登録が正しく完了したか、以下のコマンドで確認します。

1. **カタログの確認**:
   ```bash
   flightctl get catalogs
   ```

2. **カタログアイテムの確認**:
   ```bash
   flightctl get catalogitems
   ```

3. **詳細の確認** (特定のリソースを詳しく見たい場合):
   ```bash
   flightctl get catalogitem keycloak -o yaml
   ```
