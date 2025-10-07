// Vercel AI Gateway 客户端
// 专门处理 Vercel AI Gateway 调用

import fetch from 'node-fetch';

const GATEWAY_URL = 'https://ai-gateway.vercel.sh/v1';
const GATEWAY_KEY = process.env.VERCEL_AI_GATEWAY_KEY;

// 流式对话函数
export async function streamChatCompletion({
  messages,
  model = 'openai/gpt-5',  // 默认使用 GPT-5
  temperature = 0.7,
  maxTokens = 2000,
  stream = true,
}) {
  if (!GATEWAY_KEY) {
    throw new Error('VERCEL_AI_GATEWAY_KEY 未配置');
  }

  const response = await fetch(`${GATEWAY_URL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${GATEWAY_KEY}`,
    },
    body: JSON.stringify({
      model: `openai/${model}`,  // Vercel Gateway 需要指定 provider
      messages,
      temperature,
      max_tokens: maxTokens,
      stream,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Vercel AI Gateway error: ${response.status} - ${error}`);
  }

  return response;
}

// 生成嵌入向量
export async function generateEmbedding(input, model = 'text-embedding-ada-002') {
  if (!GATEWAY_KEY) {
    throw new Error('VERCEL_AI_GATEWAY_KEY 未配置');
  }

  const response = await fetch(`${GATEWAY_URL}/embeddings`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${GATEWAY_KEY}`,
    },
    body: JSON.stringify({
      model: `openai/${model}`,
      input,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Embedding error: ${response.status} - ${error}`);
  }

  const data = await response.json();
  return data.data[0].embedding;
}

// SSE 解析器
export function parseSSE(data) {
  const lines = data.split('\n');
  const messages = [];
  
  for (const line of lines) {
    if (line.startsWith('data: ')) {
      const jsonStr = line.slice(6);
      if (jsonStr === '[DONE]') {
        messages.push({ type: 'done' });
      } else {
        try {
          const json = JSON.parse(jsonStr);
          messages.push(json);
        } catch (e) {
          // 忽略解析错误
        }
      }
    }
  }
  
  return messages;
}

// 处理流式响应
export async function* handleStreamResponse(response) {
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() || '';
    
    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = line.slice(6);
        if (data === '[DONE]') {
          return;
        }
        try {
          const json = JSON.parse(data);
          const content = json.choices?.[0]?.delta?.content;
          if (content) {
            yield content;
          }
        } catch (e) {
          // 忽略解析错误
        }
      }
    }
  }
}

// 检查配置
export function isGatewayConfigured() {
  return !!GATEWAY_KEY;
}

// 导出默认客户端
export default {
  streamChatCompletion,
  generateEmbedding,
  parseSSE,
  handleStreamResponse,
  isGatewayConfigured,
};