// api/embeddings-updated.js
// Vercel Edge Function using Vercel AI Gateway for Embeddings

import { generateEmbedding } from '../lib/ai-gateway-client.js';

export const runtime = 'nodejs';
export const maxDuration = 10;

export default async function handler(req) {
  // 只允许POST请求
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ 
      success: false, 
      error: 'Method not allowed' 
    }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  try {
    // 解析请求体
    const body = await req.json();
    const { input, model = 'text-embedding-ada-002' } = body;

    // 验证输入
    if (!input) {
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Missing input text' 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // 使用 Vercel AI Gateway 生成嵌入向量
    const embedding = await generateEmbedding(input, model);

    // 返回嵌入向量
    return new Response(JSON.stringify({
      success: true,
      data: {
        object: 'embedding',
        embedding: Array.from(embedding),
        model,
        usage: {
          prompt_tokens: Math.ceil(input.length / 4), // 估算token数
          total_tokens: Math.ceil(input.length / 4)
        }
      }
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=3600' // 缓存1小时
      }
    });

  } catch (error) {
    console.error('Embeddings API error:', error);
    
    // 详细的错误处理
    let statusCode = 500;
    let errorMessage = 'Internal server error';
    
    if (error?.message?.includes('API key')) {
      statusCode = 401;
      errorMessage = 'Invalid API key configuration';
    } else if (error?.message?.includes('rate limit')) {
      statusCode = 429;
      errorMessage = 'Rate limit exceeded. Please try again later.';
    } else if (error?.message?.includes('model')) {
      statusCode = 400;
      errorMessage = 'Invalid model specified';
    }
    
    return new Response(JSON.stringify({ 
      success: false, 
      error: errorMessage,
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    }), {
      status: statusCode,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}

// 配置说明
export const config = {
  // 使用Node.js Runtime以支持AI SDK
  runtime: 'nodejs',
  
  // 设置区域（可选）
  regions: ['iad1'], // 美国东部区域，靠近OpenAI服务器
  
  // 最大执行时间
  maxDuration: 10,
};