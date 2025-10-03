//
//  DailyFortuneDetailView.swift
//  PurpleM
//
//  流日分析视图 - 展示每日详细运势和时辰吉凶
//  完全依赖iztro库计算，不自己实现算法
//

import SwiftUI

struct DailyFortuneDetailView: View {
    @ObservedObject var iztroManager: IztroManager
    @State private var selectedDate = Date()
    @State private var dailyData: DailyData? = nil
    @State private var isLoading = false
    @State private var weekData: [DailyData] = []
    @State private var showHourlyDetail = false
    
    private var year: Int {
        Calendar.current.component(.year, from: selectedDate)
    }
    
    private var month: Int {
        Calendar.current.component(.month, from: selectedDate)
    }
    
    private var day: Int {
        Calendar.current.component(.day, from: selectedDate)
    }
    
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    // 标题栏
                    HStack {
                        Image(systemName: "sun.and.horizon.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("流日运势")
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundColor(.crystalWhite)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // 日期选择器
                    DateSelector(selectedDate: $selectedDate, onDateChange: { date in
                        loadDailyData(for: date)
                    })
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .starGold))
                            .padding(.top, 50)
                    } else if let data = dailyData {
                        // 今日总览
                        DailyOverviewCard(dailyData: data, selectedDate: selectedDate)
                            .padding(.horizontal)
                        
                        // 运势评分
                        DailyScoresCard(scores: data.scores)
                            .padding(.horizontal)
                        
                        // 吉时凶时
                        LuckyHoursCard(dailyData: data, showDetail: $showHourlyDetail)
                            .padding(.horizontal)
                        
                        // 宜忌事项
                        DosAndDontsCard(dailyData: data)
                            .padding(.horizontal)
                        
                        // 一周运势对比
                        WeeklyComparisonCard(weekData: weekData, selectedDay: day)
                            .padding(.horizontal)
                        
                        // 今日指引
                        DailyGuidanceCard(dailyData: data)
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            
            // 时辰详情弹窗
            if showHourlyDetail {
                HourlyDetailView(isPresented: $showHourlyDetail)
            }
        }
        .onAppear {
            loadDailyData(for: selectedDate)
            loadWeekData()
        }
    }
    
    // 加载流日数据
    private func loadDailyData(for date: Date) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        isLoading = true
        
        iztroManager.getDailyData(year: year, month: month, day: day) { data in
            DispatchQueue.main.async {
                self.dailyData = data
                self.isLoading = false
            }
        }
    }
    
    // 加载一周数据用于对比
    private func loadWeekData() {
        weekData.removeAll()
        
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                let year = calendar.component(.year, from: date)
                let month = calendar.component(.month, from: date)
                let day = calendar.component(.day, from: date)
                
                iztroManager.getDailyData(year: year, month: month, day: day) { data in
                    if let data = data {
                        DispatchQueue.main.async {
                            self.weekData.append(data)
                            self.weekData.sort { $0.day < $1.day }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 日期选择器
struct DateSelector: View {
    @Binding var selectedDate: Date
    let onDateChange: (Date) -> Void
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 15) {
                HStack(spacing: 20) {
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                        onDateChange(selectedDate)
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange.opacity(0.8))
                    }
                    
                    VStack(spacing: 5) {
                        Text(formatDate(selectedDate))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.crystalWhite)
                        
                        Text(getWeekday(selectedDate))
                            .font(.system(size: 14))
                            .foregroundColor(.moonSilver)
                    }
                    .frame(width: 150)
                    
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                        onDateChange(selectedDate)
                    }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange.opacity(0.8))
                    }
                }
                
                // 返回今天按钮
                if !Calendar.current.isDateInToday(selectedDate) {
                    Button(action: {
                        selectedDate = Date()
                        onDateChange(selectedDate)
                    }) {
                        Text("返回今天")
                            .font(.system(size: 12))
                            .foregroundColor(.starGold)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .stroke(Color.starGold.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
    
    private func getWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - 每日总览
struct DailyOverviewCard: View {
    let dailyData: DailyData
    let selectedDate: Date
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(formatFullDate(selectedDate))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.crystalWhite)
                        
                        Text("农历\(dailyData.lunarDay)")
                            .font(.system(size: 14))
                            .foregroundColor(.moonSilver)
                    }
                    
                    Spacer()
                    
                    // 综合评分
                    VStack(spacing: 5) {
                        Text("综合运势")
                            .font(.system(size: 12))
                            .foregroundColor(.moonSilver)
                        Text("\(dailyData.scores.overall)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [scoreColor(dailyData.scores.overall), scoreColor(dailyData.scores.overall).opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                
                // 今日一句话
                Text(getDailyQuote(score: dailyData.scores.overall))
                    .font(.system(size: 14).italic())
                    .foregroundColor(.starGold)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.starGold.opacity(0.05))
                    )
            }
        }
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .yellow
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func getDailyQuote(score: Int) -> String {
        if score >= 80 {
            return "今日运势极佳，诸事顺遂，把握良机！"
        } else if score >= 60 {
            return "运势不错，稳中有进，保持积极心态。"
        } else if score >= 40 {
            return "运势平平，谨慎行事，以守为攻。"
        } else {
            return "运势较弱，宜静不宜动，调整心态。"
        }
    }
}

// MARK: - 运势评分卡片
struct DailyScoresCard: View {
    let scores: FortuneScores
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundColor(.cyan)
                    Text("各项运势")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                HStack(spacing: 15) {
                    FortuneItem(title: "事业", score: scores.career, icon: "briefcase.fill", color: .blue)
                    FortuneItem(title: "财运", score: scores.wealth, icon: "dollarsign.circle.fill", color: .yellow)
                    FortuneItem(title: "感情", score: scores.love, icon: "heart.fill", color: .pink)
                    FortuneItem(title: "健康", score: scores.health, icon: "heart.circle.fill", color: .green)
                }
            }
        }
    }
}

struct FortuneItem: View {
    let title: String
    let score: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text("\(score)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.crystalWhite)
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.moonSilver)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - 吉时卡片
struct LuckyHoursCard: View {
    let dailyData: DailyData
    @Binding var showDetail: Bool
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.orange)
                    Text("吉时凶时")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                    
                    Button(action: {
                        showDetail = true
                    }) {
                        Text("详情")
                            .font(.system(size: 12))
                            .foregroundColor(.starGold)
                    }
                }
                
                // 吉时展示
                HStack(spacing: 10) {
                    ForEach(dailyData.luckyHours, id: \.self) { hour in
                        HourBadge(hour: hour, isLucky: true)
                    }
                }
                
                Text("点击详情查看24小时吉凶")
                    .font(.system(size: 11))
                    .foregroundColor(.moonSilver.opacity(0.6))
            }
        }
    }
}

struct HourBadge: View {
    let hour: String
    let isLucky: Bool
    
    var body: some View {
        Text(hour)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isLucky ? .white : .crystalWhite)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isLucky ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
            )
    }
}

// MARK: - 宜忌事项
struct DosAndDontsCard: View {
    let dailyData: DailyData
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 15) {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundColor(.cosmicPurple)
                    Text("宜忌事项")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                HStack(alignment: .top, spacing: 20) {
                    // 宜
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                            Text("宜")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        
                        ForEach(dailyData.suitable, id: \.self) { item in
                            Text(item)
                                .font(.system(size: 13))
                                .foregroundColor(.crystalWhite.opacity(0.9))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.green.opacity(0.1))
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 忌
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                            Text("忌")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        
                        ForEach(dailyData.avoid, id: \.self) { item in
                            Text(item)
                                .font(.system(size: 13))
                                .foregroundColor(.crystalWhite.opacity(0.9))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.red.opacity(0.1))
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - 一周运势对比
struct WeeklyComparisonCard: View {
    let weekData: [DailyData]
    let selectedDay: Int
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 15) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.starGold)
                    Text("本周运势")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(weekData, id: \.day) { data in
                        VStack(spacing: 5) {
                            Text("\(data.scores.overall)")
                                .font(.system(size: 10))
                                .foregroundColor(data.day == selectedDay ? .starGold : .moonSilver.opacity(0.6))
                            
                            Rectangle()
                                .fill(
                                    data.day == selectedDay ?
                                    LinearGradient(colors: [.starGold, .orange], startPoint: .bottom, endPoint: .top) :
                                    LinearGradient(colors: [.cosmicPurple.opacity(0.5), .cosmicPurple.opacity(0.3)], startPoint: .bottom, endPoint: .top)
                                )
                                .frame(height: CGFloat(data.scores.overall) * 1.2)
                                .cornerRadius(4)
                            
                            Text(getWeekdayShort(data.weekday))
                                .font(.system(size: 11))
                                .foregroundColor(data.day == selectedDay ? .starGold : .moonSilver.opacity(0.8))
                        }
                    }
                }
                .frame(height: 150)
            }
        }
    }
    
    private func getWeekdayShort(_ weekday: Int) -> String {
        let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
        return weekdays[weekday]
    }
}

// MARK: - 今日指引
struct DailyGuidanceCard: View {
    let dailyData: DailyData
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.max.fill")
                        .foregroundColor(.yellow)
                    Text("今日指引")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                Text(getDailyGuidance(dailyData: dailyData))
                    .font(.system(size: 13))
                    .foregroundColor(.crystalWhite.opacity(0.9))
                    .lineSpacing(4)
                
                // 主要影响宫位
                HStack {
                    Image(systemName: "location.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.mysticPink)
                    Text("今日重点关注：\(getPalaceName(index: dailyData.mainPalace))")
                        .font(.system(size: 13))
                        .foregroundColor(.crystalWhite.opacity(0.9))
                }
                .padding(.top, 5)
            }
        }
    }
    
    private func getDailyGuidance(dailyData: DailyData) -> String {
        let score = dailyData.scores.overall
        if score >= 80 {
            return "今天是充满机遇的一天，各方面运势都很不错。建议积极主动，把握机会，无论是工作还是人际交往都会有好的收获。适合做重要决定和开展新计划。"
        } else if score >= 60 {
            return "今日运势平稳向好，适合按部就班地推进既定计划。工作上保持专注，感情上多些关心，财运方面谨慎理财。整体来说是稳中有进的一天。"
        } else if score >= 40 {
            return "今天需要多加小心，运势有些起伏。建议低调行事，避免冲突和争执。工作上以守为主，不宜做重大改变。多关注身体健康，保持良好心态。"
        } else {
            return "今日运势较弱，诸事不顺。建议静心调整，不要强求。避免重要决策和投资，多休息，调理身心。困难只是暂时的，保持耐心等待转机。"
        }
    }
    
    private func getPalaceName(index: Int) -> String {
        let palaces = ["命宫", "兄弟", "夫妻", "子女", "财帛", "疾厄", "迁移", "交友", "官禄", "田宅", "福德", "父母"]
        return palaces[index % 12]
    }
}

// MARK: - 时辰详情弹窗
struct HourlyDetailView: View {
    @Binding var isPresented: Bool
    
    let hours = [
        ("子时", "23:00-01:00", true),
        ("丑时", "01:00-03:00", false),
        ("寅时", "03:00-05:00", false),
        ("卯时", "05:00-07:00", true),
        ("辰时", "07:00-09:00", true),
        ("巳时", "09:00-11:00", false),
        ("午时", "11:00-13:00", true),
        ("未时", "13:00-15:00", false),
        ("申时", "15:00-17:00", true),
        ("酉时", "17:00-19:00", false),
        ("戌时", "19:00-21:00", false),
        ("亥时", "21:00-23:00", true)
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 20) {
                HStack {
                    Text("24小时吉凶")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.moonSilver.opacity(0.6))
                    }
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    ForEach(hours, id: \.0) { hour in
                        HourCard(name: hour.0, time: hour.1, isLucky: hour.2)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.9))
            )
            .padding(.horizontal, 30)
        }
    }
}

struct HourCard: View {
    let name: String
    let time: String
    let isLucky: Bool
    
    var body: some View {
        VStack(spacing: 5) {
            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.crystalWhite)
            
            Text(time)
                .font(.system(size: 11))
                .foregroundColor(.moonSilver)
            
            Text(isLucky ? "吉" : "凶")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isLucky ? .green : .red)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill((isLucky ? Color.green : Color.red).opacity(0.2))
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke((isLucky ? Color.green : Color.red).opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct DailyFortuneDetailView_Previews: PreviewProvider {
    static var previews: some View {
        DailyFortuneDetailView(iztroManager: IztroManager())
    }
}