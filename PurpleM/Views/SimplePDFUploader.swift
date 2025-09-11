//
//  SimplePDFUploader.swift
//  PurpleM
//
//  极简PDF上传器 - 一个按钮搞定所有
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 极简上传按钮（可以放在任何地方）
struct SimplePDFUploaderButton: View {
    @State private var showFilePicker = false
    @State private var isProcessing = false
    @State private var statusMessage = ""
    @StateObject private var uploader = KnowledgeUploader()
    
    var body: some View {
        VStack(spacing: 10) {
            // 上传按钮
            Button(action: {
                showFilePicker = true
            }) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up.fill")
                    }
                    Text(isProcessing ? "处理中..." : "上传PDF书籍")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.mysticPink, .starGold],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(25)
                .shadow(color: .mysticPink.opacity(0.3), radius: 5)
            }
            .disabled(isProcessing)
            
            // 状态信息
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.moonSilver)
                    .transition(.opacity)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .onReceive(uploader.$currentTask) { task in
            updateStatus(from: task)
        }
    }
    
    // MARK: - 处理文件选择
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            
            // 开始处理
            isProcessing = true
            statusMessage = "准备上传..."
            
            // 获取文件访问权限
            let accessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            
            // 复制到临时目录（避免权限问题）
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileURL.lastPathComponent)
            
            do {
                // 清理旧文件
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                
                // 复制文件
                try FileManager.default.copyItem(at: fileURL, to: tempURL)
                
                // 自动提取书名（从文件名）
                let bookTitle = fileURL.deletingPathExtension().lastPathComponent
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                
                // 添加到上传队列
                uploader.queueUpload(
                    fileURL: tempURL,
                    title: bookTitle,
                    author: nil,  // 可以让用户稍后补充
                    isPublic: false
                )
                
                print("📚 开始上传: \(bookTitle)")
                
            } catch {
                statusMessage = "❌ \(error.localizedDescription)"
                isProcessing = false
            }
            
        case .failure(let error):
            statusMessage = "❌ 选择文件失败"
            print("选择文件错误: \(error)")
        }
    }
    
    // MARK: - 更新状态
    private func updateStatus(from task: KnowledgeUploader.UploadTask?) {
        guard let task = task else {
            // 任务完成或没有任务
            if isProcessing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isProcessing = false
                    statusMessage = ""
                }
            }
            return
        }
        
        // 更新状态信息
        switch task.status {
        case .idle:
            statusMessage = "⏳ 等待..."
            
        case .uploadingFile(let progress):
            statusMessage = "📤 上传 \(Int(progress))%"
            
        case .extractingText(let page, let total):
            statusMessage = "📖 提取文本 \(page)/\(total)"
            
        case .chunking:
            statusMessage = "✂️ 智能分块..."
            
        case .generatingEmbeddings(let chunk, let total):
            statusMessage = "🧮 生成向量 \(chunk)/\(total)"
            
        case .savingToDatabase:
            statusMessage = "💾 保存数据..."
            
        case .completed:
            statusMessage = "✅ 上传成功！"
            isProcessing = false
            
        case .failed(let error):
            statusMessage = "❌ 失败: \(error.localizedDescription)"
            isProcessing = false
        }
    }
}

// MARK: - 超级简单的集成示例
struct PDFUploadTestView: View {
    var body: some View {
        VStack(spacing: 40) {
            Text("📚 知识库上传")
                .font(.largeTitle)
                .bold()
            
            Text("选择PDF文件上传到知识库")
                .foregroundColor(.gray)
            
            // 就这一个组件搞定一切！
            SimplePDFUploaderButton()
            
            Spacer()
        }
        .padding()
    }
}