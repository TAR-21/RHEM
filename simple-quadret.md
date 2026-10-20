# Red Hat Edge Manager: UBI 10 ベースの Quadlet デプロイ手順

このガイドでは、Red Hat Edge Manager 1.3 以降の環境で、RHEL 10 ベースのコンテナ（UBI 10）を Quadlet を使用してデプロイする手順を説明します。

## 構成概要
- **OS/イメージ:** RHEL 10 / `ubi10-minimal`
- **ランタイム:** Podman 5.8.2 (5.5 以降必須)
- **レジストリ:** `quay.io/tmorisu/simple-quadret`

---

## ステップ 1: Quadlet 定義ファイルの作成
デバイス上でコンテナを systemd サービスとして動作させるための定義ファイルを作成します。

**ファイル名:** `ubi10-simple.container`

```ini
[Unit]
Description=UBI10 Based Edge Application

[Container]
# RHEL 10ベースの軽量イメージを指定
Image=registry.access.redhat.com/ubi10-minimal:latest
# 実行コマンド（デモ用にスリープを維持）
Exec=sleep infinity
ContainerName=ubi10-simple-app

# レジストリ側の更新を監視して自動更新
AutoUpdate=registry

[Install]
# デバイス起動時に自動開始
WantedBy=default.target
```
[↗](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/building_running_and_managing_containers/porting-containers-to-systemd-using-podman)

---

## ステップ 2: OCI アーティファクトのビルド
Edge Manager のエージェントが取得可能な OCI アーティファクト形式にパッケージ化します。

```bash
# Podman 5.5 以降の artifact コマンドを使用
podman artifact add quay.io/tmorisu/simple-quadret:ubi10-v1 ubi10-simple.container
```
[↗](https://docs.redhat.com/en/documentation/red_hat_edge_manager/1.3/configure-proc_build_podman_packages)

---

## ステップ 3: レジストリへのログインとプッシュ
Quay.io へのプッシュ権限を持つアカウントでログインし、アーティファクトをアップロードします。

```bash
# Quay.io へのログイン
podman login quay.io

# アーティファクトのプッシュ
podman artifact push quay.io/tmorisu/simple-quadret:ubi10-v1
```
[↗](https://docs.redhat.com/en/documentation/red_hat_edge_manager/1.3/configure-proc_build_podman_packages)

---

## ステップ 4: Edge Manager でのデプロイ設定
Edge Manager の「デバイス仕様（Device Specification）」の YAML ファイルに、作成したアーティファクトを追加します。

```yaml
applications:
  - name: ubi10-app
    type: quadlet
    image: quay.io/tmorisu/simple-quadret:ubi10-v1
```

### ライフサイクルの挙動
1. **配布:** Edge Manager エージェントが Quay.io からアーティファクトを Pull します。
2. **展開:** デバイス上の `/etc/containers/systemd/` に `.container` ファイルが自動的に抽出されます。
3. **実行:** `systemctl daemon-reload` が実行され、`ubi10-simple-app.service` としてコンテナが起動します。 [↗](https://docs.redhat.com/en/documentation/red_hat_edge_manager/1.3/deploy-con_podman_lifecycle)

---

**Sources**

- [Porting containers to systemd by using Podman (RHEL 10)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/building_running_and_managing_containers/porting-containers-to-systemd-using-podman)
- [Build a Podman application package (OCI artifact) - Red Hat Edge Manager 1.3](https://docs.redhat.com/en/documentation/red_hat_edge_manager/1.3/configure-proc_build_podman_packages)
- [Podman application lifecycle on the device - Red Hat Edge Manager 1.3](https://docs.redhat.com/en/documentation/red_hat_edge_manager/1.3/deploy-con_podman_lifecycle)
