//
//  EnhancedChatComponents.swift
//  PurpleM
//
//  增强的聊天界面组件
//  支持知识引用显示和交互
//

import SwiftUI

// MARK: - 增强的聊天消息气泡
struct EnhancedChatBubble: View {
    let message: ChatMessage
    let knowledgeRefs: [KnowledgeManager.KnowledgeReference]
    @State private var showingReferences = false
    @State private var expandedRef: Int? = nil
    
    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            // 消息内容
            MessageContent(
                text: message.content,
                isUser: message.role == .user,
                knowledgeRefs: knowledgeRefs
            )
            
            // 知识引用标签
            if !knowledgeRefs.isEmpty && message.role == .assistant {
                KnowledgeReferenceTags(
                    references: knowledgeRefs,
                    showingReferences: $showingReferences,
                    expandedRef: $expandedRef
                )
            }
            
            // 消息元数据
            MessageMetadata(message: message)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingReferences) {
            KnowledgeReferenceSheet(
                references: knowledgeRefs,
                expandedRef: $expandedRef
            )
        }
    }
}

// MARK: - 消息内容视图
struct MessageContent: View {
    let text: String
    let isUser: Bool
    let knowledgeRefs: [KnowledgeManager.KnowledgeReference]
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: .leading, spacing: 4) {
                // 处理带引用标记的文本
                FormattedTextView(
                    text: text,
                    knowledgeRefs: knowledgeRefs
                )
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isUser ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundColor(isUser ? .white : .primary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isUser ? .trailing : .leading)
            
            if !isUser { Spacer() }
        }
    }
}

// MARK: - 格式化文本视图（支持引用高亮）
struct FormattedTextView: View {
    let text: String
    let knowledgeRefs: [KnowledgeManager.KnowledgeReference]
    
    var body: some View {
        let parts = parseTextWithReferences(text)
        
        Text(parts.map { part in
            if part.isReference {
                return Text("[\(part.content)]")
                    .foregroundColor(.yellow)
                    .fontWeight(.bold)
            } else {
                return Text(part.content)
            }
        }.reduce(Text(""), +))
    }
    
    private func parseTextWithReferences(_ text: String) -> [(content: String, isReference: Bool)] {
        var parts: [(String, Bool)] = []
        var currentText = ""
        var i = text.startIndex
        
        while i < text.endIndex {
            if text[i] == "[" {
                // 检查是否是引用标记 [1], [2], etc.
                let remaining = String(text[i...])
                if let match = remaining.firstMatch(of: /\[(\d+)\]/) {
                    // 保存之前的文本
                    if !currentText.isEmpty {
                        parts.append((currentText, false))
                        currentText = ""
                    }
                    // 添加引用
                    parts.append((String(match.1), true))
                    // 移动索引
                    i = text.index(i, offsetBy: match.0.count)
                    continue
                }
            }
            
            currentText.append(text[i])
            i = text.index(after: i)
        }
        
        if !currentText.isEmpty {
            parts.append((currentText, false))
        }
        
        return parts
    }
}

// MARK: - 知识引用标签
struct KnowledgeReferenceTags: View {
    let references: [KnowledgeManager.KnowledgeReference]
    @Binding var showingReferences: Bool
    @Binding var expandedRef: Int?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 引用按钮
                Button(action: {
                    showingReferences = true
                }) {
                    Label("参考资料", systemImage: "book.fill")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
                
                // 引用标签
                ForEach(references) { ref in
                    ReferenceTag(
                        reference: ref,
                        isExpanded: expandedRef == ref.number,
                        onTap: {
                            withAnimation {
                                expandedRef = expandedRef == ref.number ? nil : ref.number
                            }
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - 单个引用标签
struct ReferenceTag: View {
    let reference: KnowledgeManager.KnowledgeReference
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(reference.formatted)
                    .font(.caption2)
                    .fontWeight(.medium)
                
                if isExpanded {
                    Text(reference.citation)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isExpanded ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 消息元数据
struct MessageMetadata: View {
    let message: ChatMessage
    @State private var showTimestamp = false
    
    var body: some View {
        HStack(spacing: 4) {
            if message.role == .user {
                Spacer()
            }
            
            // 时间戳
            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.gray)
                .opacity(showTimestamp ? 1 : 0)
            
            // 状态图标
            if message.role == .assistant {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
        .onTapGesture {
            withAnimation {
                showTimestamp.toggle()
            }
        }
    }
}

// MARK: - 知识引用详情弹窗
struct KnowledgeReferenceSheet: View {
    let references: [KnowledgeManager.KnowledgeReference]
    @Binding var expandedRef: Int?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(references) { ref in
                VStack(alignment: .leading, spacing: 12) {
                    // 引用标题
                    HStack {
                        Text("[\(ref.number)]")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text(ref.citation)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        if ref.score > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Text("\(Int(ref.score * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // 内容预览
                    Text(String(ref.content.prefix(300)))
                        .font(.body)
                        .lineLimit(expandedRef == ref.number ? nil : 3)
                    
                    // 展开/收起按钮
                    Button(action: {
                        withAnimation {
                            expandedRef = expandedRef == ref.number ? nil : ref.number
                        }
                    }) {
                        Text(expandedRef == ref.number ? "收起" : "展开全文")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("📚 参考资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 智能输入建议
struct SmartInputSuggestions: View {
    @ObservedObject var knowledgeManager = KnowledgeManager.shared
    let currentInput: String
    let onSelect: (String) -> Void
    
    var suggestions: [String] {
        if currentInput.isEmpty {
            return knowledgeManager.hotTopics
        } else {
            return knowledgeManager.getRecommendedQueries(basedOn: currentInput)
        }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: {
                        onSelect(suggestion)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                            
                            Text(suggestion)
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - 知识加载指示器
struct KnowledgeLoadingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.purple)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
            
            Text("正在搜索知识库...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - 使用示例
struct EnhancedChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var knowledgeRefs: [UUID: [KnowledgeManager.KnowledgeReference]] = [:]
    @State private var inputText = ""
    @State private var isSearchingKnowledge = false
    
    var body: some View {
        VStack {
            // 消息列表
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        EnhancedChatBubble(
                            message: message,
                            knowledgeRefs: knowledgeRefs[message.id] ?? []
                        )
                    }
                    
                    if isSearchingKnowledge {
                        KnowledgeLoadingIndicator()
                    }
                }
                .padding()
            }
            
            // 智能输入建议
            SmartInputSuggestions(
                currentInput: inputText,
                onSelect: { suggestion in
                    inputText = suggestion
                }
            )
            
            // 输入区域
            HStack {
                TextField("问点什么...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .disabled(inputText.isEmpty || isSearchingKnowledge)
            }
            .padding()
        }
    }
    
    private func sendMessage() {
        // 实现发送消息逻辑
        let userMessage = ChatMessage(role: .user, content: inputText)
        messages.append(userMessage)
        
        Task {
            isSearchingKnowledge = true
            
            // 搜索知识库
            let (items, refs) = await KnowledgeManager.shared.searchWithContext(
                query: inputText,
                context: messages.suffix(5).map { $0.content }
            )
            
            // 调用AI生成回复
            // ...
            
            // 保存引用
            if let lastMessage = messages.last {
                knowledgeRefs[lastMessage.id] = refs
            }
            
            isSearchingKnowledge = false
        }
        
        inputText = ""
    }
}