# ⚠️ 重要：配置Vercel环境变量

## 当前状态
✅ Vercel已成功部署到: https://purple-m.vercel.app  
⚠️ 但缺少OpenAI API密钥，需要立即配置

## 快速配置步骤

### 1. 访问Vercel项目设置
1. 登录 https://vercel.com/dashboard
2. 找到 `purple-m` 项目
3. 点击项目进入详情页
4. 点击顶部的 "Settings" 标签

### 2. 添加环境变量
1. 在左侧菜单选择 "Environment Variables"
2. 添加以下变量：

| 变量名 | 值 | 说明 |
|--------|-----|------|
| `OPENAI_API_KEY` | sk-... | 你的OpenAI API密钥 |
| `SUPABASE_URL` | https://pwisjdcnhgbnjlcxjzzs.supabase.co | Supabase项目URL |
| `SUPABASE_ANON_KEY` | eyJ... | 你的Supabase匿名密钥（可选） |

### 3. 重新部署
添加环境变量后，需要重新部署：
1. 在项目页面点击 "Deployments" 标签
2. 找到最新的部署
3. 点击右侧的三个点 "..."
4. 选择 "Redeploy"

### 4. 验证配置
重新部署完成后（约30秒），测试API：

```bash
curl -X POST https://purple-m.vercel.app/api/chat-stream \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "你好"}], "stream": false}'
```

成功响应示例：
```json
{
  "response": "你好！我是星语，你的紫微斗数专家助手...",
  "usage": {
    "prompt_tokens": 123,
    "completion_tokens": 456
  }
}
```

## 获取API密钥

### OpenAI API密钥
1. 访问 https://platform.openai.com/api-keys
2. 点击 "Create new secret key"
3. 复制密钥（以 `sk-` 开头）

### Supabase密钥（可选）
1. 访问你的Supabase项目
2. Settings → API
3. 复制 "anon public" 密钥

## 故障排除

### 问题：仍然显示 "OpenAI API key not configured"
- 确认环境变量名称完全匹配（大小写敏感）
- 确认已经重新部署
- 检查API密钥是否有效

### 问题：API调用返回401错误
- 检查OpenAI账户是否有余额
- 确认API密钥没有过期

## iOS应用配置
✅ 已更新：StreamingAIService.swift 现在指向正确的URL:
```swift
let endpoint = "https://purple-m.vercel.app/api/chat-stream"
```

---

配置完成后，流式推理功能将立即生效！
你将在应用中看到AI回复的打字机效果。