# PurpleM 项目记忆文档

## 项目概览
PurpleM 是一个 iOS 应用项目，集成了多个现代技术栈：
- **前端**: SwiftUI iOS 应用
- **后端**: Supabase + Vercel
- **AI 服务**: 集成了 OpenAI API
- **主要功能**: 紫微斗数相关功能

## 项目结构
```
PurpleM/
├── PurpleM/              # iOS 应用主代码
├── api/                  # API 相关代码
├── supabase/            # Supabase 配置和迁移
├── vercel-backend/      # Vercel 后端服务
└── build/               # 构建输出
```

## 重要文件
- `PurpleM.xcodeproj` - Xcode 项目文件
- `package.json` - Node.js 依赖配置
- `vercel.json` - Vercel 部署配置
- `.claude/settings.local.json` - Claude 本地设置

## 常用命令

### 构建和运行
```bash
# 构建项目
xcodebuild -project PurpleM.xcodeproj -scheme PurpleM -configuration Debug -sdk iphonesimulator build

# 在模拟器运行
xcrun simctl launch "iPhone 16" com.link.PurpleM

# 查看日志
xcrun simctl spawn "iPhone 16" log stream --predicate 'processImagePath endswith "PurpleM"'
```

### Git 操作
```bash
# 添加文件
git add .

# 提交更改
git commit -m "描述"

# 推送到远程
git push
```

## 已知问题和修复

### 数据库相关
- 已修复 RLS (Row Level Security) 策略问题
- 已优化 Supabase 数据同步
- 已修复用户认证问题

### 性能优化
- JWT Token 优化已完成
- 离线缓存优化已实现
- 星盘自动加载功能已修复

### AI 集成
- EnhancedAIService 已实现
- 知识管理系统 (KnowledgeManager) 已集成
- QuickAI 集成已完成
- **🔴 极其重要**: AI Bot 必须使用 Vercel AI Gateway 统一 AI 大模型接口
  - 所有环境变量已配置完成
  - 参考文档: https://vercel.com/docs/ai-gateway
  - 不要使用其他 AI 服务接口

## 最近的改动
- 2025-09-16: 重大修复 - 完整集成知识库到流式响应模式
  - 将知识库搜索从客户端移到服务端（解决iOS无法访问API Key问题）
  - 创建增强版API端点 chat-stream-enhanced.js
  - 统一使用 Vercel AI Gateway
  - 传递完整用户上下文（用户信息、场景、情绪、命盘）
  - 修复系统提示词被覆盖的问题
- 2025-09-15: 实现了思维链深度思考功能
  - 增强了 StreamingAIService 的系统提示，支持结构化深度思考
  - 改进了 ThinkingChainParser，能识别和分析思考深度
  - 优化了 ThinkingChainView UI，支持折叠展开和深度可视化
- 2024-09-15: 添加了流式响应部署指南
- 2024-09-14: 完成了性能优化
- 2024-09-13: 修复了安全问题和数据同步

## 环境配置
- 需要配置 OpenAI API Key
- Vercel 环境变量已设置
- Supabase 连接已配置

## 🔴 AI Bot 配置（极其重要）
**关键原则**: 当讨论或实现 AI Bot 功能时，**必须**使用 Vercel AI Gateway 的统一 AI 大模型接口。

### 配置详情
- **接口**: Vercel AI Gateway
- **状态**: 所有环境变量已配置完成
- **文档**: https://vercel.com/docs/ai-gateway
- **注意**: 
  - 不要直接调用 OpenAI、Anthropic 或其他 AI 提供商的 API
  - 所有 AI 请求必须通过 Vercel AI Gateway 路由
  - 这确保了统一的错误处理、速率限制和成本管理

## 注意事项
1. 构建前确保 Xcode 和模拟器正确配置
2. 修改代码后运行 lint 和类型检查
3. 提交前测试所有功能
4. 保持文档更新

## 联系和支持
- 项目所有者: link
- 主要技术栈: Swift, SwiftUI, Supabase, Vercel

---
*最后更新: 2025-09-15*
*重要更新: 添加了 Vercel AI Gateway 配置说明*