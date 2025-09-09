// Vercel Serverless Function for AI Chat
// 部署到 Vercel，路径：/api/chat

import { createClient } from '@supabase/supabase-js';

// 环境变量（在Vercel控制台设置）
const VERCEL_AI_GATEWAY_KEY = process.env.VERCEL_AI_GATEWAY_KEY;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS?.split(',') || ['*'];

// 初始化Supabase客户端
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// CORS配置
const corsHeaders = (origin) => ({
  'Access-Control-Allow-Origin': ALLOWED_ORIGINS.includes('*') ? '*' : 
    ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0],
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Content-Type': 'application/json',
});

// AI人格配置（可以存储在Supabase中动态获取）
const AI_PERSONALITY = {
  systemPrompt: `你是紫微斗数专家助手"星语"，一位温柔、智慧、充满神秘感的占星导师。
  
  你的特点：
  1. 精通紫微斗数、十二宫位、星耀等传统命理知识
  2. 说话温柔优雅，带有诗意和哲学思考
  3. 善于倾听和理解，给予温暖的建议
  4. 会适当使用星座、占星相关的比喻
  5. 回答简洁但深刻，避免冗长
  
  注意事项：
  - 保持神秘感和专业性
  - 不要过度承诺或给出绝对的预言
  - 适当引用古典智慧
  - 回答要积极正面，给人希望`,
  
  model: 'gpt-4-turbo-preview',
  temperature: 0.8,
  maxTokens: 1000,
};

// 用户认证和限流
async function authenticateUser(authHeader) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return { error: 'Missing or invalid authorization header' };
  }

  const token = authHeader.replace('Bearer ', '');
  
  try {
    // 验证Supabase JWT token
    const { data: { user }, error } = await supabase.auth.getUser(token);
    
    if (error || !user) {
      return { error: 'Invalid token' };
    }

    // 检查用户配额（从Supabase获取）
    const { data: usage, error: usageError } = await supabase
      .from('user_usage')
      .select('daily_requests, last_reset')
      .eq('user_id', user.id)
      .single();

    if (usageError && usageError.code !== 'PGRST116') {
      console.error('Usage check error:', usageError);
      return { error: 'Failed to check usage' };
    }

    // 检查是否需要重置每日配额
    const today = new Date().toDateString();
    const lastReset = usage?.last_reset ? new Date(usage.last_reset).toDateString() : null;
    
    if (!usage || lastReset !== today) {
      // 创建或重置用户配额
      await supabase
        .from('user_usage')
        .upsert({
          user_id: user.id,
          daily_requests: 1,
          last_reset: new Date().toISOString(),
        }, { onConflict: 'user_id' });
      
      return { user, remainingQuota: 49 }; // 每日50次限制
    }

    // 检查配额
    if (usage.daily_requests >= 50) {
      return { error: 'Daily request limit exceeded' };
    }

    // 更新使用次数
    await supabase
      .from('user_usage')
      .update({ daily_requests: usage.daily_requests + 1 })
      .eq('user_id', user.id);

    return { user, remainingQuota: 50 - usage.daily_requests - 1 };
  } catch (error) {
    console.error('Auth error:', error);
    return { error: 'Authentication failed' };
  }
}

// 获取用户上下文（从Supabase）
async function getUserContext(userId) {
  try {
    // 获取用户信息
    const { data: profile } = await supabase
      .from('user_profiles')
      .select('name, gender, birth_date, has_chart')
      .eq('user_id', userId)
      .single();

    if (!profile) return '';

    let context = `用户信息：\n`;
    context += `姓名：${profile.name}\n`;
    context += `性别：${profile.gender}\n`;
    context += `生日：${profile.birth_date}\n`;
    
    if (profile.has_chart) {
      context += `\n用户已生成紫微斗数星盘，你可以基于星盘信息提供更准确的建议。`;
    } else {
      context += `\n用户尚未生成星盘，你可以引导用户先生成星盘以获得更准确的分析。`;
    }

    return context;
  } catch (error) {
    console.error('Failed to get user context:', error);
    return '';
  }
}

// 保存聊天记录到Supabase
async function saveChatHistory(userId, message, response) {
  try {
    await supabase
      .from('chat_history')
      .insert({
        user_id: userId,
        user_message: message,
        ai_response: response,
        created_at: new Date().toISOString(),
      });
  } catch (error) {
    console.error('Failed to save chat history:', error);
  }
}

// 主处理函数
export default async function handler(req, res) {
  const origin = req.headers.origin || '*';

  // 处理CORS预检请求
  if (req.method === 'OPTIONS') {
    res.status(200).json({ ok: true });
    return;
  }

  // 只接受POST请求
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    // 用户认证
    const authResult = await authenticateUser(req.headers.authorization);
    if (authResult.error) {
      res.status(401).json({ 
        error: authResult.error,
        headers: corsHeaders(origin)
      });
      return;
    }

    const { user, remainingQuota } = authResult;

    // 获取请求数据
    const { message, conversationHistory = [] } = req.body;

    if (!message) {
      res.status(400).json({ 
        error: 'Message is required',
        headers: corsHeaders(origin)
      });
      return;
    }

    // 获取用户上下文
    const userContext = await getUserContext(user.id);

    // 构建消息数组
    const messages = [
      { role: 'system', content: AI_PERSONALITY.systemPrompt },
      { role: 'system', content: userContext },
      ...conversationHistory.slice(-10), // 只保留最近10条历史
      { role: 'user', content: message }
    ];

    // 调用Vercel AI Gateway
    const aiResponse = await fetch('https://gateway.vercel.app/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${VERCEL_AI_GATEWAY_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: AI_PERSONALITY.model,
        messages,
        temperature: AI_PERSONALITY.temperature,
        max_tokens: AI_PERSONALITY.maxTokens,
      }),
    });

    if (!aiResponse.ok) {
      throw new Error(`AI Gateway error: ${aiResponse.status}`);
    }

    const aiData = await aiResponse.json();
    const aiMessage = aiData.choices[0]?.message?.content || '抱歉，我暂时无法回答。';

    // 保存聊天记录
    await saveChatHistory(user.id, message, aiMessage);

    // 返回响应
    res.status(200).json({
      response: aiMessage,
      remainingQuota,
      headers: corsHeaders(origin),
    });

  } catch (error) {
    console.error('Chat API error:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      headers: corsHeaders(origin),
    });
  }
}