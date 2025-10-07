//
//  PDFProcessor.swift
//  PurpleM
//
//  PDF文档处理器 - 负责文本提取和OCR识别
//

import Foundation
import PDFKit
import Vision
import VisionKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - PDF处理器
class PDFProcessor: ObservableObject {
    
    // MARK: - 处理状态
    enum ProcessingStatus {
        case idle
        case extracting(page: Int, total: Int)
        case performing_ocr(page: Int, total: Int)
        case completed
        case failed(Error)
    }
    
    // MARK: - PDF类型
    enum PDFType {
        case searchable    // 可搜索的PDF（包含文本层）
        case scanned      // 扫描版PDF（纯图片）
        case mixed        // 混合型（部分页面有文本）
    }
    
    // MARK: - 处理错误
    enum ProcessingError: LocalizedError {
        case fileNotFound
        case invalidPDF
        case extractionFailed
        case ocrFailed
        case pageLimitExceeded
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound: return "PDF文件未找到"
            case .invalidPDF: return "无效的PDF文件"
            case .extractionFailed: return "文本提取失败"
            case .ocrFailed: return "OCR识别失败"
            case .pageLimitExceeded: return "页数超过限制"
            }
        }
    }
    
    // MARK: - 属性
    @Published var status: ProcessingStatus = .idle
    @Published var progressPercentage: Double = 0
    
    private let maxPagesLimit = 500  // 最大页数限制
    private let ocrQueue = DispatchQueue(label: "com.purplem.ocr", qos: .userInitiated)
    
    // MARK: - 主处理方法
    func processDocument(at url: URL) async throws -> PDFDocumentInfo {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProcessingError.fileNotFound
        }
        
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ProcessingError.invalidPDF
        }
        
        let pageCount = pdfDocument.pageCount
        guard pageCount <= maxPagesLimit else {
            throw ProcessingError.pageLimitExceeded
        }
        
        // 检测PDF类型
        let pdfType = detectPDFType(pdfDocument)
        print("📄 PDF类型: \(pdfType), 页数: \(pageCount)")
        
        return PDFDocumentInfo(
            document: pdfDocument,
            type: pdfType,
            extractedPages: []
        )
    }
    
    // MARK: - 提取所有文本
    func extractAllText(from document: PDFDocumentInfo) async throws -> [PageContent] {
        var pages: [PageContent] = []
        let pageCount = document.document.pageCount
        
        for pageIndex in 0..<pageCount {
            await MainActor.run {
                self.status = .extracting(page: pageIndex + 1, total: pageCount)
                self.progressPercentage = Double(pageIndex) / Double(pageCount) * 100
            }
            
            guard let page = document.document.page(at: pageIndex) else { continue }
            
            // 尝试直接提取文本
            var text = page.string ?? ""
            
            // 如果文本为空或太短，使用OCR
            if text.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
                text = try await performOCR(on: page, pageIndex: pageIndex)
            }
            
            // 提取页面元数据
            let pageContent = PageContent(
                pageNumber: pageIndex + 1,
                text: text,
                extractionMethod: text.isEmpty ? .ocr : .direct
            )
            
            pages.append(pageContent)
        }
        
        await MainActor.run {
            self.status = .completed
            self.progressPercentage = 100
        }
        
        return pages
    }
    
    // MARK: - 检测PDF类型
    private func detectPDFType(_ document: PDFKit.PDFDocument) -> PDFType {
        let sampleSize = min(5, document.pageCount)  // 采样前5页
        var hasText = 0
        var noText = 0
        
        for i in 0..<sampleSize {
            guard let page = document.page(at: i) else { continue }
            let text = page.string ?? ""
            
            if text.trimmingCharacters(in: .whitespacesAndNewlines).count > 10 {
                hasText += 1
            } else {
                noText += 1
            }
        }
        
        if hasText > 0 && noText == 0 {
            return .searchable
        } else if hasText == 0 && noText > 0 {
            return .scanned
        } else {
            return .mixed
        }
    }
    
    // MARK: - OCR处理
    private func performOCR(on page: PDFPage, pageIndex: Int) async throws -> String {
        await MainActor.run {
            self.status = .performing_ocr(page: pageIndex + 1, total: 1)
        }
        
        // 将PDF页面转换为图像
        guard let image = pageToImage(page) else {
            throw ProcessingError.ocrFailed
        }
        
        // 创建Vision请求
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                // 提取识别的文本
                let recognizedText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            // 配置请求
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]  // 支持简体、繁体中文和英文
            request.usesLanguageCorrection = true
            
            // 执行请求
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            
            ocrQueue.async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - PDF页面转图像
    private func pageToImage(_ page: PDFPage) -> CGImage? {
        let pageRect = page.bounds(for: .mediaBox)
        
        // 提高分辨率以改善OCR效果
        let scale: CGFloat = 2.0
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )
        
        // 创建图像上下文
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return image.cgImage
    }
    
    // MARK: - 章节检测
    func detectChapters(in text: String) -> [ChapterInfo] {
        var chapters: [ChapterInfo] = []
        
        // 章节标题正则表达式模式
        let patterns = [
            "第[一二三四五六七八九十百千万零0-9]+[章节篇回].*",
            "Chapter\\s+\\d+.*",
            "[一二三四五六七八九十]\\s*[、.．].*",
            "\\d+\\s*[、.．].*"
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(
                    in: text,
                    options: [],
                    range: NSRange(location: 0, length: text.utf16.count)
                )
                
                for match in matches {
                    if let range = Range(match.range, in: text) {
                        let title = String(text[range])
                        let location = match.range.location
                        
                        chapters.append(ChapterInfo(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            startPosition: location,
                            pattern: pattern
                        ))
                    }
                }
            } catch {
                print("正则表达式错误: \(error)")
            }
        }
        
        // 按位置排序
        chapters.sort { $0.startPosition < $1.startPosition }
        
        return chapters
    }
}

// MARK: - 数据模型
extension PDFProcessor {
    
    // PDF文档包装
    struct PDFDocumentInfo {
        let document: PDFKit.PDFDocument
        let type: PDFType
        let extractedPages: [PageContent]
    }
    
    // 页面内容
    struct PageContent {
        let pageNumber: Int
        let text: String
        let extractionMethod: ExtractionMethod
        
        enum ExtractionMethod {
            case direct  // 直接提取
            case ocr    // OCR识别
        }
    }
    
    // 章节信息
    struct ChapterInfo {
        let title: String
        let startPosition: Int
        let pattern: String
    }
}

// MARK: - 批处理扩展
extension PDFProcessor {
    
    /// 批量处理多个PDF文件
    func batchProcess(_ urls: [URL]) async -> [URL: Result<PDFDocumentInfo, Error>] {
        var results: [URL: Result<PDFDocumentInfo, Error>] = [:]
        
        for url in urls {
            do {
                let document = try await processDocument(at: url)
                results[url] = .success(document)
            } catch {
                results[url] = .failure(error)
            }
        }
        
        return results
    }
    
    /// 估算处理时间
    func estimateProcessingTime(pageCount: Int, pdfType: PDFType) -> TimeInterval {
        let baseTimePerPage: TimeInterval
        
        switch pdfType {
        case .searchable:
            baseTimePerPage = 0.1  // 0.1秒/页（直接提取）
        case .scanned:
            baseTimePerPage = 2.0  // 2秒/页（OCR）
        case .mixed:
            baseTimePerPage = 1.0  // 1秒/页（混合）
        }
        
        return Double(pageCount) * baseTimePerPage
    }
}