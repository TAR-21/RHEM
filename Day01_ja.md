# 🚀 RHEM 初期設定と動作確認のまとめ

このドキュメントは、FlightCtlの初期設定、CLIのインストール、ホスト設定、およびエージェントを含むカスタムOSイメージのビルドと公開の手順をまとめたものです。

-----

## 💻 1. FlightCtl APIエンドポイントの確認

FlightCtlの各種サービスのエンドポイントを確認します。

### FlightCtl API ルート情報

| サービス | ホスト名/URL | ポート | 用途 |
| :--- | :--- | :--- | :--- |
| **FlightCtl API** | `https://api.apps.krm1027.krm.local` | `3443` | `flightctl login` で使用するメイン API |
| **FlightCtl Agent API** | `https://agent-api.apps.krm1027.krm.local` | `7443` | エージェント通信 (デバイス登録用) |
| **CLI Artifacts** | `https://cli-artifacts.apps.krm1027.krm.local` | `8090` | CLI用バイナリ配布など |

### OpenShift上でのサービスとルートの確認

`oc get` コマンドを使用して、OpenShiftクラスター上のサービスとルートが正しくデプロイされていることを確認します。

  * **Service (ClusterIP) の確認**
    ```bash
    oc get svc -n open-cluster-management | grep flightctl-api
    # flightctl-api ... 3443/TCP
    # flightctl-api-agent ... 7443/TCP
    ```
  * **Route の確認**
    ```bash
    oc get route flightctl-api-route -n open-cluster-management -o wide
    # NAME: flightctl-api-route, HOST/PORT: api.apps.krm1027.krm.local, PORT: 3443
    ```

-----

## 🛠️ 2. クライアントホストの準備

CLIを動作させるホストでの準備作業です。

### リポジトリーの有効化とCLIのインストール

1.  **システムに適したリポジトリーの検索**
    ```bash
    subscription-manager repos --list | grep rhacm
    ```
2.  **リポジトリーの有効化**
    ```bash
    subscription-manager repos --enable rhacm-2.14-for-rhel-9-x86_64-rpms
    ```
3.  **`flightctl` CLIのインストール**
    ```bash
    sudo dnf install flightctl
    ```

### `/etc/hosts` の設定

クライアントホストから FlightCtl API に名前解決できるように、 `/etc/hosts` に下記エントリーを追加します。

```text
192.168.3.127   api.apps.krm1027.krm.local
192.168.3.127   agent-api.apps.krm1027.krm.local
192.168.3.127   cli-artifacts.apps.krm1027.krm.local
```

-----

## 🔑 3. FlightCtlへのログインと認証情報取得

### FlightCtlへのログイン

提供された認証情報を使用して `flightctl` にログインします。

```bash
flightctl login \
  --username=kubeadmin \
  --password=******** \
  --insecure-skip-tls-verify \
  https://api.apps.krm1027.krm.local
```

> **注意:** 実際のパスワードは**セキュリティ上の理由からマスク**しています。

### エージェント登録認証情報の取得

デバイスが FlightCtl に登録するために必要な設定ファイルを生成します。

```bash
flightctl certificate request --signer=enrollment --expiration=365d --output=embedded > config.yaml
```

-----

## 📦 4. カスタム RHEL Bootc イメージのビルドと公開

エージェント (`flightctl-agent`) を含むカスタムOSイメージを作成し、レジストリに公開します。

### 作業ディレクトリの準備

```bash
mkdir -p rhel9.5-imagemode
cd rhel9.5-imagemode
sudo cp /etc/yum.repos.d/redhat.repo .
```

### `Containerfile` の作成とカスタマイズ

`flightctl-agent`、`NetworkManager`、`openssh-server` を組み込み、特定のユーザー(`demo:redhat`)とホスト名を定義し、サービス(`sshd`, `flightctl-agent`)を有効化します。

  * **主な設定内容**
      * ホストの `redhat.repo` をコンテナイメージに組み込む。
      * `flightctl-agent`、`NetworkManager`、`openssh-server` をインストール。
      * デモユーザー (`demo:redhat`) の作成と `sudo` 権限の設定。
      * `sshd.service` と `flightctl-agent.service` を有効化。
      * `bootc-fetch-apply-updates.timer` を **マスク** し、更新管理を Edge Manager に委ねる。
      * イメージメタデータとして `bootc-image="true"` などを設定。

### コンテナイメージのビルドと公開

1.  **環境変数の設定**
    ```bash
    export OCI_IMAGE_REPO="quay.io/*********/custom-rhel95-bootc"
    export OCI_IMAGE_TAG="1.0.0"
    ```
2.  **イメージのビルド**
    ```bash
    sudo podman build -t ${OCI_IMAGE_REPO}:${OCI_IMAGE_TAG} .
    ```
3.  **レジストリ (Quay.io) へのログインとプッシュ**
    ```bash
    sudo podman login quay.io # 既にログイン済みの場合はスキップ
    sudo podman push ${OCI_IMAGE_REPO}:${OCI_IMAGE_TAG}
    ```

### ISOイメージの生成

ビルドしたコンテナイメージを、実際のデバイスにデプロイ可能なISOファイルに変換します。

```bash
mkdir -p output
sudo podman run --rm -it --privileged \
    --security-opt label=type:unconfined_t \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v "${PWD}/output":/output \
    registry.redhat.io/rhel9/bootc-image-builder:latest \
    --type iso \
    --output /output \
    --progress=verbose \
    ${OCI_IMAGE_REPO}:${OCI_IMAGE_TAG}
```

生成された ISO イメージは、`output` ディレクトリに保存されます。
