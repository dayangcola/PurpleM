//
//  ChatTab.swift
//  PurpleM
//
//  Tab3: 聊天 - AI助手和智能问答
//

import SwiftUI

struct ChatTab: View {
    @StateObject private var aiService = AIService.shared
    @StateObject private var userDataManager = UserDataManager.shared
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                
                VStack(spacing: 0) {
                    // 顶部标题栏
                    HStack {
                        Image(systemName: "sparkles.tv")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.starGold, .mysticPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("星语助手")
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundColor(.crystalWhite)
                        
                        Spacer()
                        
                        Button(action: clearChat) {
                            Image(systemName: "arrow.counterclockwise.circle")
                                .foregroundColor(.moonSilver.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    
                    if messages.isEmpty {
                        // 欢迎页面
                        WelcomeMessageView(onQuestionTap: sendQuickQuestion)
                    } else {
                        // 聊天记录区域
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 15) {
                                    ForEach(messages) { message in
                                        ChatBubble(message: message)
                                            .id(message.id)
                                    }
                                    
                                    if isTyping {
                                        TypingIndicator()
                                            .id("typing")
                                    }
                                }
                                .padding()
                            }
                            .onChange(of: messages.count) { _ in
                                withAnimation {
                                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                                }
                            }
                            .onChange(of: isTyping) { typing in
                                if typing {
                                    withAnimation {
                                        proxy.scrollTo("typing", anchor: .bottom)
                                    }
                                }
                            }
                            .onAppear {
                                scrollProxy = proxy
                            }
                        }
                    }
                    
                    // 输入区域
                    ChatInputBar(
                        text: $inputText,
                        isLoading: aiService.isLoading,
                        onSend: sendMessage
                    )
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadChatHistory()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // 发送消息
    private func sendMessage() {
        let messageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }
        
        // 添加用户消息
        let userMessage = ChatMessage(
            id: UUID(),
            content: messageText,
            isFromUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        saveChatHistory()
        
        // 清空输入框
        inputText = ""
        isTyping = true
        
        // 发送到AI服务
        Task {
            let response = await aiService.sendMessage(messageText)
            
            await MainActor.run {
                isTyping = false
                
                // 添加AI回复
                let aiMessage = ChatMessage(
                    id: UUID(),
                    content: response,
                    isFromUser: false,
                    timestamp: Date()
                )
                messages.append(aiMessage)
                saveChatHistory()
            }
        }
    }
    
    // 发送快速问题
    private func sendQuickQuestion(_ question: String) {
        inputText = question
        sendMessage()
    }
    
    // 清空聊天
    private func clearChat() {
        messages = []
        aiService.resetConversation()
        UserDefaults.standard.removeObject(forKey: "ChatHistory")
    }
    
    // 保存聊天历史
    private func saveChatHistory() {
        // 只保存最近50条消息
        let recentMessages = Array(messages.suffix(50))
        if let data = try? JSONEncoder().encode(recentMessages) {
            UserDefaults.standard.set(data, forKey: "ChatHistory")
        }
    }
    
    // 加载聊天历史
    private func loadChatHistory() {
        if let data = UserDefaults.standard.data(forKey: "ChatHistory"),
           let history = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = history
        }
    }
}

// MARK: - 欢迎消息视图
struct WelcomeMessageView: View {
    let onQuestionTap: (String) -> Void
    @StateObject private var userDataManager = UserDataManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                Spacer(minLength: 40)
                
                // 虚拟助手头像
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.cosmicPurple.opacity(0.3), .mysticPink.opacity(0.1)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.starGold, .mysticPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 10) {
                    Text("你好！我是星语")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.crystalWhite)
                    
                    Text("你的专属紫微斗数导师")
                        .font(.system(size: 16))
                        .foregroundColor(.moonSilver)
                    
                    Text("我可以为你解答命理疑惑，分析星盘奥秘，陪你探索人生方向")
                        .font(.system(size: 14))
                        .foregroundColor(.moonSilver.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 5)
                }
                
                // 快捷问题
                VStack(spacing: 15) {
                    Text("你可以问我")
                        .font(.system(size: 14))
                        .foregroundColor(.moonSilver.opacity(0.7))
                    
                    let questions = AIService.getQuickQuestions(
                        hasChart: userDataManager.hasGeneratedChart
                    )
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(questions, id: \.self) { question in
                            QuickQuestionButton(text: question) {
                                onQuestionTap(question)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - 聊天消息模型
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

// MARK: - 聊天气泡
struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                // 消息内容
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(message.isFromUser ? .white : .crystalWhite)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isFromUser ? 
                                  AnyShapeStyle(LinearGradient(colors: [.mysticPink, .cosmicPurple], startPoint: .leading, endPoint: .trailing)) :
                                  AnyShapeStyle(Color.white.opacity(0.1))
                            )
                    )
                    .overlay(
                        message.isFromUser ? nil :
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.moonSilver.opacity(0.2), lineWidth: 1)
                    )
                
                // 时间戳
                Text(timeString(from: message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.moonSilver.opacity(0.6))
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isFromUser ? .trailing : .leading)
            
            if !message.isFromUser {
                Spacer()
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 输入框
struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 输入框
            HStack {
                TextField("输入你想问的问题...", text: $text)
                    .foregroundColor(.crystalWhite)
                    .disabled(isLoading)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .starGold))
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.moonSilver.opacity(0.3), lineWidth: 1)
            )
            
            // 发送按钮
            Button(action: onSend) {
                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(text.isEmpty || isLoading ? .gray : .mysticPink)
            }
            .disabled(text.isEmpty || isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2))
    }
}

// MARK: - 快捷问题按钮
struct QuickQuestionButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.crystalWhite)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.moonSilver.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - 输入指示器
struct TypingIndicator: View {
    @State private var animationAmount = 0.0
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.moonSilver.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationAmount)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animationAmount
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.moonSilver.opacity(0.2), lineWidth: 1)
                    )
            )
            
            Spacer()
        }
        .onAppear {
            animationAmount = 1.2
        }
    }
}

struct ChatTab_Previews: PreviewProvider {
    static var previews: some View {
        ChatTab()
    }
}