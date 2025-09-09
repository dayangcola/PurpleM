import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

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
    // 获取Authorization header
    const token = req.headers.authorization?.replace('Bearer ', '');

    if (token) {
      // 使用token登出
      const { error } = await supabase.auth.admin.signOut(token);
      
      if (error) {
        console.error('Logout error:', error);
      }
    }

    // 无论是否有token，都返回成功
    res.status(200).json({
      success: true,
      message: '已成功登出'
    });

  } catch (error) {
    console.error('Logout error:', error);
    // 即使出错也返回成功，确保客户端清理本地状态
    res.status(200).json({
      success: true,
      message: '已登出'
    });
  }
}