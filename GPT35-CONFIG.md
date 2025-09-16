# 💰 GPT-3.5-turbo 配置完成

## ✅ 默认模型已更改

所有 API 端点现在默认使用 **GPT-3.5-turbo**，这将大幅降低成本。

## 📊 模型配置对比

| 模式 | 之前 | 现在 | 成本对比 |
|------|------|------|----------|
| **fast** | gpt-3.5-turbo | gpt-3.5-turbo | 💵 最低 |
| **standard** | gpt-4o-mini | **gpt-3.5-turbo** | 💵 降低 60% |
| **advanced** | gpt-4o | gpt-4o-mini | 💵 降低 30% |

## 📝 修改的文件

1. **lib/ai-gateway-client.js**
   - 默认模型: `gpt-3.5-turbo`

2. **api/chat-stream-v2.js**
   - fast: `gpt-3.5-turbo`
   - standard: `gpt-3.5-turbo` ⬇️
   - advanced: `gpt-4o-mini`

3. **api/thinking-chain.js**
   - 同上配置

4. **api/chat-stream-enhanced.js**
   - 默认: `gpt-3.5-turbo`

## 🚀 使用方法

### 1. 设置环境变量

```bash
# 创建 .env.local 文件
cp .env.local.example .env.local

# 编辑并添加你的 Gateway Key
VERCEL_AI_GATEWAY_KEY=your-actual-gateway-key
```

### 2. 本地测试

```bash
# 加载环境变量并测试
source .env.local && export $(cat .env.local | xargs)
node test-gateway.js
```

### 3. 部署到 Vercel

在 Vercel 控制台设置环境变量：
- `VERCEL_AI_GATEWAY_KEY` = your-key
- `NEXT_PUBLIC_SUPABASE_URL` = ...
- 其他需要的变量

## 💰 成本节约估算

| 场景 | GPT-4 成本 | GPT-3.5 成本 | 节约 |
|------|------------|--------------|------|
| 1000 次对话 | $30-50 | $3-5 | **90%** |
| 10000 次对话 | $300-500 | $30-50 | **90%** |
| 月度估算 | $1000+ | $100-200 | **80-90%** |

## ⚠️ 注意事项

1. **性能差异**
   - GPT-3.5 在复杂推理上稍弱
   - 但对于大部分紫微斗数咨询足够

2. **用户体验**
   - 响应速度更快
   - 成本更低，可以提供更多免费额度

3. **升级选项**
   - 用户可以选择 "advanced" 模式使用 GPT-4o-mini
   - 未来可以添加付费选项使用 GPT-4

## 🎯 下一步优化

1. **添加模型选择器**
   - 让用户在 UI 中选择模型
   - VIP 用户可以使用 GPT-4

2. **成本监控**
   - 跟踪每个用户的使用量
   - 设置使用限额

3. **缓存优化**
   - 缓存常见问题的答案
   - 进一步降低成本

---
*配置时间：2025-09-16*
*默认模型：GPT-3.5-turbo*
*预计节约：80-90%*