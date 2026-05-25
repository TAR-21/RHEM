# Flightctl 管理下 Edge デバイスにおけるアップデート失敗事象まとめ

## 1. 発生した事象

Flightctl 管理下の Edge デバイス（bootc ベースの RHEL 10 環境）において、OS／コンテナイメージのアップデート中に停電（強制シャットダウン）が発生しました。

通電再開後、デバイス側のアップデート処理が `prefetch failed` エラーで停止し、その後も更新処理が進行しない状態となりました。

---

## 2. 原因

停電により、コンテナイメージのダウンロードおよび展開処理が途中で中断され、Podman/OverlayFS のコンテナストレージ領域が論理的に破損しました。

特に OverlayFS のシンボリックリンク構造（インデックス情報）が不整合状態となり、以下のエラーが継続的に発生していました。

```bash
readlink /var/lib/containers/storage/overlay/l: invalid argument
```

通常のクリーンアップコマンド（例: `podman system prune`）では、OverlayFS のメタデータ破損までは解消できず、不正なリンク情報が残存していました。

その結果、

* イメージ取得処理が毎回同じ箇所で失敗する
* Flightctl の prefetch 処理が再試行を繰り返す
* アップデートが進行しない

という「スタック状態」に陥っていました。

---

## 3. 確立したリカバリ手順

今後、アップデート中の停電や強制終了によって `prefetch failed` が発生した場合は、以下の手順で復旧可能です。

---

## Step 1. Flightctl Agent の停止

まず、コンテナストレージへのアクセスを停止するため、Flightctl Agent を停止します。

```bash
sudo systemctl stop flightctl-agent
```

---

## Step 2. Podman ストレージの完全初期化

破損した OverlayFS メタデータを含めてコンテナストレージ全体を初期化します。

```bash
sudo podman system reset
```

実行時に確認プロンプトが表示された場合は `y` を入力して続行します。

この操作により、`/var/lib/containers/storage` 配下が完全にリセットされ、破損した OverlayFS 情報も削除されます。

---

## Step 3. Flightctl Agent の再起動

ストレージ初期化後、Flightctl Agent を再起動します。

```bash
sudo systemctl start flightctl-agent
```

Agent はコンテナイメージの取得処理を最初から再実行します。

---

## Step 4. ログ確認

以下のコマンドでログを監視し、イメージ取得処理が正常に進行していることを確認します。

```bash
sudo journalctl -u flightctl-agent -f
```

特に `Pulling image...` が停止せず継続して進むことを確認します。

---

## 4. 補足

今回の事象は、アップデート中の突然の電源断によって OverlayFS のメタデータ整合性が失われたことが直接原因でした。

`podman system prune` のような通常クリーンアップでは解消できないケースがあり、その場合は `podman system reset` によるコンテナストレージ全体の初期化が有効です。

特に Edge 環境では、停電・通信断・強制再起動を前提とした運用設計が重要であり、以下のような対策も有効と考えられます。

* アップデート中の電源保護（UPS 等）
* OverlayFS/コンテナストレージの健全性監視
* prefetch 失敗時の自動リカバリ処理
* bootc rollback と組み合わせた耐障害設計
