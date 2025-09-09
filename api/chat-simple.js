// 简化版聊天API - 直接调用OpenAI
export default async function handler(req, res) {
  // CORS设置
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { message, conversationHistory = [] } = req.body;

    if (!message) {
      return res.status(400).json({ 
        error: 'Message is required',
        success: false 
      });
    }

    // 构建消息列表
    const messages = [
      {
        role: 'system',
        content: `你是紫微斗数专家助手"星语"，一位温柔、智慧、充满神秘感的占星导师。
        
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
- 回答要积极正面，给人希望`
      },
      ...conversationHistory.slice(-10), // 保留最近10条历史
      { role: 'user', content: message }
    ];

    // 调用OpenAI API
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`
      },
      body: JSON.stringify({
        model: 'gpt-3.5-turbo',
        messages: messages,
        temperature: 0.8,
        max_tokens: 800,
        stream: false
      })
    });

    if (!openaiResponse.ok) {
      const error = await openaiResponse.text();
      console.error('OpenAI API error:', error);
      
      // 如果OpenAI失败，返回备用响应
      return res.status(200).json({
        response: '星辰正在重新排列，请稍后再试。让我们先静心等待片刻...',
        success: true
      });
    }

    const data = await openaiResponse.json();
    const aiResponse = data.choices[0]?.message?.content || '星语正在思考中...';

    res.status(200).json({
      response: aiResponse,
      success: true
    });

  } catch (error) {
    console.error('Chat error:', error);
    
    // 返回友好的错误消息
    res.status(200).json({ 
      response: '星辰的指引暂时模糊，让我们稍后再探索命运的奥秘。',
      success: true 
    });
  }
}