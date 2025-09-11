//
//  ChatTab.swift
//  PurpleM
//
//  Tab3: 聊天 - AI助手和智能问答
//

import SwiftUI
import Combine

struct ChatTab: View {
    @StateObject private var userDataManager = UserDataManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var supabaseManager = SupabaseManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineQueue = OfflineQueueManager.shared
    @StateObject private var recommendationEngine = SmartRecommendationEngine.shared
    @StateObject private var streamingService = StreamingAIService.shared
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var currentStreamingMessageId: UUID? = nil  // 当前流式消息ID
    @State private var isInitializing = true
    @State private var showQuotaAlert = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var cancellables = Set<AnyCancellable>()
    
    // 动态获取AI服务
    private var aiService: NSObject {
        switch settingsManager.aiMode {
        case .standard:
            return AIService.shared
        case .enhanced:
            return EnhancedAIService.shared
        }
    }
    
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
                        
                        // 网络状态指示器
                        HStack(spacing: 4) {
                            if !networkMonitor.isConnected {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange.opacity(0.8))
                            }
                            
                            if offlineQueue.queueSize > 0 {
                                Label("\(offlineQueue.queueSize)", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow.opacity(0.8))
                            }
                        }
                        
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
                                    
                                    // 显示智能推荐问题（增强版）
                                    if settingsManager.aiMode == .enhanced && 
                                       !isTyping && 
                                       !recommendationEngine.suggestedQuestions.isEmpty &&
                                       !messages.isEmpty {
                                        SuggestedQuestionsView(
                                            questions: recommendationEngine.suggestedQuestions,
                                            onQuestionTap: sendQuickQuestion
                                        )
                                        .id("suggestions")
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                    }
                                }
                                .padding()
                            }
                            .onChange(of: messages.count) { oldCount, newCount in
                                withAnimation {
                                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                                }
                            }
                            .onChange(of: isTyping) { oldValue, newValue in
                                if newValue {
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
                        isLoading: isTyping,
                        onSend: sendMessage
                    )
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadChatHistory()
                setupAIModeListener()
                initializeCloudServices()
            }
            .alert("配额提醒", isPresented: $showQuotaAlert) {
                Button("了解升级", role: .none) {
                    // TODO: 跳转到订阅页面
                }
                Button("稍后", role: .cancel) { }
            } message: {
                Text("升级到专业版，享受无限对话和更多功能")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // 发送消息（支持智能流式）
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
        
        // 检测当前场景（增强版功能）
        let currentScene: ConversationScene = settingsManager.aiMode == .enhanced ? 
            EnhancedAIService.shared.currentScene : .greeting
        
        // 智能判断是否使用流式响应
        let shouldUseStreaming = StreamingDetector.shouldUseStreaming(
            for: currentScene,
            message: messageText,
            settings: settingsManager
        )
        
        if shouldUseStreaming && settingsManager.aiMode == .enhanced {
            // 使用流式响应
            sendStreamingMessage(messageText, scene: currentScene)
        } else {
            // 使用普通响应
            sendNormalMessage(messageText)
        }
    }
    
    // 普通消息发送（非流式）
    private func sendNormalMessage(_ messageText: String) {
        Task {
            let response: String
            
            // 根据AI模式和网络状态选择合适的方法
            if settingsManager.aiMode == .standard {
                response = await AIService.shared.sendMessage(messageText)
            } else {
                // 增强版支持云端同步
                if AuthManager.shared.currentUser != nil && networkMonitor.isConnected {
                    response = await EnhancedAIService.shared.sendMessageWithCloud(messageText)
                } else {
                    response = await EnhancedAIService.shared.sendMessage(messageText)
                }
            }
            
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
                
                // 检查是否需要显示配额提醒
                if response.contains("免费额度已用完") {
                    showQuotaAlert = true
                }
                
                // 增强版：生成智能推荐问题
                if settingsManager.aiMode == .enhanced {
                    recommendationEngine.generateQuestionSuggestions(
                        basedOn: messageText,
                        response: response
                    )
                }
                
                // 记录统计
                StreamingAnalytics.shared.recordUsage(
                    scene: EnhancedAIService.shared.currentScene,
                    messageLength: messageText.count,
                    responseLength: response.count,
                    usedStreaming: false
                )
            }
        }
    }
    
    // 流式消息发送
    private func sendStreamingMessage(_ messageText: String, scene: ConversationScene) {
        // 创建AI消息占位符
        let aiMessageId = UUID()
        currentStreamingMessageId = aiMessageId
        
        let aiMessage = ChatMessage(
            id: aiMessageId,
            content: "",
            isFromUser: false,
            timestamp: Date()
        )
        messages.append(aiMessage)
        
        Task {
            do {
                var fullResponse = ""
                
                // 构建上下文
                let context = buildStreamingContext()
                
                // 获取流式响应
                let stream = try await streamingService.sendStreamingMessage(
                    messageText,
                    context: context
                )
                
                // 逐块更新消息
                for try await chunk in stream {
                    fullResponse += chunk
                    
                    // 更新UI上的消息
                    await MainActor.run {
                        if let index = messages.firstIndex(where: { $0.id == aiMessageId }) {
                            messages[index] = ChatMessage(
                                id: aiMessageId,
                                content: fullResponse,
                                isFromUser: false,
                                timestamp: Date()
                            )
                            
                            // 自动滚动到底部
                            withAnimation(.easeInOut(duration: 0.2)) {
                                scrollProxy?.scrollTo(aiMessageId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                await MainActor.run {
                    isTyping = false
                    currentStreamingMessageId = nil
                    saveChatHistory()
                    
                    // 生成智能推荐
                    recommendationEngine.generateQuestionSuggestions(
                        basedOn: messageText,
                        response: fullResponse
                    )
                    
                    // 记录统计
                    StreamingAnalytics.shared.recordUsage(
                        scene: scene,
                        messageLength: messageText.count,
                        responseLength: fullResponse.count,
                        usedStreaming: true
                    )
                }
                
            } catch {
                // 错误处理：降级到普通模式
                await MainActor.run {
                    // 移除占位消息
                    messages.removeAll { $0.id == aiMessageId }
                    currentStreamingMessageId = nil
                    
                    // 使用普通模式重试
                    sendNormalMessage(messageText)
                }
            }
        }
    }
    
    // 构建流式上下文
    private func buildStreamingContext() -> [(role: String, content: String)] {
        var context: [(role: String, content: String)] = []
        
        // 添加系统提示词
        context.append((role: "system", content: AIPersonality.systemPrompt))
        
        // 添加最近的对话历史（限制10条避免token过多）
        let recentMessages = messages.suffix(10).filter { !$0.content.isEmpty }
        for message in recentMessages {
            context.append((
                role: message.isFromUser ? "user" : "assistant",
                content: message.content
            ))
        }
        
        return context
    }
    
    // 发送快速问题
    private func sendQuickQuestion(_ question: String) {
        inputText = question
        sendMessage()
    }
    
    // 清空聊天
    private func clearChat() {
        messages = []
        // 重置对应的AI服务
        if settingsManager.aiMode == .standard {
            AIService.shared.resetConversation()
        } else {
            EnhancedAIService.shared.resetConversation()
        }
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
    
    // 设置AI模式监听器
    private func setupAIModeListener() {
        NotificationCenter.default.publisher(for: .aiModeChanged)
            .sink { _ in
                // AI模式改变时清空聊天并重置
                clearChat()
                // 显示模式切换提示
                let modeMessage = ChatMessage(
                    id: UUID(),
                    content: "已切换到\(settingsManager.aiMode.rawValue)模式 ✨",
                    isFromUser: false,
                    timestamp: Date()
                )
                messages.append(modeMessage)
            }
            .store(in: &cancellables)
    }
    
    // 初始化云端服务
    private func initializeCloudServices() {
        guard settingsManager.aiMode == .enhanced else { return }
        
        Task {
            isInitializing = true
            
            // 初始化增强版AI的云端数据
            if AuthManager.shared.currentUser != nil {
                await EnhancedAIService.shared.initializeFromCloud()
                
                // 加载用户配额信息
                if let userId = AuthManager.shared.currentUser?.id {
                    _ = try? await SupabaseManager.shared.getUserQuota(userId: userId)
                }
            }
            
            await MainActor.run {
                isInitializing = false
            }
        }
    }
}

// MARK: - 欢迎消息视图
struct WelcomeMessageView: View {
    let onQuestionTap: (String) -> Void
    @StateObject private var userDataManager = UserDataManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var recommendationEngine = SmartRecommendationEngine.shared
    
    private func getQuestions() -> [String] {
        if settingsManager.aiMode == .enhanced {
            // 增强版提供的智能问题
            let smartQuestions = recommendationEngine.suggestedQuestions
            if !smartQuestions.isEmpty {
                return smartQuestions
            }
            // 如果没有智能推荐，返回默认推荐
            return EnhancedAIService.shared.suggestedQuestions
        } else {
            // 标准版的基础问题
            return AIService.getQuickQuestions(
                hasChart: userDataManager.hasGeneratedChart
            )
        }
    }
    
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
                    
                    // 根据AI模式获取不同的快捷问题
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(getQuestions(), id: \.self) { question in
                            QuickQuestionButton(text: question) {
                                onQuestionTap(question)
                            }
                        }
                    }
                    
                    // 增强版显示智能推荐
                    if settingsManager.aiMode == .enhanced && !recommendationEngine.currentRecommendations.isEmpty {
                        VStack(spacing: 10) {
                            Text("智能推荐")
                                .font(.system(size: 14))
                                .foregroundColor(.starGold.opacity(0.7))
                                .padding(.top, 10)
                            
                            ForEach(recommendationEngine.currentRecommendations.prefix(3)) { item in
                                SmartRecommendationCard(item: item, onQuestionTap: onQuestionTap)
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
    @State private var isStreaming: Bool = false
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                // 流式响应指示器
                if !message.isFromUser && isStreaming {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 10))
                            .foregroundColor(.starGold)
                            .symbolEffect(.pulse, options: .repeating)
                        
                        Text("实时响应中...")
                            .font(.system(size: 10))
                            .foregroundColor(.starGold.opacity(0.8))
                    }
                    .padding(.horizontal, 4)
                }
                
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
                            .stroke(isStreaming ? Color.starGold.opacity(0.3) : Color.moonSilver.opacity(0.2), lineWidth: 1)
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

// MARK: - 推荐问题视图
struct SuggestedQuestionsView: View {
    let questions: [String]
    let onQuestionTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("接下来你可以问:")
                .font(.system(size: 12))
                .foregroundColor(.moonSilver.opacity(0.7))
                .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(questions, id: \.self) { question in
                        Button(action: {
                            onQuestionTap(question)
                        }) {
                            Text(question)
                                .font(.system(size: 12))
                                .foregroundColor(.crystalWhite)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.mysticPink.opacity(0.3), .cosmicPurple.opacity(0.3)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.starGold.opacity(0.3), lineWidth: 0.5)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 智能推荐卡片（聊天界面版本）
struct SmartRecommendationCard: View {
    let item: RecommendationItem
    let onQuestionTap: (String) -> Void
    
    var body: some View {
        Button(action: {
            // 将推荐转换为问题
            let question = convertToQuestion(item)
            onQuestionTap(question)
        }) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 16))
                    .foregroundColor(colorForType(item.type))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.crystalWhite)
                    
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.moonSilver.opacity(0.7))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.moonSilver.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(colorForType(item.type).opacity(0.3), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func convertToQuestion(_ item: RecommendationItem) -> String {
        switch item.type {
        case .question:
            return item.subtitle ?? item.title
        case .feature:
            return "我想了解\(item.title)"
        case .content:
            return "请给我介绍\(item.title)"
        case .timing:
            return "告诉我关于\(item.title)的信息"
        }
    }
    
    private func colorForType(_ type: RecommendationType) -> Color {
        switch type {
        case .question:
            return .starGold
        case .feature:
            return .mysticPink
        case .content:
            return .cosmicPurple
        case .timing:
            return .crystalWhite
        }
    }
}

struct ChatTab_Previews: PreviewProvider {
    static var previews: some View {
        ChatTab()
    }
}