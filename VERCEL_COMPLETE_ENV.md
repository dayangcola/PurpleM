# Vercel 完整环境变量配置

## 必需的环境变量

在 Vercel Dashboard 中配置以下所有环境变量：
https://vercel.com/dashboard/[your-project]/settings/environment-variables

### 1. Supabase 配置（已配置）
```
NEXT_PUBLIC_SUPABASE_URL = https://pwisjdcnhgbnjlcxjzzs.supabase.co
SUPABASE_SERVICE_ROLE_KEY = [你的service role key]
```

### 2. OpenAI 配置（需要添加）
```
OPENAI_API_KEY = [你的OpenAI API Key]
```

获取方式：
1. 访问 https://platform.openai.com/api-keys
2. 创建新的API Key
3. 复制并保存

### 3. AI Gateway 配置（可选）
如果你有 Vercel AI Gateway：
```
VERCEL_AI_GATEWAY_KEY = [你的Gateway Key]
AI_GATEWAY_API_KEY = [同上]
```

## 验证配置

配置完成后，访问以下URL验证：

1. 环境变量检查：
```
https://purple-m.vercel.app/api/check-env
```

2. 测试聊天功能：
```
curl -X POST https://purple-m.vercel.app/api/chat-simple \
  -H "Content-Type: application/json" \
  -d '{"message": "你好"}'
```

## API端点说明

- `/api/auth` - 认证相关（登录、注册、登出）
- `/api/chat-simple` - 简单聊天（直接调用OpenAI）
- `/api/chat-openai` - OpenAI聊天（带更多配置）
- `/api/chat-auto` - 自动选择最佳模型
- `/api/chat-with-personality` - 带个性化设置的聊天
- `/api/supabase-init` - Supabase初始化检查
- `/api/check-env` - 环境变量检查

## 重要提示

1. **OPENAI_API_KEY 是必需的** - 没有它，AI聊天功能无法工作
2. 所有环境变量配置后需要等待 Vercel 重新部署
3. 不要在代码中硬编码任何密钥
4. Service Role Key 只能在服务端使用

## 故障排查

如果聊天不工作：
1. 检查是否配置了 OPENAI_API_KEY
2. 查看 Vercel Function Logs 了解具体错误
3. 确认 API Key 有效且有余额
4. 检查网络请求是否到达服务器