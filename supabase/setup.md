# Supabase设置指南（通过Vercel）

## 1. 通过Vercel创建Supabase项目

### 在Vercel Dashboard:
1. 进入项目设置: https://vercel.com/dashboard/purple-m/settings
2. 点击 Integrations → Add Integration
3. 搜索并选择 Supabase
4. 点击 "Add Integration"
5. 选择 "Create New Supabase Project" 或连接现有项目

## 2. 配置完成后获得的资源

Vercel会自动配置以下环境变量：
- `NEXT_PUBLIC_SUPABASE_URL` - Supabase项目URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` - 公开密钥
- `SUPABASE_SERVICE_ROLE_KEY` - 服务密钥
- `DATABASE_URL` - 数据库连接串

## 3. 在Supabase Dashboard执行数据库Schema

### 访问Supabase Dashboard:
1. 从Vercel集成页面点击 "Open Supabase Dashboard"
2. 或直接访问: https://app.supabase.com

### 执行SQL Schema:
1. 在左侧菜单选择 **SQL Editor**
2. 点击 **New Query**
3. 复制 `supabase/schema.sql` 的内容
4. 粘贴到编辑器
5. 点击 **Run** 执行

### 验证表创建:
1. 在左侧菜单选择 **Table Editor**
2. 应该能看到以下表：
   - profiles
   - user_birth_info
   - star_charts
   - chat_sessions
   - chat_messages
   - user_ai_preferences
   - user_ai_quotas
   - daily_fortunes

## 4. 配置认证设置

### 在Supabase Dashboard:
1. 进入 **Authentication** → **Providers**
2. 确保 **Email** 已启用
3. 配置邮件模板（可选）

### 配置认证URL（重要）:
1. 进入 **Authentication** → **URL Configuration**
2. 添加以下URL：
   - Site URL: `https://purple-m.vercel.app`
   - Redirect URLs: 
     - `https://purple-m.vercel.app/*`
     - `capacitor://localhost` (iOS应用)
     - `http://localhost:3000/*` (开发环境)

## 5. 测试连接

### 通过API测试:
```bash
curl https://purple-m.vercel.app/api/supabase-init
```

应该返回:
```json
{
  "success": true,
  "message": "Supabase connection successful",
  "config": {
    "url": "✅ Configured",
    "anonKey": "✅ Configured",
    "serviceKey": "✅ Configured"
  }
}
```

## 6. iOS应用配置

在iOS项目中创建配置文件:

### Config.swift
```swift
struct Config {
    // 这些值从Vercel环境变量获取
    static let supabaseURL = "你的SUPABASE_URL"
    static let supabaseAnonKey = "你的SUPABASE_ANON_KEY"
    
    // 深链接配置
    static let redirectURL = "com.purple.app://login-callback"
}
```

## 7. 常见问题

### Q: 环境变量没有自动添加？
A: 在Vercel项目设置中手动添加，或重新运行集成。

### Q: 数据库连接失败？
A: 检查RLS策略是否正确配置，确保表已创建。

### Q: iOS应用无法连接？
A: 检查Redirect URLs是否包含 `capacitor://localhost`

## 8. 下一步

1. ✅ Supabase项目创建完成
2. ✅ 数据库Schema执行完成
3. ✅ 环境变量配置完成
4. ⏭️ 开始iOS SDK集成
5. ⏭️ 实现认证功能

---

## 快速检查清单

- [ ] Vercel集成已添加
- [ ] 环境变量已配置
- [ ] 数据库Schema已执行
- [ ] 认证已启用
- [ ] URL配置已添加
- [ ] API测试通过