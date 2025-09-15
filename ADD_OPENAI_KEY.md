# 添加 OpenAI API 密钥

## 当前状态
- ✅ Vercel 已配置 VERCEL_AI_GATEWAY_KEY
- ⚠️ 还需要 OPENAI_API_KEY 才能使用流式 API

## 快速添加步骤

1. **获取 OpenAI API 密钥**
   - 访问 https://platform.openai.com/api-keys
   - 创建新密钥（以 sk- 开头）

2. **在 Vercel 添加环境变量**
   - 访问 https://vercel.com/dashboard
   - 进入 purple-m 项目
   - Settings → Environment Variables
   - 添加：
     - 名称：`OPENAI_API_KEY`
     - 值：`sk-...`（你的密钥）

3. **重新部署**
   - Deployments → 最新部署 → Redeploy

完成！流式 API 将立即工作。