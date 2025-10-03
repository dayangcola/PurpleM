//
//  ThinkingChainView.swift
//  PurpleM
//
//  思维链显示组件 - 展示AI的思考过程
//

import SwiftUI

// MARK: - 思维链消息结构
struct ThinkingChainMessage {
    let id = UUID()
    var thinkingContent: String = ""
    var answerContent: String = ""
    var isThinkingVisible: Bool = true
    var showingThinking: Bool = false
    var isComplete: Bool = false
}

// MARK: - 思维链显示视图
struct ThinkingChainView: View {
    let message: ThinkingChainMessage
    @State private var thinkingOpacity: Double = 1.0
    @State private var answerOpacity: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 思考过程显示
            if message.showingThinking && !message.thinkingContent.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain")
                            .font(.caption)
                            .foregroundColor(.purple.opacity(0.7))
                        Text("思考中...")
                            .font(.caption)
                            .foregroundColor(.purple.opacity(0.7))
                    }
                    
                    Text(message.thinkingContent)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
                .opacity(thinkingOpacity)
                .animation(.easeInOut(duration: 0.5), value: thinkingOpacity)
            }
            
            // 最终答案显示
            if !message.answerContent.isEmpty {
                Text(message.answerContent)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .opacity(answerOpacity)
                    .animation(.easeIn(duration: 0.3).delay(0.2), value: answerOpacity)
            }
        }
        .onAppear {
            if message.isComplete {
                // 延迟后淡出思考内容
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 1.0)) {
                        thinkingOpacity = 0.0
                    }
                    withAnimation(.easeIn(duration: 0.5).delay(0.5)) {
                        answerOpacity = 1.0
                    }
                }
            }
        }
    }
}

// 注意：ThinkingChainParser已移至Models/ThinkingChainParser.swift

// MARK: - 流式思维链消息视图
struct StreamingThinkingChainView: View {
    @State private var thinkingText = ""
    @State private var answerText = ""
    @State private var showThinking = true
    @State private var thinkingOpacity = 1.0
    @State private var thinkingDepth: ThinkingChainParser.ThinkingDepth = .basic
    @State private var thinkingSections: [String: String] = [:]
    @State private var expandedSections: Set<String> = []
    
    let streamContent: String
    private let parser = ThinkingChainParser()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 思考过程
            if showThinking && !thinkingText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: depthIcon)
                            .font(.caption)
                            .symbolEffect(.pulse, options: .repeating)
                        Text(depthText)
                            .font(.caption)
                        Spacer()
                        if thinkingDepth == .deep {
                            Label("\(thinkingSections.count)个维度", systemImage: "chart.xyaxis.line")
                                .font(.caption2)
                                .foregroundColor(.purple.opacity(0.5))
                        }
                    }
                    .foregroundColor(depthColor)
                    
                    // 根据深度显示不同的UI
                    if thinkingDepth == .deep || thinkingDepth == .structured {
                        // 结构化显示
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(thinkingSections.keys.sorted()), id: \.self) { section in
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { expandedSections.contains(section) },
                                        set: { isExpanded in
                                            if isExpanded {
                                                expandedSections.insert(section)
                                            } else {
                                                expandedSections.remove(section)
                                            }
                                        }
                                    )
                                ) {
                                    Text(thinkingSections[section] ?? "")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary.opacity(0.7))
                                        .padding(8)
                                } label: {
                                    Text(section)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.purple.opacity(0.8))
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.purple.opacity(0.03))
                                )
                            }
                        }
                    } else {
                        // 基础显示
                        Text(thinkingText)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.8))
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple.opacity(0.05))
                            )
                    }
                }
                .opacity(thinkingOpacity)
            }
            
            // 答案内容
            if !answerText.isEmpty {
                Text(answerText)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: streamContent) { newValue in
            parseStreamContent(newValue)
        }
    }
    
    // 计算属性
    private var depthIcon: String {
        switch thinkingDepth {
        case .basic:
            return "brain"
        case .structured:
            return "brain.head.profile"
        case .deep:
            return "sparkles.rectangle.stack"
        }
    }
    
    private var depthText: String {
        switch thinkingDepth {
        case .basic:
            return "思考中..."
        case .structured:
            return "结构化分析中..."
        case .deep:
            return "深度思考中..."
        }
    }
    
    private var depthColor: Color {
        switch thinkingDepth {
        case .basic:
            return .purple.opacity(0.7)
        case .structured:
            return .indigo.opacity(0.8)
        case .deep:
            return .blue.opacity(0.9)
        }
    }
    
    private func parseStreamContent(_ content: String) {
        let result = parser.parse(content)
        
        if let thinking = result.thinking {
            thinkingText = thinking
            // 分析思考深度
            parser.analyzeThinkingDepth(thinking)
            let analysis = parser.getThinkingAnalysis()
            thinkingDepth = analysis.depth
            thinkingSections = analysis.sections
            
            // 深度思考时自动展开前两个部分
            if thinkingDepth == .deep && expandedSections.isEmpty {
                let sortedKeys = Array(thinkingSections.keys.sorted())
                if sortedKeys.count > 0 {
                    expandedSections.insert(sortedKeys[0])
                }
                if sortedKeys.count > 1 {
                    expandedSections.insert(sortedKeys[1])
                }
            }
        }
        
        if let answer = result.answer {
            answerText += answer
            
            // 当开始接收答案时，淡出思考内容
            if !answer.isEmpty && showThinking {
                withAnimation(.easeOut(duration: 1.0).delay(1.0)) {
                    thinkingOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showThinking = false
                }
            }
        }
    }
}