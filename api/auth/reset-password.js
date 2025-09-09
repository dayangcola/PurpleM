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
    const { email } = req.body;

    // 验证输入
    if (!email) {
      return res.status(400).json({ 
        error: '请提供邮箱地址' 
      });
    }

    // 发送重置密码邮件
    const { data, error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: 'https://purple-m.vercel.app/reset-password-confirm'
    });

    if (error) {
      // 不暴露用户是否存在的信息
      console.error('Reset password error:', error);
      return res.status(200).json({
        success: true,
        message: '如果该邮箱已注册，您将收到重置密码的链接'
      });
    }

    res.status(200).json({
      success: true,
      message: '重置密码链接已发送到您的邮箱'
    });

  } catch (error) {
    console.error('Reset password error:', error);
    res.status(500).json({ 
      error: '服务器错误，请稍后重试',
      success: false 
    });
  }
}