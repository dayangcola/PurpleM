//
//  ThinkingChainParser.swift
//  PurpleM
//
//  思维链解析器 - 解析AI响应中的思考过程和答案
//

import Foundation

// MARK: - 思维链解析器
class ThinkingChainParser {
    private var currentThinking = ""
    private var currentAnswer = ""
    private var inThinkingBlock = false
    private var inAnswerBlock = false
    
    // 思考深度分析
    private var thinkingDepth: ThinkingDepth = .basic
    private var thinkingSections: [String: String] = [:]
    
    enum ThinkingDepth {
        case basic      // 基础思考
        case structured // 结构化思考（包含多个部分）
        case deep       // 深度思考（包含完整的分析框架）
    }
    
    func parse(_ chunk: String) -> (thinking: String?, answer: String?) {
        var newThinking: String? = nil
        var newAnswer: String? = nil
        
        // 检查思考块开始
        if chunk.contains("<thinking>") {
            inThinkingBlock = true
            inAnswerBlock = false
            let parts = chunk.components(separatedBy: "<thinking>")
            if parts.count > 1 {
                currentThinking = parts[1]
                if currentThinking.contains("</thinking>") {
                    let endParts = currentThinking.components(separatedBy: "</thinking>")
                    currentThinking = endParts[0]
                    inThinkingBlock = false
                    newThinking = currentThinking
                    
                    // 检查是否紧接着有答案
                    if endParts.count > 1 {
                        let result = parse(endParts[1])
                        return (newThinking, result.answer)
                    }
                }
            }
        }
        // 检查思考块结束
        else if inThinkingBlock && chunk.contains("</thinking>") {
            let parts = chunk.components(separatedBy: "</thinking>")
            currentThinking += parts[0]
            inThinkingBlock = false
            newThinking = currentThinking
            
            // 继续解析剩余部分
            if parts.count > 1 {
                let remainingResult = parse(parts[1])
                return (newThinking, remainingResult.answer)
            }
        }
        // 检查答案块开始
        else if chunk.contains("<answer>") {
            inAnswerBlock = true
            inThinkingBlock = false
            let parts = chunk.components(separatedBy: "<answer>")
            if parts.count > 1 {
                currentAnswer = parts[1]
                if currentAnswer.contains("</answer>") {
                    let endParts = currentAnswer.components(separatedBy: "</answer>")
                    currentAnswer = endParts[0]
                    inAnswerBlock = false
                    newAnswer = currentAnswer
                }
            }
        }
        // 检查答案块结束
        else if inAnswerBlock && chunk.contains("</answer>") {
            let parts = chunk.components(separatedBy: "</answer>")
            currentAnswer += parts[0]
            inAnswerBlock = false
            newAnswer = currentAnswer
        }
        // 继续累积内容
        else if inThinkingBlock {
            currentThinking += chunk
        } else if inAnswerBlock {
            currentAnswer += chunk
        } else {
            // 如果不在任何块中，可能是普通内容，当作答案处理
            currentAnswer += chunk
            newAnswer = chunk
        }
        
        return (newThinking, newAnswer)
    }
    
    func getFullContent() -> (thinking: String, answer: String) {
        return (currentThinking, currentAnswer)
    }
    
    func reset() {
        currentThinking = ""
        currentAnswer = ""
        inThinkingBlock = false
        inAnswerBlock = false
        thinkingDepth = .basic
        thinkingSections.removeAll()
    }
    
    // 分析思考内容的深度和结构
    func analyzeThinkingDepth(_ thinking: String) {
        let sections = ["【问题理解】", "【多维分析】", "【逻辑推理】", "【潜在影响】", "【最佳方案】"]
        var foundSections = 0
        
        for section in sections {
            if thinking.contains(section) {
                foundSections += 1
                // 提取该部分的内容
                if let range = thinking.range(of: section) {
                    let startIndex = range.upperBound
                    var endIndex = thinking.endIndex
                    
                    // 找到下一个section或结束
                    for nextSection in sections {
                        if nextSection != section,
                           let nextRange = thinking.range(of: nextSection, range: startIndex..<thinking.endIndex) {
                            endIndex = min(endIndex, nextRange.lowerBound)
                        }
                    }
                    
                    let content = String(thinking[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    thinkingSections[section] = content
                }
            }
        }
        
        // 根据找到的部分数量判断思考深度
        if foundSections >= 4 {
            thinkingDepth = .deep
        } else if foundSections >= 2 {
            thinkingDepth = .structured
        } else {
            thinkingDepth = .basic
        }
    }
    
    // 获取思考深度信息
    func getThinkingAnalysis() -> (depth: ThinkingDepth, sections: [String: String]) {
        return (thinkingDepth, thinkingSections)
    }
}