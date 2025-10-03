//
//  DailyFortuneEngine.swift
//  PurpleM
//
//  每日运势计算引擎 - 基于紫微斗数算法
//

import SwiftUI

// MARK: - 每日运势数据模型
struct DailyFortune {
    let date: Date
    let overallScore: Int          // 综合运势 (0-100)
    let careerScore: Int          // 事业运 (0-100)
    let loveScore: Int            // 爱情运 (0-100)
    let wealthScore: Int          // 财运 (0-100)
    let healthScore: Int          // 健康运 (0-100)
    
    let luckyColor: Color         // 幸运色
    let luckyNumber: Int          // 幸运数字
    let luckyDirection: String    // 幸运方位
    
    let advice: String            // 今日建议
    let warning: String           // 注意事项
    let luckyTime: String         // 吉时
    
    let starInfluence: String     // 星耀影响
    let palaceInfluence: String   // 宫位影响
}

// MARK: - 运势计算引擎
class DailyFortuneEngine {
    
    // 基于用户星盘和当前日期计算运势
    static func calculateDailyFortune(chartData: ChartData?, date: Date = Date()) -> DailyFortune {
        // 获取当前日期信息
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        let day = components.day ?? 1
        let month = components.month ?? 1
        let weekday = components.weekday ?? 1
        
        // 基础分数（使用日期作为随机种子，确保同一天结果一致）
        let seed = (components.year ?? 2025) * 10000 + month * 100 + day
        
        // 计算各项运势分数
        let overallScore = calculateScore(base: 60, seed: seed, offset: 0)
        let careerScore = calculateScore(base: 55, seed: seed, offset: 10)
        let loveScore = calculateScore(base: 65, seed: seed, offset: 20)
        let wealthScore = calculateScore(base: 50, seed: seed, offset: 30)
        let healthScore = calculateScore(base: 70, seed: seed, offset: 40)
        
        // 计算幸运元素
        let luckyColor = getLuckyColor(day: day, month: month)
        let luckyNumber = getLuckyNumber(day: day)
        let luckyDirection = getLuckyDirection(weekday: weekday)
        
        // 获取建议和提醒
        let advice = getAdvice(overallScore: overallScore, day: day)
        let warning = getWarning(lowestScore: min(careerScore, loveScore, wealthScore, healthScore))
        let luckyTime = getLuckyTime(day: day)
        
        // 星耀影响（如果有星盘数据）
        let starInfluence = getStarInfluence(chartData: chartData, date: date)
        let palaceInfluence = getPalaceInfluence(chartData: chartData, date: date)
        
        return DailyFortune(
            date: date,
            overallScore: overallScore,
            careerScore: careerScore,
            loveScore: loveScore,
            wealthScore: wealthScore,
            healthScore: healthScore,
            luckyColor: luckyColor,
            luckyNumber: luckyNumber,
            luckyDirection: luckyDirection,
            advice: advice,
            warning: warning,
            luckyTime: luckyTime,
            starInfluence: starInfluence,
            palaceInfluence: palaceInfluence
        )
    }
    
    // MARK: - 私有计算方法
    
    private static func calculateScore(base: Int, seed: Int, offset: Int) -> Int {
        // 使用种子生成伪随机数
        let random = abs((seed * 31 + offset * 17) % 41) - 20 // -20 到 20 的变化
        let score = base + random
        return max(0, min(100, score))
    }
    
    private static func getLuckyColor(day: Int, month: Int) -> Color {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .blue,
            .purple, .pink, .cyan, .indigo, .brown
        ]
        let index = (day + month) % colors.count
        return colors[index].opacity(0.8)
    }
    
    private static func getLuckyNumber(day: Int) -> Int {
        return (day * 3 + 7) % 10
    }
    
    private static func getLuckyDirection(weekday: Int) -> String {
        let directions = ["东", "东南", "南", "西南", "西", "西北", "北", "东北"]
        return directions[weekday % directions.count]
    }
    
    private static func getAdvice(overallScore: Int, day: Int) -> String {
        let advices = [
            "今天适合主动出击，把握机会。",
            "保持谦逊，稳步前进。",
            "多与他人交流，会有意外收获。",
            "专注于手头的工作，避免分心。",
            "适合学习新知识，充实自己。",
            "今日宜静不宜动，适合思考规划。",
            "贵人运佳，可寻求他人帮助。",
            "创意爆发的一天，大胆尝试新想法。",
            "注意细节，避免粗心大意。",
            "适合处理人际关系，化解误会。"
        ]
        
        if overallScore >= 80 {
            return "运势极佳！" + advices[day % advices.count]
        } else if overallScore >= 60 {
            return advices[day % advices.count]
        } else {
            return "运势平平，" + advices[day % advices.count]
        }
    }
    
    private static func getWarning(lowestScore: Int) -> String {
        if lowestScore < 30 {
            return "今日需特别谨慎，避免冲动决定。"
        } else if lowestScore < 50 {
            return "注意劳逸结合，不要过度劳累。"
        } else {
            return "保持积极心态，一切顺其自然。"
        }
    }
    
    private static func getLuckyTime(day: Int) -> String {
        let times = [
            "子时(23:00-01:00)", "丑时(01:00-03:00)", "寅时(03:00-05:00)",
            "卯时(05:00-07:00)", "辰时(07:00-09:00)", "巳时(09:00-11:00)",
            "午时(11:00-13:00)", "未时(13:00-15:00)", "申时(15:00-17:00)",
            "酉时(17:00-19:00)", "戌时(19:00-21:00)", "亥时(21:00-23:00)"
        ]
        let index = day % times.count
        return times[index]
    }
    
    private static func getStarInfluence(chartData: ChartData?, date: Date) -> String {
        guard let chartData = chartData else {
            return "生成星盘后可查看详细星耀影响"
        }
        
        // 这里可以根据星盘数据计算实际的星耀影响
        // 简化版本：根据日期返回不同的影响描述
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        
        let influences = [
            "紫微星照耀，贵人运势强",
            "天府星当值，财运亨通",
            "太阳星高照，事业有成",
            "太阴星柔和，感情顺利",
            "天机星活跃，智慧倍增",
            "天同星温和，人际和谐",
            "廉贞星正旺，魅力四射",
            "武曲星刚强，执行力强",
            "破军星变动，适合创新",
            "七杀星果断，决策明确"
        ]
        
        return influences[day % influences.count]
    }
    
    private static func getPalaceInfluence(chartData: ChartData?, date: Date) -> String {
        guard let chartData = chartData else {
            return "今日流年宫位待解析"
        }
        
        // 简化版本：根据日期返回不同的宫位影响
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        
        let palaces = [
            "命宫：主导整体运势走向",
            "财帛宫：影响财务收支",
            "官禄宫：事业发展关键",
            "夫妻宫：感情关系重点",
            "迁移宫：外出机遇增多",
            "福德宫：精神愉悦充实",
            "田宅宫：家庭和谐稳定",
            "兄弟宫：朋友助力明显",
            "子女宫：创意灵感丰富",
            "疾厄宫：健康需要关注",
            "交友宫：社交活跃顺畅",
            "父母宫：长辈支持有力"
        ]
        
        return palaces[day % palaces.count]
    }
}

// MARK: - 心情记录模型
struct MoodRecord: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let mood: MoodType
    let note: String?
    let fortuneScore: Int  // 当天的运势分数
    
    enum MoodType: String, Codable, CaseIterable {
        case veryHappy = "非常开心"
        case happy = "开心"
        case normal = "平常"
        case sad = "低落"
        case verySad = "很低落"
        
        var emoji: String {
            switch self {
            case .veryHappy: return "😄"
            case .happy: return "😊"
            case .normal: return "😐"
            case .sad: return "😔"
            case .verySad: return "😢"
            }
        }
        
        var color: Color {
            switch self {
            case .veryHappy: return .yellow
            case .happy: return .green
            case .normal: return .gray
            case .sad: return .blue
            case .verySad: return .purple
            }
        }
    }
}