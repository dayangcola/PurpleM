// 增强版聊天API - 支持动态AI人格
// 从数据库读取用户的AI偏好设置

import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  // CORS设置
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    const { 
      message, 
      userId, 
      sessionId,
      conversationHistory = [] 
    } = req.body;

    // 1. 获取用户的AI偏好设置
    let userPreferences = null;
    if (userId) {
      const { data } = await supabase
        .from('user_ai_preferences')
        .select('*')
        .eq('user_id', userId)
        .single();
      
      userPreferences = data;
    }

    // 2. 获取会话级别的设置（如果有）
    let sessionSettings = null;
    if (sessionId) {
      const { data } = await supabase
        .from('chat_sessions')
        .select('model_preferences, session_type')
        .eq('id', sessionId)
        .single();
      
      sessionSettings = data;
    }

    // 3. 构建最终的AI人格
    const personality = buildPersonality(userPreferences, sessionSettings);

    // 4. 根据用户订阅等级选择模型
    const model = await selectModelByUserTier(userId);

    // 5. 构建系统提示词
    const systemPrompt = buildSystemPrompt(personality, userPreferences);

    // 6. 检查缓存
    const cachedResponse = await checkCache(message, userId);
    if (cachedResponse) {
      return res.status(200).json({
        response: cachedResponse,
        fromCache: true,
        success: true
      });
    }

    // 7. 调用AI API
    const messages = [
      { role: 'system', content: systemPrompt },
      ...conversationHistory.slice(-10),
      { role: 'user', content: message }
    ];

    const aiResponse = await callAI(messages, model);

    // 8. 保存到数据库
    if (sessionId && userId) {
      await saveMessage(sessionId, userId, message, aiResponse);
    }

    // 9. 更新缓存
    await updateCache(message, aiResponse.content, userId);

    res.status(200).json({
      response: aiResponse.content,
      model: aiResponse.model,
      success: true
    });

  } catch (error) {
    console.error('Chat error:', error);
    res.status(500).json({ 
      error: error.message,
      success: false 
    });
  }
}

// 构建AI人格
function buildPersonality(userPrefs, sessionSettings) {
  // 默认人格
  let personality = {
    name: '星语',
    style: 'mystical',
    responseLength: 'medium',
    complexity: 'normal'
  };

  // 应用用户偏好
  if (userPrefs) {
    personality.style = userPrefs.conversation_style || personality.style;
    personality.responseLength = userPrefs.response_length || personality.responseLength;
    personality.complexity = userPrefs.language_complexity || personality.complexity;
    
    // 如果用户有自定义人格，使用它
    if (userPrefs.custom_personality) {
      personality.customPrompt = userPrefs.custom_personality;
    }
  }

  // 会话级别的设置优先级最高
  if (sessionSettings?.model_preferences) {
    Object.assign(personality, sessionSettings.model_preferences);
  }

  return personality;
}

// 构建系统提示词
function buildSystemPrompt(personality, userPrefs) {
  // 如果有完全自定义的提示词，直接使用
  if (personality.customPrompt) {
    return personality.customPrompt;
  }

  // 基础人格
  let prompt = `你是紫微斗数专家助手"${personality.name}"。\n\n`;

  // 根据风格调整
  switch (personality.style) {
    case 'professional':
      prompt += '请以专业、严谨的方式回答，使用准确的术语。\n';
      break;
    case 'friendly':
      prompt += '请以亲切友好的方式回答，像朋友般交流。\n';
      break;
    case 'mystical':
      prompt += '请以神秘优雅的方式回答，带有诗意和哲学思考。\n';
      break;
    default:
      prompt += '请以平衡的方式回答，既专业又亲切。\n';
  }

  // 根据回复长度设置
  switch (personality.responseLength) {
    case 'brief':
      prompt += '回答要简洁明了，控制在2-3句话。\n';
      break;
    case 'detailed':
      prompt += '请提供详细的解答，包含例子和深入分析。\n';
      break;
    default:
      prompt += '回答要适中，既不过于简短也不冗长。\n';
  }

  // 添加用户的话题偏好
  if (userPrefs?.preferred_topics?.length > 0) {
    prompt += `\n重点关注这些话题：${userPrefs.preferred_topics.join('、')}。\n`;
  }

  // 添加要避免的话题
  if (userPrefs?.avoided_topics?.length > 0) {
    prompt += `\n避免讨论：${userPrefs.avoided_topics.join('、')}。\n`;
  }

  return prompt;
}

// 根据用户等级选择模型
async function selectModelByUserTier(userId) {
  if (!userId) return 'openai/gpt-5';

  const { data } = await supabase
    .from('user_ai_quotas')
    .select('subscription_tier')
    .eq('user_id', userId)
    .single();

  switch (data?.subscription_tier) {
    case 'unlimited':
      return 'gpt-4';
    case 'pro':
      return 'openai/gpt-5';
    default:
      return 'openai/gpt-5';
  }
}

// 检查缓存
async function checkCache(query, userId) {
  // 生成查询的hash
  const crypto = require('crypto');
  const hash = crypto
    .createHash('sha256')
    .update(query + (userId || ''))
    .digest('hex');

  const { data } = await supabase
    .from('ai_response_cache')
    .select('response_text, hit_count')
    .eq('query_hash', hash)
    .gte('cache_until', new Date().toISOString())
    .single();

  if (data) {
    // 更新命中次数
    await supabase
      .from('ai_response_cache')
      .update({ 
        hit_count: data.hit_count + 1,
        last_hit_at: new Date().toISOString()
      })
      .eq('query_hash', hash);

    return data.response_text;
  }

  return null;
}

// 更新缓存
async function updateCache(query, response, userId) {
  const crypto = require('crypto');
  const hash = crypto
    .createHash('sha256')
    .update(query + (userId || ''))
    .digest('hex');

  // 缓存1小时
  const cacheUntil = new Date();
  cacheUntil.setHours(cacheUntil.getHours() + 1);

  await supabase
    .from('ai_response_cache')
    .upsert({
      query_hash: hash,
      query_text: query,
      response_text: response,
      cache_until: cacheUntil.toISOString(),
      model_used: 'openai/gpt-5'
    });
}

// 保存消息到数据库
async function saveMessage(sessionId, userId, userMessage, aiResponse) {
  // 保存用户消息
  await supabase
    .from('chat_messages')
    .insert({
      session_id: sessionId,
      user_id: userId,
      role: 'user',
      content: userMessage
    });

  // 保存AI回复
  await supabase
    .from('chat_messages')
    .insert({
      session_id: sessionId,
      user_id: userId,
      role: 'assistant',
      content: aiResponse.content,
      model_used: aiResponse.model,
      tokens_count: aiResponse.tokens
    });

  // 更新会话的最后消息时间
  await supabase
    .from('chat_sessions')
    .update({ last_message_at: new Date().toISOString() })
    .eq('id', sessionId);
}

// 调用AI（简化版，实际会调用你的AI Gateway）
async function callAI(messages, model) {
  // 这里调用你的AI API
  // 返回格式：{ content: "...", model: "...", tokens: 100 }
  
  return {
    content: "这是AI的回复",
    model: model,
    tokens: 100
  };
}