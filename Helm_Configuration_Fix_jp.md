## 📄 Flightctl 復旧・Helm 構成修正ドキュメント

### 1. データベース永続化ボリュームの権限修正

**【事象】**
Helm でデプロイ後、`flightctl-db` が `Permission denied` で起動失敗。
**【原因】**
Helm チャートが作成した PVC の所有権が PostgreSQL 実行ユーザー（UID 26）と一致せず、初期ディレクトリの作成に失敗した。
**【恒久対策（Helm 設定）】**
`values.yaml` または Deployment のマニフェストに以下を反映させる必要があります。

```yaml
spec:
  template:
    spec:
      securityContext:
        fsGroup: 26  # ボリュームの所有権をPostgreSQLグループに強制

```

**【実施した暫定対処】**
root 権限の Pod を一時的にデプロイし、手動で所有権を修正。

```bash
oc run fix-db --image=busybox --restart=Never --overrides='{"spec":{"containers":[{"name":"fix","image":"busybox","command":["sh","-c","chown -R 26:26 /var/lib/pgsql/data"],"volumeMounts":[{"name":"data","mountPath":"/var/lib/pgsql/data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"flightctl-db"}}]}}'

```

---

### 2. 依存関係による Pod 起動待ちの解消

**【事象】**
DB 復旧後も他の Pod が `Init:CrashLoopBackOff` から抜けない。
**【原因】**
Kubernetes の Back-off 指数関数的リトライにより、次の起動試行まで最大 5 分程度の待機が発生していた。
**【対応】**
Deployment のリスタートにより、Helm デプロイ直後のクリーンな起動シーケンスを強制。

```bash
oc rollout restart deployment -l flightctl.service

```

---

### 3. OpenShift コンソールプラグインの有効化

**【事象】**
`ConsolePlugin` リソースは Helm によりデプロイされたが、OpenShift コンソールのメニューに項目が表示されない。
**【原因】**
クラスター全体のコンソール設定 (`consoles.operator.openshift.io/cluster`) の `spec.plugins` リストに `flightctl-plugin` が登録されていなかった。
**【修正内容】**
クラスター設定をパッチしてプラグインを有効化。

```bash
oc patch consoles.operator.openshift.io cluster --type=json -p '[{"op": "add", "path": "/spec/plugins/-", "value": "flightctl-plugin"}]'

```
