// AI Chat API - Non-streaming wrapper for enhanced endpoint
// 路径: /api/chat-auto

import fetch from 'node-fetch';
import {
  DEFAULT_PROMPT_PROFILE_ID,
  buildEnhancedMessages
} from './_shared/enhancedChatCore.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const {
      message,
      conversationHistory = [],
      userInfo = {},
      promptProfileId = DEFAULT_PROMPT_PROFILE_ID,
      userContext = null,
      chartContext = null,
      enableKnowledge = true,
      scene = null,
      emotion = null,
      model = 'standard',
      temperature = 0.8
    } = req.body || {};

    if (!message) {
      res.status(400).json({ success: false, error: 'Message is required' });
      return;
    }

    const history = Array.isArray(conversationHistory)
      ? conversationHistory.slice(-10).filter((item) => item?.role && item?.content)
          .map((item) => ({ role: item.role, content: item.content }))
      : [];

    const normalizedUserInfo = userInfo && Object.keys(userInfo).length > 0
      ? {
          name: userInfo.name,
          gender: userInfo.gender,
          birthDate: userInfo.birthDate,
          birthLocation: userInfo.birthLocation
        }
      : null;

    const {
      messages: allMessages,
      references
    } = await buildEnhancedMessages({
      messages: history,
      userMessage: message,
      promptProfileId,
      userContext,
      scene,
      emotion,
      chartContext,
      userInfo: normalizedUserInfo,
      enableKnowledge,
      model,
      temperature
    });

    const gatewayKey = process.env.VERCEL_AI_GATEWAY_KEY;
    if (!gatewayKey) {
      res.status(500).json({
        success: false,
        error: 'Vercel AI Gateway key not configured'
      });
      return;
    }

    const modelMap = {
      fast: 'openai/gpt-5',
      standard: 'openai/gpt-5',
      advanced: 'openai/gpt-5'
    };
    const actualModel = modelMap[model] || 'openai/gpt-5';

    const response = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${gatewayKey}`
      },
      body: JSON.stringify({
        model: actualModel,
        messages: allMessages,
        temperature,
        max_tokens: 1000,
        stream: false
      })
    });

    if (!response.ok) {
      const errorDetails = await response.text();
      console.error('❌ chat-auto 调用失败:', errorDetails);
      res.status(response.status).json({
        success: false,
        error: 'AI Gateway request failed',
        details: errorDetails
      });
      return;
    }

    const data = await response.json();
    const aiMessage = data.choices?.[0]?.message?.content || '';

    res.status(200).json({
      success: true,
      response: aiMessage,
      model: actualModel,
      references: references.map((ref) => ({
        index: ref.index,
        similarity: ref.similarity,
        book: ref.book,
        chapter: ref.chapter,
        page: ref.page
      }))
    });
  } catch (error) {
    console.error('Chat API error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Internal server error'
    });
  }
}
