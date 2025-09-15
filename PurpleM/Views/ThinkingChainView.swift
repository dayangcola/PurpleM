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
    
    let streamContent: String
    private let parser = ThinkingChainParser()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 思考过程
            if showThinking && !thinkingText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain")
                            .font(.caption)
                        Text("思考中...")
                            .font(.caption)
                    }
                    .foregroundColor(.purple.opacity(0.7))
                    
                    Text(thinkingText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.05))
                        )
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
    
    private func parseStreamContent(_ content: String) {
        let result = parser.parse(content)
        
        if let thinking = result.thinking {
            thinkingText = thinking
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