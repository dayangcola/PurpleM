# 🏗️ 架构选择建议：直接 Fetch vs Vercel AI SDK

## 📊 功能支持对比

| 功能 | 直接 Fetch 调用 | Vercel AI SDK | 说明 |
|------|----------------|---------------|------|
| **流式响应** | ✅ 支持 | ✅ 支持 | 两者都能处理 SSE |
| **思维链** | ✅ 支持 | ✅ 支持 | 只是 prompt 工程 |
| **知识库** | ✅ 支持 | ✅ 支持 | 与 AI 调用无关 |
| **错误重试** | 🔧 手动实现 | ✅ 内置 | SDK 自带重试 |
| **类型安全** | ❌ 无 | ✅ TypeScript | SDK 有完整类型 |
| **流处理** | 🔧 手动解析 | ✅ 自动 | SDK 简化流处理 |
| **Token 计数** | 🔧 手动 | ✅ 自动 | SDK 自动统计 |

## 🔍 深度分析

### 1️⃣ **直接 Fetch 调用**

```javascript
// 当前实现方式
const response = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
  headers: { 'Authorization': `Bearer ${GATEWAY_KEY}` },
  body: JSON.stringify({ model: 'openai/gpt-3.5-turbo', ... })
});

// 手动处理 SSE
for await (const chunk of response.body) {
  // 手动解析 data: [DONE] 等
}
```

**优点**：
- ✅ **轻量级** - 无额外依赖（Bundle 小）
- ✅ **完全控制** - 可以自定义所有细节
- ✅ **简单直接** - 代码逻辑清晰
- ✅ **完全支持所有功能** - 流式/思维链/知识库

**缺点**：
- ❌ 需要手动处理 SSE 解析
- ❌ 错误处理需要自己写
- ❌ 没有类型支持
- ❌ 需要手动处理 token 计数

### 2️⃣ **Vercel AI SDK**

```javascript
import { streamText } from 'ai';
import { openai } from '@ai-sdk/openai';

const result = await streamText({
  model: openai('gpt-3.5-turbo'),
  messages,
  // SDK 自动处理流、重试、错误
});

for await (const text of result.textStream) {
  // 直接得到文本，无需解析
}
```

**优点**：
- ✅ **开发效率高** - 封装好的 API
- ✅ **错误处理完善** - 自动重试、超时
- ✅ **TypeScript 支持** - 完整类型
- ✅ **功能丰富** - 工具调用、结构化输出等
- ✅ **未来兼容** - 跟随 Vercel 更新

**缺点**：
- ❌ **Bundle 较大** - ai + @ai-sdk/openai 约 200KB+
- ❌ **学习成本** - 需要学习 SDK API
- ❌ **灵活性降低** - 受 SDK 限制

## 🎯 我的建议：**直接 Fetch 调用**

### 理由：

1. **你们的需求简单**
   - 只需要基本的对话功能
   - 不需要复杂的工具调用
   - 不需要结构化输出

2. **已经实现完整**
   - ai-gateway-client.js 已经完整实现
   - 支持所有需要的功能
   - 代码稳定运行

3. **性能优势**
   - Bundle Size 更小（重要！）
   - 加载速度更快
   - 特别是移动端

4. **维护简单**
   - 代码直观易懂
   - 不依赖第三方 SDK 更新
   - 完全控制

## 🛠️ 优化方案

### 立即执行：清理不必要的依赖

```bash
# 1. 删除不用的包
npm uninstall ai @ai-sdk/openai

# 2. 删除混淆的配置
rm lib/ai-config.js  # 或简化为只包含常量

# 3. 保留核心文件
# - lib/ai-gateway-client.js ✅
# - 所有 API 端点 ✅
```

### 优化后的架构：

```
┌─────────────────────────┐
│  ai-gateway-client.js  │  ← 核心客户端
└─────────┬──────────────┘
            │
    ┌───────┼───────┐
    │       │       │
┌───┴───┐ ┌┴───┐ ┌─┴───┐
│ Stream│ │Think│ │Embed│  ← API 端点
└───────┘ └─────┘ └─────┘
```

## ✅ 功能验证

**直接 Fetch 完全支持：**

1. **流式响应** ✅
   ```javascript
   // ai-gateway-client.js 已实现
   handleStreamResponse(response) // SSE 解析
   ```

2. **思维链** ✅
   ```javascript
   // 只是 prompt 工程
   systemPrompt = THINKING_CHAIN_PROMPT
   ```

3. **知识库** ✅
   ```javascript
   // 与 AI 调用无关，独立实现
   generateEmbedding() + Supabase
   ```

## 🎆 结论

**推荐：保持直接 Fetch 调用**

- ✅ 已经完整实现所有功能
- ✅ Bundle Size 更小（重要！）
- ✅ 简单、可控、稳定
- ✅ 不需要学习新 API

**如果未来需要高级功能**（如工具调用、多模态），再考虑迁移到 SDK。

---
*建议时间：2025-09-16*
*推荐方案：直接 Fetch 调用*
*理由：简单、轻量、完全满足需求*