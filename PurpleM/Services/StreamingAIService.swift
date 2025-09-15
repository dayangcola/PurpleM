//
//  StreamingAIService.swift
//  PurpleM
//
//  流式AI响应服务 - 实现打字机效果和实时响应
//

import Foundation
import SwiftUI
import Combine

// MARK: - 流式响应块
struct StreamChunk: Decodable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]?
    
    struct Choice: Decodable {
        let delta: Delta
        let index: Int
        let finish_reason: String?
    }
    
    struct Delta: Decodable {
        let content: String?
        let role: String?
    }
}

// MARK: - SSE事件类型
enum SSEEvent {
    case message(String)
    case error(Error)
    case completed
}

// MARK: - 流式AI服务
@MainActor
class StreamingAIService: NSObject, ObservableObject, URLSessionDelegate {
    static let shared = StreamingAIService()
    
    // MARK: - 发布的属性
    @Published var currentResponse: String = ""
    @Published var isStreaming: Bool = false
    @Published var streamProgress: Double = 0.0
    @Published var typingSpeed: Double = 30.0 // 每秒字符数
    
    // MARK: - 私有属性
    private var urlSession: URLSession!
    private var currentTask: URLSessionDataTask?
    private var responseBuffer = ""
    private var eventParser = SSEParser()
    
    // 用于流式响应的Subject
    private let streamSubject = PassthroughSubject<String, Error>()
    var streamPublisher: AnyPublisher<String, Error> {
        streamSubject.eraseToAnyPublisher()
    }
    
    override init() {
        super.init()
        
        // 配置URLSession用于流式响应
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        
        // 重要：允许流式传输
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        self.urlSession = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: .main
        )
    }
    
    // MARK: - 发送流式消息
    func sendStreamingMessage(
        _ message: String,
        context: [(role: String, content: String)] = [],
        temperature: Double = 0.7,
        useThinkingChain: Bool = true  // 默认使用思维链
    ) async throws -> AsyncThrowingStream<String, Error> {
        
        // 暂时都使用 chat-stream，通过修改消息来实现思维链
        let endpoint = "https://purple-m.vercel.app/api/chat-stream"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "Invalid URL", code: -1)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // 构建请求体
        var messages = context
        
        // 如果使用思维链，添加系统提示
        if useThinkingChain && messages.first?.role != "system" {
            let thinkingPrompt = """
            你是一个深度思考的智能助手。请按照以下格式进行深入分析和回答：
            
            使用 <thinking> 标签包裹你的思考过程，包含以下层次：
            【问题理解】首先准确理解用户的真实需求和问题核心
            【多维分析】从不同角度（如紫微斗数、心理学、实用性等）分析问题
            【逻辑推理】通过严密的逻辑推导得出结论
            【潜在影响】考虑各种可能的影响和结果
            【最佳方案】综合考虑后确定最优解决方案
            
            使用 <answer> 标签包裹你的最终答案，要求：
            - 结构清晰，层次分明
            - 观点明确，论据充分
            - 语言优美，易于理解
            - 提供可操作的建议
            
            示例格式：
            <thinking>
            【问题理解】用户询问的核心是...
            【多维分析】
            - 从紫微斗数角度：...
            - 从心理层面：...
            - 从实际操作：...
            【逻辑推理】基于以上分析，我认为...
            【潜在影响】这可能会带来...
            【最佳方案】综合考虑，建议...
            </thinking>
            
            <answer>
            根据深入分析，我的建议是...
            [清晰的结构化回答]
            </answer>
            """
            messages.insert((role: "system", content: thinkingPrompt), at: 0)
        }
        
        messages.append((role: "user", content: message))
        
        let requestBody: [String: Any] = [
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "model": "gpt-4o-mini",
            "temperature": temperature,
            "stream": true,  // 启用流式响应
            "userInfo": [
                "name": "星语用户",
                "userId": AuthManager.shared.currentUser?.id ?? "anonymous"
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 创建异步流
        return AsyncThrowingStream<String, Error> { continuation in
            Task {
                await self.startStreaming(request: request, continuation: continuation)
            }
        }
    }
    
    // MARK: - 开始流式传输
    private func startStreaming(
        request: URLRequest,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async {
        
        isStreaming = true
        currentResponse = ""
        responseBuffer = ""
        streamProgress = 0.0
        
        // 创建数据任务
        currentTask = urlSession.dataTask(with: request)
        currentTask?.resume()
        
        // 设置流处理器
        eventParser.onEvent = { [weak self] event in
            guard let self = self else { return }
            
            switch event {
            case .message(let content):
                self.currentResponse += content
                continuation.yield(content)
                
            case .error(let error):
                continuation.finish(throwing: error)
                self.isStreaming = false
                
            case .completed:
                continuation.finish()
                self.isStreaming = false
            }
        }
    }
    
    // MARK: - 取消流式传输
    func cancelStreaming() {
        currentTask?.cancel()
        isStreaming = false
        streamSubject.send(completion: .finished)
    }
    
    // MARK: - 带打字机效果的消息发送
    func sendMessageWithTypingEffect(
        _ message: String,
        context: [(role: String, content: String)] = []
    ) -> AnyPublisher<String, Error> {
        
        return Future<String, Error> { [weak self] promise in
            guard let self = self else { return }
            
            Task {
                do {
                    var fullResponse = ""
                    let stream = try await self.sendStreamingMessage(message, context: context)
                    
                    for try await chunk in stream {
                        fullResponse += chunk
                        
                        // 模拟打字效果
                        await self.simulateTyping(chunk)
                    }
                    
                    promise(.success(fullResponse))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 模拟打字效果
    private func simulateTyping(_ text: String) async {
        let delay = 1.0 / typingSpeed
        
        for character in text {
            currentResponse.append(character)
            
            // 根据字符类型调整延迟
            let adjustedDelay: Double
            switch character {
            case "。", "！", "？", ".", "!", "?":
                adjustedDelay = delay * 3  // 句号后停顿更长
            case "，", ",", "；", ";":
                adjustedDelay = delay * 2  // 逗号停顿稍长
            case "\n":
                adjustedDelay = delay * 4  // 换行停顿更长
            default:
                adjustedDelay = delay
            }
            
            try? await Task.sleep(nanoseconds: UInt64(adjustedDelay * 1_000_000_000))
        }
    }
}

// MARK: - URLSession Delegate
extension StreamingAIService: URLSessionDataDelegate {
    
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Task { @MainActor in
            // 处理接收到的流数据
            guard let string = String(data: data, encoding: .utf8) else { return }
            
            responseBuffer += string
            
            // 解析SSE事件
            let lines = responseBuffer.components(separatedBy: "\n")
            
            for line in lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    
                    if jsonString == "[DONE]" {
                        print("📌 收到流结束信号")
                        eventParser.onEvent?(.completed)
                        continue
                    }
                    
                    // 尝试解析我们的简化格式
                    if let jsonData = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        
                        // 检查是否是我们的格式 {type: "content", content: "..."}
                        if let type = json["type"] as? String,
                           type == "content",
                           let content = json["content"] as? String {
                            print("📝 收到内容块: \(content)")
                            eventParser.onEvent?(.message(content))
                            continue
                        }
                        
                        // 如果是连接成功消息
                        if let type = json["type"] as? String,
                           type == "connected" {
                            print("✅ 流式连接已建立")
                            continue
                        }
                    }
                    
                    // 尝试解析 OpenAI 格式（备用）
                    do {
                        if let jsonData = jsonString.data(using: .utf8),
                           let chunk = try? JSONDecoder().decode(StreamChunk.self, from: jsonData),
                           let content = chunk.choices?.first?.delta.content {
                            print("📝 收到内容块 (OpenAI格式): \(content)")
                            eventParser.onEvent?(.message(content))
                        }
                    } catch {
                        print("⚠️ 无法解析数据: \(jsonString)")
                        continue
                    }
                }
            }
            
            // 清理已处理的数据
            if let lastNewline = responseBuffer.lastIndex(of: "\n") {
                responseBuffer = String(responseBuffer[responseBuffer.index(after: lastNewline)...])
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            if let error = error {
                eventParser.onEvent?(.error(error))
            } else {
                eventParser.onEvent?(.completed)
            }
            
            isStreaming = false
        }
    }
}

// MARK: - SSE解析器
class SSEParser {
    var onEvent: ((SSEEvent) -> Void)?
    
    private var eventType: String = ""
    private var eventData: String = ""
    
    func parse(_ line: String) {
        if line.isEmpty {
            // 空行表示事件结束
            if !eventData.isEmpty {
                processEvent()
            }
            reset()
        } else if line.hasPrefix("event:") {
            eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            eventData += data + "\n"
        }
    }
    
    private func processEvent() {
        if eventData == "[DONE]" {
            onEvent?(.completed)
        } else {
            onEvent?(.message(eventData))
        }
    }
    
    private func reset() {
        eventType = ""
        eventData = ""
    }
}

// MARK: - 聊天界面集成方法
extension StreamingAIService {
    
    /// 为ChatTab提供的流式消息发送方法
    func sendStreamingMessageForChat(
        _ messageText: String,
        context: [(role: String, content: String)]
    ) async throws -> String {
        var fullResponse = ""
        
        // 获取流式响应
        let stream = try await sendStreamingMessage(
            messageText,
            context: context
        )
        
        // 收集所有响应块
        for try await chunk in stream {
            fullResponse += chunk
            // 可以在这里通过回调更新UI
            streamSubject.send(chunk)
        }
        
        return fullResponse
    }
}

// MARK: - 流式响应UI组件
struct StreamingMessageView: View {
    let message: String
    @State private var displayedText = ""
    @State private var currentIndex = 0
    
    var body: some View {
        Text(displayedText)
            .onAppear {
                animateText()
            }
    }
    
    private func animateText() {
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if currentIndex < message.count {
                let index = message.index(message.startIndex, offsetBy: currentIndex)
                displayedText.append(message[index])
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}