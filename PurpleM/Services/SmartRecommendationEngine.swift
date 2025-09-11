//
//  SmartRecommendationEngine.swift
//  PurpleM
//
//  智能推荐引擎 - 基于上下文和历史推荐相关内容
//

import Foundation
import SwiftUI

// MARK: - 推荐类型
enum RecommendationType {
    case question       // 问题推荐
    case feature       // 功能推荐
    case content       // 内容推荐
    case timing        // 时机推荐
}

// MARK: - 推荐项模型
struct RecommendationItem: Identifiable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let subtitle: String?
    let icon: String
    let action: () -> Void
}

// MARK: - 智能推荐引擎
@MainActor
class SmartRecommendationEngine: ObservableObject {
    static let shared = SmartRecommendationEngine()
    
    @Published var currentRecommendations: [RecommendationItem] = []
    @Published var suggestedQuestions: [String] = []
    @Published var isGenerating = false
    
    private let enhancedAI = EnhancedAIService.shared
    
    private init() {
        updateRecommendations()
    }
    
    // MARK: - 根据当前场景生成推荐
    func updateRecommendations() {
        currentRecommendations.removeAll()
        
        let scene = enhancedAI.currentScene
        let emotion = enhancedAI.detectedEmotion
        
        // 基于场景的推荐
        switch scene {
        case .greeting:
            addGreetingRecommendations()
        case .chartReading:
            addChartReadingRecommendations()
        case .fortuneTelling:
            addFortuneTellingRecommendations()
        case .learning:
            addLearningRecommendations()
        case .counseling:
            addConsultationRecommendations(emotion: emotion)
        case .emergency:
            addEmergencyRecommendations()
        }
        
        // 基于时间的推荐
        addTimeBasedRecommendations()
        
        // 基于历史的推荐
        addHistoryBasedRecommendations()
    }
    
    // MARK: - 生成智能问题推荐
    func generateQuestionSuggestions(basedOn message: String, response: String) {
        isGenerating = true
        
        Task {
            // 基于对话内容分析
            let keywords = extractKeywords(from: message + " " + response)
            var suggestions: [String] = []
            
            // 根据关键词生成问题
            if keywords.contains(where: { $0.contains("运势") || $0.contains("运程") }) {
                suggestions.append("我的事业运势如何？")
                suggestions.append("今年的感情运势怎么样？")
                suggestions.append("财运什么时候会好转？")
            }
            
            if keywords.contains(where: { $0.contains("紫微") || $0.contains("命盘") }) {
                suggestions.append("我的紫微主星代表什么？")
                suggestions.append("命宫的含义是什么？")
                suggestions.append("如何看懂我的命盘？")
            }
            
            if keywords.contains(where: { $0.contains("感情") || $0.contains("爱情") }) {
                suggestions.append("我什么时候会遇到真爱？")
                suggestions.append("如何改善感情运势？")
                suggestions.append("我和TA的缘分如何？")
            }
            
            if keywords.contains(where: { $0.contains("事业") || $0.contains("工作") }) {
                suggestions.append("适合我的职业方向是什么？")
                suggestions.append("今年适合跳槽吗？")
                suggestions.append("如何提升事业运？")
            }
            
            // 通用推荐
            if suggestions.isEmpty {
                suggestions = [
                    "帮我详细解读一下命盘",
                    "我的大运走势如何？",
                    "今日运势怎么样？",
                    "有什么需要注意的吗？"
                ]
            }
            
            await MainActor.run {
                self.suggestedQuestions = Array(suggestions.prefix(4))
                self.isGenerating = false
            }
        }
    }
    
    // MARK: - 场景相关推荐
    private func addGreetingRecommendations() {
        currentRecommendations.append(contentsOf: [
            RecommendationItem(
                type: .feature,
                title: "生成命盘",
                subtitle: "开始你的命理之旅",
                icon: "star.circle",
                action: { }
            ),
            RecommendationItem(
                type: .question,
                title: "了解紫微斗数",
                subtitle: "什么是紫微斗数？",
                icon: "questionmark.circle",
                action: { }
            ),
            RecommendationItem(
                type: .feature,
                title: "今日运势",
                subtitle: "查看今天的运势",
                icon: "sun.max",
                action: { }
            )
        ])
    }
    
    private func addChartReadingRecommendations() {
        currentRecommendations.append(contentsOf: [
            RecommendationItem(
                type: .question,
                title: "主星解读",
                subtitle: "了解你的紫微主星",
                icon: "star.fill",
                action: { }
            ),
            RecommendationItem(
                type: .feature,
                title: "大运分析",
                subtitle: "查看十年大运",
                icon: "calendar",
                action: { }
            ),
            RecommendationItem(
                type: .content,
                title: "命盘格局",
                subtitle: "你的特殊格局",
                icon: "square.grid.3x3",
                action: { }
            )
        ])
    }
    
    private func addFortuneTellingRecommendations() {
        currentRecommendations.append(contentsOf: [
            RecommendationItem(
                type: .timing,
                title: "择日建议",
                subtitle: "近期吉日推荐",
                icon: "calendar.badge.plus",
                action: { }
            ),
            RecommendationItem(
                type: .question,
                title: "流年分析",
                subtitle: "今年运势详解",
                icon: "arrow.triangle.time.rtl.badge.clock",
                action: { }
            ),
            RecommendationItem(
                type: .content,
                title: "运势报告",
                subtitle: "生成完整报告",
                icon: "doc.text",
                action: { }
            )
        ])
    }
    
    private func addLearningRecommendations() {
        currentRecommendations.append(contentsOf: [
            RecommendationItem(
                type: .content,
                title: "基础知识",
                subtitle: "紫微斗数入门",
                icon: "book",
                action: { }
            ),
            RecommendationItem(
                type: .question,
                title: "进阶学习",
                subtitle: "四化是什么？",
                icon: "graduationcap",
                action: { }
            ),
            RecommendationItem(
                type: .feature,
                title: "学习路径",
                subtitle: "系统学习计划",
                icon: "map",
                action: { }
            )
        ])
    }
    
    private func addConsultationRecommendations(emotion: UserEmotion) {
        // 根据情绪调整推荐
        if emotion == .anxious || emotion == .sad {
            currentRecommendations.append(
                RecommendationItem(
                    type: .content,
                    title: "情绪疏导",
                    subtitle: "放松技巧和建议",
                    icon: "heart.circle",
                    action: { }
                )
            )
        }
        
        currentRecommendations.append(contentsOf: [
            RecommendationItem(
                type: .question,
                title: "深度咨询",
                subtitle: "预约1对1咨询",
                icon: "person.2.circle",
                action: { }
            ),
            RecommendationItem(
                type: .content,
                title: "相似案例",
                subtitle: "看看别人的经历",
                icon: "person.3",
                action: { }
            )
        ])
    }
    
    private func addEmergencyRecommendations() {
        currentRecommendations.append(contentsOf: [
            RecommendationItem(
                type: .feature,
                title: "紧急支持",
                subtitle: "立即获得帮助",
                icon: "sos.circle.fill",
                action: { }
            ),
            RecommendationItem(
                type: .content,
                title: "心理资源",
                subtitle: "专业心理支持",
                icon: "heart.text.square",
                action: { }
            ),
            RecommendationItem(
                type: .question,
                title: "联系专家",
                subtitle: "专业命理师咨询",
                icon: "phone.circle",
                action: { }
            )
        ])
    }
    
    // MARK: - 时间相关推荐
    private func addTimeBasedRecommendations() {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        // 早晨推荐
        if hour >= 6 && hour < 9 {
            currentRecommendations.insert(
                RecommendationItem(
                    type: .timing,
                    title: "早安问候",
                    subtitle: "今日宜忌查看",
                    icon: "sunrise",
                    action: { }
                ),
                at: 0
            )
        }
        
        // 晚间推荐
        if hour >= 20 && hour < 24 {
            currentRecommendations.insert(
                RecommendationItem(
                    type: .timing,
                    title: "晚间回顾",
                    subtitle: "今日运势总结",
                    icon: "moon.stars",
                    action: { }
                ),
                at: 0
            )
        }
        
        // 特殊日期推荐
        checkSpecialDates()
    }
    
    private func checkSpecialDates() {
        let calendar = Calendar.current
        let now = Date()
        
        // 检查是否接近月初或月末
        let day = calendar.component(.day, from: now)
        if day == 1 || day == calendar.range(of: .day, in: .month, for: now)?.count {
            currentRecommendations.append(
                RecommendationItem(
                    type: .timing,
                    title: "月度运势",
                    subtitle: "查看本月运势分析",
                    icon: "calendar.circle",
                    action: { }
                )
            )
        }
        
        // 检查是否接近用户生日
        if let user = UserDataManager.shared.currentUser {
            let userBirthday = user.birthDate
            let daysToBirthday = calendar.dateComponents([.day], from: now, to: userBirthday).day ?? 365
            
            if daysToBirthday <= 7 && daysToBirthday >= 0 {
                currentRecommendations.insert(
                    RecommendationItem(
                        type: .timing,
                        title: "生日特别分析",
                        subtitle: "你的生日运势",
                        icon: "gift",
                        action: { }
                    ),
                    at: 0
                )
            }
        }
    }
    
    // MARK: - 历史相关推荐
    private func addHistoryBasedRecommendations() {
        // 从用户记忆中获取关注点
        let concerns = enhancedAI.userMemory.concerns
        
        for concern in concerns.prefix(2) {
            if concern.contains("感情") {
                currentRecommendations.append(
                    RecommendationItem(
                        type: .content,
                        title: "感情专题",
                        subtitle: "你关注的感情话题",
                        icon: "heart",
                        action: { }
                    )
                )
            } else if concern.contains("事业") {
                currentRecommendations.append(
                    RecommendationItem(
                        type: .content,
                        title: "事业专题",
                        subtitle: "你关注的事业话题",
                        icon: "briefcase",
                        action: { }
                    )
                )
            }
        }
    }
    
    // MARK: - 辅助方法
    private func extractKeywords(from text: String) -> [String] {
        // 简单的关键词提取
        let keywords = ["运势", "命盘", "紫微", "感情", "事业", "财运", "健康", "学业", "大运", "流年"]
        return keywords.filter { text.contains($0) }
    }
}

// MARK: - 推荐卡片视图
struct RecommendationCard: View {
    let item: RecommendationItem
    
    var body: some View {
        Button(action: item.action) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 24))
                    .foregroundColor(colorForType(item.type))
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.crystalWhite)
                    
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.moonSilver.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.moonSilver.opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - 推荐列表视图
struct RecommendationListView: View {
    @StateObject private var engine = SmartRecommendationEngine.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("为你推荐")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.crystalWhite)
            
            ForEach(engine.currentRecommendations.prefix(3)) { item in
                RecommendationCard(item: item)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cosmicPurple.opacity(0.1),
                            Color.mysticPink.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}