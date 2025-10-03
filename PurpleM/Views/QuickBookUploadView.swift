//
//  QuickBookUploadView.swift
//  PurpleM
//
//  超简单的PDF上传界面 - 支持文件选择和拖放
//

import SwiftUI
import UniformTypeIdentifiers

struct QuickBookUploadView: View {
    @State private var selectedFile: URL?
    @State private var bookTitle = ""
    @State private var bookAuthor = ""
    @State private var isUploading = false
    @State private var uploadStatus = ""
    @State private var showFilePicker = false
    @State private var uploadProgress: Double = 0
    
    @StateObject private var uploader = KnowledgeUploader()
    
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            VStack(spacing: 30) {
                // 标题
                Text("📚 快速上传PDF书籍")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.crystalWhite)
                
                // 文件选择区域
                GlassmorphicCard {
                    VStack(spacing: 20) {
                        // 文件选择/拖放区域
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                            .foregroundColor(.starGold.opacity(0.5))
                            .frame(height: 150)
                            .overlay(
                                VStack(spacing: 10) {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.starGold.opacity(0.5))
                                    
                                    if let selectedFile = selectedFile {
                                        Text(selectedFile.lastPathComponent)
                                            .font(.headline)
                                            .foregroundColor(.crystalWhite)
                                    } else {
                                        Text("点击选择PDF文件")
                                            .foregroundColor(.moonSilver)
                                    }
                                }
                            )
                            .onTapGesture {
                                showFilePicker = true
                            }
                        
                        // 书籍信息输入
                        VStack(alignment: .leading, spacing: 12) {
                            // 书名
                            HStack {
                                Text("书名:")
                                    .foregroundColor(.moonSilver)
                                    .frame(width: 60, alignment: .trailing)
                                
                                TextField("紫微斗数全书", text: $bookTitle)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            // 作者
                            HStack {
                                Text("作者:")
                                    .foregroundColor(.moonSilver)
                                    .frame(width: 60, alignment: .trailing)
                                
                                TextField("作者名", text: $bookAuthor)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        
                        // 上传按钮
                        Button(action: startUpload) {
                            HStack {
                                if isUploading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "icloud.and.arrow.up")
                                }
                                Text(isUploading ? "上传中..." : "开始上传")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.mysticPink, .starGold],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isUploading || selectedFile == nil || bookTitle.isEmpty)
                        
                        // 进度条
                        if isUploading {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(uploadStatus)
                                    .font(.caption)
                                    .foregroundColor(.moonSilver)
                                
                                ProgressView(value: uploadProgress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .starGold))
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: 500)
                .padding(.horizontal)
                
                // 快速测试按钮
                #if DEBUG
                Button("使用测试数据") {
                    fillTestData()
                }
                .foregroundColor(.starGold)
                #endif
                
                Spacer()
            }
            .padding(.top, 50)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedFile = url
                    // 自动填充书名
                    if bookTitle.isEmpty {
                        bookTitle = url.deletingPathExtension().lastPathComponent
                    }
                }
            case .failure(let error):
                print("选择文件失败: \(error)")
            }
        }
        .onReceive(uploader.$currentTask) { task in
            updateUploadStatus(task)
        }
    }
    
    // MARK: - 方法
    
    func startUpload() {
        guard let fileURL = selectedFile else { return }
        
        isUploading = true
        uploadStatus = "准备上传..."
        uploadProgress = 0
        
        // 确保能访问文件
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // 复制文件到临时目录
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileURL.lastPathComponent)
        
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: tempURL)
            
            // 添加到上传队列
            uploader.queueUpload(
                fileURL: tempURL,
                title: bookTitle,
                author: bookAuthor.isEmpty ? nil : bookAuthor,
                isPublic: false
            )
        } catch {
            uploadStatus = "错误: \(error.localizedDescription)"
            isUploading = false
        }
    }
    
    func updateUploadStatus(_ task: KnowledgeUploader.UploadTask?) {
        guard let task = task else {
            if isUploading {
                // 上传完成
                isUploading = false
                uploadStatus = "✅ 上传完成！"
                uploadProgress = 1.0
                
                // 清空表单
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    selectedFile = nil
                    bookTitle = ""
                    bookAuthor = ""
                    uploadStatus = ""
                    uploadProgress = 0
                }
            }
            return
        }
        
        switch task.status {
        case .idle:
            uploadStatus = "等待开始..."
            uploadProgress = 0
            
        case .uploadingFile(let progress):
            uploadStatus = "📤 上传文件中..."
            uploadProgress = progress * 0.2
            
        case .extractingText(let page, let total):
            uploadStatus = "📖 提取文本: \(page)/\(total)页"
            uploadProgress = 0.2 + (Double(page) / Double(max(total, 1))) * 0.2
            
        case .chunking(let progress):
            uploadStatus = "✂️ 智能分块处理..."
            uploadProgress = 0.4 + progress * 0.001
            
        case .generatingEmbeddings(let chunk, let total):
            uploadStatus = "🧮 生成向量: \(chunk)/\(total)"
            uploadProgress = 0.5 + (Double(chunk) / Double(max(total, 1))) * 0.4
            
        case .savingToDatabase(let progress):
            uploadStatus = "💾 保存到数据库..."
            uploadProgress = 0.9 + progress * 0.001
            
        case .completed(let bookId):
            uploadStatus = "✅ 成功！书籍ID: \(bookId.prefix(8))..."
            uploadProgress = 1.0
            isUploading = false
            
        case .failed(let error):
            uploadStatus = "❌ 失败: \(error.localizedDescription)"
            uploadProgress = 0
            isUploading = false
        }
    }
    
    #if DEBUG
    func fillTestData() {
        // 创建测试PDF
        let testContent = """
        紫微斗数测试内容
        
        第一章：基础概念
        紫微斗数是中国传统命理学...
        """
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).pdf")
        
        do {
            try testContent.write(to: tempURL, atomically: true, encoding: .utf8)
            selectedFile = tempURL
            bookTitle = "测试书籍 - 紫微斗数"
            bookAuthor = "测试作者"
        } catch {
            print("创建测试文件失败: \(error)")
        }
    }
    #endif
}

// MARK: - 在主界面添加入口
struct BookUploadButton: View {
    @State private var showUploader = false
    
    var body: some View {
        Button(action: {
            showUploader = true
        }) {
            Label("上传PDF书籍", systemImage: "square.and.arrow.up")
        }
        .sheet(isPresented: $showUploader) {
            QuickBookUploadView()
        }
    }
}