//
//  KnowledgeUploader.swift
//  PurpleM
//
//  知识库上传管理器 - 协调PDF处理、向量化和数据存储
//

import Foundation
import SwiftUI
import Combine

// MARK: - 知识上传管理器
@MainActor
class KnowledgeUploader: ObservableObject {
    
    // MARK: - 上传状态
    enum UploadStatus {
        case idle
        case uploadingFile(progress: Double)
        case extractingText(page: Int, total: Int)
        case chunking(progress: Double)
        case generatingEmbeddings(chunk: Int, total: Int)
        case savingToDatabase(progress: Double)
        case completed(bookId: String)
        case failed(Error)
        
        var description: String {
            switch self {
            case .idle:
                return "准备就绪"
            case .uploadingFile(let progress):
                return "上传文件中 (\(Int(progress))%)"
            case .extractingText(let page, let total):
                return "提取文本 (\(page)/\(total)页)"
            case .chunking(let progress):
                return "智能分块中 (\(Int(progress))%)"
            case .generatingEmbeddings(let chunk, let total):
                return "生成向量 (\(chunk)/\(total))"
            case .savingToDatabase(let progress):
                return "保存数据 (\(Int(progress))%)"
            case .completed:
                return "上传完成"
            case .failed(let error):
                return "上传失败: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 上传任务
    struct UploadTask: Identifiable {
        let id = UUID()
        let fileURL: URL
        let bookTitle: String
        let author: String?
        let isPublic: Bool
        var status: UploadStatus = .idle
        var startTime: Date?
        var endTime: Date?
        var bookId: String?
        
        var elapsedTime: TimeInterval {
            guard let start = startTime else { return 0 }
            let end = endTime ?? Date()
            return end.timeIntervalSince(start)
        }
    }
    
    // MARK: - 属性
    @Published var currentTask: UploadTask?
    @Published var uploadQueue: [UploadTask] = []
    @Published var completedTasks: [UploadTask] = []
    @Published var overallProgress: Double = 0
    
    private let pdfProcessor = PDFProcessor()
    private let textChunker = TextChunker()
    private let embeddingService = EmbeddingService.shared  // 使用单例
    private let supabaseManager = SupabaseManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // 监听PDF处理器状态
        pdfProcessor.$status
            .sink { [weak self] status in
                self?.updateTaskStatus(from: status)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 公共方法
    
    /// 添加上传任务到队列
    func queueUpload(
        fileURL: URL,
        title: String? = nil,
        author: String? = nil,
        isPublic: Bool = false
    ) {
        let bookTitle = title ?? fileURL.deletingPathExtension().lastPathComponent
        
        let task = UploadTask(
            fileURL: fileURL,
            bookTitle: bookTitle,
            author: author,
            isPublic: isPublic
        )
        
        uploadQueue.append(task)
        
        // 如果没有正在进行的任务，开始处理
        if currentTask == nil {
            processNextTask()
        }
    }
    
    /// 取消当前任务
    func cancelCurrentTask() {
        currentTask?.status = .failed(UploadError.cancelled)
        currentTask = nil
        processNextTask()
    }
    
    /// 清空队列
    func clearQueue() {
        uploadQueue.removeAll()
    }
    
    // MARK: - 私有方法
    
    private func processNextTask() {
        guard currentTask == nil,
              !uploadQueue.isEmpty else { return }
        
        var task = uploadQueue.removeFirst()
        task.startTime = Date()
        currentTask = task
        
        Task {
            await processUpload(task)
        }
    }
    
    private func processUpload(_ task: UploadTask) async {
        do {
            // 1. 创建书籍记录
            updateStatus(.uploadingFile(progress: 10))
            let book = try await createBookRecord(task)
            currentTask?.bookId = book.id
            
            // 2. 上传PDF文件到Storage
            updateStatus(.uploadingFile(progress: 30))
            let storagePath = try await uploadPDFFile(task.fileURL, bookId: book.id)
            
            // 3. 提取文本
            updateStatus(.extractingText(page: 0, total: 0))
            let pdfDocument = try await pdfProcessor.processDocument(at: task.fileURL)
            let pages = try await pdfProcessor.extractAllText(from: pdfDocument)
            
            // 4. 智能分块
            updateStatus(.chunking(progress: 0))
            let chunks = await performChunking(pages: pages, pdfDocument: pdfDocument)
            
            // 5. 生成向量
            updateStatus(.generatingEmbeddings(chunk: 0, total: chunks.count))
            let knowledgeItems = try await generateEmbeddings(
                chunks: chunks,
                book: book
            )
            
            // 6. 保存到数据库
            updateStatus(.savingToDatabase(progress: 0))
            try await saveKnowledgeItems(knowledgeItems)
            
            // 7. 更新书籍状态
            try await supabaseManager.updateBookProgress(
                bookId: book.id,
                progress: 100,
                status: .completed
            )
            
            // 完成
            completeTask(bookId: book.id)
            
        } catch {
            handleError(error)
        }
    }
    
    private func createBookRecord(_ task: UploadTask) async throws -> Book {
        let fileSize = try FileManager.default.attributesOfItem(
            atPath: task.fileURL.path
        )[.size] as? Int
        
        return try await supabaseManager.createBook(
            title: task.bookTitle,
            author: task.author,
            category: "紫微斗数",
            fileSize: fileSize,
            isPublic: task.isPublic
        )
    }
    
    private func uploadPDFFile(_ fileURL: URL, bookId: String) async throws -> String {
        return try await supabaseManager.uploadPDF(
            fileURL: fileURL,
            bookId: bookId
        )
    }
    
    private func performChunking(
        pages: [PDFProcessor.PageContent],
        pdfDocument: PDFProcessor.PDFDocumentInfo
    ) async -> [TextChunker.TextChunk] {
        var allChunks: [TextChunker.TextChunk] = []
        
        // 合并所有页面文本
        let fullText = pages.map { $0.text }.joined(separator: "\n\n")
        
        // 检测章节
        let chapters = pdfProcessor.detectChapters(in: fullText)
        
        // 执行分块
        let chunkResult = textChunker.chunk(
            text: fullText,
            chapters: chapters
        )
        
        // 为每个块添加页码信息
        for (pageIndex, page) in pages.enumerated() {
            let pageChunks = chunkResult.chunks.filter { chunk in
                // 简单判断：检查块内容是否包含该页的部分文本
                chunk.content.contains(String(page.text.prefix(50)))
            }
            
            for var chunk in pageChunks {
                // 创建新的chunk并添加页码
                let newChunk = TextChunker.TextChunk(
                    content: chunk.content,
                    index: chunk.index,
                    startPosition: chunk.startPosition,
                    endPosition: chunk.endPosition,
                    chapter: chunk.chapter,
                    section: chunk.section,
                    pageNumber: pageIndex + 1,
                    isComplete: chunk.isComplete
                )
                allChunks.append(newChunk)
            }
        }
        
        // 去重
        let uniqueChunks = Array(Set(allChunks.map { $0.content }))
            .enumerated()
            .map { index, content in
                TextChunker.TextChunk(
                    content: content,
                    index: index,
                    startPosition: 0,
                    endPosition: content.count,
                    chapter: allChunks.first { $0.content == content }?.chapter,
                    section: nil,
                    pageNumber: allChunks.first { $0.content == content }?.pageNumber,
                    isComplete: true
                )
            }
        
        return uniqueChunks
    }
    
    private func generateEmbeddings(
        chunks: [TextChunker.TextChunk],
        book: Book
    ) async throws -> [KnowledgeItem] {
        var knowledgeItems: [KnowledgeItem] = []
        
        // 分批处理
        let batchSize = 20
        for batchStart in stride(from: 0, to: chunks.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, chunks.count)
            let batch = Array(chunks[batchStart..<batchEnd])
            
            updateStatus(.generatingEmbeddings(
                chunk: batchStart + batch.count,
                total: chunks.count
            ))
            
            // 生成向量（这里需要实际调用OpenAI API）
            for chunk in batch {
                let embedding = try await embeddingService.generateEmbedding(
                    for: chunk.content
                )
                
                let item = KnowledgeItem(
                    id: UUID().uuidString,
                    bookId: book.id,
                    bookTitle: book.title,
                    chapter: chunk.chapter,
                    section: chunk.section,
                    pageNumber: chunk.pageNumber,
                    content: chunk.content,
                    contentLength: chunk.content.count,
                    chunkIndex: chunk.index,
                    embedding: embedding,
                    metadata: nil,
                    createdAt: Date(),
                    similarity: nil,
                    textRank: nil,
                    combinedScore: nil
                )
                
                knowledgeItems.append(item)
            }
            
            // 避免请求过快
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        }
        
        return knowledgeItems
    }
    
    private func saveKnowledgeItems(_ items: [KnowledgeItem]) async throws {
        let totalBatches = (items.count + 99) / 100  // 每批100条
        
        for (index, batch) in items.chunked(into: 100).enumerated() {
            updateStatus(.savingToDatabase(
                progress: Double(index + 1) / Double(totalBatches) * 100
            ))
            
            try await supabaseManager.insertKnowledgeItems(batch)
        }
    }
    
    // MARK: - 状态管理
    
    private func updateStatus(_ status: UploadStatus) {
        currentTask?.status = status
        
        // 计算总体进度
        switch status {
        case .uploadingFile(let progress):
            overallProgress = progress * 0.1
        case .extractingText(let page, let total):
            overallProgress = 10 + (Double(page) / Double(max(total, 1))) * 20
        case .chunking(let progress):
            overallProgress = 30 + progress * 0.1
        case .generatingEmbeddings(let chunk, let total):
            overallProgress = 40 + (Double(chunk) / Double(max(total, 1))) * 40
        case .savingToDatabase(let progress):
            overallProgress = 80 + progress * 0.2
        case .completed:
            overallProgress = 100
        default:
            break
        }
    }
    
    private func updateTaskStatus(from pdfStatus: PDFProcessor.ProcessingStatus) {
        switch pdfStatus {
        case .extracting(let page, let total):
            updateStatus(.extractingText(page: page, total: total))
        case .performing_ocr(let page, let total):
            updateStatus(.extractingText(page: page, total: total))
        default:
            break
        }
    }
    
    private func completeTask(bookId: String) {
        currentTask?.status = .completed(bookId: bookId)
        currentTask?.endTime = Date()
        
        if let task = currentTask {
            completedTasks.append(task)
        }
        
        currentTask = nil
        overallProgress = 0
        
        // 处理下一个任务
        processNextTask()
    }
    
    private func handleError(_ error: Error) {
        currentTask?.status = .failed(error)
        currentTask?.endTime = Date()
        
        if let task = currentTask {
            completedTasks.append(task)
        }
        
        currentTask = nil
        overallProgress = 0
        
        // 处理下一个任务
        processNextTask()
    }
}

// MARK: - 错误定义
enum UploadError: LocalizedError {
    case cancelled
    case invalidFile
    case networkError
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "上传已取消"
        case .invalidFile:
            return "无效的文件"
        case .networkError:
            return "网络错误"
        case .processingFailed:
            return "处理失败"
        }
    }
}

// MARK: - Array扩展
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// 使用真实的EmbeddingService（已实现）
// EmbeddingService现在通过Vercel AI Gateway调用OpenAI