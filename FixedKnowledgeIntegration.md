# 🚀 知识库流式集成修复文档

## 修复日期
2025-09-16

## 🎯 核心问题
流式模式（ChatTab 默认模式）无法使用知识库功能，导致：
1. iOS 客户端无法访问环境变量中的 OpenAI API Key
2. 系统提示词被多次覆盖
3. 用户个性化信息未传递到服务端
4. 知识库搜索在客户端无法执行

## ✅ 解决方案

### 1. **创建增强版服务端 API**
**文件**: `api/chat-stream-enhanced.js`

**功能**：
- ✅ 在服务端进行知识库搜索（使用 Supabase）
- ✅ 通过 Vercel AI Gateway 生成嵌入向量
- ✅ 接收完整的用户上下文（用户信息、场景、情绪、命盘）
- ✅ 构建完整的系统提示词
- ✅ 保持流式响应的实时性

**关键代码**：
```javascript
// 1. 服务端知识库搜索
const embedding = await generateEmbedding(userMessage);
const { data: searchResults } = await supabase
  .rpc('search_knowledge', {
    query_embedding: embedding,
    match_threshold: 0.7,
    match_count: 3
  });

// 2. 使用 Vercel AI Gateway
const response = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
  headers: {
    'Authorization': `Bearer ${VERCEL_AI_GATEWAY_KEY}`
  },
  body: JSON.stringify({
    model: `openai/${model}`,
    messages: allMessages,
    stream: true
  })
});
```

### 2. **修改 StreamingAIService**
**文件**: `PurpleM/Services/StreamingAIService.swift`

**改动**：
- ✅ 调用新的增强端点 `/api/chat-stream-enhanced`
- ✅ 支持传递完整用户上下文参数
- ✅ 不再覆盖系统提示词

**新增参数**：
```swift
func sendStreamingMessage(
    _ message: String,
    context: [(role: String, content: String)] = [],
    temperature: Double = 0.7,
    useThinkingChain: Bool = true,
    userInfo: UserInfo? = nil,      // 新增
    scene: String? = nil,           // 新增
    emotion: String? = nil,         // 新增
    chartContext: String? = nil,    // 新增
    systemPrompt: String? = nil     // 新增
)
```

### 3. **修改 ChatTab**
**文件**: `PurpleM/ChatTab.swift`

**改动**：
- ✅ 移除本地知识库搜索（已移到服务端）
- ✅ 传递完整用户上下文到服务端
- ✅ 添加情绪检测和命盘上下文提取

**关键修改**：
```swift
// 获取用户信息和上下文
let userInfo = userDataManager.currentChart?.userInfo
let chartContext = extractChartContext(for: messageText)
let detectedEmotion = detectEmotion(from: messageText)

// 调用增强版流式服务
let stream = try await streamingService.sendStreamingMessage(
    messageText,
    context: context,
    temperature: 0.8,
    useThinkingChain: true,
    userInfo: userInfo,
    scene: scene.rawValue,
    emotion: detectedEmotion.rawValue,
    chartContext: chartContext,
    systemPrompt: systemPrompt
)
```

## 📊 对比表

| 功能 | 修复前 | 修复后 |
|-----|--------|--------|
| 知识库搜索位置 | ❌ 客户端（iOS无法执行） | ✅ 服务端（正常工作） |
| API Key 访问 | ❌ ProcessInfo（iOS不支持） | ✅ 服务端环境变量 |
| 系统提示词 | ❌ 被多次覆盖 | ✅ 完整传递 |
| 用户信息 | ❌ 未传递 | ✅ 完整传递 |
| 场景/情绪 | ❌ 缺失 | ✅ 包含 |
| 流式响应 | ✅ 正常 | ✅ 保持正常 |
| Vercel AI Gateway | ❌ 未使用 | ✅ 统一使用 |

## 🧪 测试要点

### 1. 功能测试
```
测试问题：
- "什么是化忌？"
- "紫微星在命宫代表什么？"
- "我最近事业运势如何？"
```

**期望结果**：
- ✅ AI 回复包含知识库内容
- ✅ 个性化程度提升（如果有用户信息）
- ✅ 场景化回复（根据问题类型）
- ✅ 流式文字正常显示

### 2. 性能测试
- 知识库搜索不应造成明显延迟
- 流式响应保持流畅
- 首字节时间 < 2秒

### 3. 错误处理
- 知识库为空时正常降级
- API Key 缺失时友好提示
- 网络异常时的重试机制

## 🔧 环境配置

### Vercel 环境变量
```
VERCEL_AI_GATEWAY_KEY=xxx
NEXT_PUBLIC_SUPABASE_URL=xxx
SUPABASE_SERVICE_KEY=xxx
```

### 注意事项
1. **必须**使用 Vercel AI Gateway，不直接调用 OpenAI
2. 确保 Supabase 的 `search_knowledge` 函数已创建
3. 知识库需要预先上传 PDF 文件

## 📈 改进效果

1. **知识库功能正常工作** - 用户可以获得基于专业书籍的准确回答
2. **个性化程度提升** - AI 能识别用户信息、情绪和场景
3. **统一的 AI 调用** - 所有请求通过 Vercel AI Gateway
4. **更好的用户体验** - 保持流式响应的同时提供知识增强

## 🎉 总结

通过将知识库搜索移到服务端，并传递完整的用户上下文，成功解决了流式模式下知识库功能无法使用的问题。现在用户在 Tab 3 聊天时，可以同时享受：
- 实时的流式响应体验
- 基于知识库的专业回答
- 个性化的对话内容
- 场景化的智能交互

---
*修复人: Claude Code Assistant*
*遵循原则: 使用 Vercel AI Gateway 统一 AI 接口*