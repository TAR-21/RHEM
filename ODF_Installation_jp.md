## 💾 ODFインストール前の準備と失敗時のクリーンアップ手順

### 1\. 🛠️ ODFインストール前の準備

RHEM（Red Hat Enterprise Migration Toolkit for Virtualization）のインストールに先立ち、以下のコンポーネントを準備します。

  * **OpenShift (OCP)**
  * **OpenShift Data Foundation (ODF)**
  * **Advanced Cluster Management for Kubernetes (ACM)**

この手順では、**ODFのオペレータをインストールした後**に作成する **`Storage System` リソース**の作成が**失敗**することがあります。失敗した場合は、**完全にクリーンな状態**に戻してから**再インストール**が必要です。

-----

### 2\. ❌ `Storage System` 作成失敗時のクリーンアップ手順

ODFのインストールが途中で失敗した場合、**正式なアンインストール手順**を実行した後、**ノード上の残留データを完全に消去**する必要があります。

#### 2.1. 📝 正式な ODF アンインストール手順の実行

まず、以下のRed Hat Customer Portalのドキュメントに従い、ODFの**正式なアンインストール**を実施してください。

> **🔗 Red Hat Customer Portal**
> [Uninstalling OpenShift Data Foundation in Internal mode](https://access.redhat.com/articles/6525111)

#### 2.2. 💻 ノードに残ったデータの徹底的な消去

正式なアンインストール後もデータが残留し、再インストールがうまくいかないことがあります。その場合は、ODFのノード（ストレージ機能を持つノード）にSSHなどでログインし、**ストレージ関連のデータを手動で完全に消去**します。

> **⚠️ 注意**
> この手順は、ノードの**既存のデータや設定を破壊的に削除**するものです。**対象デバイスやパスがODF専用として割り当てられていることを**必ず確認してから実行してください。特に\*\*`/dev/sdb`\*\*は、ODFに割り当てたディスクであることを確認してください。

1.  **RookとLocal Storageのディレクトリを削除します。**

    ```bash
    rm -rf /var/lib/rook
    rm -rf /mnt/local-storage/
    ```

2.  **ODFで使用していたディスク（例: `/dev/sdb`）の情報を徹底的に消去します。**

      * `ceph-osd` が使用していたデバイスであることを確認したうえで実行してください。
      * 以下のコマンドは、ディスクの**先頭と末尾**の領域にゼロを書き込み、パーティションテーブルやファイルシステムなどの**痕跡を徹底的に消去**します。

    <!-- end list -->

    ```bash
    # ディスクの先頭100MBをゼロで上書き
    dd if=/dev/zero of=/dev/sdb bs=1M count=100

    # ディスクサイズを取得し、末尾1000ブロックをゼロで上書き（メタデータ領域を消去）
    DISK_SIZE=$(blockdev --getsz /dev/sdb)
    dd if=/dev/zero of=/dev/sdb bs=512 seek=$(($DISK_SIZE - 1000)) count=1000

    # 全てのパーティションテーブル（GPT/MBRなど）を消去
    sgdisk --zap-all /dev/sdb

    # ファイルシステムやRAID、LVMなどのシグネチャを全て消去
    wipefs -a /dev/sdb
    ```

この**徹底的な消去**を行うことで、ノードがクリーンな状態に戻り、**ODF（バージョン 4.19.6で動作確認済み）** の再インストールが成功する可能性が高まります。
