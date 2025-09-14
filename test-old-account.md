# 测试老账户功能 - 操作指南

## 问题已解决 ✅

我们已经成功解决了数据库同步问题。主要修复包括：

### 1. 数据库层面修复
- ✅ 所有Auth用户现在都有对应的profiles记录
- ✅ 用户配额(quotas)已正确初始化
- ✅ 用户偏好(preferences)已创建
- ✅ session_type约束已修正（从'chat'改为'general'）

### 2. 应用层面修复
- ✅ 修复了TestSupabaseConnection中的userId问题
- ✅ 创建了CacheCleaner工具清理缓存的错误数据
- ✅ 确保应用使用真实的Auth用户ID而不是随机UUID

## 测试步骤

### 方法1：使用测试界面（推荐）
1. 启动应用
2. 使用老账户登录：
   - Email: test@gmail.com
   - 密码: [您的密码]
3. 点击"测试Supabase"按钮
4. 运行所有测试，确认全部通过

### 方法2：直接测试功能
1. 登录老账户
2. 进入聊天界面
3. 发送一条消息
4. 确认消息正常发送和接收，无错误提示

### 方法3：清理缓存后测试
如果仍有问题，可以：
1. 在应用中调用 `CacheCleaner.cleanAllUserCache()`
2. 重新登录
3. 测试功能

## 验证成功的标志
- ✅ 能正常登录
- ✅ 能发送和接收消息
- ✅ 无外键约束错误
- ✅ 无"用户ID不匹配"错误
- ✅ Supabase测试全部通过

## 已知用户ID
- test@gmail.com: b6e6ea91-9e1a-453f-8007-ea67a35bd5d1
- newtestuser@gmail.com: e3d0c147-e625-4dc8-b94c-67f604e41ee9

## 如果还有问题
1. 检查控制台日志
2. 运行Supabase测试查看具体失败项
3. 使用DebugHelper.showCacheStatus()查看缓存状态