// Vercel Serverless Function for AI Chat with Streaming Support
// 部署到 Vercel，路径：/api/chat-stream
// 支持 Server-Sent Events (SSE) 流式响应

import { createClient } from '@supabase/supabase-js';
import OpenAI from 'openai';

// 环境变量
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS?.split(',') || ['*'];

// 初始化客户端
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
const openai = new OpenAI({
  apiKey: OPENAI_API_KEY,
});

// CORS配置
const corsHeaders = (origin) => ({
  'Access-Control-Allow-Origin': ALLOWED_ORIGINS.includes('*') ? '*' : 
    ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0],
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
});

// AI人格配置
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
  
  model: 'gpt-3.5-turbo', // 使用 gpt-3.5-turbo 以获得更快的流式响应
  temperature: 0.8,
  maxTokens: 1000,
};

// 简化的用户认证（开发阶段）
async function authenticateUser(authHeader) {
  // 开发阶段简化认证，正式环境需要完整认证
  if (!authHeader) {
    // 允许匿名用户，但有限制
    return { 
      user: { id: 'anonymous', email: 'anonymous@example.com' },
      remainingQuota: 10 
    };
  }

  if (authHeader.startsWith('Bearer ')) {
    const token = authHeader.replace('Bearer ', '');
    try {
      const { data: { user }, error } = await supabase.auth.getUser(token);
      if (user) {
        return { user, remainingQuota: 50 };
      }
    } catch (error) {
      console.error('Auth error:', error);
    }
  }

  return { 
    user: { id: 'anonymous', email: 'anonymous@example.com' },
    remainingQuota: 10 
  };
}

// 主处理函数 - 支持流式响应
export default async function handler(req, res) {
  const origin = req.headers.origin || '*';

  // 处理CORS预检请求
  if (req.method === 'OPTIONS') {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');
    res.status(200).end();
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
    const { user, remainingQuota } = authResult;

    // 获取请求数据
    const { 
      messages: userMessages = [], 
      model = AI_PERSONALITY.model,
      temperature = AI_PERSONALITY.temperature,
      stream = true  // 默认启用流式
    } = req.body;

    // 构建消息数组
    const messages = [
      { role: 'system', content: AI_PERSONALITY.systemPrompt }
    ];

    // 添加用户提供的历史消息
    if (userMessages.length > 0) {
      messages.push(...userMessages);
    }

    // 检查是否需要流式响应
    if (!stream) {
      // 非流式响应
      const completion = await openai.chat.completions.create({
        model,
        messages,
        temperature,
        max_tokens: AI_PERSONALITY.maxTokens,
      });

      const responseText = completion.choices[0]?.message?.content || '';
      
      // 设置CORS头
      Object.entries(corsHeaders(origin)).forEach(([key, value]) => {
        res.setHeader(key, value);
      });
      
      res.status(200).json({
        response: responseText,
        usage: completion.usage,
        remainingQuota,
      });
      return;
    }

    // 流式响应设置
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no'); // 禁用 Nginx 缓冲
    
    // 设置CORS头
    Object.entries(corsHeaders(origin)).forEach(([key, value]) => {
      res.setHeader(key, value);
    });

    // 发送初始连接成功消息
    res.write(`data: ${JSON.stringify({ type: 'connected', remainingQuota })}\n\n`);

    // 创建流式响应
    const stream = await openai.chat.completions.create({
      model,
      messages,
      temperature,
      max_tokens: AI_PERSONALITY.maxTokens,
      stream: true,
    });

    let fullResponse = '';
    
    // 处理流式数据
    for await (const chunk of stream) {
      const content = chunk.choices[0]?.delta?.content || '';
      
      if (content) {
        fullResponse += content;
        
        // 发送SSE格式的数据
        const data = JSON.stringify({
          type: 'content',
          content: content,
          fullResponse: fullResponse,
        });
        
        res.write(`data: ${data}\n\n`);
      }

      // 检查是否完成
      if (chunk.choices[0]?.finish_reason) {
        const finishData = JSON.stringify({
          type: 'done',
          finish_reason: chunk.choices[0].finish_reason,
          fullResponse: fullResponse,
        });
        
        res.write(`data: ${finishData}\n\n`);
        
        // 保存聊天历史（异步，不等待）
        saveChatHistory(user.id, userMessages[userMessages.length - 1]?.content || '', fullResponse).catch(console.error);
        
        break;
      }
    }

    // 发送结束信号
    res.write('data: [DONE]\n\n');
    res.end();

  } catch (error) {
    console.error('Stream error:', error);
    
    // 错误处理
    const errorData = JSON.stringify({
      type: 'error',
      error: error.message || 'An error occurred',
    });
    
    // 如果还没有开始流式响应，返回普通错误
    if (!res.headersSent) {
      Object.entries(corsHeaders(origin)).forEach(([key, value]) => {
        res.setHeader(key, value);
      });
      res.status(500).json({ error: error.message });
    } else {
      // 如果已经开始流式响应，发送错误事件
      res.write(`data: ${errorData}\n\n`);
      res.end();
    }
  }
}

// 保存聊天记录（简化版）
async function saveChatHistory(userId, message, response) {
  try {
    // 如果是匿名用户，不保存
    if (userId === 'anonymous') return;
    
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

// Vercel Edge Runtime 配置（可选，提高性能）
export const config = {
  runtime: 'edge',
  regions: ['iad1'], // 美国东部区域
};