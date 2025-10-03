// Supabase Edge Function for Knowledge Search
// Deploy with: supabase functions deploy search-knowledge

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { query, limit = 5, useEmbedding = false } = await req.json()

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    let results

    if (useEmbedding) {
      // 向量搜索（需要先生成查询的embedding）
      const openaiKey = Deno.env.get('OPENAI_API_KEY') ?? ''
      
      // 生成查询向量
      const embeddingResponse = await fetch('https://api.openai.com/v1/embeddings', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${openaiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'text-embedding-ada-002',
          input: query,
        }),
      })

      const embeddingData = await embeddingResponse.json()
      const queryEmbedding = embeddingData.data[0].embedding

      // 执行向量相似度搜索
      const { data, error } = await supabase.rpc('search_knowledge_by_embedding', {
        query_embedding: queryEmbedding,
        match_threshold: 0.7,
        match_count: limit,
      })

      if (error) throw error
      results = data
    } else {
      // 关键词搜索
      const { data, error } = await supabase
        .from('knowledge_base_simple')
        .select('id, content, category, keywords')
        .textSearch('content', query, {
          type: 'websearch',
          config: 'chinese',
        })
        .limit(limit)

      if (error) throw error
      results = data
    }

    // 处理结果
    const processedResults = results.map((item: any) => ({
      id: item.id,
      content: item.content.substring(0, 500) + '...',
      category: item.category || '未分类',
      keywords: item.keywords || [],
      relevance: item.similarity || 1.0,
    }))

    return new Response(
      JSON.stringify({
        success: true,
        query,
        results: processedResults,
        count: processedResults.length,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})