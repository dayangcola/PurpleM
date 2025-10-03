//
//  EmbeddingService.swift
//  PurpleM
//
//  文本向量化服务 - 使用Vercel AI Gateway调用OpenAI Embeddings
//

import Foundation

// MARK: - 向量化服务
class EmbeddingService: NSObject, URLSessionDelegate {
    
    // MARK: - 单例
    static let shared = EmbeddingService()
    
    // MARK: - 配置
    struct Config {
        // 使用Vercel AI Gateway的embedding端点
        static let backendURL = "https://purple-m.vercel.app/api/embeddings"
        static let model = "text-embedding-ada-002"
        static let dimension = 1536
        
        // 批处理配置
        static let maxBatchSize = 20
        static let maxTextLength = 8000  // Ada-002的token限制约8k
    }
    
    // MARK: - 错误定义
    enum EmbeddingError: LocalizedError {
        case textTooLong
        case batchTooLarge
        case networkError(String)
        case invalidResponse
        case serverError(String)
        
        var errorDescription: String? {
            switch self {
            case .textTooLong:
                return "文本超过最大长度限制"
            case .batchTooLarge:
                return "批次大小超过限制"
            case .networkError(let message):
                return "网络错误: \(message)"
            case .invalidResponse:
                return "无效的服务器响应"
            case .serverError(let message):
                return "服务器错误: \(message)"
            }
        }
    }
    
    // MARK: - 请求/响应模型
    struct EmbeddingRequest: Codable {
        let input: EmbeddingInput
        let model: String
        
        enum EmbeddingInput: Codable {
            case single(String)
            case batch([String])
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .single(let text):
                    try container.encode(text)
                case .batch(let texts):
                    try container.encode(texts)
                }
            }
        }
    }
    
    struct EmbeddingResponse: Codable {
        let data: [EmbeddingData]
        let model: String
        let usage: Usage?
        
        struct EmbeddingData: Codable {
            let embedding: [Float]
            let index: Int
        }
        
        struct Usage: Codable {
            let prompt_tokens: Int
            let total_tokens: Int
        }
    }
    
    // MARK: - 备用响应格式（兼容Vercel返回）
    struct VercelEmbeddingResponse: Codable {
        let success: Bool
        let embeddings: [[Float]]?
        let embedding: [Float]?  // 单个文本时
        let error: String?
        let usage: EmbeddingResponse.Usage?
    }
    
    // MARK: - 属性
    private var session: URLSession!
    private var requestCount = 0
    private let requestLimit = 1000  // 每分钟限制
    private var lastResetTime = Date()
    
    // MARK: - 初始化
    override init() {
        super.init()
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - 公共方法
    
    /// 生成单个文本的向量
    func generateEmbedding(for text: String) async throws -> [Float] {
        // 检查文本长度
        guard text.count <= Config.maxTextLength else {
            throw EmbeddingError.textTooLong
        }
        
        // 清理文本
        let cleanedText = preprocessText(text)
        
        // 创建请求
        let request = EmbeddingRequest(
            input: .single(cleanedText),
            model: Config.model
        )
        
        // 发送请求
        let response = try await sendRequest(request)
        
        // 提取向量
        if let embedding = response.embedding {
            return embedding
        } else if let embeddings = response.embeddings, !embeddings.isEmpty {
            return embeddings[0]
        } else {
            throw EmbeddingError.invalidResponse
        }
    }
    
    /// 批量生成向量
    func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
        // 检查批次大小
        guard texts.count <= Config.maxBatchSize else {
            throw EmbeddingError.batchTooLarge
        }
        
        // 清理文本
        let cleanedTexts = texts.map { preprocessText($0) }
        
        // 检查每个文本的长度
        for text in cleanedTexts {
            guard text.count <= Config.maxTextLength else {
                throw EmbeddingError.textTooLong
            }
        }
        
        // 创建请求
        let request = EmbeddingRequest(
            input: .batch(cleanedTexts),
            model: Config.model
        )
        
        // 发送请求
        let response = try await sendRequest(request)
        
        // 提取向量
        if let embeddings = response.embeddings {
            return embeddings
        } else {
            throw EmbeddingError.invalidResponse
        }
    }
    
    /// 分批处理大量文本
    func generateEmbeddingsInBatches(
        for texts: [String],
        batchSize: Int = Config.maxBatchSize,
        onProgress: ((Int, Int) -> Void)? = nil
    ) async throws -> [[Float]] {
        var allEmbeddings: [[Float]] = []
        
        // 分批处理
        for batchStart in stride(from: 0, to: texts.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, texts.count)
            let batch = Array(texts[batchStart..<batchEnd])
            
            // 更新进度
            onProgress?(batchStart + batch.count, texts.count)
            
            // 生成向量
            let embeddings = try await generateEmbeddings(for: batch)
            allEmbeddings.append(contentsOf: embeddings)
            
            // 速率限制：每批之间暂停
            if batchEnd < texts.count {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            }
        }
        
        return allEmbeddings
    }
    
    // MARK: - 私有方法
    
    private func preprocessText(_ text: String) -> String {
        // 清理文本
        var cleaned = text
        
        // 移除多余空白
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // 移除控制字符
        cleaned = cleaned.replacingOccurrences(of: "[\\x00-\\x1F\\x7F]", with: "", options: .regularExpression)
        
        // 修剪首尾空白
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 截断过长文本
        if cleaned.count > Config.maxTextLength {
            let endIndex = cleaned.index(cleaned.startIndex, offsetBy: Config.maxTextLength)
            cleaned = String(cleaned[..<endIndex])
        }
        
        return cleaned
    }
    
    private func sendRequest(_ request: EmbeddingRequest) async throws -> VercelEmbeddingResponse {
        // 构建URL请求
        guard let url = URL(string: Config.backendURL) else {
            throw EmbeddingError.networkError("无效的URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 编码请求体
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        // 发送请求
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            // 检查HTTP响应
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw EmbeddingError.serverError("HTTP \(httpResponse.statusCode): \(errorMessage)")
                }
            }
            
            // 解码响应
            let decoder = JSONDecoder()
            
            // 尝试解码为Vercel格式
            if let vercelResponse = try? decoder.decode(VercelEmbeddingResponse.self, from: data) {
                if vercelResponse.success {
                    return vercelResponse
                } else {
                    throw EmbeddingError.serverError(vercelResponse.error ?? "未知错误")
                }
            }
            
            // 尝试解码为OpenAI格式并转换
            if let openAIResponse = try? decoder.decode(EmbeddingResponse.self, from: data) {
                // 转换为Vercel格式
                let embeddings = openAIResponse.data
                    .sorted { $0.index < $1.index }
                    .map { $0.embedding }
                
                return VercelEmbeddingResponse(
                    success: true,
                    embeddings: embeddings,
                    embedding: embeddings.first,
                    error: nil,
                    usage: openAIResponse.usage
                )
            }
            
            throw EmbeddingError.invalidResponse
            
        } catch let error as EmbeddingError {
            throw error
        } catch {
            throw EmbeddingError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - URLSessionDelegate
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // 信任Vercel证书
        if challenge.protectionSpace.host.contains("vercel.app") {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - 向量工具类
extension EmbeddingService {
    
    /// 计算两个向量的余弦相似度
    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        
        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator != 0 else { return 0 }
        
        return dotProduct / denominator
    }
    
    /// 估算文本的token数量（粗略估算）
    static func estimateTokenCount(_ text: String) -> Int {
        // 中文约1.5字符=1token，英文约4字符=1token
        let chineseCount = text.filter { $0.isChineseCharacter }.count
        let englishCount = text.count - chineseCount
        
        return Int(Double(chineseCount) / 1.5 + Double(englishCount) / 4)
    }
}

// MARK: - Character扩展
private extension Character {
    var isChineseCharacter: Bool {
        guard let scalar = self.unicodeScalars.first else { return false }
        return (0x4E00...0x9FFF).contains(scalar.value) ||
               (0x3400...0x4DBF).contains(scalar.value) ||
               (0x20000...0x2A6DF).contains(scalar.value)
    }
}