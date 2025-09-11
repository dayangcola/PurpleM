// api/embeddings.js
// Vercel Edge Function for OpenAI Embeddings via AI Gateway

export const runtime = 'edge';

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

    // 准备OpenAI API请求
    const openaiRequest = {
      model,
      input
    };

    // 使用Vercel AI Gateway调用OpenAI
    // 注意：需要在Vercel项目设置中配置OPENAI_API_KEY
    const gatewayUrl = process.env.AI_GATEWAY_URL || 'https://gateway.ai.cloudflare.com/v1/YOUR_ACCOUNT_ID/YOUR_GATEWAY/openai';
    
    // 如果使用Vercel的AI SDK
    const response = await fetch(`${gatewayUrl}/embeddings`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`
      },
      body: JSON.stringify(openaiRequest)
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('OpenAI API error:', error);
      return new Response(JSON.stringify({ 
        success: false, 
        error: `OpenAI API error: ${response.status}` 
      }), {
        status: response.status,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const data = await response.json();

    // 转换响应格式
    if (Array.isArray(input)) {
      // 批量请求
      const embeddings = data.data
        .sort((a, b) => a.index - b.index)
        .map(item => item.embedding);
      
      return new Response(JSON.stringify({
        success: true,
        embeddings,
        usage: data.usage
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });
    } else {
      // 单个请求
      return new Response(JSON.stringify({
        success: true,
        embedding: data.data[0].embedding,
        usage: data.usage
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });
    }

  } catch (error) {
    console.error('Embedding error:', error);
    return new Response(JSON.stringify({ 
      success: false, 
      error: error.message 
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}

// 如果你想使用Vercel AI SDK（推荐）
// 首先安装：npm install @vercel/ai
/*
import { OpenAIEmbeddings } from '@vercel/ai';

export default async function handler(req) {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const { input } = await req.json();
    
    const embeddings = new OpenAIEmbeddings({
      apiKey: process.env.OPENAI_API_KEY,
      model: 'text-embedding-ada-002'
    });

    const result = await embeddings.embedMany(
      Array.isArray(input) ? input : [input]
    );

    return new Response(JSON.stringify({
      success: true,
      embeddings: result.embeddings,
      usage: result.usage
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (error) {
    return new Response(JSON.stringify({ 
      success: false, 
      error: error.message 
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}
*/