// Supabase初始化 - Vercel Edge Function
// 用于初始化Supabase客户端和处理认证

import { createClient } from '@supabase/supabase-js';

// 从环境变量获取配置（Vercel自动注入）
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

// 创建公开客户端（用于前端）
export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// 创建服务端客户端（用于后端，有更高权限）
export const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

// 验证Supabase连接的API
export default async function handler(req, res) {
  // CORS设置
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    // 测试连接
    const { data, error } = await supabase
      .from('profiles')
      .select('count')
      .limit(1);

    if (error && error.code !== 'PGRST116') { // PGRST116 = 表不存在
      throw error;
    }

    res.status(200).json({
      success: true,
      message: 'Supabase connection successful',
      config: {
        url: supabaseUrl ? '✅ Configured' : '❌ Missing',
        anonKey: supabaseAnonKey ? '✅ Configured' : '❌ Missing',
        serviceKey: supabaseServiceKey ? '✅ Configured' : '❌ Missing',
      }
    });
  } catch (error) {
    console.error('Supabase connection error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      hint: 'Please check your Supabase configuration in Vercel dashboard'
    });
  }
}