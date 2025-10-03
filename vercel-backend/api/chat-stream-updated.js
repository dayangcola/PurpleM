// Vercel Serverless Function for AI Chat with Streaming Support
// 使用 Vercel AI SDK 替代直接调用 OpenAI API
// 部署到 Vercel，路径：/api/chat-stream

import { createClient } from '@supabase/supabase-js';
import { streamText } from 'ai';
import { openai } from '@ai-sdk/openai';

// 环境变量
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS?.split(',') || ['*'];

// 初始化 Supabase 客户端
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

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
  
  model: 'gpt-3.5-turbo',
  temperature: 0.8,
  maxTokens: 1000,
};

// 简化的用户认证（开发阶段）
async function authenticateUser(token) {
  if (!token) return { authenticated: false };
  
  try {
    // 验证JWT token
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) return { authenticated: false };
    
    return { 
      authenticated: true, 
      userId: user.id,
      email: user.email 
    };
  } catch (error) {
    console.error('Auth error:', error);
    return { authenticated: false };
  }
}

// 获取或创建对话历史
async function getOrCreateConversation(userId, conversationId = null) {
  try {
    if (conversationId) {
      // 获取现有对话
      const { data, error } = await supabase
        .from('conversations')
        .select('*')
        .eq('id', conversationId)
        .eq('user_id', userId)
        .single();
      
      if (error) throw error;
      return data;
    } else {
      // 创建新对话
      const { data, error } = await supabase
        .from('conversations')
        .insert([{
          user_id: userId,
          title: '新对话',
          created_at: new Date().toISOString()
        }])
        .select()
        .single();
      
      if (error) throw error;
      return data;
    }
  } catch (error) {
    console.error('Conversation error:', error);
    return null;
  }
}

// 保存消息到数据库
async function saveMessage(conversationId, role, content) {
  try {
    const { data, error } = await supabase
      .from('messages')
      .insert([{
        conversation_id: conversationId,
        role,
        content,
        created_at: new Date().toISOString()
      }])
      .select()
      .single();
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Save message error:', error);
    return null;
  }
}

// 获取对话历史
async function getConversationHistory(conversationId, limit = 10) {
  try {
    const { data, error } = await supabase
      .from('messages')
      .select('*')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: false })
      .limit(limit);
    
    if (error) throw error;
    return data?.reverse() || [];
  } catch (error) {
    console.error('Get history error:', error);
    return [];
  }
}

// 主处理函数
export default async function handler(req) {
  const origin = req.headers.get('origin');
  
  // 处理 OPTIONS 请求
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders(origin),
    });
  }
  
  // 只允许 POST 请求
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders(origin),
      },
    });
  }
  
  try {
    // 解析请求体
    const body = await req.json();
    const { 
      message, 
      conversationId, 
      includeHistory = true,
      stream = true 
    } = body;
    
    // 获取认证信息
    const authHeader = req.headers.get('authorization');
    const token = authHeader?.replace('Bearer ', '');
    const auth = await authenticateUser(token);
    
    // 开发阶段：如果没有认证，使用默认用户
    const userId = auth.authenticated ? auth.userId : 'dev-user';
    
    // 获取或创建对话
    const conversation = await getOrCreateConversation(userId, conversationId);
    if (!conversation) {
      throw new Error('Failed to get or create conversation');
    }
    
    // 构建消息历史
    let messages = [];
    
    if (includeHistory && conversation.id) {
      const history = await getConversationHistory(conversation.id);
      messages = history.map(msg => ({
        role: msg.role,
        content: msg.content
      }));
    }
    
    // 添加当前用户消息
    messages.push({ role: 'user', content: message });
    
    // 保存用户消息
    await saveMessage(conversation.id, 'user', message);
    
    // 使用 Vercel AI SDK 创建流式响应
    const result = await streamText({
      model: openai(AI_PERSONALITY.model),
      system: AI_PERSONALITY.systemPrompt,
      messages,
      temperature: AI_PERSONALITY.temperature,
      maxTokens: AI_PERSONALITY.maxTokens,
    });
    
    // 如果需要流式响应
    if (stream) {
      const encoder = new TextEncoder();
      let assistantResponse = '';
      
      // 创建流式响应
      const customStream = new ReadableStream({
        async start(controller) {
          try {
            // 发送对话ID
            controller.enqueue(
              encoder.encode(`data: ${JSON.stringify({ 
                type: 'conversation', 
                conversationId: conversation.id 
              })}\n\n`)
            );
            
            // 流式发送AI响应
            for await (const textPart of result.textStream) {
              assistantResponse += textPart;
              
              controller.enqueue(
                encoder.encode(`data: ${JSON.stringify({ 
                  type: 'content', 
                  content: textPart 
                })}\n\n`)
              );
            }
            
            // 保存完整的AI响应
            await saveMessage(conversation.id, 'assistant', assistantResponse);
            
            // 发送完成信号
            controller.enqueue(
              encoder.encode(`data: ${JSON.stringify({ 
                type: 'done' 
              })}\n\n`)
            );
            
            controller.close();
          } catch (error) {
            console.error('Stream error:', error);
            controller.enqueue(
              encoder.encode(`data: ${JSON.stringify({ 
                type: 'error', 
                error: error.message 
              })}\n\n`)
            );
            controller.close();
          }
        },
      });
      
      return new Response(customStream, {
        headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
          ...corsHeaders(origin),
        },
      });
    } else {
      // 非流式响应
      const { text } = await result;
      
      // 保存AI响应
      await saveMessage(conversation.id, 'assistant', text);
      
      return new Response(JSON.stringify({
        success: true,
        conversationId: conversation.id,
        response: text,
      }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders(origin),
        },
      });
    }
  } catch (error) {
    console.error('Handler error:', error);
    
    // 错误处理
    const errorMessage = error.message || 'Internal server error';
    const statusCode = error.message?.includes('rate limit') ? 429 : 500;
    
    return new Response(JSON.stringify({ 
      success: false, 
      error: errorMessage 
    }), {
      status: statusCode,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders(origin),
      },
    });
  }
}

// Edge runtime configuration
export const config = {
  runtime: 'edge',
};