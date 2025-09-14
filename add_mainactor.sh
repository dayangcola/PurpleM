#!/bin/bash

# 为关键UI类添加@MainActor
echo "🔧 检查需要添加@MainActor的类..."

# 列出所有Manager类
echo "📋 Manager类列表："
grep -r "class.*Manager" --include="*.swift" PurpleM/ | grep -v "@MainActor" | cut -d: -f1 | sort | uniq | while read file; do
    basename "$file"
done

echo ""
echo "📋 ViewModel类列表："
grep -r "class.*ViewModel" --include="*.swift" PurpleM/ | grep -v "@MainActor" | cut -d: -f1 | sort | uniq | while read file; do
    basename "$file"
done

echo ""
echo "⚠️  这些类应该添加@MainActor以确保线程安全"
echo "✅ 分析完成"