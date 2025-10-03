# 数据库修复指南

## 问题总结

我们发现并修复了以下数据库相关问题：

1. **外键约束错误** - profiles表缺失用户记录导致chat_sessions和chat_messages无法创建
2. **Supabase Auth同步问题** - 邮件注册的用户未自动在profiles表创建记录
3. **重复键错误** - user_ai_preferences表的upsert操作处理不当
4. **UPDATE语句错误** - 缺少WHERE子句导致更新失败

## 已实施的解决方案

### 1. 创建了三个核心修复文件

#### A. DatabaseFixManager.swift
- 位置：`PurpleM/Services/DatabaseFixManager.swift`
- 功能：
  - 确保profile存在后再创建session和message
  - 使用UPSERT避免重复键冲突
  - 修复UPDATE语句问题

#### B. AuthSyncManager.swift
- 位置：`PurpleM/Services/AuthSyncManager.swift`
- 功能：
  - 同步Supabase Auth用户到profiles表
  - 初始化用户相关的所有必要数据
  - 处理新用户注册后的初始化

#### C. fix-auth-profiles-sync.sql
- 位置：`supabase/fix-auth-profiles-sync.sql`
- 功能：
  - 创建数据库触发器自动同步Auth用户
  - 修复现有的孤立用户数据
  - 设置正确的RLS策略

### 2. 修改了现有文件

- **DataSyncManager.swift** - 使用DatabaseFixManager的安全方法
- **AuthManager.swift** - 使用AuthSyncManager进行用户同步

## 如何应用修复

### 步骤1：在Supabase中运行SQL脚本

1. 登录到您的Supabase项目控制台
2. 进入SQL编辑器
3. 复制并运行 `supabase/fix-auth-profiles-sync.sql` 的内容
4. 检查输出，确认：
   - Auth用户总数
   - Profile记录总数
   - 孤立的Auth用户数（应该为0）

### 步骤2：重新构建应用

```bash
# 清理构建缓存
rm -rf ~/Library/Developer/Xcode/DerivedData/PurpleM-*

# 重新构建
xcodebuild -project PurpleM.xcodeproj -scheme PurpleM -configuration Debug -sdk iphonesimulator build
```

### 步骤3：测试认证流程

1. 注册新用户（使用邮件）
2. 检查数据库确认以下表都有对应记录：
   - profiles
   - user_ai_quotas
   - user_ai_preferences
   - chat_sessions（至少一个默认会话）

## 错误处理机制

### 离线队列处理
当网络不可用时，所有操作会被加入离线队列，网络恢复后自动重试。

### 永久性错误处理
- 409错误（重复键）：使用UPSERT自动处理
- 400错误（缺少WHERE）：已修复为使用正确的UPSERT语法
- 外键约束错误：通过确保父记录存在来避免

## 监控和调试

### 检查数据完整性
运行以下SQL查询检查数据完整性：

```sql
-- 检查孤立的Auth用户
SELECT au.id, au.email 
FROM auth.users au 
LEFT JOIN profiles p ON au.id = p.id 
WHERE p.id IS NULL;

-- 检查没有配额的用户
SELECT p.id, p.email 
FROM profiles p 
LEFT JOIN user_ai_quotas q ON p.id = q.user_id 
WHERE q.user_id IS NULL;

-- 检查没有偏好设置的用户
SELECT p.id, p.email 
FROM profiles p 
LEFT JOIN user_ai_preferences pref ON p.id = pref.user_id 
WHERE pref.user_id IS NULL;
```

### 日志监控
应用中的关键操作都有详细日志：
- 🔍 检查操作
- 📝 创建操作
- ✅ 成功
- ⚠️ 警告
- ❌ 错误

## 预防措施

1. **始终使用UPSERT** - 避免重复键错误
2. **使用on_conflict参数** - 指定冲突处理策略
3. **检查父记录** - 在创建子记录前确保父记录存在
4. **使用事务** - 确保数据一致性

## 常见问题

### Q: 用户注册后仍然出现外键约束错误？
A: 检查数据库触发器是否正确安装，运行fix-auth-profiles-sync.sql

### Q: UPDATE语句仍然报错？
A: 确保使用UPSERT而不是PATCH/UPDATE，参考DatabaseFixManager的实现

### Q: 离线队列一直重试失败的操作？
A: 检查OfflineQueueManager，确保永久性错误（如409）被正确识别并丢弃

## 联系支持

如果问题持续存在，请提供：
1. 错误日志截图
2. Supabase项目ID
3. 测试用户的email

---

最后更新：2024-01-13