# Supabase数据同步问题系统排查报告

## 📊 排查总结

经过系统性排查，发现了以下可能导致数据无法正确保存到Supabase的问题：

`★ Insight ─────────────────────────────────────`
主要问题集中在：1) RLS策略配置不当 2) 用户ID初始化时机 3) 字段映射不一致 4) 错误处理不足。这些问题相互影响，导致数据同步链条中任何一环出错都会静默失败。
`─────────────────────────────────────────────────`

## 🔴 关键问题

### 1. RLS（行级安全）策略问题 ⚠️ 严重

**问题描述**：
- star_charts表可能缺少INSERT策略
- 很多表的INSERT策略使用`WITH CHECK (true)`，这可能导致权限问题
- 用户认证状态可能影响RLS策略执行

**影响**：
- 数据无法写入数据库
- API调用返回403权限错误
- 触发器可能因RLS限制无法执行

**解决方案**：
```sql
-- 为star_charts表添加完整的RLS策略
CREATE POLICY "Users can insert own charts" ON star_charts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own charts" ON star_charts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own charts" ON star_charts
  FOR UPDATE USING (auth.uid() = user_id);
```

### 2. 用户ID初始化时机问题 ⚠️ 严重

**问题描述**：
- UserDataManager的currentUserId初始化延迟
- 新用户注册后立即生成星盘时，currentUserId可能为nil
- 导致syncToCloudIfNeeded无法执行

**影响**：
- 星盘数据只保存在本地
- 用户登出后数据丢失

**已修复**：✅ 在UserDataManager中增加了备用获取用户ID的逻辑

### 3. API认证问题 ⚠️ 中等

**问题描述**：
- 同时使用Bearer token和apikey可能造成冲突
- 用户token可能过期或无效
- anon key权限可能不足

**影响**：
- API调用失败
- 数据无法提交到服务器

**建议检查点**：
- 确认token是否有效
- 验证apikey权限
- 检查Supabase的JWT设置

### 4. 数据字段映射问题 ⚠️ 中等

**发现的不一致**：
- 数据库使用`generated_at`，代码中使用`generatedAt`
- 数据库使用下划线命名，Swift使用驼峰命名
- JSON序列化时可能丢失数据

**影响**：
- 数据无法正确解析
- 某些字段可能为null

**解决方案**：
- 使用CodingKeys确保字段映射正确
- 添加字段验证

### 5. 错误处理不足 ⚠️ 中等

**问题描述**：
- 很多API调用使用`try?`，错误被静默忽略
- 缺少详细的错误日志
- 没有重试机制

**影响**：
- 问题难以排查
- 暂时性网络问题导致数据丢失

**已部分修复**：✅ 增强了错误日志输出

### 6. 网络连接和离线处理 ✅ 良好

**现状**：
- 已实现OfflineQueueManager
- 有NetworkMonitor监控网络状态
- 离线数据会缓存并在网络恢复后同步

**潜在问题**：
- 队列可能因错误累积过多
- 需要定期清理失败的操作

## 🟡 潜在问题

### 1. 并发问题
- 多个设备同时修改可能造成冲突
- 缺少乐观锁或版本控制

### 2. 数据大小限制
- Supabase可能对单个请求大小有限制
- 星盘数据可能过大

### 3. 触发器执行问题
- 数据库触发器可能因权限问题失败
- SECURITY DEFINER设置可能不正确

## 🟢 做得好的地方

1. **双重保障机制**：客户端主动同步 + 数据库触发器
2. **离线支持**：OfflineQueueManager处理离线场景
3. **本地缓存**：UserDefaults缓存提升性能

## 📋 建议的修复优先级

1. **立即修复**：
   - 添加star_charts表的完整RLS策略
   - 确保所有表的INSERT策略正确

2. **尽快修复**：
   - 增强所有API调用的错误处理
   - 添加重试机制

3. **计划改进**：
   - 实现数据版本控制
   - 添加同步状态UI反馈
   - 实现冲突解决机制

## 🔧 测试检查清单

创建新用户并测试以下场景：

- [ ] 注册新用户 → 检查profiles表
- [ ] 生成星盘 → 检查star_charts表
- [ ] 创建聊天会话 → 检查chat_sessions表
- [ ] 发送消息 → 检查chat_messages表
- [ ] 离线生成数据 → 恢复网络后检查同步
- [ ] 切换设备登录 → 验证数据同步

## 📝 监控建议

### SQL监控查询
```sql
-- 检查最近失败的操作
SELECT * FROM audit_logs 
WHERE status = 'failed' 
AND created_at > NOW() - INTERVAL '1 hour';

-- 检查RLS策略
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public';

-- 检查用户数据完整性
SELECT 
    p.id,
    p.email,
    COUNT(sc.id) as chart_count,
    COUNT(cs.id) as session_count
FROM profiles p
LEFT JOIN star_charts sc ON p.id = sc.user_id
LEFT JOIN chat_sessions cs ON p.id = cs.user_id
GROUP BY p.id, p.email
ORDER BY p.created_at DESC
LIMIT 10;
```

### 客户端日志监控点
- `🔄 开始同步星盘到云端`
- `✅ 星盘已同步到云端`
- `❌ 同步到云端失败`
- `❌ 保存星盘失败`
- `⚠️ 无法同步星盘`

## 状态
📅 **排查日期**：2025-09-13
🔄 **需要持续监控和改进**