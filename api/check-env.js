export default async function handler(req, res) {
  // CORS设置
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // 检查环境变量是否存在（不暴露实际值）
  const envCheck = {
    NEXT_PUBLIC_SUPABASE_URL: !!process.env.NEXT_PUBLIC_SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY: !!process.env.SUPABASE_SERVICE_ROLE_KEY,
    NODE_ENV: process.env.NODE_ENV,
    VERCEL: !!process.env.VERCEL,
    VERCEL_ENV: process.env.VERCEL_ENV
  };

  // 如果有Supabase URL，验证格式
  if (process.env.NEXT_PUBLIC_SUPABASE_URL) {
    try {
      const url = new URL(process.env.NEXT_PUBLIC_SUPABASE_URL);
      envCheck.SUPABASE_URL_VALID = url.hostname.includes('supabase.co');
    } catch (e) {
      envCheck.SUPABASE_URL_VALID = false;
    }
  }

  // 返回检查结果
  res.status(200).json({
    success: true,
    timestamp: new Date().toISOString(),
    environment: envCheck,
    message: envCheck.NEXT_PUBLIC_SUPABASE_URL && envCheck.SUPABASE_SERVICE_ROLE_KEY 
      ? '✅ 环境变量已配置' 
      : '❌ 缺少必要的环境变量'
  });
}