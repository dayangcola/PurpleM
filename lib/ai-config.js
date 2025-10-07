// AI 配置中心 - 使用 Vercel AI Gateway
// 简化版：只包含常量配置
// 不再依赖 Vercel AI SDK

// 模型名称映射
export const MODEL_NAMES = {
  chat: {
    fast: 'openai/gpt-5',
    standard: 'openai/gpt-5',  // 使用GPT-5
    advanced: 'openai/gpt-5',
  },
  embedding: {
    default: 'text-embedding-ada-002',
    large: 'text-embedding-3-large',
    small: 'text-embedding-3-small',
  }
};

// 温度配置（控制输出的随机性）
export const TEMPERATURE = {
  creative: 0.9,  // 创意性回答
  balanced: 0.7,  // 平衡
  precise: 0.3,   // 精确性回答
  deterministic: 0, // 确定性输出
};

// Token 限制配置
export const TOKEN_LIMITS = {
  small: 500,
  medium: 1000,
  large: 2000,
  max: 4000,
};

// 系统提示词配置
export const SYSTEM_PROMPTS = {
  base: `你是紫微斗数专家助手"星语"，一位温柔、智慧、充满神秘感的占星导师。

【核心身份】
- 千年命理智慧的传承者
- 现代心理学的实践者
- 温暖而专业的人生导师

【专业能力】
1. 精通紫微斗数全部理论体系
2. 熟悉十二宫位、十四主星、百余星曜
3. 掌握四化飞星、流年流月推算
4. 了解各种格局（如君臣庆会、日月并明等）
5. 结合现代心理学提供建议

【沟通原则】
- 保持温柔、智慧、神秘的气质
- 用诗意的语言表达深刻的道理
- 给予积极正面的引导
- 适时使用比喻和故事`,
  
  thinking: `请按照以下格式进行深入分析和回答：

<thinking>
【问题理解】准确理解用户的真实需求
【多维分析】从紫微斗数、心理学、实用性等角度分析
【逻辑推理】通过严密的逻辑推导得出结论
【潜在影响】考虑各种可能的影响和结果
【最佳方案】综合考虑后确定最优解决方案
</thinking>

<answer>
根据深入分析，我的建议是...
[清晰的结构化回答]
</answer>`,
};

// 场景配置
export const SCENE_CONFIGS = {
  greeting: {
    temperature: TEMPERATURE.balanced,
    maxTokens: TOKEN_LIMITS.medium,
    prompt: '用户刚刚开始对话，请用温暖亲切的方式打招呼，简单介绍你能提供的帮助。',
  },
  chartReading: {
    temperature: TEMPERATURE.precise,
    maxTokens: TOKEN_LIMITS.large,
    prompt: '用户正在查看命盘，请系统地解读命盘结构，分析主星组合，指出特殊格局。',
  },
  fortuneTelling: {
    temperature: TEMPERATURE.balanced,
    maxTokens: TOKEN_LIMITS.large,
    prompt: '用户关心运势走向，请分析大运流年，指出机遇和注意事项，提供开运建议。',
  },
  learning: {
    temperature: TEMPERATURE.precise,
    maxTokens: TOKEN_LIMITS.large,
    prompt: '用户想学习命理知识，请循序渐进地讲解，用例子帮助理解，提供记忆技巧。',
  },
  counseling: {
    temperature: TEMPERATURE.creative,
    maxTokens: TOKEN_LIMITS.large,
    prompt: '用户需要心理支持，请给予温暖理解，提供实际建议，保持专业界限。',
  },
};

// 错误消息配置
export const ERROR_MESSAGES = {
  noApiKey: 'Vercel AI Gateway Key 未配置，请在环境变量中设置 VERCEL_AI_GATEWAY_KEY',
  rateLimited: '请求过于频繁，请稍后再试',
  networkError: '网络连接失败，请检查网络设置',
  invalidRequest: '请求参数无效',
  serviceUnavailable: 'AI 服务暂时不可用',
  tokenLimitExceeded: '输入内容过长，请缩短后重试',
};

// 导出配置验证函数
export function validateConfig() {
  const errors = [];
  
  if (!process.env.VERCEL_AI_GATEWAY_KEY) {
    errors.push(ERROR_MESSAGES.noApiKey);
  }
  
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL) {
    errors.push('Supabase URL 未配置');
  }
  
  if (!process.env.SUPABASE_SERVICE_KEY && !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
    errors.push('Supabase Key 未配置');
  }
  
  return {
    isValid: errors.length === 0,
    errors,
  };
}

// 导出配置常量
export default {
  modelNames: MODEL_NAMES,
  temperature: TEMPERATURE,
  tokenLimits: TOKEN_LIMITS,
  systemPrompts: SYSTEM_PROMPTS,
  sceneConfigs: SCENE_CONFIGS,
  errorMessages: ERROR_MESSAGES,
  validateConfig,
};