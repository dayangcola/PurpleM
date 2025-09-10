# Supabase连接测试指南

## 快速开始

现在您可以通过两种方式测试Supabase连接：

### 方法1：使用Node.js脚本测试（推荐）

在终端运行以下命令：

```bash
cd /Users/link/Downloads/iztro-main/PurpleM
node test-supabase.js
```

这个脚本会测试：
1. ✅ Supabase服务状态
2. ✅ profiles表访问权限  
3. ✅ chat_sessions表
4. ✅ chat_messages表
5. ✅ user_ai_preferences表
6. ✅ user_ai_quotas表
7. ✅ Vercel AI API
8. ✅ search_knowledge RPC函数

### 方法2：在App内测试

1. 运行PurpleM应用
2. 进入"我的"标签页
3. 在DEBUG模式下，您会看到"测试Supabase连接"选项
4. 点击进入测试界面
5. 点击"开始测试"按钮

App内测试包括：
- 网络连接检查
- Supabase连接验证
- 会话创建测试
- 消息保存测试
- 配额检查
- AI API测试
- 离线队列测试
- 记忆同步测试

## 预期结果

### 成功的测试结果

```
🧪 开始测试Supabase连接...

1. 测试Supabase服务状态...
   ✅ Supabase服务正常

2. 测试profiles表访问权限...
   ✅ profiles表可访问

3. 测试chat_sessions表...
   ✅ chat_sessions表可访问

...

📊 测试完成！
   ✅ 通过: 8 项
🎉 恭喜！所有测试通过，系统配置正确！
```

### 常见问题解决

#### 1. Supabase连接失败
- 检查网络连接
- 确认Supabase项目URL和API Key正确
- 检查Supabase项目是否处于活跃状态

#### 2. 表访问失败
- 确认已运行schema.sql创建所有表
- 检查RLS（Row Level Security）策略是否正确设置
- 在Supabase Dashboard中验证表是否存在

#### 3. AI API失败
- 确认Vercel部署成功
- 检查环境变量是否正确配置
- 验证API端点是否可访问

## 配置信息

当前配置（已设置）：
- **Supabase URL**: `https://pwisjdcnhgbnjlcxjzzs.supabase.co`
- **Vercel API**: `https://purple-m.vercel.app/api/chat-auto`
- **API Key**: 已配置

## 下一步

测试通过后，您可以：
1. 开始使用云端同步功能
2. 测试离线模式下的数据队列
3. 验证用户配额管理
4. 检查AI对话历史同步

## 调试提示

如需查看更详细的调试信息：
1. 在Xcode中设置断点
2. 查看Network Monitor的连接状态
3. 检查OfflineQueueManager的队列状态
4. 在Supabase Dashboard中查看实时日志

## 安全注意事项

- 生产环境中应使用环境变量存储敏感信息
- 定期轮换API密钥
- 启用RLS保护数据安全
- 监控API使用量避免超额