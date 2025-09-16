// 测试流式API是否正常工作
const https = require('https');

// 测试数据
const testData = {
  messages: [
    { role: "user", content: "你好，请简单回复一下" }
  ],
  userMessage: "你好，请简单回复一下",
  scene: "greeting",
  model: "fast",
  enableKnowledge: false,
  enableThinking: false
};

const postData = JSON.stringify(testData);

const options = {
  hostname: 'purple-m.vercel.app',
  port: 443,
  path: '/api/chat-stream-enhanced',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

console.log('🚀 开始测试流式API...');
console.log('📡 请求URL:', `https://${options.hostname}${options.path}`);
console.log('📦 请求数据:', JSON.stringify(testData, null, 2));

const req = https.request(options, (res) => {
  console.log('📡 状态码:', res.statusCode);
  console.log('📡 响应头:', res.headers);
  
  let buffer = '';
  
  res.on('data', (chunk) => {
    const str = chunk.toString();
    console.log('📥 收到数据块:', str);
    buffer += str;
  });
  
  res.on('end', () => {
    console.log('✅ 响应完成');
    console.log('📄 完整响应:', buffer);
    
    // 尝试解析SSE事件
    const lines = buffer.split('\n');
    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = line.slice(6);
        if (data && data !== '[DONE]') {
          try {
            const json = JSON.parse(data);
            console.log('📝 解析的事件:', json);
          } catch (e) {
            console.log('⚠️ 无法解析:', data);
          }
        }
      }
    }
  });
});

req.on('error', (e) => {
  console.error('❌ 请求错误:', e);
});

// 发送请求
req.write(postData);
req.end();