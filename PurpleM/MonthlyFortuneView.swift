//
//  MonthlyFortuneView.swift
//  PurpleM
//
//  流月分析视图 - 展示每月详细运势
//  完全依赖iztro库计算，不自己实现算法
//

import SwiftUI

struct MonthlyFortuneView: View {
    @ObservedObject var iztroManager: IztroManager
    @State private var selectedDate = Date()
    @State private var monthlyData: MonthlyData? = nil
    @State private var isLoading = false
    @State private var dailyDataList: [DailyData] = []
    @State private var selectedDay: Int = Calendar.current.component(.day, from: Date())
    
    private var year: Int {
        Calendar.current.component(.year, from: selectedDate)
    }
    
    private var month: Int {
        Calendar.current.component(.month, from: selectedDate)
    }
    
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    // 标题栏
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.mysticPink, .cosmicPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("流月运势")
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundColor(.crystalWhite)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // 月份选择器
                    MonthSelector(selectedDate: $selectedDate, onDateChange: { date in
                        loadMonthlyData(for: date)
                    })
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .starGold))
                            .padding(.top, 50)
                    } else {
                        // 月度总览
                        if let data = monthlyData {
                            MonthOverviewCard(monthlyData: data)
                                .padding(.horizontal)
                            
                            // 月度运势评分
                            MonthScoresCard(scores: data.scores)
                                .padding(.horizontal)
                            
                            // 日历视图
                            MonthCalendarView(
                                year: year,
                                month: month,
                                selectedDay: $selectedDay,
                                dailyDataList: dailyDataList
                            )
                            .padding(.horizontal)
                            
                            // 选中日期详情
                            if let dailyData = dailyDataList.first(where: { $0.day == selectedDay }) {
                                DayDetailCard(dailyData: dailyData)
                                    .padding(.horizontal)
                            }
                            
                            // 月度建议
                            MonthAdviceCard(month: month)
                                .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .onAppear {
            loadMonthlyData(for: selectedDate)
            loadAllDailyData()
        }
    }
    
    // 加载流月数据
    private func loadMonthlyData(for date: Date) {
        let year = Calendar.current.component(.year, from: date)
        let month = Calendar.current.component(.month, from: date)
        
        isLoading = true
        
        iztroManager.getMonthlyData(year: year, month: month) { data in
            DispatchQueue.main.async {
                self.monthlyData = data
                self.isLoading = false
                self.loadAllDailyData()
            }
        }
    }
    
    // 加载整月的每日数据
    private func loadAllDailyData() {
        dailyDataList.removeAll()
        
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: selectedDate)!
        
        for day in 1...range.count {
            iztroManager.getDailyData(year: year, month: month, day: day) { data in
                if let data = data {
                    DispatchQueue.main.async {
                        self.dailyDataList.append(data)
                        self.dailyDataList.sort { $0.day < $1.day }
                    }
                }
            }
        }
    }
}

// MARK: - 月份选择器
struct MonthSelector: View {
    @Binding var selectedDate: Date
    let onDateChange: (Date) -> Void
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 15) {
                HStack(spacing: 20) {
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                        onDateChange(selectedDate)
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title2)
                            .foregroundColor(.mysticPink.opacity(0.8))
                    }
                    
                    VStack(spacing: 5) {
                        Text("\(Calendar.current.component(.year, from: selectedDate))年")
                            .font(.system(size: 14))
                            .foregroundColor(.moonSilver)
                        
                        Text("\(Calendar.current.component(.month, from: selectedDate))月")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.mysticPink, .cosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .frame(width: 100)
                    
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                        onDateChange(selectedDate)
                    }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title2)
                            .foregroundColor(.mysticPink.opacity(0.8))
                    }
                }
                
                // 快速跳转到当月
                Button(action: {
                    selectedDate = Date()
                    onDateChange(selectedDate)
                }) {
                    Text("返回本月")
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

// MARK: - 月度总览卡片
struct MonthOverviewCard: View {
    let monthlyData: MonthlyData
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "moon.stars")
                        .foregroundColor(.starGold)
                    Text("本月主题")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                Text(monthlyData.mainInfluence)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.starGold)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.starGold.opacity(0.1))
                    )
                
                // 重点宫位
                if let focusPalace = monthlyData.palaces.first(where: { $0.isMonthlyFocus }) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.mysticPink)
                        Text("本月重点宫位：\(focusPalace.name)")
                            .font(.system(size: 14))
                            .foregroundColor(.crystalWhite.opacity(0.9))
                    }
                }
            }
        }
    }
}

// MARK: - 月度运势评分
struct MonthScoresCard: View {
    let scores: FortuneScores
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 15) {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(.cyan)
                    Text("本月运势")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                    
                    Text("\(scores.overall)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.starGold, .mysticPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                VStack(spacing: 10) {
                    ScoreBar(label: "事业", score: scores.career, color: .blue)
                    ScoreBar(label: "财运", score: scores.wealth, color: .yellow)
                    ScoreBar(label: "感情", score: scores.love, color: .pink)
                    ScoreBar(label: "健康", score: scores.health, color: .green)
                }
            }
        }
    }
}

struct ScoreBar: View {
    let label: String
    let score: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.moonSilver)
                .frame(width: 40, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.8))
                        .frame(width: geometry.size.width * CGFloat(score) / 100, height: 6)
                }
            }
            .frame(height: 6)
            
            Text("\(score)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
                .frame(width: 30)
        }
    }
}

// MARK: - 月历视图
struct MonthCalendarView: View {
    let year: Int
    let month: Int
    @Binding var selectedDay: Int
    let dailyDataList: [DailyData]
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 15) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.cosmicPurple)
                    Text("日历")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                // 星期标题
                HStack {
                    ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12))
                            .foregroundColor(.moonSilver)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // 日历网格
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                    // 填充前面的空白
                    ForEach(0..<firstWeekday, id: \.self) { _ in
                        Color.clear
                            .frame(height: 40)
                    }
                    
                    // 实际日期
                    ForEach(1...numberOfDays, id: \.self) { day in
                        DayCell(
                            day: day,
                            isSelected: selectedDay == day,
                            isToday: isToday(day: day),
                            score: dailyDataList.first(where: { $0.day == day })?.scores.overall,
                            onTap: {
                                withAnimation {
                                    selectedDay = day
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var firstWeekday: Int {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month, day: 1)
        let firstDay = calendar.date(from: components)!
        return calendar.component(.weekday, from: firstDay) - 1
    }
    
    private var numberOfDays: Int {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month)
        let date = calendar.date(from: components)!
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }
    
    private func isToday(day: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        return calendar.component(.year, from: today) == year &&
               calendar.component(.month, from: today) == month &&
               calendar.component(.day, from: today) == day
    }
}

// MARK: - 日期单元格
struct DayCell: View {
    let day: Int
    let isSelected: Bool
    let isToday: Bool
    let score: Int?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                    .foregroundColor(textColor)
                
                if let score = score {
                    Circle()
                        .fill(scoreColor(score))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .starGold
        } else {
            return .crystalWhite
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.mysticPink.opacity(0.8)
        } else if isToday {
            return Color.starGold.opacity(0.1)
        } else {
            return Color.white.opacity(0.05)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return .mysticPink
        } else if isToday {
            return .starGold.opacity(0.5)
        } else {
            return .clear
        }
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
}

// MARK: - 日详情卡片
struct DayDetailCard: View {
    let dailyData: DailyData
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.yellow)
                    Text("\(dailyData.month)月\(dailyData.day)日详情")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                    Text("农历\(dailyData.lunarDay)")
                        .font(.system(size: 12))
                        .foregroundColor(.moonSilver)
                }
                
                // 吉时
                HStack(alignment: .top) {
                    Text("吉时：")
                        .font(.system(size: 13))
                        .foregroundColor(.starGold)
                    Text(dailyData.luckyHours.joined(separator: "、"))
                        .font(.system(size: 13))
                        .foregroundColor(.crystalWhite.opacity(0.9))
                }
                
                // 宜忌
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("宜")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.green)
                        ForEach(dailyData.suitable, id: \.self) { item in
                            Text("• \(item)")
                                .font(.system(size: 12))
                                .foregroundColor(.crystalWhite.opacity(0.8))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("忌")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red)
                        ForEach(dailyData.avoid, id: \.self) { item in
                            Text("• \(item)")
                                .font(.system(size: 12))
                                .foregroundColor(.crystalWhite.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - 月度建议
struct MonthAdviceCard: View {
    let month: Int
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.circle")
                        .foregroundColor(.yellow)
                    Text("本月建议")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                Text(getMonthAdvice(month: month))
                    .font(.system(size: 13))
                    .foregroundColor(.crystalWhite.opacity(0.9))
                    .lineSpacing(4)
            }
        }
    }
    
    private func getMonthAdvice(month: Int) -> String {
        let advices = [
            "年初制定计划，稳扎稳打。注意健康，避免过度劳累。",
            "春寒料峭，保重身体。工作上可能有新机遇，要把握时机。",
            "春暖花开，适合社交拓展人脉。感情方面会有好的进展。",
            "事业发展关键期，需要全力以赴。财运不错，可适当投资。",
            "创意和灵感爆发期，适合学习新技能。注意劳逸结合。",
            "年中调整期，回顾上半年得失，调整下半年计划。",
            "下半年开端，重新出发。外出旅行会带来好运。",
            "收获的季节，之前的努力会看到成果。适合签约合作。",
            "学习运佳，考试升学顺利。人际关系需要维护。",
            "深秋时节，适合思考和规划。投资需谨慎。",
            "年末冲刺，把握最后机会。注意身体健康。",
            "总结全年，展望来年。适合与家人团聚，增进感情。"
        ]
        return advices[month - 1]
    }
}

struct MonthlyFortuneView_Previews: PreviewProvider {
    static var previews: some View {
        MonthlyFortuneView(iztroManager: IztroManager())
    }
}