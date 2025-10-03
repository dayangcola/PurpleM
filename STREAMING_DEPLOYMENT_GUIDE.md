# 流式推理部署和调试指南

## 当前状态
✅ 前端已配置为支持流式响应
⚠️ 暂时使用普通模式以确保功能正常
❌ 流式 API 端点需要部署到 Vercel

## 问题诊断
根据日志分析，流式功能不工作的原因是：
1. 后端 `chat-stream.js` API 还未部署到 Vercel
2. 前端尝试访问 `https://purplem.vercel.app/api/chat-stream` 但端点不存在
3. 流式请求失败后，降级机制也失败了，导致对话框无响应

## 紧急修复（已完成）
已将 `ChatTab.swift` 临时改回普通模式，确保应用正常工作。

## 完整部署步骤

### 步骤 1：准备后端环境

```bash
cd /Users/link/Downloads/iztro-main/PurpleM/vercel-backend

# 安装必要依赖
npm init -y  # 如果没有 package.json
npm install openai @supabase/supabase-js
```

### 步骤 2：配置环境变量

创建 `.env.local` 文件（本地测试用）：
```env
OPENAI_API_KEY=your_openai_api_key_here
SUPABASE_URL=https://pwisjdcnhgbnjlcxjzzs.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here
ALLOWED_ORIGINS=*
```

### 步骤 3：本地测试流式 API

```bash
# 安装 Vercel CLI（如果还没安装）
npm i -g vercel

# 本地运行测试
vercel dev

# 测试端点（在另一个终端）
curl -X POST http://localhost:3000/api/chat-stream \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "你好"}
    ],
    "stream": true
  }'
```

### 步骤 4：部署到 Vercel

```bash
# 登录 Vercel
vercel login

# 部署项目
vercel --prod

# 部署过程中会询问：
# - Set up and deploy "~/Downloads/iztro-main/PurpleM/vercel-backend"? [Y/n] Y
# - Which scope do you want to deploy to? 选择你的账户
# - Link to existing project? [y/N] N
# - What's your project's name? purplem-backend
# - In which directory is your code located? ./
```

### 步骤 5：配置 Vercel 环境变量

1. 登录 [Vercel Dashboard](https://vercel.com/dashboard)
2. 找到 `purplem-backend` 项目
3. 进入 Settings → Environment Variables
4. 添加以下环境变量：
   - `OPENAI_API_KEY`：你的 OpenAI API 密钥
   - `SUPABASE_URL`：`https://pwisjdcnhgbnjlcxjzzs.supabase.co`
   - `SUPABASE_ANON_KEY`：你的 Supabase 匿名密钥
   - `ALLOWED_ORIGINS`：`*`（生产环境建议设置具体域名）

### 步骤 6：验证部署

```bash
# 获取部署的 URL（通常是 https://purplem-backend.vercel.app）
vercel ls

# 测试流式端点
curl -X POST https://purplem-backend.vercel.app/api/chat-stream \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "测试流式响应"}
    ],
    "stream": true
  }'
```

### 步骤 7：更新前端配置

如果你的 Vercel 部署 URL 不是 `https://purplem.vercel.app`，需要更新前端：

编辑 `/Users/link/Downloads/iztro-main/PurpleM/PurpleM/Services/StreamingAIService.swift`:
```swift
// 将第 89 行的 URL 改为你的实际部署地址
let endpoint = "https://your-actual-url.vercel.app/api/chat-stream"
```

### 步骤 8：启用流式功能

部署成功后，编辑 `ChatTab.swift` 第 177-180 行：
```swift
// 改为使用流式
sendStreamingMessage(messageText, scene: currentScene)
// 注释掉普通模式
// sendNormalMessage(messageText)
```

## 测试检查清单

- [ ] Vercel 部署成功
- [ ] 环境变量配置正确
- [ ] API 端点可访问
- [ ] 本地测试流式响应正常
- [ ] 前端 URL 配置正确
- [ ] 应用中对话功能恢复正常
- [ ] 流式打字机效果显示正确

## 常见问题

### 1. CORS 错误
确保 `ALLOWED_ORIGINS` 环境变量配置正确，或设置为 `*`。

### 2. OpenAI API 错误
- 检查 API 密钥是否有效
- 确认账户有余额
- 验证模型名称正确（使用 `gpt-3.5-turbo`）

### 3. 流式不工作但普通模式正常
- 检查 SSE（Server-Sent Events）是否被防火墙阻止
- 确认 Vercel Edge Runtime 配置正确
- 查看浏览器控制台是否有错误

### 4. 响应很慢
- 考虑使用 `gpt-3.5-turbo` 而非 `gpt-4`
- 检查 Vercel 函数的区域设置
- 优化 token 限制

## 调试命令

```bash
# 查看 Vercel 函数日志
vercel logs

# 查看部署状态
vercel inspect [deployment-url]

# 重新部署
vercel --prod --force
```

## 注意事项

1. **API 密钥安全**：永远不要将 API 密钥提交到 Git
2. **成本控制**：监控 OpenAI API 使用量
3. **错误处理**：确保有降级机制
4. **用户体验**：流式失败时应有明确提示

## 完成后

当流式功能正常工作后，你将看到：
- AI 回复逐字显示
- 打字机效果流畅
- 用户体验显著提升
- 所有对话都使用流式响应

---

如需帮助，请提供：
1. Vercel 部署日志
2. 浏览器控制台错误
3. 网络请求详情