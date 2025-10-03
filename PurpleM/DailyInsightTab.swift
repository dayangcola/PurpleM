//
//  DailyInsightTab.swift
//  PurpleM
//
//  Tab2: 今日要点 - 每日运势和个人洞察
//

import SwiftUI

struct DailyInsightTab: View {
    @StateObject private var userDataManager = UserDataManager.shared
    @State private var currentDate = Date()
    @State private var dailyFortune: DailyFortune?
    @State private var showMoodPicker = false
    @State private var selectedMood: MoodRecord.MoodType = .normal
    @State private var moodNote = ""
    @State private var todayMoodRecord: MoodRecord?
    
    var body: some View {
        NavigationView {
            ZStack {
                // 复用相同的背景
                AnimatedBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 顶部日期和标题
                        VStack(spacing: 8) {
                            Text("今日要点")
                                .font(.system(size: 28, weight: .light, design: .serif))
                                .foregroundColor(.crystalWhite)
                            
                            Text(formatDate(currentDate))
                                .font(.system(size: 16))
                                .foregroundColor(.moonSilver)
                        }
                        .padding(.top, 20)
                        
                        if userDataManager.hasGeneratedChart {
                            // 有星盘数据，显示运势
                            if let fortune = dailyFortune {
                                // 综合运势卡片
                                OverallFortuneCard(fortune: fortune)
                                    .padding(.horizontal)
                                
                                // 各项运势
                                FortuneDetailsCard(fortune: fortune)
                                    .padding(.horizontal)
                                
                                // 幸运元素
                                LuckyElementsCard(fortune: fortune)
                                    .padding(.horizontal)
                                
                                // 星耀影响
                                StarInfluenceCard(fortune: fortune)
                                    .padding(.horizontal)
                                
                                // 今日建议
                                AdviceCard(fortune: fortune)
                                    .padding(.horizontal)
                                
                                // 心情记录
                                MoodRecordCard(
                                    todayMoodRecord: $todayMoodRecord,
                                    showMoodPicker: $showMoodPicker
                                )
                                .padding(.horizontal)
                            } else {
                                // 加载中
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .starGold))
                                    .padding(.top, 100)
                            }
                        } else {
                            // 没有星盘数据，提示生成
                            NoChartPromptView()
                                .padding(.horizontal)
                                .padding(.top, 50)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                calculateTodayFortune()
                loadTodayMoodRecord()
            }
            .sheet(isPresented: $showMoodPicker) {
                MoodPickerView(
                    selectedMood: $selectedMood,
                    moodNote: $moodNote,
                    onSave: saveMoodRecord
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日 EEEE"
        return formatter.string(from: date)
    }
    
    private func calculateTodayFortune() {
        dailyFortune = DailyFortuneEngine.calculateDailyFortune(
            chartData: userDataManager.currentChart,
            date: currentDate
        )
    }
    
    private func loadTodayMoodRecord() {
        // 从UserDefaults加载今天的心情记录
        let key = "MoodRecord_\(formatDateKey(currentDate))"
        if let data = UserDefaults.standard.data(forKey: key),
           let record = try? JSONDecoder().decode(MoodRecord.self, from: data) {
            todayMoodRecord = record
        }
    }
    
    private func saveMoodRecord() {
        let record = MoodRecord(
            date: currentDate,
            mood: selectedMood,
            note: moodNote.isEmpty ? nil : moodNote,
            fortuneScore: dailyFortune?.overallScore ?? 0
        )
        
        // 保存到UserDefaults
        let key = "MoodRecord_\(formatDateKey(currentDate))"
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: key)
            todayMoodRecord = record
        }
        
        showMoodPicker = false
    }
    
    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}

// MARK: - 综合运势卡片
struct OverallFortuneCard: View {
    let fortune: DailyFortune
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "star.circle.fill")
                        .font(.title2)
                        .foregroundColor(.starGold)
                    
                    Text("综合运势")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    
                    Spacer()
                    
                    Text("\(fortune.overallScore)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [scoreColor(fortune.overallScore), scoreColor(fortune.overallScore).opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // 运势条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 10)
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [scoreColor(fortune.overallScore), scoreColor(fortune.overallScore).opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(fortune.overallScore) / 100, height: 10)
                    }
                }
                .frame(height: 10)
                
                Text(getFortuneDescription(score: fortune.overallScore))
                    .font(.system(size: 16))
                    .foregroundColor(.moonSilver)
            }
        }
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 {
            return .starGold
        } else if score >= 60 {
            return .green
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func getFortuneDescription(score: Int) -> String {
        if score >= 90 {
            return "今日运势绝佳，万事如意！"
        } else if score >= 80 {
            return "运势大吉，把握机会！"
        } else if score >= 70 {
            return "运势不错，稳步前进。"
        } else if score >= 60 {
            return "运势平顺，保持积极。"
        } else if score >= 50 {
            return "运势一般，谨慎行事。"
        } else if score >= 40 {
            return "运势欠佳，需要小心。"
        } else {
            return "运势较弱，宜静不宜动。"
        }
    }
}

// MARK: - 各项运势详情
struct FortuneDetailsCard: View {
    let fortune: DailyFortune
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 15) {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(.mysticPink)
                    Text("运势详情")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    FortuneBar(icon: "briefcase", title: "事业", score: fortune.careerScore, color: .blue)
                    FortuneBar(icon: "heart", title: "爱情", score: fortune.loveScore, color: .pink)
                    FortuneBar(icon: "dollarsign.circle", title: "财运", score: fortune.wealthScore, color: .yellow)
                    FortuneBar(icon: "heart.circle", title: "健康", score: fortune.healthScore, color: .green)
                }
            }
        }
    }
}

// 单项运势条
struct FortuneBar: View {
    let icon: String
    let title: String
    let score: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 25)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.crystalWhite)
                .frame(width: 40, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.8))
                        .frame(width: geometry.size.width * CGFloat(score) / 100, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(score)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(width: 30)
        }
    }
}

// MARK: - 幸运元素卡片
struct LuckyElementsCard: View {
    let fortune: DailyFortune
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 15) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.starGold)
                    Text("幸运元素")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                HStack(spacing: 20) {
                    // 幸运色
                    VStack(spacing: 8) {
                        Circle()
                            .fill(fortune.luckyColor)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                        Text("幸运色")
                            .font(.system(size: 12))
                            .foregroundColor(.moonSilver)
                    }
                    
                    // 幸运数字
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.starGold.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Text("\(fortune.luckyNumber)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.starGold)
                        }
                        Text("幸运数")
                            .font(.system(size: 12))
                            .foregroundColor(.moonSilver)
                    }
                    
                    // 幸运方位
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Text(fortune.luckyDirection)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.cyan)
                        }
                        Text("幸运方位")
                            .font(.system(size: 12))
                            .foregroundColor(.moonSilver)
                    }
                    
                    Spacer()
                }
                
                // 吉时
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("吉时：\(fortune.luckyTime)")
                        .font(.system(size: 14))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - 星耀影响卡片
struct StarInfluenceCard: View {
    let fortune: DailyFortune
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "moon.stars")
                        .foregroundColor(.cosmicPurple)
                    Text("星象影响")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text("星耀：")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.starGold)
                        Text(fortune.starInfluence)
                            .font(.system(size: 14))
                            .foregroundColor(.crystalWhite.opacity(0.9))
                    }
                    
                    HStack(alignment: .top) {
                        Text("宫位：")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.mysticPink)
                        Text(fortune.palaceInfluence)
                            .font(.system(size: 14))
                            .foregroundColor(.crystalWhite.opacity(0.9))
                    }
                }
            }
        }
    }
}

// MARK: - 建议卡片
struct AdviceCard: View {
    let fortune: DailyFortune
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                    Text("今日指引")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        Text(fortune.advice)
                            .font(.system(size: 14))
                            .foregroundColor(.crystalWhite.opacity(0.9))
                            .lineSpacing(4)
                    }
                    
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                        Text(fortune.warning)
                            .font(.system(size: 14))
                            .foregroundColor(.crystalWhite.opacity(0.9))
                            .lineSpacing(4)
                    }
                }
            }
        }
    }
}

// MARK: - 心情记录卡片
struct MoodRecordCard: View {
    @Binding var todayMoodRecord: MoodRecord?
    @Binding var showMoodPicker: Bool
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 15) {
                HStack {
                    Image(systemName: "heart.text.square")
                        .foregroundColor(.pink)
                    Text("心情记录")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                if let record = todayMoodRecord {
                    // 已记录心情
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(record.mood.emoji)
                                .font(.system(size: 30))
                            Text(record.mood.rawValue)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.crystalWhite)
                            Spacer()
                            Button(action: {
                                showMoodPicker = true
                            }) {
                                Text("修改")
                                    .font(.system(size: 12))
                                    .foregroundColor(.mysticPink)
                            }
                        }
                        
                        if let note = record.note {
                            Text(note)
                                .font(.system(size: 14))
                                .foregroundColor(.moonSilver)
                                .lineSpacing(4)
                        }
                    }
                } else {
                    // 未记录心情
                    Button(action: {
                        showMoodPicker = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("记录今日心情")
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.mysticPink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.mysticPink.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - 心情选择器
struct MoodPickerView: View {
    @Binding var selectedMood: MoodRecord.MoodType
    @Binding var moodNote: String
    @Environment(\.presentationMode) var presentationMode
    let onSave: () -> Void
    
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            VStack(spacing: 25) {
                // 标题
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.moonSilver.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Text("记录心情")
                        .font(.system(size: 24, weight: .light, design: .serif))
                        .foregroundColor(.crystalWhite)
                    
                    Spacer()
                    
                    Button(action: {
                        onSave()
                    }) {
                        Text("保存")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.starGold)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // 心情选择
                VStack(spacing: 20) {
                    Text("今天的心情如何？")
                        .font(.system(size: 18))
                        .foregroundColor(.crystalWhite)
                    
                    HStack(spacing: 15) {
                        ForEach(MoodRecord.MoodType.allCases, id: \.self) { mood in
                            Button(action: {
                                withAnimation(.spring()) {
                                    selectedMood = mood
                                }
                            }) {
                                VStack(spacing: 8) {
                                    Text(mood.emoji)
                                        .font(.system(size: 30))
                                    
                                    Text(mood.rawValue)
                                        .font(.system(size: 10))
                                        .foregroundColor(selectedMood == mood ? .crystalWhite : .moonSilver.opacity(0.6))
                                }
                                .frame(width: 60, height: 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedMood == mood ? mood.color.opacity(0.3) : Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedMood == mood ? mood.color : Color.clear, lineWidth: 2)
                                        )
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // 备注输入
                VStack(alignment: .leading, spacing: 10) {
                    Text("备注（可选）")
                        .font(.system(size: 14))
                        .foregroundColor(.moonSilver)
                    
                    TextEditor(text: $moodNote)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.crystalWhite)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.moonSilver.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
}

// MARK: - 无星盘提示
struct NoChartPromptView: View {
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 20) {
                Image(systemName: "star.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.moonSilver.opacity(0.5))
                
                Text("还没有生成星盘")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.crystalWhite)
                
                Text("请先在星盘页面生成您的专属星盘\n即可查看每日运势")
                    .font(.system(size: 14))
                    .foregroundColor(.moonSilver.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.vertical, 30)
        }
    }
}

struct DailyInsightTab_Previews: PreviewProvider {
    static var previews: some View {
        DailyInsightTab()
    }
}