# 🔄 完整的 AI 调用流程图

## 📱 整体架构

```
┌─────────────────────────────────────────────────────┐
│                   iOS App (SwiftUI)                  │
│                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │   Tab 1      │  │   Tab 2      │  │   Tab 3   │ │
│  │  命盘/运势    │  │   学习中心    │  │  AI 对话  │ │
│  └──────────────┘  └──────────────┘  └─────┬─────┘ │
└─────────────────────────────────────────────┼───────┘
                                              │
                                              ▼
                              ┌──────────────────────────┐
                              │  StreamingAIService.swift│
                              │  (iOS 客户端服务)         │
                              └──────────┬───────────────┘
                                         │
                                    HTTP POST
                                         │
                    ┌────────────────────▼────────────────────┐
                    │         Vercel Serverless Functions     │
                    │                                          │
                    │  ┌────────────────────────────────────┐ │
                    │  │  /api/chat-stream-v2 (主要端点)     │ │
                    │  │  /api/chat-stream-enhanced         │ │
                    │  │  /api/thinking-chain              │ │
                    │  └──────────┬─────────────────────────┘ │
                    └─────────────┼───────────────────────────┘
                                  │
                         ┌────────▼────────┐
                         │ ai-gateway-client.js │
                         │ (统一客户端)      │
                         └────────┬────────┘
                                  │
                            HTTPS + Auth
                                  │
                    ┌─────────────▼──────────────┐
                    │  Vercel AI Gateway         │
                    │  gateway.vercel.sh         │
                    │  使用 VERCEL_AI_GATEWAY_KEY│
                    └─────────────┬──────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │   OpenAI API    │
                         │  GPT-3.5-turbo  │
                         └─────────────────┘
```

## 🔍 详细流程步骤

### 1️⃣ **用户在 iOS App 发起对话**

```swift
// ChatTab.swift
Button("发送") {
    // 收集用户输入
    let message = inputText
    let userInfo = userDataManager.currentChart?.userInfo
    let emotion = detectEmotion(from: message)
    let scene = detectScene(from: message)
    
    // 调用 StreamingAIService
    await streamingService.sendStreamingMessage(...)
}
```

### 2️⃣ **StreamingAIService 构建请求**

```swift
// StreamingAIService.swift
func sendStreamingMessage() {
    // 构建请求体
    let requestBody = [
        "messages": messages,
        "userMessage": message,
        "model": "standard",  // 使用 GPT-3.5-turbo
        "enableKnowledge": true,
        "enableThinking": useThinkingChain,
        "userInfo": userInfo,
        "scene": scene,
        "emotion": emotion,
        "chartContext": chartContext
    ]
    
    // 发送到 Vercel
    let url = "https://purple-m.vercel.app/api/chat-stream-v2"
    URLSession.dataTask(with: request)
}
```

### 3️⃣ **Vercel API 处理请求**

```javascript
// api/chat-stream-v2.js
export default async function handler(req, res) {
    const { messages, userMessage, enableKnowledge, ... } = req.body;
    
    // Step 1: 构建系统提示词
    let systemPrompt = SYSTEM_PROMPTS.base;
    
    // Step 2: 如果启用知识库
    if (enableKnowledge && userMessage) {
        // 调用 Supabase 向量搜索
        const embedding = await generateEmbedding(userMessage);
        const knowledgeResults = await supabase.rpc('search_knowledge', {
            query_embedding: embedding
        });
        systemPrompt += knowledgeResults;
    }
    
    // Step 3: 添加场景、情绪、用户信息
    systemPrompt += buildContext(scene, emotion, userInfo);
    
    // Step 4: 调用 AI Gateway
    const response = await streamChatCompletion({
        messages: [{ role: 'system', content: systemPrompt }, ...messages],
        model: 'gpt-3.5-turbo'
    });
    
    // Step 5: 流式返回
    for await (const chunk of handleStreamResponse(response)) {
        res.write(`data: {"content": "${chunk}"}\n\n`);
    }
}
```

### 4️⃣ **AI Gateway 客户端处理**

```javascript
// lib/ai-gateway-client.js
export async function streamChatCompletion(options) {
    // 构建 Gateway 请求
    const response = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
        headers: {
            'Authorization': `Bearer ${VERCEL_AI_GATEWAY_KEY}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            model: `openai/${options.model}`,  // openai/gpt-3.5-turbo
            messages: options.messages,
            temperature: 0.7,
            stream: true
        })
    });
    
    return response;
}
```

### 5️⃣ **iOS 接收流式响应**

```swift
// StreamingAIService.swift
func handleStreamResponse() {
    // 解析 Server-Sent Events
    for await chunk in response {
        if let data = parseSSE(chunk) {
            // 更新 UI
            currentResponse += data.content
            // 通知 SwiftUI 更新
            continuation.yield(data.content)
        }
    }
}
```

## 🎯 关键组件说明

### 核心文件
| 文件 | 作用 | 位置 |
|------|------|------|
| **StreamingAIService.swift** | iOS 端 AI 服务 | 客户端 |
| **chat-stream-v2.js** | 主要 API 端点 | 服务端 |
| **ai-gateway-client.js** | Gateway 调用封装 | 服务端 |
| **ChatTab.swift** | 对话界面 | 客户端 |

### 环境变量
```bash
# Vercel 部署需要设置
VERCEL_AI_GATEWAY_KEY=your-gateway-key
NEXT_PUBLIC_SUPABASE_URL=...
SUPABASE_SERVICE_KEY=...
```

## 🔄 数据流

```
1. 用户输入
   ↓
2. iOS App 收集上下文（用户信息、命盘、情绪）
   ↓
3. HTTP POST 到 Vercel Function
   ↓
4. 服务端增强（知识库搜索、场景优化）
   ↓
5. 调用 Vercel AI Gateway
   ↓
6. Gateway 转发到 OpenAI
   ↓
7. 流式返回响应
   ↓
8. iOS 实时显示打字效果
```

## ⚡ 优化特点

1. **知识库集成**
   - 服务端进行向量搜索
   - 自动增强 AI 回答的准确性

2. **上下文感知**
   - 传递用户信息
   - 识别对话场景
   - 检测用户情绪

3. **流式响应**
   - 实时打字效果
   - 用户体验流畅

4. **成本优化**
   - 默认使用 GPT-3.5-turbo
   - 通过 Gateway 统一管理

## 🚀 调用示例

### 简单对话
```
用户: "今天运势如何？"
→ 场景: fortuneTelling
→ 知识库: 搜索运势相关内容
→ AI: 流式返回个性化运势分析
```

### 思维链模式
```
用户: "分析我的命盘"
→ 启用: enableThinking = true
→ 返回: <thinking>分析过程</thinking><answer>结论</answer>
```

---
*更新时间：2025-09-16*
*架构：iOS → Vercel → Gateway → OpenAI*
*默认模型：GPT-3.5-turbo*