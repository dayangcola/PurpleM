#!/bin/bash

# 替换所有文件中的Token获取方式
FILES=(
    "PurpleM/Services/SupabaseManager.swift"
    "PurpleM/Services/SupabaseManager+Charts.swift"
    "PurpleM/Services/SessionManager.swift"
    "PurpleM/Services/AuthSyncManager.swift"
    "PurpleM/Services/SupabaseValidationTest.swift"
    "PurpleM/Utils/CacheCleaner.swift"
    "PurpleM/Utils/DebugHelper.swift"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "Processing $file..."
        # 替换 UserDefaults.standard.string(forKey: "accessToken") 为 KeychainManager.shared.getAccessToken()
        sed -i '' 's/UserDefaults\.standard\.string(forKey: "accessToken")/KeychainManager.shared.getAccessToken()/g' "$file"
        echo "✅ Updated $file"
    fi
done

echo "✅ All files updated!"