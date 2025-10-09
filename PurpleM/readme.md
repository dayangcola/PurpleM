当前提示词构建流程如下：

  - 系统人格基线：前端仅携带 `promptProfileId`（默认 `stellar_master_v1`），由后端根据该 ID 在
  `api/chat-stream-enhanced.js` 与 `api/chat-auto.js` 中的 `promptProfiles` 表构建完整提示词，避免在客户端暴露内部策略。
  - 最近对话上下文：同一个函数会附加最近最多 10 条非空消息，按 user/assistant 角色写入，用于维持短期
  上下文（ChatTab.swift:408）。
  - 命盘背景拼装：发送流式请求前，extractChartContext(for:) 会解析当前登录用户的
  currentChart.jsonData，组合姓名、生辰、五行、命宫等基础信息，并针对输入问题命中不同宫位时附上该宫位
  的主星、辅星、杂曜和大限信息（ChatTab.swift:431 起）。若输入未命中关键词，默认返还命宫、身宫、福德
  宫概略，从而保证提示词永远对应“当前用户”的命盘数据。
  - 情绪与场景调优：detectEmotion 依据关键词给出情绪标签，EnhancedAIService.shared.currentScene 表
  示当前对话场景。两者都随请求传入，以便服务端选择合适的 ScenePrompt/情绪调节提示（定义在 Services/
  AIPersonality.swift:120 之后的枚举），实现个性化口吻。
  - 请求封装：以上生成的上下文聊天记录、命盘背景（chartContext）、用户信息（userInfo）、场景/情绪，以及
  `promptProfileId` 会被打包后发送到 https://purple-
  m.vercel.app/api/chat-stream-enhanced（Services/StreamingAIService.swift:82）或 `api/chat-auto`。服务端会基于这些字段
  再拼进一步的提示词（如解盘流程、质量要求等）。

- 要更新“如何解盘”等提示内容，可编辑 `api/chat-stream-enhanced.js` / `api/chat-auto.js` 顶部的
  `promptProfiles.stellar_master_v1` 配置，统一生效。

  因此，整套提示词链条保证：先加载统一人格 → 添加最近对话 → 注入当前用户命盘摘要 → 加情绪/场景 → 提交
  到服务器，让 AI 在回复时始终掌握该用户的背景资料，并不会混用其他用户的数据。
