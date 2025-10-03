//
//  YearlyFortuneView.swift
//  PurpleM
//
//  流年运势视图 - 展示年度和月度运势分析
//  完全依赖iztro库计算，不自己实现算法
//

import SwiftUI
import Charts

struct YearlyFortuneView: View {
    @ObservedObject var iztroManager: IztroManager
    @StateObject private var userDataManager = UserDataManager.shared
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var yearlyData: YearlyData? = nil
    @State private var isLoading = false
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var monthlyScores: [MonthScore] = []
    
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    // 标题栏
                    HStack {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.starGold, .cosmicPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("流年运势")
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundColor(.crystalWhite)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // 年份选择器
                    YearSelector(selectedYear: $selectedYear, onYearChange: { year in
                        loadYearlyData(for: year)
                    })
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .starGold))
                            .padding(.top, 50)
                    } else {
                        // 年度总览
                        YearOverviewCard(year: selectedYear, yearlyData: yearlyData)
                            .padding(.horizontal)
                        
                        // 运势趋势图
                        if !monthlyScores.isEmpty {
                            FortuneTrendChart(monthlyScores: monthlyScores, selectedMonth: $selectedMonth)
                                .padding(.horizontal)
                        }
                        
                        // 月度详情
                        MonthlyDetailCard(month: selectedMonth, yearlyData: yearlyData)
                            .padding(.horizontal)
                        
                        // 流年四化
                        YearlyMutagenCard(yearlyData: yearlyData)
                            .padding(.horizontal)
                        
                        // 重要提醒
                        YearlyRemindersCard(year: selectedYear)
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .onAppear {
            loadYearlyData(for: selectedYear)
            generateMonthlyScores()
        }
    }
    
    // 加载流年数据
    private func loadYearlyData(for year: Int) {
        isLoading = true
        
        iztroManager.getYearlyData(year: year) { data in
            DispatchQueue.main.async {
                self.yearlyData = data
                self.isLoading = false
                self.generateMonthlyScores()
            }
        }
    }
    
    // 生成月度运势分数（模拟数据，实际应从iztro获取）
    private func generateMonthlyScores() {
        var scores: [MonthScore] = []
        
        for month in 1...12 {
            // 这里应该根据流年数据计算每月运势
            // 暂时使用模拟数据
            let baseScore = 60 + Int.random(in: -20...30)
            scores.append(MonthScore(
                month: month,
                score: min(100, max(0, baseScore)),
                fortune: getMonthFortune(month: month)
            ))
        }
        
        monthlyScores = scores
    }
    
    private func getMonthFortune(month: Int) -> String {
        let fortunes = [
            "事业有成", "财运亨通", "贵人相助", "感情顺利",
            "学业进步", "健康良好", "出行顺利", "投资获利",
            "人际和谐", "创意爆发", "机遇降临", "心想事成"
        ]
        return fortunes[month - 1]
    }
}

// MARK: - 年份选择器
struct YearSelector: View {
    @Binding var selectedYear: Int
    let onYearChange: (Int) -> Void
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 15) {
                Text("选择年份")
                    .font(.system(size: 14))
                    .foregroundColor(.moonSilver)
                
                HStack(spacing: 20) {
                    Button(action: {
                        selectedYear -= 1
                        onYearChange(selectedYear)
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title2)
                            .foregroundColor(.cosmicPurple.opacity(0.8))
                    }
                    
                    Text("\(selectedYear)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.starGold, .cosmicPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 100)
                    
                    Text("年")
                        .font(.system(size: 20))
                        .foregroundColor(.crystalWhite)
                    
                    Button(action: {
                        selectedYear += 1
                        onYearChange(selectedYear)
                    }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title2)
                            .foregroundColor(.cosmicPurple.opacity(0.8))
                    }
                }
                
                // 快速跳转到当前年
                Button(action: {
                    let currentYear = Calendar.current.component(.year, from: Date())
                    selectedYear = currentYear
                    onYearChange(currentYear)
                }) {
                    Text("返回今年")
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

// MARK: - 年度总览卡片
struct YearOverviewCard: View {
    let year: Int
    let yearlyData: YearlyData?
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.starGold)
                    Text("\(year)年运势总览")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                // 年度评分
                HStack(spacing: 30) {
                    VStack {
                        Text("综合运势")
                            .font(.system(size: 12))
                            .foregroundColor(.moonSilver)
                        
                        Text("\(calculateYearScore())")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.starGold, .mysticPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FortuneIndicator(label: "事业", score: 75, color: .blue)
                        FortuneIndicator(label: "财运", score: 80, color: .yellow)
                        FortuneIndicator(label: "感情", score: 70, color: .pink)
                        FortuneIndicator(label: "健康", score: 85, color: .green)
                    }
                    
                    Spacer()
                }
                
                // 年度关键词
                HStack(spacing: 10) {
                    ForEach(getYearKeywords(), id: \.self) { keyword in
                        Text(keyword)
                            .font(.system(size: 12))
                            .foregroundColor(.crystalWhite)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.cosmicPurple.opacity(0.3))
                            )
                    }
                }
            }
        }
    }
    
    private func calculateYearScore() -> Int {
        // 根据流年数据计算，暂时返回模拟值
        return 75
    }
    
    private func getYearKeywords() -> [String] {
        // 根据流年特点返回关键词
        return ["稳步上升", "贵人相助", "把握机遇"]
    }
}

// MARK: - 运势指示器
struct FortuneIndicator: View {
    let label: String
    let score: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.moonSilver)
                .frame(width: 30)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.8))
                        .frame(width: geometry.size.width * CGFloat(score) / 100, height: 4)
                }
            }
            .frame(width: 60, height: 4)
            
            Text("\(score)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
        }
    }
}

// MARK: - 运势趋势图
struct FortuneTrendChart: View {
    let monthlyScores: [MonthScore]
    @Binding var selectedMonth: Int
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.cyan)
                    Text("月度运势趋势")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                // 使用简单的柱状图代替Charts框架
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(monthlyScores, id: \.month) { score in
                        VStack(spacing: 4) {
                            Text("\(score.score)")
                                .font(.system(size: 8))
                                .foregroundColor(selectedMonth == score.month ? .starGold : .moonSilver.opacity(0.6))
                            
                            Rectangle()
                                .fill(
                                    selectedMonth == score.month ?
                                    LinearGradient(colors: [.starGold, .mysticPink], startPoint: .bottom, endPoint: .top) :
                                    LinearGradient(colors: [.cosmicPurple.opacity(0.5), .cosmicPurple.opacity(0.3)], startPoint: .bottom, endPoint: .top)
                                )
                                .frame(height: CGFloat(score.score) * 1.5)
                                .cornerRadius(2)
                            
                            Text("\(score.month)")
                                .font(.system(size: 10))
                                .foregroundColor(selectedMonth == score.month ? .starGold : .moonSilver.opacity(0.8))
                        }
                        .onTapGesture {
                            withAnimation {
                                selectedMonth = score.month
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }
}

// MARK: - 月度详情卡片
struct MonthlyDetailCard: View {
    let month: Int
    let yearlyData: YearlyData?
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar.day.timeline.left")
                        .foregroundColor(.mysticPink)
                    Text("\(month)月运势详情")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                Text(getMonthlyDescription(month: month))
                    .font(.system(size: 13))
                    .foregroundColor(.crystalWhite.opacity(0.9))
                    .lineSpacing(4)
                
                // 本月重点
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.starGold)
                        Text("本月宜：\(getMonthlyDo(month: month))")
                            .font(.system(size: 13))
                            .foregroundColor(.crystalWhite.opacity(0.9))
                    }
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("本月忌：\(getMonthlyDont(month: month))")
                            .font(.system(size: 13))
                            .foregroundColor(.crystalWhite.opacity(0.9))
                    }
                }
                .padding(.top, 5)
            }
        }
    }
    
    private func getMonthlyDescription(month: Int) -> String {
        let descriptions = [
            "新年伊始，万象更新，适合制定全年计划。",
            "春回大地，生机勃勃，事业开始起步。",
            "春暖花开，贵人相助，人际关系活跃。",
            "承上启下，稳步前进，财运逐渐提升。",
            "活力充沛，创意无限，适合开展新项目。",
            "年中转折，调整方向，注意劳逸结合。",
            "下半年开端，重新出发，把握新机遇。",
            "收获季节，努力有回报，财运亨通。",
            "金秋时节，学业事业双丰收。",
            "深秋反思，总结经验，规划未来。",
            "年末冲刺，全力以赴，创造佳绩。",
            "岁末年终，总结全年，展望来年。"
        ]
        return descriptions[month - 1]
    }
    
    private func getMonthlyDo(month: Int) -> String {
        let dos = [
            "开始新计划", "拓展人脉", "投资理财", "学习进修",
            "创新创业", "休养生息", "外出旅行", "签约合作",
            "求职跳槽", "表白求婚", "装修搬家", "总结规划"
        ]
        return dos[month - 1]
    }
    
    private func getMonthlyDont(month: Int) -> String {
        let donts = [
            "冲动决策", "过度消费", "轻信他人", "忽视健康",
            "急于求成", "情绪化", "冒险投资", "口舌是非",
            "拖延懈怠", "固执己见", "透支身体", "铺张浪费"
        ]
        return donts[month - 1]
    }
}

// MARK: - 流年四化卡片
struct YearlyMutagenCard: View {
    let yearlyData: YearlyData?
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath.circle")
                        .foregroundColor(.cosmicPurple)
                    Text("流年四化")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                Text("四化是紫微斗数中的重要概念，影响流年运势的关键因素。")
                    .font(.system(size: 12))
                    .foregroundColor(.moonSilver.opacity(0.9))
                    .lineSpacing(3)
                
                // 四化展示（需要从iztro获取实际数据）
                HStack(spacing: 15) {
                    MutagenItem(type: "化禄", star: "天机", color: .green)
                    MutagenItem(type: "化权", star: "天梁", color: .orange)
                    MutagenItem(type: "化科", star: "紫微", color: .blue)
                    MutagenItem(type: "化忌", star: "太阳", color: .red)
                }
            }
        }
    }
}

struct MutagenItem: View {
    let type: String
    let star: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Text(type)
                .font(.system(size: 11))
                .foregroundColor(color)
            
            Text(star)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.crystalWhite)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(color.opacity(0.5), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - 年度重要提醒
struct YearlyRemindersCard: View {
    let year: Int
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bell.badge.circle")
                        .foregroundColor(.yellow)
                    Text("年度重要提醒")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    ReminderItem(icon: "checkmark.circle.fill", text: "上半年适合开展新项目", color: .green)
                    ReminderItem(icon: "star.circle.fill", text: "5-7月贵人运旺盛", color: .starGold)
                    ReminderItem(icon: "heart.circle.fill", text: "8-10月感情机遇多", color: .pink)
                    ReminderItem(icon: "exclamationmark.circle.fill", text: "年底注意健康保养", color: .orange)
                }
            }
        }
    }
}

struct ReminderItem: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.crystalWhite.opacity(0.9))
        }
    }
}

// MARK: - 数据模型
struct MonthScore {
    let month: Int
    let score: Int
    let fortune: String
}

struct YearlyFortuneView_Previews: PreviewProvider {
    static var previews: some View {
        YearlyFortuneView(iztroManager: IztroManager())
    }
}