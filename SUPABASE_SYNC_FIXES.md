# Supabase数据同步修复总结

## 修复日期：2025-09-13

## 问题概述
用户通过Supabase注册账户后，无法自动同步到profiles表，星盘数据无法跟随账户在不同设备间同步。

## 已修复的问题

### 1. 用户注册后Profile不自动创建
**问题**：用户注册后profiles表没有自动创建对应记录
**解决方案**：
- 在AuthManager的signUp方法中添加了AuthSyncManager调用
- 确保注册成功后立即创建profile记录

### 2. 字段映射不一致
**问题**：Swift代码使用camelCase，数据库使用snake_case，导致数据无法正确保存
**解决方案**：
- 创建SupabaseAPIHelper类统一处理字段映射
- 建立完整的字段映射表（swiftToDatabase/databaseToSwift）

### 3. star_charts表使用generated_at而不是created_at
**问题**：SQL脚本和代码中错误使用created_at字段
**解决方案**：
- 更新所有相关代码使用正确的generated_at字段
- 修复CloudChartData的CodingKeys映射

### 4. profiles表错误包含quota字段
**问题**：尝试向profiles表写入quota_limit和quota_used字段，但这些字段属于user_ai_quotas表
**解决方案**：
- 从profiles插入数据中移除quota相关字段
- 将quota字段正确写入user_ai_quotas表

### 5. 认证方式不一致
**问题**：有些API调用使用apikey，有些使用Bearer token，导致认证失败
**解决方案**：
- 创建SupabaseAuthType枚举定义认证类型
- 统一使用authenticated类型（Bearer token + apikey）

### 6. UserDataManager初始化问题
**问题**：currentUserId没有在初始化时设置，导致星盘无法关联用户
**解决方案**：
- 在UserDataManager的init方法中立即设置currentUserId
- 确保星盘保存时有正确的用户ID

## 新增文件

### 1. SupabaseAPIHelper.swift
统一的API帮助类，处理：
- 字段映射（Swift ↔ Database）
- 认证方式标准化
- 请求/响应日志
- 错误处理

### 2. RetryManager.swift
网络重试管理器，实现：
- 指数退避重试机制
- 可配置的重试次数和延迟
- 自动处理暂时性网络故障

### 3. AuthSyncManager.swift
认证同步管理器，负责：
- 确保Auth用户与Profile表同步
- 初始化用户配额（user_ai_quotas）
- 初始化用户偏好（user_ai_preferences）
- 创建默认会话和欢迎消息

### 4. SupabaseValidationTest.swift
验证测试类，可以：
- 检查所有表的数据同步状态
- 验证字段映射是否正确
- 测试完整的数据流程

## 数据库表结构

### profiles表
- id (uuid) - 主键，对应auth.users.id
- email, username, full_name, avatar_url, phone
- subscription_tier, is_active
- created_at, updated_at

### star_charts表
- id (uuid) - 主键
- user_id - 外键关联profiles.id
- chart_data (jsonb) - 星盘数据
- generated_at - 生成时间（注意：不是created_at）
- updated_at

### user_ai_quotas表
- user_id - 外键关联profiles.id
- daily_limit, daily_used, monthly_limit, monthly_used
- daily_reset_at, monthly_reset_at（日期类型）
- total_tokens_used, total_cost_credits
- bonus_credits, bonus_expires_at

### user_ai_preferences表
- user_id - 外键关联profiles.id
- conversation_style, response_length, language_complexity
- use_terminology, custom_personality, auto_include_chart
- preferred_topics[], avoided_topics[]
- enable_suggestions, enable_voice_input, enable_markdown

## 测试方法

1. 运行应用并注册新用户
2. 检查Supabase控制台确认：
   - profiles表有新记录
   - user_ai_quotas表有初始化数据
   - user_ai_preferences表有默认设置
3. 生成星盘后检查star_charts表
4. 运行SupabaseValidationTest进行自动化测试

## SQL脚本

- `get-table-structure.sql` - 查询所有表结构
- `fix-all-rls-policies.sql` - 修复RLS策略（已更新使用generated_at）

## 注意事项

1. **不要修复旧数据** - 根据用户要求，只修复新功能，不处理历史测试数据
2. **字段映射必须准确** - 任何新字段都需要在SupabaseAPIHelper中添加映射
3. **使用正确的时间字段** - star_charts使用generated_at，其他表使用created_at
4. **配额字段位置** - quota相关字段在user_ai_quotas表，不在profiles表

## 验证成功标志

✅ 新用户注册后profiles表自动创建记录
✅ 星盘数据成功保存到star_charts表
✅ 星盘数据能跨设备同步
✅ 所有字段映射正确
✅ RLS策略正常工作
✅ 编译无错误