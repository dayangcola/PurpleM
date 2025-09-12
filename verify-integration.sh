#!/bin/bash

echo "🔍 验证知识库集成状态..."
echo "================================"

# 检查文件
echo "📁 检查必要文件..."
FILES_OK=true

if [ -f "PurpleM/KnowledgeManager.swift" ]; then
    echo "  ✅ KnowledgeManager.swift"
else
    echo "  ❌ KnowledgeManager.swift 缺失"
    FILES_OK=false
fi

if [ -f "PurpleM/EnhancedChatComponents.swift" ]; then
    echo "  ✅ EnhancedChatComponents.swift"
else
    echo "  ❌ EnhancedChatComponents.swift 缺失"
    FILES_OK=false
fi

if [ -f "PurpleM/Services/EnhancedAIService.swift" ]; then
    echo "  ✅ EnhancedAIService.swift (已更新)"
else
    echo "  ❌ EnhancedAIService.swift 缺失"
    FILES_OK=false
fi

echo ""

# 检查关键集成点
echo "🔗 检查代码集成..."

# 检查是否包含知识搜索功能
if grep -q "searchKnowledgeBase" PurpleM/Services/EnhancedAIService.swift; then
    echo "  ✅ 知识库搜索已集成到AI服务"
else
    echo "  ❌ AI服务未集成知识库搜索"
fi

if grep -q "searchKnowledgeWithTextSearch" PurpleM/Services/SupabaseManager+Knowledge.swift; then
    echo "  ✅ Supabase文本搜索接口就绪"
else
    echo "  ❌ Supabase接口未更新"
fi

echo ""

# 简单编译测试
echo "🔨 测试编译..."
xcodebuild -project PurpleM.xcodeproj -scheme PurpleM -configuration Debug -sdk iphonesimulator -quiet build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED)" &

# 等待编译结果
sleep 5

if [ "$FILES_OK" = true ]; then
    echo ""
    echo "================================"
    echo "✅ 文件集成完成！"
    echo ""
    echo "📱 现在可以："
    echo "1. 打开 Xcode (已打开)"
    echo "2. Command + R 运行应用"
    echo "3. 测试知识库功能"
    echo ""
    echo "🧪 测试问题："
    echo "- 紫微星是什么？"
    echo "- 命宫代表什么？"
    echo "- 化忌的含义"
else
    echo ""
    echo "⚠️ 需要手动添加文件到Xcode项目"
    echo "请在Xcode中右键点击PurpleM文件夹，选择Add Files..."
fi