// 测试 Vercel AI Gateway 配置
// 验证 GPT-3.5-turbo 是否正常工作

import fetch from 'node-fetch';

const GATEWAY_URL = 'https://ai-gateway.vercel.sh/v1';
const GATEWAY_KEY = process.env.VERCEL_AI_GATEWAY_KEY;

async function testGateway() {
  console.log('🚀 测试 Vercel AI Gateway 配置');
  console.log('=' .repeat(50));
  
  // 检查环境变量
  if (!GATEWAY_KEY) {
    console.error('❌ 未找到 VERCEL_AI_GATEWAY_KEY 环境变量');
    console.log('请设置环境变量：export VERCEL_AI_GATEWAY_KEY=your-key');
    process.exit(1);
  }
  
  console.log('✅ 找到 Gateway Key：', GATEWAY_KEY.substring(0, 10) + '...');
  
  try {
    console.log('\n📡 测试 GPT-3.5-turbo 调用...');
    
    const response = await fetch(`${GATEWAY_URL}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${GATEWAY_KEY}`,
      },
      body: JSON.stringify({
        model: 'openai/gpt-3.5-turbo',  // 注意需要 openai/ 前缀
        messages: [
          {
            role: 'system',
            content: '你是一个友好的助手',
          },
          {
            role: 'user',
            content: '请简单说“Hello World”',
          },
        ],
        temperature: 0.7,
        max_tokens: 50,
        stream: false,
      }),
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error('❌ 请求失败：', response.status);
      console.error('错误信息：', errorText);
      
      if (response.status === 401) {
        console.log('\n🔑 可能的问题：');
        console.log('1. Gateway Key 不正确');
        console.log('2. Key 没有权限访问 OpenAI');
        console.log('3. 请在 Vercel 控制台检查 AI Gateway 设置');
      }
      
      process.exit(1);
    }
    
    const data = await response.json();
    
    console.log('✅ 调用成功！');
    console.log('\n🤖 AI 回复：', data.choices[0].message.content);
    console.log('\n📊 使用统计：');
    console.log('- 模型：', data.model);
    console.log('- 输入 Token：', data.usage?.prompt_tokens);
    console.log('- 输出 Token：', data.usage?.completion_tokens);
    console.log('- 总计 Token：', data.usage?.total_tokens);
    
    // 测试流式响应
    console.log('\n🔄 测试流式响应...');
    
    const streamResponse = await fetch(`${GATEWAY_URL}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${GATEWAY_KEY}`,
      },
      body: JSON.stringify({
        model: 'openai/gpt-3.5-turbo',
        messages: [
          {
            role: 'user',
            content: '请说三个数字',
          },
        ],
        temperature: 0.7,
        max_tokens: 50,
        stream: true,  // 启用流式
      }),
    });
    
    if (!streamResponse.ok) {
      console.error('❌ 流式请求失败');
      process.exit(1);
    }
    
    console.log('✅ 流式响应成功开始');
    console.log('\n🔄 流式内容：');
    
    const reader = streamResponse.body;
    const decoder = new TextDecoder();
    let buffer = '';
    let fullResponse = '';
    
    for await (const chunk of reader) {
      buffer += decoder.decode(chunk, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';
      
      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = line.slice(6);
          if (data === '[DONE]') {
            console.log('\n✅ 流式传输完成');
            break;
          }
          try {
            const json = JSON.parse(data);
            const content = json.choices?.[0]?.delta?.content;
            if (content) {
              process.stdout.write(content);
              fullResponse += content;
            }
          } catch (e) {
            // 忽略解析错误
          }
        }
      }
    }
    
    console.log('\n\n✅ 所有测试通过！');
    console.log('=' .repeat(50));
    console.log('🎆 Vercel AI Gateway 配置正确，GPT-3.5-turbo 工作正常！');
    
  } catch (error) {
    console.error('\n❌ 测试失败：', error.message);
    console.error(error);
    process.exit(1);
  }
}

// 执行测试
if (process.argv[1] === new URL(import.meta.url).pathname) {
  testGateway().catch(console.error);
}

export default testGateway;