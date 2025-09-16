// 测试 Vercel AI SDK 实现
// 验证新的 API 端点是否正常工作

import fetch from 'node-fetch';

const BASE_URL = 'https://purple-m.vercel.app';
// 或使用本地测试: const BASE_URL = 'http://localhost:3000';

// ANSI 颜色代码
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
};

// 测试结果记录
const testResults = [];

// 输出测试结果
function logTest(name, success, message = '') {
  const icon = success ? '✅' : '❌';
  const color = success ? colors.green : colors.red;
  console.log(`${color}${icon} ${name}${colors.reset}`);
  if (message) {
    console.log(`   ${message}`);
  }
  testResults.push({ name, success, message });
}

// 测试流式响应
async function testStreamingAPI() {
  console.log(`\n${colors.blue}⭐ 测试流式 API (chat-stream-v2)${colors.reset}`);
  
  try {
    const response = await fetch(`${BASE_URL}/api/chat-stream-v2`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        messages: [
          { role: 'user', content: '你好，请简单介绍一下紫微斗数' }
        ],
        userMessage: '你好，请简单介绍一下紫微斗数',
        model: 'standard',
        enableKnowledge: false, // 简单测试，不启用知识库
        enableThinking: false,  // 简单测试，不启用思维链
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let chunks = [];
    
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      
      const chunk = decoder.decode(value, { stream: true });
      chunks.push(chunk);
    }
    
    logTest('Stream v2 API', true, `接收到 ${chunks.length} 个数据块`);
    
  } catch (error) {
    logTest('Stream v2 API', false, error.message);
  }
}

// 测试思维链 API
async function testThinkingChainAPI() {
  console.log(`\n${colors.blue}🤔 测试思维链 API (thinking-chain)${colors.reset}`);
  
  try {
    const response = await fetch(`${BASE_URL}/api/thinking-chain`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        messages: [
          { role: 'user', content: '命宫有太阳星代表什么？' }
        ],
        stream: false, // 非流式测试
        model: 'fast',
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`HTTP ${response.status}: ${error}`);
    }

    const data = await response.json();
    
    // 检查是否包含思维链标记
    const hasThinkingChain = data.content?.includes('<thinking>') && 
                            data.content?.includes('</thinking>');
    
    logTest('Thinking Chain API', true, 
           hasThinkingChain ? '✅ 包含思维链结构' : '⚠️ 未找到思维链结构');
    
  } catch (error) {
    logTest('Thinking Chain API', false, error.message);
  }
}

// 测试嵌入向量 API
async function testEmbeddingsAPI() {
  console.log(`\n${colors.blue}🔍 测试嵌入向量 API (embeddings-updated)${colors.reset}`);
  
  try {
    const response = await fetch(`${BASE_URL}/api/embeddings-updated`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        input: '紫微斗数是中国古代的命理学',
        model: 'text-embedding-ada-002',
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`HTTP ${response.status}: ${error}`);
    }

    const data = await response.json();
    
    // 检查嵌入向量
    const hasEmbedding = data.success && 
                        data.data?.embedding && 
                        Array.isArray(data.data.embedding) &&
                        data.data.embedding.length > 0;
    
    logTest('Embeddings API', hasEmbedding, 
           hasEmbedding ? `生成了 ${data.data.embedding.length} 维向量` : '未生成嵌入向量');
    
  } catch (error) {
    logTest('Embeddings API', false, error.message);
  }
}

// 测试配置验证
async function testConfiguration() {
  console.log(`\n${colors.blue}⚙️ 验证配置${colors.reset}`);
  
  // 检查环境变量
  const hasGatewayKey = !!process.env.VERCEL_AI_GATEWAY_KEY;
  const hasSupabaseURL = !!process.env.NEXT_PUBLIC_SUPABASE_URL;
  const hasSupabaseKey = !!process.env.SUPABASE_SERVICE_KEY || 
                        !!process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  
  logTest('Vercel AI Gateway Key', hasGatewayKey, 
         hasGatewayKey ? '✅ 已配置' : '❌ 未配置 VERCEL_AI_GATEWAY_KEY');
  logTest('Supabase URL', hasSupabaseURL,
         hasSupabaseURL ? '✅ 已配置' : '❌ 未配置 NEXT_PUBLIC_SUPABASE_URL');
  logTest('Supabase Key', hasSupabaseKey,
         hasSupabaseKey ? '✅ 已配置' : '❌ 未配置 Supabase Key');
}

// 主测试函数
async function runTests() {
  console.log(`${colors.yellow}✨ 开始测试 Vercel AI SDK 实现${colors.reset}`);
  console.log(`🌐 测试地址: ${BASE_URL}`);
  console.log('=' .repeat(50));
  
  // 执行测试
  await testConfiguration();
  await testStreamingAPI();
  await testThinkingChainAPI();
  await testEmbeddingsAPI();
  
  // 总结
  console.log('\n' + '=' .repeat(50));
  const successCount = testResults.filter(r => r.success).length;
  const totalCount = testResults.length;
  const allPassed = successCount === totalCount;
  
  const summaryColor = allPassed ? colors.green : colors.yellow;
  console.log(`${summaryColor}📋 测试总结: ${successCount}/${totalCount} 通过${colors.reset}`);
  
  if (!allPassed) {
    console.log(`\n${colors.red}失败的测试:${colors.reset}`);
    testResults.filter(r => !r.success).forEach(r => {
      console.log(`  ❌ ${r.name}: ${r.message}`);
    });
  } else {
    console.log(`${colors.green}✨ 所有测试通过！Vercel AI SDK 实现成功！${colors.reset}`);
  }
  
  process.exit(allPassed ? 0 : 1);
}

// 执行测试
if (process.argv[1] === new URL(import.meta.url).pathname) {
  runTests().catch(error => {
    console.error(`${colors.red}❌ 测试失败: ${error.message}${colors.reset}`);
    process.exit(1);
  });
}

export { testStreamingAPI, testThinkingChainAPI, testEmbeddingsAPI };