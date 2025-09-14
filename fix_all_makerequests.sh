#!/bin/bash

# 修复所有makeRequest调用的脚本
echo "🔧 开始批量修复makeRequest调用..."

# 统计需要修复的文件
echo "📊 需要修复的文件："
grep -r "makeRequest" --include="*.swift" PurpleM/Services/ | cut -d: -f1 | sort | uniq

# 创建备份
echo "📦 创建备份..."
cp -r PurpleM/Services PurpleM/Services.backup.$(date +%Y%m%d_%H%M%S)

# 统计makeRequest的数量
TOTAL=$(grep -r "makeRequest" --include="*.swift" PurpleM/Services/ | wc -l)
echo "🔍 共找到 $TOTAL 处makeRequest调用需要修复"

# 显示每个文件的makeRequest数量
echo "📈 各文件的makeRequest数量："
for file in $(grep -r "makeRequest" --include="*.swift" PurpleM/Services/ | cut -d: -f1 | sort | uniq); do
    COUNT=$(grep -c "makeRequest" "$file")
    echo "  - $(basename $file): $COUNT 处"
done

echo ""
echo "⚠️  注意：这些文件需要手动修复："
echo "  1. 将所有makeRequest替换为SupabaseAPIHelper的对应方法"
echo "  2. 添加 let userToken = KeychainManager.shared.getAccessToken()"
echo "  3. 使用正确的authType: .authenticated"
echo ""
echo "✅ 分析完成！"