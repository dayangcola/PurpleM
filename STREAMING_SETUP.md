# 流式推理功能部署指南

## 概述
PurpleM 应用的 AI 助手（第三个 Tab）现已支持流式推理功能，提供打字机效果的实时响应体验。

## 功能特点
- ✅ **实时流式响应**：AI 回复逐字显示，提升用户体验
- ✅ **智能检测**：根据问题类型自动选择是否使用流式
- ✅ **默认启用**：流式功能已默认开启
- ✅ **降级机制**：流式失败时自动降级到普通模式

## 架构说明

### 前端组件
1. **StreamingAIService.swift** - 流式 AI 服务管理
   - 处理 SSE (Server-Sent Events) 响应
   - 管理流式数据解析
   - 提供打字机效果

2. **StreamingDetector.swift** - 智能流式检测
   - 根据消息长度和内容判断
   - 优化后更积极使用流式响应
   - 阈值降低至 20 字符

3. **ChatTab.swift** - 聊天界面
   - 集成流式消息处理
   - 实时更新 UI
   - 自动滚动到最新消息

### 后端 API
- **chat-stream-enhanced.js** - 新的流式 API 端点
  - 路径：`/api/chat-stream-enhanced`
  - 支持 SSE 流式响应
  - 使用 Vercel AI Gateway 模型映射

## 部署步骤

### 1. 后端部署（Vercel）

```bash
# 进入后端目录
cd /Users/link/Downloads/iztro-main/PurpleM/vercel-backend

# 安装依赖
npm install openai @supabase/supabase-js

# 部署到 Vercel
vercel deploy
```

### 2. 环境变量配置

在 Vercel 控制台设置以下环境变量：

```env
OPENAI_API_KEY=your_openai_api_key
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
ALLOWED_ORIGINS=*  # 生产环境请设置具体域名
```

### 3. 前端构建

```bash
# 进入项目目录
cd /Users/link/Downloads/iztro-main/PurpleM

# 清理构建
xcodebuild clean -project PurpleM.xcodeproj -scheme PurpleM

# 构建项目
xcodebuild -project PurpleM.xcodeproj \
           -scheme PurpleM \
           -configuration Release \
           -sdk iphoneos \
           build
```

## 测试流式功能

### 在模拟器中测试

1. 打开 Xcode
2. 选择 iPhone 模拟器
3. 运行项目
4. 切换到第三个 Tab（聊天）
5. 输入测试问题：
   - "详细介绍一下紫微斗数"（触发流式）
   - "好的"（简短回复，可能不触发流式）

### 验证流式响应

观察以下特征确认流式工作正常：
1. AI 回复逐字显示
2. 打字机效果明显
3. 句号后有短暂停顿
4. 控制台无错误日志

## 配置选项

### 用户设置
用户可在设置页面控制：
- **启用流式响应**：总开关（默认开启）
- **智能检测**：自动判断是否使用流式（默认开启）

### 开发者配置

在 `StreamingDetector.swift` 中可调整：
```swift
// 触发流式的最小字符数
if message.count > 20 {  // 可调整此值
    return true
}

// 打字速度（字符/秒）
typingSpeed: 50.0  // 高性能设备
typingSpeed: 30.0  // 普通设备
```

## 监控和调试

### 查看流式统计
```swift
// StreamingAnalytics 会自动记录使用情况
StreamingAnalytics.shared.recordUsage(
    scene: scene,
    messageLength: messageText.count,
    responseLength: fullResponse.count,
    usedStreaming: true
)
```

### 常见问题

1. **流式不工作**
   - 检查后端 API 是否正确部署
   - 验证环境变量配置
   - 确认网络连接正常

2. **响应速度慢**
   - 考虑使用 GPT-3.5-turbo 而非 GPT-4
   - 检查网络延迟
   - 调整打字速度设置

3. **降级到普通模式**
   - 检查错误日志
   - 验证 API 密钥有效性
   - 确认请求格式正确

## 性能优化建议

1. **缓存优化**
   - 启用响应缓存减少重复请求
   - 使用 Vercel Edge Runtime 提升性能

2. **流式缓冲**
   - 调整 bufferSize 优化更新频率
   - 平衡流畅度和性能消耗

3. **智能预测**
   - 根据历史数据优化流式检测
   - 自动学习用户偏好

## 下一步计划

- [ ] 添加语音输入支持
- [ ] 实现多轮对话上下文管理
- [ ] 优化知识库集成
- [ ] 添加响应中断功能
- [ ] 支持 Markdown 渲染

## 联系支持

如有问题，请联系开发团队或查看项目文档。
