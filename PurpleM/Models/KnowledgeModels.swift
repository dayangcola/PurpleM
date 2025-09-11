//
//  KnowledgeModels.swift
//  PurpleM
//
//  知识库系统数据模型
//

import Foundation

// MARK: - 书籍模型
struct Book: Codable, Identifiable {
    let id: String
    let title: String
    let author: String?
    let category: String?
    let description: String?
    let fileUrl: String?
    let fileSize: Int?
    let totalPages: Int?
    let processingStatus: ProcessingStatus
    let processingProgress: Double?
    let errorMessage: String?
    let userId: String?
    let isPublic: Bool
    let createdAt: Date?
    let updatedAt: Date?
    
    // 处理状态枚举
    enum ProcessingStatus: String, Codable {
        case pending = "pending"
        case processing = "processing"
        case completed = "completed"
        case failed = "failed"
        
        var displayText: String {
            switch self {
            case .pending: return "待处理"
            case .processing: return "处理中"
            case .completed: return "已完成"
            case .failed: return "处理失败"
            }
        }
        
        var icon: String {
            switch self {
            case .pending: return "clock"
            case .processing: return "arrow.triangle.2.circlepath"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    // 数据库字段映射
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case category
        case description
        case fileUrl = "file_url"
        case fileSize = "file_size"
        case totalPages = "total_pages"
        case processingStatus = "processing_status"
        case processingProgress = "processing_progress"
        case errorMessage = "error_message"
        case userId = "user_id"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 知识条目模型
struct KnowledgeItem: Codable, Identifiable {
    let id: String
    let bookId: String
    let bookTitle: String
    let chapter: String?
    let section: String?
    let pageNumber: Int?
    let content: String
    let contentLength: Int?
    let chunkIndex: Int?
    let embedding: [Float]?  // 1536维向量
    let metadata: [String: Any]?
    let createdAt: Date?
    
    // 搜索结果额外字段
    var similarity: Double?
    var textRank: Double?
    var combinedScore: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case bookId = "book_id"
        case bookTitle = "book_title"
        case chapter
        case section
        case pageNumber = "page_number"
        case content
        case contentLength = "content_length"
        case chunkIndex = "chunk_index"
        case embedding
        case metadata
        case createdAt = "created_at"
        case similarity
        case textRank = "text_rank"
        case combinedScore = "combined_score"
    }
    
    // 成员初始化器
    init(
        id: String,
        bookId: String,
        bookTitle: String,
        chapter: String? = nil,
        section: String? = nil,
        pageNumber: Int? = nil,
        content: String,
        contentLength: Int? = nil,
        chunkIndex: Int? = nil,
        embedding: [Float]? = nil,
        metadata: [String: Any]? = nil,
        createdAt: Date? = nil,
        similarity: Double? = nil,
        textRank: Double? = nil,
        combinedScore: Double? = nil
    ) {
        self.id = id
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.chapter = chapter
        self.section = section
        self.pageNumber = pageNumber
        self.content = content
        self.contentLength = contentLength
        self.chunkIndex = chunkIndex
        self.embedding = embedding
        self.metadata = metadata
        self.createdAt = createdAt
        self.similarity = similarity
        self.textRank = textRank
        self.combinedScore = combinedScore
    }
    
    // 自定义解码（处理metadata的Any类型）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        bookId = try container.decode(String.self, forKey: .bookId)
        bookTitle = try container.decode(String.self, forKey: .bookTitle)
        chapter = try container.decodeIfPresent(String.self, forKey: .chapter)
        section = try container.decodeIfPresent(String.self, forKey: .section)
        pageNumber = try container.decodeIfPresent(Int.self, forKey: .pageNumber)
        content = try container.decode(String.self, forKey: .content)
        contentLength = try container.decodeIfPresent(Int.self, forKey: .contentLength)
        chunkIndex = try container.decodeIfPresent(Int.self, forKey: .chunkIndex)
        embedding = try container.decodeIfPresent([Float].self, forKey: .embedding)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        
        // 解码JSON类型的metadata
        if let metadataData = try container.decodeIfPresent(Data.self, forKey: .metadata) {
            metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        } else {
            metadata = nil
        }
        
        // 搜索结果字段
        similarity = try container.decodeIfPresent(Double.self, forKey: .similarity)
        textRank = try container.decodeIfPresent(Double.self, forKey: .textRank)
        combinedScore = try container.decodeIfPresent(Double.self, forKey: .combinedScore)
    }
    
    // 自定义编码
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(bookId, forKey: .bookId)
        try container.encode(bookTitle, forKey: .bookTitle)
        try container.encodeIfPresent(chapter, forKey: .chapter)
        try container.encodeIfPresent(section, forKey: .section)
        try container.encodeIfPresent(pageNumber, forKey: .pageNumber)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(contentLength, forKey: .contentLength)
        try container.encodeIfPresent(chunkIndex, forKey: .chunkIndex)
        try container.encodeIfPresent(embedding, forKey: .embedding)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        
        // 编码metadata为JSON
        if let metadata = metadata {
            let metadataData = try JSONSerialization.data(withJSONObject: metadata)
            try container.encode(metadataData, forKey: .metadata)
        }
        
        try container.encodeIfPresent(similarity, forKey: .similarity)
        try container.encodeIfPresent(textRank, forKey: .textRank)
        try container.encodeIfPresent(combinedScore, forKey: .combinedScore)
    }
}

// MARK: - 搜索请求模型
struct KnowledgeSearchRequest: Codable {
    let query: String
    let embedding: [Float]?
    let matchCount: Int
    let similarityThreshold: Double?
    let searchType: SearchType
    
    enum SearchType: String, Codable {
        case vector = "vector"          // 纯向量搜索
        case text = "text"              // 纯文本搜索
        case hybrid = "hybrid"          // 混合搜索
    }
    
    enum CodingKeys: String, CodingKey {
        case query
        case embedding = "query_embedding"
        case matchCount = "match_count"
        case similarityThreshold = "similarity_threshold"
        case searchType = "search_type"
    }
}

// MARK: - 搜索结果模型
struct KnowledgeSearchResult {
    let items: [KnowledgeItem]
    let totalCount: Int
    let searchTime: TimeInterval
    
    // 获取格式化的引用
    func getFormattedReferences() -> [String] {
        return items.enumerated().map { index, item in
            var reference = "[\\(index + 1)] 《\\(item.bookTitle)》"
            
            if let chapter = item.chapter {
                reference += " \\(chapter)"
            }
            
            if let pageNumber = item.pageNumber {
                reference += "，第\\(pageNumber)页"
            }
            
            return reference
        }
    }
    
    // 构建增强的提示词
    func buildEnhancedPrompt(userQuery: String) -> String {
        guard !items.isEmpty else {
            return userQuery
        }
        
        var prompt = """
        用户问题：\(userQuery)
        
        【参考资料】
        """
        
        for (index, item) in items.enumerated() {
            prompt += """
            
            来源\(index + 1)：《\(item.bookTitle)》
            """
            
            if let chapter = item.chapter {
                prompt += " - \(chapter)"
            }
            
            if let similarity = item.similarity {
                prompt += " (相关度：\(String(format: "%.0f%%", similarity * 100)))"
            }
            
            prompt += """
            
            内容：\(item.content)
            """
        }
        
        prompt += """
        
        
        请基于以上参考资料回答用户问题。如果引用了资料，请标注来源编号，如[1]。
        """
        
        return prompt
    }
}

// MARK: - 书籍统计模型
struct BookStatistics: Codable {
    let totalBooks: Int
    let completedBooks: Int
    let processingBooks: Int
    let failedBooks: Int
    let totalKnowledgeItems: Int
    let totalStorageMB: Double
    
    enum CodingKeys: String, CodingKey {
        case totalBooks = "total_books"
        case completedBooks = "completed_books"
        case processingBooks = "processing_books"
        case failedBooks = "failed_books"
        case totalKnowledgeItems = "total_knowledge_items"
        case totalStorageMB = "total_storage_mb"
    }
}

// MARK: - PDF处理任务模型
struct PDFProcessingTask {
    let bookId: String
    let fileURL: URL
    let userId: String
    var currentPage: Int = 0
    var totalPages: Int = 0
    var extractedChunks: [TextChunk] = []
    var status: Book.ProcessingStatus = .pending
    var errorMessage: String?
    
    struct TextChunk {
        let content: String
        let chapter: String?
        let section: String?
        let pageNumber: Int
        let chunkIndex: Int
    }
    
    // 计算进度百分比
    var progressPercentage: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages) * 100
    }
}

// MARK: - 上传配置
struct KnowledgeUploadConfig {
    static let maxFileSize: Int = 50 * 1024 * 1024  // 50MB
    static let supportedFormats = ["pdf"]
    static let chunkSize = 1000  // 每块最大字符数
    static let chunkOverlap = 100  // 块之间重叠字符数
    static let embeddingBatchSize = 20  // 向量生成批次大小
    static let embeddingDimension = 1536  // OpenAI embedding维度
}