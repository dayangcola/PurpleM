# Vercel 环境变量配置指南

## 必需的环境变量

你需要在 Vercel Dashboard 中配置以下环境变量：

### 1. 获取 Supabase 配置

访问你的 Supabase Dashboard:
https://supabase.com/dashboard/project/pwisjdcnhgbnjlcxjzzs/settings/api

#### 需要配置的变量：

1. **NEXT_PUBLIC_SUPABASE_URL**
   - 值: `https://pwisjdcnhgbnjlcxjzzs.supabase.co`
   - 位置: Project Settings > API > Project URL

2. **SUPABASE_SERVICE_ROLE_KEY** ⚠️ 重要
   - 位置: Project Settings > API > Service role (secret)
   - 注意: 这是 service_role key，不是 anon key！
   - 这个key有完全的数据库访问权限，请保密

### 2. 在 Vercel 中配置

1. 访问: https://vercel.com/dashboard
2. 选择你的项目 (purple-m)
3. 进入 Settings > Environment Variables
4. 添加以下变量：

```
NEXT_PUBLIC_SUPABASE_URL = https://pwisjdcnhgbnjlcxjzzs.supabase.co
SUPABASE_SERVICE_ROLE_KEY = [从Supabase获取的service role key]
```

### 3. 验证配置

配置完成后，访问以下URL验证：
```
https://purple-m.vercel.app/api/check-env
```

应该返回：
```json
{
  "success": true,
  "environment": {
    "NEXT_PUBLIC_SUPABASE_URL": true,
    "SUPABASE_SERVICE_ROLE_KEY": true,
    "SUPABASE_URL_VALID": true
  },
  "message": "✅ 环境变量已配置"
}
```

## 重要提示

- Service Role Key 拥有完全的数据库访问权限
- 永远不要在客户端代码中使用 Service Role Key
- 只在服务器端（API routes）使用
- 确保 Service Role Key 不要提交到 Git

## 获取 Service Role Key 步骤

1. 登录 Supabase Dashboard
2. 选择你的项目
3. 左侧菜单选择 Settings (设置)
4. 选择 API 子菜单
5. 找到 "Service role" 部分
6. 点击 "Reveal" 显示密钥
7. 复制整个密钥（很长的JWT token）
8. 粘贴到 Vercel 环境变量中