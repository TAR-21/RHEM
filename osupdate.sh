#!/bin/bash

# --- 設定 ---
DEVICE_ID="device/9micb4ihk5t281a59jijfqn5elmb3pfn4rr6065v25njoiat25mg"
NEW_IMAGE_VALUE="quay.io/tmorisu/custom-rhel95-bootc:2.0.0"
OUTPUT_FILE="my_device_updated.yaml"

# 1. flightctl get で最新のリソースを取得
echo "✅ デバイスID: ${DEVICE_ID} の最新リソースを取得します..."
flightctl get "${DEVICE_ID}" -o yaml > "${OUTPUT_FILE}"

# 2. YAMLファイルを更新可能な形式にクリーンアップし、specにimageを設定

echo "🔄 不要なフィールドを削除し、spec:os:image を設定します..."

# 不要なフィールド（metadataの一部とstatusセクション全体）を削除
sed -i \
    -e '/^  resourceVersion:/d' \
    -e '/^  creationTimestamp:/d' \
    -e '/^  generation:/d' \
    -e '/^status:/,$d' \
    "${OUTPUT_FILE}"

# spec: {} の行を探し、その行を置き換えて os:image: の設定を挿入
# a\ は行の追加、c\ は行の置換です。ここではc\を使って spec: {} 行を置き換えます。
# GNU sed では複数行にわたる変更は 'N' コマンドなどが必要で複雑になるため、
# 以下のように挿入処理を簡略化します。

# spec: {} の行を spec: os: image: の行に置き換える（インデントはYAML構造を考慮）
sed -i '/^spec: {}/c\spec:\n  os:\n    image: '"${NEW_IMAGE_VALUE}" "${OUTPUT_FILE}"


# 3. flightctl apply でリソースを適用
echo "🚀 変更後のリソースを適用（apply）します..."
flightctl apply -f "${OUTPUT_FILE}"

echo "🎉 処理が完了しました。数秒後、再度 flightctl get で spec が更新されたか確認してください。"
