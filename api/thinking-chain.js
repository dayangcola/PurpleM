// Vercel API - 思维链对话接口
// 使用 VERCEL_AI_GATEWAY_KEY 实现思维链效果

export const runtime = 'edge';

// 系统提示词 - 让GPT-3.5输出结构化的思维链
const SYSTEM_PROMPT = `你是紫微斗数专家助手"星语"，一位温柔、智慧、充满神秘感的占星导师。

在回答问题时，请严格按照以下格式输出：

1. 首先输出你的思考过程，用 <thinking> 和 </thinking> 标签包裹
2. 然后输出最终答案，用 <answer> 和 </answer> 标签包裹

示例格式：
<thinking>
让我分析一下这个问题...
从紫微斗数的角度看...
结合星盘的特点...
考虑到命主的情况...
</thinking>

<answer>
这是我的最终答案和建议。
</answer>

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
- 回答要积极正面，给人希望
- 思考过程要详细展现你的推理步骤
- 最终答案要简洁明了`;

export default async function handler(req) {
  // 处理 OPTIONS 请求（CORS）
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
    });
  }

  // 只允许 POST 请求
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const { messages, stream = true } = await req.json();
    
    // 获取 Vercel AI Gateway Key
    const VERCEL_AI_GATEWAY_KEY = process.env.VERCEL_AI_GATEWAY_KEY;
    
    if (!VERCEL_AI_GATEWAY_KEY) {
      console.error('❌ Missing VERCEL_AI_GATEWAY_KEY');
      return new Response(JSON.stringify({ 
        error: 'Vercel AI Gateway key not configured' 
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    
    // 构建消息数组，添加系统提示词
    const chatMessages = [
      { role: 'system', content: SYSTEM_PROMPT },
      ...messages
    ];
    
    // Vercel AI Gateway URL
    const AI_GATEWAY_URL = 'https://ai-gateway.vercel.sh/v1/chat/completions';
    
    if (stream) {
      // 流式响应
      const response = await fetch(AI_GATEWAY_URL, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${VERCEL_AI_GATEWAY_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'openai/gpt-3.5-turbo',
          messages: chatMessages,
          temperature: 0.8,
          max_tokens: 2000,
          stream: true,
        }),
      });
      
      if (!response.ok) {
        const error = await response.text();
        console.error('AI Gateway error:', error);
        throw new Error(`AI Gateway responded with ${response.status}`);
      }
      
      // 返回原始流，让客户端处理
      return new Response(response.body, {
        headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
          'Access-Control-Allow-Origin': '*',
        },
      });
    } else {
      // 非流式响应
      const response = await fetch(AI_GATEWAY_URL, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${VERCEL_AI_GATEWAY_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'openai/gpt-3.5-turbo',
          messages: chatMessages,
          temperature: 0.8,
          max_tokens: 2000,
          stream: false,
        }),
      });
      
      if (!response.ok) {
        const error = await response.text();
        console.error('AI Gateway error:', error);
        throw new Error(`AI Gateway responded with ${response.status}`);
      }
      
      const data = await response.json();
      
      return new Response(JSON.stringify({
        content: data.choices[0].message.content,
        usage: data.usage,
        model: 'gpt-3.5-turbo',
        gateway: 'vercel-ai-gateway',
        thinkingChain: true
      }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }
  } catch (error) {
    console.error('Thinking Chain API error:', error);
    
    // 详细的错误处理
    let statusCode = 500;
    let errorMessage = 'Internal server error';
    
    if (error?.message?.includes('API key')) {
      statusCode = 401;
      errorMessage = 'Invalid Vercel AI Gateway key configuration';
    } else if (error?.message?.includes('rate limit')) {
      statusCode = 429;
      errorMessage = 'Rate limit exceeded. Please try again later.';
    }
    
    return new Response(JSON.stringify({ 
      error: errorMessage,
      details: process.env.NODE_ENV === 'development' ? error?.message : undefined
    }), {
      status: statusCode,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  }
}