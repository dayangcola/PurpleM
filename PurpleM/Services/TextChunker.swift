//
//  TextChunker.swift
//  PurpleM
//
//  智能文本分块器 - 将长文本分割成适合向量化的块
//

import Foundation

// MARK: - 文本分块器
class TextChunker {
    
    // MARK: - 配置
    struct Configuration {
        let maxChunkSize: Int          // 最大块大小（字符数）
        let overlapSize: Int           // 块之间重叠大小
        let minChunkSize: Int          // 最小块大小
        let preserveParagraphs: Bool   // 是否保持段落完整
        let preserveSentences: Bool    // 是否保持句子完整
        
        static let `default` = Configuration(
            maxChunkSize: 1000,
            overlapSize: 100,
            minChunkSize: 100,
            preserveParagraphs: true,
            preserveSentences: true
        )
        
        static let aggressive = Configuration(
            maxChunkSize: 500,
            overlapSize: 50,
            minChunkSize: 50,
            preserveParagraphs: false,
            preserveSentences: true
        )
        
        static let conservative = Configuration(
            maxChunkSize: 1500,
            overlapSize: 200,
            minChunkSize: 200,
            preserveParagraphs: true,
            preserveSentences: true
        )
    }
    
    // MARK: - 分块结果
    struct ChunkResult {
        let chunks: [TextChunk]
        let metadata: ChunkingMetadata
    }
    
    struct TextChunk {
        let content: String
        let index: Int                 // 块索引
        let startPosition: Int         // 在原文中的起始位置
        let endPosition: Int           // 在原文中的结束位置
        let chapter: String?           // 所属章节
        let section: String?           // 所属小节
        let pageNumber: Int?           // 页码
        let isComplete: Bool           // 是否是完整的语义单元
    }
    
    struct ChunkingMetadata {
        let totalChunks: Int
        let averageChunkSize: Int
        let processingTime: TimeInterval
        let method: ChunkingMethod
    }
    
    enum ChunkingMethod {
        case bySize         // 按大小分块
        case bySemantic     // 按语义分块
        case byChapter      // 按章节分块
        case hybrid         // 混合方法
    }
    
    // MARK: - 属性
    private let configuration: Configuration
    private let chineseTermDictionary: Set<String>  // 紫微斗数专业术语词典
    
    // MARK: - 初始化
    init(configuration: Configuration = .default) {
        self.configuration = configuration
        
        // 初始化专业术语词典
        self.chineseTermDictionary = Self.loadTermDictionary()
    }
    
    // MARK: - 主要分块方法
    
    /// 智能分块 - 自动选择最佳策略
    func chunk(
        text: String,
        chapters: [PDFProcessor.ChapterInfo]? = nil,
        pageBreaks: [Int]? = nil
    ) -> ChunkResult {
        let startTime = Date()
        
        // 预处理文本
        let processedText = preprocessText(text)
        
        // 选择分块策略
        let method: ChunkingMethod
        let chunks: [TextChunk]
        
        if let chapters = chapters, !chapters.isEmpty {
            // 有章节信息，按章节分块
            method = .byChapter
            chunks = chunkByChapters(processedText, chapters: chapters)
        } else if detectSemanticStructure(processedText) {
            // 检测到语义结构，按语义分块
            method = .bySemantic
            chunks = chunkBySemantic(processedText)
        } else {
            // 默认按大小分块
            method = .bySize
            chunks = chunkBySize(processedText)
        }
        
        // 后处理：添加重叠
        let finalChunks = addOverlap(to: chunks, originalText: processedText)
        
        // 计算元数据
        let metadata = ChunkingMetadata(
            totalChunks: finalChunks.count,
            averageChunkSize: finalChunks.map { $0.content.count }.reduce(0, +) / max(finalChunks.count, 1),
            processingTime: Date().timeIntervalSince(startTime),
            method: method
        )
        
        return ChunkResult(chunks: finalChunks, metadata: metadata)
    }
    
    // MARK: - 按大小分块
    private func chunkBySize(_ text: String) -> [TextChunk] {
        var chunks: [TextChunk] = []
        var currentPosition = 0
        var chunkIndex = 0
        
        while currentPosition < text.count {
            let startPos = currentPosition
            var endPos = min(currentPosition + configuration.maxChunkSize, text.count)
            
            // 如果需要保持句子完整
            if configuration.preserveSentences && endPos < text.count {
                endPos = findSentenceBoundary(in: text, near: endPos)
            }
            
            // 如果需要保持段落完整
            if configuration.preserveParagraphs && endPos < text.count {
                endPos = findParagraphBoundary(in: text, near: endPos)
            }
            
            // 提取块内容
            let startIndex = text.index(text.startIndex, offsetBy: startPos)
            let endIndex = text.index(text.startIndex, offsetBy: endPos)
            let content = String(text[startIndex..<endIndex])
            
            // 跳过太小的块
            if content.count >= configuration.minChunkSize {
                chunks.append(TextChunk(
                    content: content,
                    index: chunkIndex,
                    startPosition: startPos,
                    endPosition: endPos,
                    chapter: nil,
                    section: nil,
                    pageNumber: nil,
                    isComplete: true
                ))
                chunkIndex += 1
            }
            
            currentPosition = endPos
        }
        
        return chunks
    }
    
    // MARK: - 按语义分块
    private func chunkBySemantic(_ text: String) -> [TextChunk] {
        var chunks: [TextChunk] = []
        
        // 分割成段落
        let paragraphs = text.components(separatedBy: "\n\n")
        var currentChunk = ""
        var chunkIndex = 0
        var currentPosition = 0
        
        for paragraph in paragraphs {
            let trimmedParagraph = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 如果段落本身就超过最大大小，需要进一步分割
            if trimmedParagraph.count > configuration.maxChunkSize {
                // 保存当前块
                if !currentChunk.isEmpty {
                    chunks.append(createChunk(
                        content: currentChunk,
                        index: chunkIndex,
                        startPosition: currentPosition - currentChunk.count,
                        endPosition: currentPosition
                    ))
                    chunkIndex += 1
                    currentChunk = ""
                }
                
                // 分割大段落
                let subChunks = splitLargeParagraph(trimmedParagraph)
                for subChunk in subChunks {
                    chunks.append(createChunk(
                        content: subChunk,
                        index: chunkIndex,
                        startPosition: currentPosition,
                        endPosition: currentPosition + subChunk.count
                    ))
                    chunkIndex += 1
                    currentPosition += subChunk.count
                }
            } else if currentChunk.count + trimmedParagraph.count > configuration.maxChunkSize {
                // 当前块加上新段落会超过限制，保存当前块
                if !currentChunk.isEmpty {
                    chunks.append(createChunk(
                        content: currentChunk,
                        index: chunkIndex,
                        startPosition: currentPosition - currentChunk.count,
                        endPosition: currentPosition
                    ))
                    chunkIndex += 1
                }
                currentChunk = trimmedParagraph
                currentPosition += trimmedParagraph.count
            } else {
                // 添加到当前块
                if !currentChunk.isEmpty {
                    currentChunk += "\n\n"
                }
                currentChunk += trimmedParagraph
                currentPosition += trimmedParagraph.count + 2
            }
        }
        
        // 保存最后的块
        if !currentChunk.isEmpty {
            chunks.append(createChunk(
                content: currentChunk,
                index: chunkIndex,
                startPosition: currentPosition - currentChunk.count,
                endPosition: currentPosition
            ))
        }
        
        return chunks
    }
    
    // MARK: - 按章节分块
    private func chunkByChapters(_ text: String, chapters: [PDFProcessor.ChapterInfo]) -> [TextChunk] {
        var chunks: [TextChunk] = []
        var chunkIndex = 0
        
        for (index, chapter) in chapters.enumerated() {
            let startPos = chapter.startPosition
            let endPos = index < chapters.count - 1 ? chapters[index + 1].startPosition : text.count
            
            let startIndex = text.index(text.startIndex, offsetBy: startPos)
            let endIndex = text.index(text.startIndex, offsetBy: min(endPos, text.count))
            let chapterContent = String(text[startIndex..<endIndex])
            
            // 如果章节内容太大，进一步分割
            if chapterContent.count > configuration.maxChunkSize {
                let subChunks = chunkBySize(chapterContent)
                for subChunk in subChunks {
                    chunks.append(TextChunk(
                        content: subChunk.content,
                        index: chunkIndex,
                        startPosition: startPos + subChunk.startPosition,
                        endPosition: startPos + subChunk.endPosition,
                        chapter: chapter.title,
                        section: nil,
                        pageNumber: nil,
                        isComplete: subChunk.isComplete
                    ))
                    chunkIndex += 1
                }
            } else {
                chunks.append(TextChunk(
                    content: chapterContent,
                    index: chunkIndex,
                    startPosition: startPos,
                    endPosition: endPos,
                    chapter: chapter.title,
                    section: nil,
                    pageNumber: nil,
                    isComplete: true
                ))
                chunkIndex += 1
            }
        }
        
        return chunks
    }
    
    // MARK: - 辅助方法
    
    private func preprocessText(_ text: String) -> String {
        var processed = text
        
        // 标准化换行符
        processed = processed.replacingOccurrences(of: "\r\n", with: "\n")
        processed = processed.replacingOccurrences(of: "\r", with: "\n")
        
        // 移除多余空白
        processed = processed.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
        processed = processed.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        return processed
    }
    
    private func detectSemanticStructure(_ text: String) -> Bool {
        // 检查是否有明显的语义结构（标题、列表等）
        let patterns = [
            "^[一二三四五六七八九十]+[、.]",
            "^\\d+[、.]",
            "^第.+[章节篇]",
            "^[【《].+[】》]"
        ]
        
        for pattern in patterns {
            if let _ = text.range(of: pattern, options: .regularExpression) {
                return true
            }
        }
        
        return false
    }
    
    private func findSentenceBoundary(in text: String, near position: Int) -> Int {
        // 查找最近的句子边界
        let sentenceEnders = ["。", "！", "？", ".", "!", "?"]
        
        // 向前查找最近的句子结束符
        var searchPos = position
        while searchPos > max(position - 100, 0) {
            let index = text.index(text.startIndex, offsetBy: searchPos)
            let char = String(text[index])
            
            if sentenceEnders.contains(char) {
                return searchPos + 1
            }
            searchPos -= 1
        }
        
        return position
    }
    
    private func findParagraphBoundary(in text: String, near position: Int) -> Int {
        // 查找最近的段落边界
        var searchPos = position
        
        while searchPos > max(position - 200, 0) {
            let index = text.index(text.startIndex, offsetBy: searchPos)
            if text[index] == "\n" {
                return searchPos
            }
            searchPos -= 1
        }
        
        return position
    }
    
    private func splitLargeParagraph(_ paragraph: String) -> [String] {
        // 分割大段落
        var result: [String] = []
        var current = ""
        
        // 先尝试按句子分割
        let sentences = paragraph.components(separatedBy: CharacterSet(charactersIn: "。！？.!?"))
        
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if current.count + trimmed.count > configuration.maxChunkSize {
                if !current.isEmpty {
                    result.append(current)
                }
                current = trimmed
            } else {
                if !current.isEmpty {
                    current += "。"
                }
                current += trimmed
            }
        }
        
        if !current.isEmpty {
            result.append(current)
        }
        
        return result
    }
    
    private func addOverlap(to chunks: [TextChunk], originalText: String) -> [TextChunk] {
        guard configuration.overlapSize > 0, chunks.count > 1 else {
            return chunks
        }
        
        var overlappedChunks: [TextChunk] = []
        
        for (index, chunk) in chunks.enumerated() {
            var content = chunk.content
            
            // 添加前一块的结尾作为重叠
            if index > 0 {
                let prevChunk = chunks[index - 1]
                let overlapStart = max(prevChunk.content.count - configuration.overlapSize, 0)
                let overlapContent = String(prevChunk.content.suffix(configuration.overlapSize))
                content = overlapContent + "\n[...]\n" + content
            }
            
            // 添加后一块的开头作为重叠
            if index < chunks.count - 1 {
                let nextChunk = chunks[index + 1]
                let overlapContent = String(nextChunk.content.prefix(configuration.overlapSize))
                content = content + "\n[...]\n" + overlapContent
            }
            
            overlappedChunks.append(TextChunk(
                content: content,
                index: chunk.index,
                startPosition: chunk.startPosition,
                endPosition: chunk.endPosition,
                chapter: chunk.chapter,
                section: chunk.section,
                pageNumber: chunk.pageNumber,
                isComplete: chunk.isComplete
            ))
        }
        
        return overlappedChunks
    }
    
    private func createChunk(
        content: String,
        index: Int,
        startPosition: Int,
        endPosition: Int
    ) -> TextChunk {
        return TextChunk(
            content: content,
            index: index,
            startPosition: startPosition,
            endPosition: endPosition,
            chapter: nil,
            section: nil,
            pageNumber: nil,
            isComplete: true
        )
    }
    
    // MARK: - 专业术语词典
    private static func loadTermDictionary() -> Set<String> {
        // 紫微斗数专业术语
        return Set([
            "紫微星", "天机星", "太阳星", "武曲星", "天同星", "廉贞星",
            "天府星", "太阴星", "贪狼星", "巨门星", "天相星", "天梁星",
            "七杀星", "破军星", "文昌", "文曲", "左辅", "右弼",
            "天魁", "天钺", "火星", "铃星", "地空", "地劫",
            "命宫", "兄弟宫", "夫妻宫", "子女宫", "财帛宫", "疾厄宫",
            "迁移宫", "交友宫", "官禄宫", "田宅宫", "福德宫", "父母宫",
            "化禄", "化权", "化科", "化忌", "大运", "流年", "流月", "流日",
            "三方四正", "对宫", "会照", "同宫", "庙旺", "落陷", "得地", "平和"
        ])
    }
}