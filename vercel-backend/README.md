# Purple App Backend - Vercel + Supabase

## 🏗️ 架构说明

```
iOS App 
  ↓ (HTTPS + JWT Auth)
Vercel Serverless Functions
  ↓
  ├─ Vercel AI Gateway → OpenAI
  └─ Supabase → PostgreSQL
```

## 🚀 部署步骤

### 1. Supabase设置

1. 创建Supabase项目：https://app.supabase.com
2. 在SQL编辑器中执行 `supabase-schema.sql`
3. 启用Email认证
4. 获取项目URL和Anon Key

### 2. Vercel部署

```bash
# 安装Vercel CLI
npm i -g vercel

# 登录Vercel
vercel login

# 部署
vercel --prod
```

### 3. 环境变量配置

在Vercel控制台设置：
- `VERCEL_AI_GATEWAY_KEY`: 你的Vercel AI Gateway密钥
- `SUPABASE_URL`: Supabase项目URL
- `SUPABASE_ANON_KEY`: Supabase匿名密钥
- `ALLOWED_ORIGINS`: 允许的源（如：`https://yourapp.com,capacitor://localhost`）

## 📱 iOS客户端更新

需要更新 `AIService.swift`：

```swift
// 新的配置
struct AIConfig {
    static let backendURL = "https://your-project.vercel.app/api/chat"
    // 不再需要API密钥
}

// 更新请求方法
func sendMessage(_ message: String) async -> String {
    // 1. 先通过Supabase认证获取JWT token
    let token = await getSupabaseToken()
    
    // 2. 调用后端API
    var request = URLRequest(url: URL(string: AIConfig.backendURL)!)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    // ... 其余代码
}
```

## 🔐 安全特性

1. **API密钥安全**：密钥存储在服务器端
2. **用户认证**：使用Supabase JWT认证
3. **访问控制**：Row Level Security保护用户数据
4. **限流保护**：每用户每日50次请求限制
5. **CORS配置**：限制允许的源

## 📊 数据库功能

- **用户配置**：存储用户信息和星盘数据
- **使用配额**：追踪API使用量
- **聊天历史**：保存对话记录
- **AI人格**：动态配置AI行为
- **运势缓存**：缓存每日运势数据
- **心情记录**：存储用户心情日记

## 🔄 数据流

1. 用户在iOS App发起请求
2. 请求携带JWT token到Vercel Function
3. Function验证用户身份和配额
4. 调用Vercel AI Gateway获取AI响应
5. 保存聊天记录到Supabase
6. 返回响应给客户端

## 💰 成本估算

- **Vercel**：免费套餐包含100GB带宽/月
- **Supabase**：免费套餐包含500MB数据库
- **AI Gateway**：按使用量计费（约$0.03/1K tokens）

月活1000用户估算：
- 每用户每日10次对话
- 每次对话约500 tokens
- 月成本：1000 * 30 * 10 * 500 * 0.00003 = $450

## 🛠️ 监控和维护

1. **Vercel Dashboard**：监控函数调用和错误
2. **Supabase Dashboard**：查看数据库使用情况
3. **日志收集**：使用Vercel内置日志
4. **错误追踪**：集成Sentry（可选）

## 📝 API文档

### POST /api/chat

请求头：
```
Authorization: Bearer <supabase-jwt-token>
Content-Type: application/json
```

请求体：
```json
{
  "message": "用户消息",
  "conversationHistory": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ]
}
```

响应：
```json
{
  "response": "AI回复内容",
  "remainingQuota": 45
}
```

错误响应：
```json
{
  "error": "错误信息"
}
```

## 🔄 后续优化

1. **缓存优化**：使用Vercel KV缓存热点数据
2. **流式响应**：实现SSE流式输出
3. **多模型支持**：支持切换不同AI模型
4. **WebSocket**：实时聊天体验
5. **边缘计算**：使用Edge Functions降低延迟