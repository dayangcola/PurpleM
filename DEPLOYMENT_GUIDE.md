# 🚀 PurpleM 部署和测试指南

## 📋 当前状态
- ✅ iOS应用代码已修复
- ✅ API代码已修复
- ⏳ 需要重新部署Vercel API

## 🔧 部署步骤

### 1. 重新部署Vercel API (必须)

**方法A：通过Vercel Dashboard**
1. 访问 https://vercel.com
2. 登录你的账号
3. 找到 `purple-m` 项目
4. 点击 "Redeploy" 按钮
5. 等待部署完成

**方法B：通过GitHub推送**
```bash
# 提交修改
git add .
git commit -m "修复AI Gateway模型配置错误"
git push origin main

# 这会自动触发Vercel部署
```

### 2. 验证部署
部署完成后，测试API端点：

```bash
curl -X POST "https://purple-m.vercel.app/api/chat-stream-enhanced" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "测试消息"}],
    "userMessage": "测试消息",
    "model": "standard",
    "temperature": 0.8,
    "stream": true
  }'
```

**期望结果：**
- 应该返回流式数据而不是错误
- 不应该看到 "Model 'openai/standard' not found" 错误

### 3. 重新构建iOS应用

**在Xcode中：**
1. 打开 `PurpleM.xcodeproj`
2. 选择目标设备（iPhone模拟器或真机）
3. 按 `Cmd + Shift + K` 清理项目
4. 按 `Cmd + B` 重新构建
5. 按 `Cmd + R` 运行应用

## 🧪 测试流程

### 1. API测试
```bash
# 测试标准模式
curl -X POST "https://purple-m.vercel.app/api/chat-stream-enhanced" \
  -H "Content-Type: application/json" \
  -d '{"userMessage": "你好", "model": "standard", "stream": true}'

# 测试快速模式
curl -X POST "https://purple-m.vercel.app/api/chat-stream-enhanced" \
  -H "Content-Type: application/json" \
  -d '{"userMessage": "你好", "model": "fast", "stream": true}'
```

### 2. iOS应用测试
1. 启动应用
2. 进入聊天界面
3. 发送消息："我的性格特点是什么？"
4. 观察是否显示流式响应
5. 检查控制台日志

## 🔍 故障排除

### 如果API仍然报错：
1. 检查Vercel Dashboard中的部署日志
2. 确认环境变量 `VERCEL_AI_GATEWAY_KEY` 已设置
3. 检查OpenAI API密钥是否有效

### 如果iOS应用不显示响应：
1. 检查Xcode控制台日志
2. 确认网络连接正常
3. 检查API端点URL是否正确

## 📊 预期结果

**成功的测试应该显示：**
- ✅ API返回流式数据而不是错误
- ✅ iOS应用实时显示AI响应
- ✅ 控制台显示 "📝 收到内容块" 日志
- ✅ 用户界面显示完整的AI回复

## 🎯 关键修复点

1. **模型映射**：`standard` → `gpt-3.5-turbo`
2. **错误处理**：显示具体错误信息给用户
3. **自动重试**：3秒后自动降级到普通模式

---

**下一步：** 重新部署Vercel API，然后测试iOS应用
