# Vercel 部署设置指南

## 当前问题
API端点还未成功部署到Vercel。需要手动在Vercel仪表板上连接GitHub仓库。

## 快速设置步骤

### 1. 登录Vercel
访问 https://vercel.com 并使用GitHub账号登录

### 2. 导入项目
1. 点击 "Add New..." → "Project"
2. 选择 "Import Git Repository"
3. 搜索并选择 `dayangcola/PurpleM` 仓库
4. 点击 "Import"

### 3. 配置项目
在项目配置页面：

**基础设置：**
- Framework Preset: `Other`
- Root Directory: `.` (留空或输入点号)
- Build Command: 留空
- Output Directory: 留空
- Install Command: `npm install`

### 4. 添加环境变量
点击 "Environment Variables" 添加以下变量：

```
OPENAI_API_KEY = [你的OpenAI API密钥]
SUPABASE_URL = https://pwisjdcnhgbnjlcxjzzs.supabase.co
SUPABASE_ANON_KEY = [你的Supabase密钥]
```

### 5. 部署
点击 "Deploy" 按钮开始部署

### 6. 获取部署URL
部署成功后，你会得到一个URL，类似：
- `https://purplem-xxx.vercel.app`
- 或 `https://your-project-name.vercel.app`

### 7. 更新iOS应用配置
在 `PurpleM/Services/StreamingAIService.swift` 文件中，更新第89行的URL：

```swift
let endpoint = "https://你的实际部署URL/api/chat-stream-enhanced"
```

## 验证部署

部署成功后，测试API端点：

```bash
curl -X POST https://你的部署URL/api/chat-stream-enhanced \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "测试"}], "stream": false}'
```

应该返回类似：
```json
{
  "response": "AI的回复内容",
  "usage": {...}
}
```

## 临时解决方案

如果Vercel部署有问题，可以使用以下临时方案：

### 选项1：使用现有的API端点
如果你有其他已部署的API，可以直接修改 `StreamingAIService.swift` 中的URL。

### 选项2：禁用流式，使用普通模式
编辑 `ChatTab.swift` 第177-180行，改回普通模式：
```swift
// sendStreamingMessage(messageText, scene: currentScene)
sendNormalMessage(messageText)
```

### 选项3：本地开发服务器
如果在本地测试，可以运行本地API服务器：
```bash
cd vercel-backend
npm install
vercel dev
```
然后将URL改为 `http://localhost:3000/api/chat-stream-enhanced`

## 故障排除

### 问题：DEPLOYMENT_NOT_FOUND
- 确认项目已成功导入Vercel
- 检查GitHub仓库是否正确连接
- 确认build没有错误

### 问题：API密钥错误
- 在Vercel项目设置中检查环境变量
- 确认OPENAI_API_KEY有效且有余额

### 问题：CORS错误
- vercel.json已配置CORS，如果还有问题，检查前端请求headers

## 需要帮助？

1. 查看Vercel部署日志
2. 检查GitHub Actions（如果配置了）
3. 在Vercel Dashboard查看Functions日志

---

更新时间：2025-09-15
状态：等待手动连接Vercel
