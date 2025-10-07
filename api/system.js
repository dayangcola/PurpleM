import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const supabasePublic = supabaseUrl && supabaseAnonKey ? createClient(supabaseUrl, supabaseAnonKey) : null;

function applyCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

function respond(res, statusCode, payload) {
  res.status(statusCode).json(payload);
}

function resolveAction(req) {
  const actionFromQuery = req.query?.action;
  const actionFromBody = req.body?.action;
  const fallback = 'health';

  const rawAction = actionFromQuery || actionFromBody || fallback;
  return typeof rawAction === 'string' ? rawAction.toLowerCase() : fallback;
}

function buildEnvReport() {
  const baseReport = {
    NEXT_PUBLIC_SUPABASE_URL: !!supabaseUrl,
    SUPABASE_SERVICE_ROLE_KEY: !!supabaseServiceKey,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: !!supabaseAnonKey,
    NODE_ENV: process.env.NODE_ENV,
    VERCEL: !!process.env.VERCEL,
    VERCEL_ENV: process.env.VERCEL_ENV
  };

  if (supabaseUrl) {
    try {
      const url = new URL(supabaseUrl);
      baseReport.SUPABASE_URL_VALID = url.hostname.includes('supabase.co');
    } catch (error) {
      baseReport.SUPABASE_URL_VALID = false;
    }
  }

  return baseReport;
}

async function handleSupabaseStatus() {
  if (!supabasePublic) {
    return {
      success: false,
      message: 'Supabase public client is not configured',
      config: {
        url: supabaseUrl ? '✅ Configured' : '❌ Missing',
        anonKey: supabaseAnonKey ? '✅ Configured' : '❌ Missing',
        serviceKey: supabaseServiceKey ? '✅ Configured' : '❌ Missing'
      }
    };
  }

  try {
    const { error } = await supabasePublic.from('profiles').select('id').limit(1);

    if (error && error.code !== 'PGRST116') {
      throw error;
    }

    return {
      success: true,
      message: 'Supabase connection successful',
      config: {
        url: supabaseUrl ? '✅ Configured' : '❌ Missing',
        anonKey: supabaseAnonKey ? '✅ Configured' : '❌ Missing',
        serviceKey: supabaseServiceKey ? '✅ Configured' : '❌ Missing'
      }
    };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      hint: 'Please check your Supabase configuration in Vercel dashboard'
    };
  }
}

export default async function handler(req, res) {
  applyCors(res);

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const action = resolveAction(req);

  switch (action) {
    case 'health':
    case 'ping':
    case 'test':
      return respond(res, 200, {
        status: 'ok',
        message: 'API is healthy',
        timestamp: new Date().toISOString()
      });

    case 'check-env':
      return respond(res, 200, {
        success: true,
        timestamp: new Date().toISOString(),
        environment: buildEnvReport(),
        message:
          supabaseUrl && supabaseServiceKey
            ? '✅ 环境变量已配置'
            : '❌ 缺少必要的环境变量'
      });

    case 'supabase-status':
    case 'supabase-init':
      return respond(res, 200, await handleSupabaseStatus());

    default:
      return respond(res, 400, {
        success: false,
        error: `Unsupported action: ${action}`,
        supported: ['health', 'check-env', 'supabase-status']
      });
  }
}
