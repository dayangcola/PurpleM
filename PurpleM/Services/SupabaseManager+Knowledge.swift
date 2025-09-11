//
//  SupabaseManager+Knowledge.swift
//  PurpleM
//
//  Supabase知识库系统扩展
//

import Foundation

// MARK: - 知识库系统扩展
extension SupabaseManager {
    
    // MARK: - 书籍管理
    
    /// 获取用户的书籍列表
    func getUserBooks(userId: String? = nil) async throws -> [Book] {
        let effectiveUserId = userId ?? AuthManager.shared.currentUser?.id ?? ""
        
        return try await makeRequest(
            endpoint: "/rest/v1/books",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(effectiveUserId)"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ],
            expecting: [Book].self
        )
    }
    
    /// 获取公开书籍列表
    func getPublicBooks() async throws -> [Book] {
        return try await makeRequest(
            endpoint: "/rest/v1/books",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "is_public", value: "eq.true"),
                URLQueryItem(name: "processing_status", value: "eq.completed"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ],
            expecting: [Book].self
        )
    }
    
    /// 创建新书籍记录
    func createBook(
        title: String,
        author: String? = nil,
        category: String = "紫微斗数",
        description: String? = nil,
        fileUrl: String? = nil,
        fileSize: Int? = nil,
        totalPages: Int? = nil,
        isPublic: Bool = false
    ) async throws -> Book {
        let userId = AuthManager.shared.currentUser?.id ?? ""
        
        let bookData: [String: Any] = [
            "title": title,
            "author": author ?? NSNull(),
            "category": category,
            "description": description ?? NSNull(),
            "file_url": fileUrl ?? NSNull(),
            "file_size": fileSize ?? NSNull(),
            "total_pages": totalPages ?? NSNull(),
            "user_id": userId,
            "is_public": isPublic,
            "processing_status": "pending"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: bookData)
        
        let books = try await makeRequest(
            endpoint: "/rest/v1/books",
            method: "POST",
            body: jsonData,
            headers: [
                "Prefer": "return=representation"
            ],
            expecting: [Book].self
        )
        guard let book = books.first else {
            throw APIError.invalidResponse
        }
        
        return book
    }
    
    /// 更新书籍处理进度
    func updateBookProgress(
        bookId: String,
        progress: Double,
        status: Book.ProcessingStatus? = nil
    ) async throws {
        var updateData: [String: Any] = [
            "processing_progress": progress
        ]
        
        if let status = status {
            updateData["processing_status"] = status.rawValue
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: updateData)
        
        _ = try await makeRequest(
            endpoint: "/rest/v1/books",
            method: "PATCH",
            body: jsonData,
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(bookId)")
            ],
            expecting: Data.self
        )
    }
    
    /// 删除书籍（级联删除相关知识）
    func deleteBook(bookId: String) async throws {
        _ = try await makeRequest(
            endpoint: "/rest/v1/books",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(bookId)")
            ],
            expecting: Data.self
        )
    }
    
    // MARK: - 知识内容管理
    
    /// 批量插入知识条目
    func insertKnowledgeItems(_ items: [KnowledgeItem]) async throws {
        // 分批插入，每批最多100条
        let batchSize = 100
        
        for batchStart in stride(from: 0, to: items.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, items.count)
            let batch = Array(items[batchStart..<batchEnd])
            
            let jsonData = try JSONEncoder.supabaseEncoder.encode(batch)
            
            _ = try await makeRequest(
                endpoint: "/rest/v1/knowledge_base",
                method: "POST",
                body: jsonData,
                expecting: Data.self
            )
            
            // 避免请求过快
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }
    }
    
    /// 获取书籍的知识条目
    func getBookKnowledge(bookId: String, limit: Int = 100) async throws -> [KnowledgeItem] {
        return try await makeRequest(
            endpoint: "/rest/v1/knowledge_base",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "book_id", value: "eq.\(bookId)"),
                URLQueryItem(name: "order", value: "page_number.asc,chunk_index.asc"),
                URLQueryItem(name: "limit", value: String(limit))
            ],
            expecting: [KnowledgeItem].self
        )
    }
    
    // MARK: - 知识搜索
    
    /// 向量相似度搜索
    func searchKnowledgeByVector(
        embedding: [Float],
        matchCount: Int = 5,
        similarityThreshold: Double = 0.7
    ) async throws -> [KnowledgeItem] {
        let rpcData: [String: Any] = [
            "query_embedding": embedding,
            "match_count": matchCount,
            "similarity_threshold": similarityThreshold
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: rpcData)
        
        return try await makeRequest(
            endpoint: "/rest/v1/rpc/search_knowledge",
            method: "POST",
            body: jsonData,
            expecting: [KnowledgeItem].self
        )
    }
    
    /// 混合搜索（向量 + 全文）
    func hybridSearchKnowledge(
        query: String,
        embedding: [Float]? = nil,
        matchCount: Int = 5
    ) async throws -> [KnowledgeItem] {
        // 如果没有提供embedding，先生成
        let queryEmbedding: [Float]
        if let embedding = embedding {
            queryEmbedding = embedding
        } else {
            // 调用OpenAI生成embedding
            queryEmbedding = try await generateEmbedding(for: query)
        }
        
        let rpcData: [String: Any] = [
            "query_text": query,
            "query_embedding": queryEmbedding,
            "match_count": matchCount,
            "vector_weight": 0.7  // 向量权重70%
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: rpcData)
        
        return try await makeRequest(
            endpoint: "/rest/v1/rpc/hybrid_search",
            method: "POST",
            body: jsonData,
            expecting: [KnowledgeItem].self
        )
    }
    
    /// 获取知识条目的上下文
    func getKnowledgeContext(
        knowledgeId: String,
        contextSize: Int = 1
    ) async throws -> [KnowledgeItem] {
        let rpcData: [String: Any] = [
            "knowledge_id": knowledgeId,
            "context_size": contextSize
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: rpcData)
        
        return try await makeRequest(
            endpoint: "/rest/v1/rpc/get_knowledge_context",
            method: "POST",
            body: jsonData,
            expecting: [KnowledgeItem].self
        )
    }
    
    // MARK: - 统计信息
    
    /// 获取用户的书籍统计
    func getUserBookStatistics(userId: String? = nil) async throws -> BookStatistics {
        let effectiveUserId = userId ?? AuthManager.shared.currentUser?.id
        
        let rpcData: [String: Any] = effectiveUserId != nil ? 
            ["user_id": effectiveUserId!] : [:]
        
        let jsonData = try JSONSerialization.data(withJSONObject: rpcData)
        
        let stats = try await makeRequest(
            endpoint: "/rest/v1/rpc/get_user_book_stats",
            method: "POST",
            body: jsonData,
            expecting: [BookStatistics].self
        )
        guard let stat = stats.first else {
            throw APIError.invalidResponse
        }
        
        return stat
    }
    
    // MARK: - PDF文件管理
    
    /// 上传PDF到Storage
    func uploadPDF(fileURL: URL, bookId: String) async throws -> String {
        let userId = AuthManager.shared.currentUser?.id ?? ""
        
        // 生成存储路径
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = fileURL.lastPathComponent
        let storagePath = "\(userId)/\(timestamp)_\(fileName)"
        
        // 读取文件数据
        let fileData = try Data(contentsOf: fileURL)
        
        // 上传到Storage
        _ = try await makeRequest(
            endpoint: "/storage/v1/object/pdf-books/\(storagePath)",
            method: "POST",
            body: fileData,
            headers: [
                "Content-Type": "application/pdf"
            ],
            expecting: Data.self
        )
        
        // 返回存储路径
        return storagePath
    }
    
    /// 获取PDF签名URL（用于下载）
    func getPDFSignedURL(storagePath: String, expiresIn: Int = 3600) async throws -> URL {
        let requestData: [String: Any] = [
            "expiresIn": expiresIn
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestData)
        
        let response = try await makeRequest(
            endpoint: "/storage/v1/object/sign/pdf-books/\(storagePath)",
            method: "POST",
            body: jsonData,
            expecting: Data.self
        )
        
        let result = try JSONSerialization.jsonObject(with: response) as? [String: Any]
        guard let signedUrl = result?["signedURL"] as? String,
              let url = URL(string: signedUrl) else {
            throw APIError.invalidResponse
        }
        
        return url
    }
    
    /// 删除PDF文件
    func deletePDF(storagePath: String) async throws {
        _ = try await makeRequest(
            endpoint: "/storage/v1/object/pdf-books/\(storagePath)",
            method: "DELETE",
            expecting: Data.self
        )
    }
    
    // MARK: - OpenAI Embedding生成
    
    /// 生成文本的向量表示
    private func generateEmbedding(for text: String) async throws -> [Float] {
        // 这里需要调用OpenAI API
        // 暂时返回模拟数据，实际实现需要集成OpenAI
        print("⚠️ 需要实现OpenAI Embedding API调用")
        return Array(repeating: 0.0, count: 1536)
    }
}

// MARK: - JSON编解码器扩展
extension JSONDecoder {
    static let supabaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    static let supabaseEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}