# 应用RLS策略修复

## 步骤 1: 登录Supabase控制台
1. 访问: https://app.supabase.com
2. 选择你的项目 (pwisjdcnhgbnjlcxjzzs)

## 步骤 2: 运行SQL脚本
1. 在左侧菜单点击 "SQL Editor"
2. 点击 "New Query"
3. 复制 `fix-rls-policies.sql` 文件的内容
4. 点击 "Run" 执行脚本

## 步骤 3: 验证策略已应用
脚本最后会显示所有表的策略列表，确认看到:
- chat_sessions: "Enable all for anon"
- chat_messages: "Enable all for anon"
- user_ai_preferences: "Enable all for anon"
- user_ai_quotas: "Enable all for anon"
- star_charts: "Enable all for anon"

## 注意事项
⚠️ 这些宽松的策略仅用于开发测试！
生产环境应该使用更严格的基于用户ID的策略。

## 测试验证
应用策略后，运行:
```bash
swift test_supabase.swift
```

应该看到:
✅ Successfully created test session!
🎉 Supabase connection is working!