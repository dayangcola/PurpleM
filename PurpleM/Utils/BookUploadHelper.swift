//
//  BookUploadHelper.swift
//  PurpleM
//
//  简单的书籍上传助手 - 用于上传少量PDF书籍
//

import Foundation
import SwiftUI

// MARK: - 书籍上传助手
@MainActor
class BookUploadHelper {
    
    static let shared = BookUploadHelper()
    private let uploader = KnowledgeUploader()
    
    // MARK: - 预设书籍列表
    struct PresetBook {
        let fileName: String
        let title: String
        let author: String
        let isPublic: Bool
        
        static let books = [
            PresetBook(
                fileName: "紫微斗数全书.pdf",
                title: "紫微斗数全书",
                author: "陈抟",
                isPublic: false
            ),
            PresetBook(
                fileName: "紫微斗数精成.pdf",
                title: "紫微斗数精成",
                author: "潘子渔",
                isPublic: false
            ),
            PresetBook(
                fileName: "十八飞星策天紫微斗数.pdf",
                title: "十八飞星策天紫微斗数",
                author: "明·陈雯",
                isPublic: false
            )
        ]
    }
    
    // MARK: - 上传单本书
    func uploadBook(
        fileURL: URL,
        title: String,
        author: String,
        isPublic: Bool = false,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        print("📚 开始上传: \(title)")
        print("📄 文件: \(fileURL.lastPathComponent)")
        print("👤 作者: \(author)")
        print("🔒 权限: \(isPublic ? "公开" : "私有")")
        print("---")
        
        // 添加到上传队列
        uploader.queueUpload(
            fileURL: fileURL,
            title: title,
            author: author,
            isPublic: isPublic
        )
        
        // 监听上传状态
        Task { @MainActor in
            // 等待上传开始
            while uploader.currentTask == nil {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
            
            // 监控上传进度
            while let task = uploader.currentTask {
                switch task.status {
                case .idle:
                    print("⏳ 等待开始...")
                    
                case .uploadingFile(let progress):
                    print("📤 上传文件: \(Int(progress))%")
                    
                case .extractingText(let page, let total):
                    print("📖 提取文本: \(page)/\(total)页")
                    
                case .chunking(let progress):
                    print("✂️ 智能分块: \(Int(progress))%")
                    
                case .generatingEmbeddings(let chunk, let total):
                    print("🧮 生成向量: \(chunk)/\(total)")
                    
                case .savingToDatabase(let progress):
                    print("💾 保存数据: \(Int(progress))%")
                    
                case .completed(let bookId):
                    print("✅ 上传成功！书籍ID: \(bookId)")
                    completion(.success(bookId))
                    return
                    
                case .failed(let error):
                    print("❌ 上传失败: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            }
        }
    }
    
    // MARK: - 批量上传预设书籍
    func uploadPresetBooks(from directory: URL) {
        print("========================================")
        print("📚 批量上传紫微斗数书籍")
        print("📁 目录: \(directory.path)")
        print("========================================\n")
        
        for book in PresetBook.books {
            let fileURL = directory.appendingPathComponent(book.fileName)
            
            // 检查文件是否存在
            if FileManager.default.fileExists(atPath: fileURL.path) {
                uploadBook(
                    fileURL: fileURL,
                    title: book.title,
                    author: book.author,
                    isPublic: book.isPublic
                ) { result in
                    switch result {
                    case .success(let bookId):
                        print("✅ \(book.title) 上传完成: \(bookId)\n")
                    case .failure(let error):
                        print("❌ \(book.title) 上传失败: \(error)\n")
                    }
                }
            } else {
                print("⚠️ 文件不存在: \(book.fileName)\n")
            }
        }
    }
    
    // MARK: - 测试上传（使用模拟PDF）
    func testUploadWithMockPDF() {
        print("🧪 测试上传流程（模拟PDF）\n")
        
        // 创建测试PDF
        let testContent = """
        第一章 紫微斗数概论
        
        紫微斗数是中国传统命理学的重要组成部分，以紫微星为首的星曜系统，
        通过十二宫位的排布，揭示人生的吉凶祸福。
        
        第二章 十二宫位
        
        命宫：代表个人的基本性格和人生格局
        兄弟宫：代表兄弟姐妹关系
        夫妻宫：代表婚姻感情
        子女宫：代表子女缘分
        财帛宫：代表财富状况
        疾厄宫：代表健康状况
        迁移宫：代表外出发展
        交友宫：代表人际关系
        官禄宫：代表事业发展
        田宅宫：代表不动产
        福德宫：代表精神享受
        父母宫：代表父母关系
        """
        
        // 保存为临时文件
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_book_\(UUID().uuidString).pdf")
        
        do {
            try testContent.write(to: tempURL, atomically: true, encoding: .utf8)
            
            uploadBook(
                fileURL: tempURL,
                title: "测试书籍 - 紫微斗数入门",
                author: "测试作者",
                isPublic: false
            ) { result in
                // 清理临时文件
                try? FileManager.default.removeItem(at: tempURL)
                
                switch result {
                case .success(let bookId):
                    print("\n✅ 测试成功！可以开始上传真实书籍了。")
                    print("书籍ID: \(bookId)")
                case .failure(let error):
                    print("\n❌ 测试失败: \(error)")
                    print("请检查配置是否正确。")
                }
            }
        } catch {
            print("创建测试文件失败: \(error)")
        }
    }
}

// MARK: - 简单的上传触发视图（可选）
struct SimpleBookUploadView: View {
    @State private var isUploading = false
    @State private var statusMessage = "准备就绪"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("书籍上传工具")
                .font(.largeTitle)
                .bold()
            
            Text(statusMessage)
                .font(.body)
                .foregroundColor(.gray)
            
            Button("测试上传流程") {
                guard !isUploading else { return }
                isUploading = true
                statusMessage = "正在上传..."
                
                BookUploadHelper.shared.testUploadWithMockPDF()
            }
            .disabled(isUploading)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button("从Documents上传预设书籍") {
                guard !isUploading else { return }
                isUploading = true
                statusMessage = "正在批量上传..."
                
                // 获取Documents目录
                if let documentsPath = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                ).first {
                    BookUploadHelper.shared.uploadPresetBooks(from: documentsPath)
                }
            }
            .disabled(isUploading)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

// MARK: - 在AppDelegate或SceneDelegate中调用
extension BookUploadHelper {
    
    /// 在应用启动时检查并上传书籍
    static func checkAndUploadBooksIfNeeded() {
        Task {
            // 检查是否已有书籍
            do {
                let books = try await SupabaseManager.shared.getUserBooks()
                
                if books.isEmpty {
                    print("📚 未发现书籍，准备上传默认书籍...")
                    
                    // 这里你可以指定PDF文件的路径
                    // 例如：从Bundle中读取
                    if let bundlePath = Bundle.main.resourcePath {
                        let bundleURL = URL(fileURLWithPath: bundlePath)
                        BookUploadHelper.shared.uploadPresetBooks(from: bundleURL)
                    }
                } else {
                    print("📚 已有 \(books.count) 本书籍")
                    for book in books {
                        print("  - \(book.title) (\(book.processingStatus.rawValue))")
                    }
                }
            } catch {
                print("检查书籍失败: \(error)")
            }
        }
    }
}