//
//  ZiWeiContentView.swift
//  PurpleM
//
//  紫微斗数专业排盘界面
//

import SwiftUI

struct ZiWeiContentView: View {
    @StateObject private var iztroManager = IztroManager()
    @State private var selectedDate = Date()
    @State private var selectedGender = "男"
    @State private var isLunarDate = false
    @State private var showingResult = false
    @State private var birthPlace = "北京"
    
    // 中国传统色彩
    let purpleColor = Color(red: 102/255, green: 51/255, blue: 153/255)
    let goldColor = Color(red: 255/255, green: 215/255, blue: 0/255)
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 245/255, green: 245/255, blue: 250/255),
                        Color(red: 230/255, green: 230/255, blue: 240/255)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 标题部分
                        VStack(spacing: 8) {
                            Text("紫微斗数")
                                .font(.system(size: 36, weight: .bold, design: .serif))
                                .foregroundColor(purpleColor)
                            
                            Text("专业排盘系统")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        
                        // 输入卡片
                        VStack(spacing: 16) {
                            // 性别选择
                            HStack(spacing: 0) {
                                ForEach(["男", "女"], id: \.self) { gender in
                                    Button(action: {
                                        selectedGender = gender
                                    }) {
                                        Text(gender)
                                            .font(.system(size: 18, weight: .medium))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                selectedGender == gender ?
                                                purpleColor : Color.white
                                            )
                                            .foregroundColor(
                                                selectedGender == gender ?
                                                .white : .black
                                            )
                                    }
                                }
                            }
                            .cornerRadius(10)
                            .shadow(color: .gray.opacity(0.2), radius: 5)
                            
                            // 日期类型切换
                            HStack {
                                Text("历法")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                
                                Picker("", selection: $isLunarDate) {
                                    Text("公历").tag(false)
                                    Text("农历").tag(true)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            // 日期时间选择
                            VStack(alignment: .leading, spacing: 12) {
                                Label("出生日期", systemImage: "calendar")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(purpleColor)
                                
                                DatePicker(
                                    "",
                                    selection: $selectedDate,
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(CompactDatePickerStyle())
                                .labelsHidden()
                                
                                Label("出生时辰", systemImage: "clock")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(purpleColor)
                                
                                DatePicker(
                                    "",
                                    selection: $selectedDate,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .datePickerStyle(CompactDatePickerStyle())
                                .labelsHidden()
                                
                                Label("出生地", systemImage: "location")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(purpleColor)
                                
                                TextField("请输入出生地", text: $birthPlace)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .gray.opacity(0.1), radius: 5)
                        }
                        .padding(.horizontal)
                        
                        // 排盘按钮
                        Button(action: calculateAstrolabe) {
                            HStack {
                                if iztroManager.isCalculating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "sparkles")
                                    Text(iztroManager.isReady ? "开始排盘" : "正在准备...")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        purpleColor,
                                        purpleColor.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: purpleColor.opacity(0.3), radius: 10)
                        }
                        .padding(.horizontal)
                        .disabled(!iztroManager.isReady || iztroManager.isCalculating)
                        
                        // 测试按钮 - 快速生成样例数据
                        Button(action: {
                            // 使用固定的测试日期：1990年1月1日 12点
                            iztroManager.calculate(
                                year: 1990,
                                month: 1,
                                day: 1,
                                hour: 12,
                                minute: 0,
                                gender: "男",
                                isLunar: false
                            )
                        }) {
                            Text("测试样例 (1990-01-01 12:00)")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                                .underline()
                        }
                        .disabled(!iztroManager.isReady || iztroManager.isCalculating)
                        
                        // 说明文字
                        VStack(spacing: 4) {
                            Text("紫微斗数 • 千年传承")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text("精准推算 • 趋吉避凶")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingResult) {
                ZiWeiChartView(resultData: iztroManager.resultData)
            }
        }
        .onChange(of: iztroManager.resultData) { newValue in
            if !newValue.isEmpty && !newValue.contains("\"status\":\"ready\"") {
                showingResult = true
            }
        }
    }
    
    private func calculateAstrolabe() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedDate)
        
        iztroManager.calculate(
            year: components.year ?? 2000,
            month: components.month ?? 1,
            day: components.day ?? 1,
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            gender: selectedGender,
            isLunar: isLunarDate
        )
    }
}

// 星盘显示视图 - 专业全屏版
struct ZiWeiChartView: View {
    let resultData: String
    @Environment(\.presentationMode) var presentationMode
    
    // 十二宫位置映射 - 按照地支顺序：从右上角申开始顺时针
    let earthlyBranches = ["申", "酉", "戌", "亥", "子", "丑", "寅", "卯", "辰", "巳", "午", "未"]
    
    // 按照地支顺序的宫位位置（顺时针）
    let palacePositions: [(row: Int, col: Int)] = [
        (0, 3), // 申 - 右上角
        (1, 3), // 酉
        (2, 3), // 戌  
        (3, 3), // 亥 - 右下角
        (3, 2), // 子
        (3, 1), // 丑
        (3, 0), // 寅 - 左下角
        (2, 0), // 卯
        (1, 0), // 辰
        (0, 0), // 巳 - 左上角
        (0, 1), // 午
        (0, 2), // 未
    ]
    
    var body: some View {
        if let data = resultData.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let screenHeight = geometry.size.height
                let cellWidth = screenWidth / 4
                let cellHeight = screenHeight / 4
                            
                ZStack {
                    // 背景
                    Color.white
                        .ignoresSafeArea()
                    
                    // 绘制12宫格 - 占满全屏
                    ForEach(0..<12, id: \.self) { posIndex in
                        let position = palacePositions[posIndex]
                        let branch = earthlyBranches[posIndex]
                        
                        // 找到对应地支的宫位
                        let palace = findPalaceByBranch(from: json, branch: branch)
                        
                        FullPalaceView(
                            palace: palace,
                            cellWidth: cellWidth,
                            cellHeight: cellHeight,
                            earthlyBranch: branch
                        )
                        .position(
                            x: CGFloat(position.col) * cellWidth + cellWidth/2,
                            y: CGFloat(position.row) * cellHeight + cellHeight/2
                        )
                    }
                    
                    // 中央信息区域
                    CenterInfoView(json: json)
                        .frame(width: cellWidth * 2 - 20, height: cellHeight * 2 - 20)
                        .position(x: screenWidth/2, y: screenHeight/2)
                }
            }
            .ignoresSafeArea()
            .overlay(
                // 顶部工具栏
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                            .padding(8)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                    }
                    .padding()
                    Spacer()
                }
                , alignment: .topLeading
            )
        } else {
            // 错误或测试视图
            VStack {
                Text("数据解析中...")
                    .font(.headline)
                Text(resultData)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
            }
        }
    }
    
    private func getPalace(from json: [String: Any], at index: Int) -> [String: Any]? {
        guard let palaces = json["palaces"] as? [[String: Any]],
              index < palaces.count else { return nil }
        return palaces[index]
    }
    
    private func findPalaceByBranch(from json: [String: Any], branch: String) -> [String: Any]? {
        guard let palaces = json["palaces"] as? [[String: Any]] else { return nil }
        
        // 查找对应地支的宫位
        for palace in palaces {
            if let palaceBranch = palace["earthlyBranch"] as? String,
               palaceBranch == branch {
                return palace
            }
        }
        return nil
    }
}

// 全屏宫位视图 - 完美版显示所有信息
struct FullPalaceView: View {
    let palace: [String: Any]?
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let earthlyBranch: String
    
    // 星曜颜色定义
    let majorStarColor = Color(red: 255/255, green: 193/255, blue: 7/255) // 金黄色
    let luckyStarColor = Color(red: 34/255, green: 139/255, blue: 34/255) // 绿色
    let minorStarColor = Color(red: 147/255, green: 112/255, blue: 219/255) // 紫色
    
    var body: some View {
        ZStack {
            // 边框
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                .background(Color.white)
            
            if let palace = palace {
                VStack(alignment: .leading, spacing: 0) {
                    // 顶部信息栏
                    HStack(spacing: 2) {
                        // 宫名
                        Text(palace["name"] as? String ?? "")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.purple)
                        
                        // 天干地支
                        if let stem = palace["heavenlyStem"] as? String {
                            Text(stem + earthlyBranch)
                                .font(.system(size: 8))
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        // 身宫标记
                        if palace["isBodyPalace"] as? Bool == true {
                            Text("身")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 2)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(2)
                        }
                    }
                    .padding(.horizontal, 3)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.05))
                    
                    // 星曜显示区域 - 完美分类显示
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 2) {
                            // 收集并分类显示所有数据
                            let palaceData = collectCompletePalaceData(palace)
                            
                            // 1. 主星（显示亮度）
                            if !palaceData.majorStars.isEmpty {
                                StarRowView(stars: palaceData.majorStars.map { $0.name }, 
                                          color: .red, 
                                          prefix: "主",
                                          starInfos: palaceData.majorStars)
                            }
                            
                            // 2. 辅星（显示亮度）
                            if !palaceData.minorStars.isEmpty {
                                StarRowView(stars: palaceData.minorStars.map { $0.name }, 
                                          color: .purple, 
                                          prefix: "辅",
                                          starInfos: palaceData.minorStars)
                            }
                            
                            // 3. 杂曜（显示亮度）
                            if !palaceData.adjectiveStars.isEmpty {
                                StarRowView(stars: palaceData.adjectiveStars.map { $0.name }, 
                                          color: .blue, 
                                          prefix: "杂",
                                          starInfos: palaceData.adjectiveStars)
                            }
                            
                            // 4. 四化
                            if !palaceData.mutagens.isEmpty {
                                StarRowView(stars: palaceData.mutagens, color: .orange, prefix: "化")
                            }
                            
                            // 5. 神煞系统
                            if !palaceData.shensha.isEmpty {
                                VStack(alignment: .leading, spacing: 1) {
                                    ForEach(palaceData.shensha, id: \.name) { item in
                                        HStack(spacing: 2) {
                                            Text(item.type)
                                                .font(.system(size: 7))
                                                .foregroundColor(.gray)
                                            Text(item.name)
                                                .font(.system(size: 8))
                                                .foregroundColor(.brown)
                                        }
                                    }
                                }
                            }
                            
                            // 6. 运限星曜（显示亮度）
                            if !palaceData.horoscopeStars.isEmpty {
                                VStack(alignment: .leading, spacing: 1) {
                                    ForEach(palaceData.horoscopeStars, id: \.type) { group in
                                        if !group.stars.isEmpty {
                                            StarRowView(stars: group.stars.map { $0.name }, 
                                                      color: group.color, 
                                                      prefix: group.type,
                                                      starInfos: group.stars)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(3)
                    }
                    .frame(maxHeight: cellHeight - 40)
                    
                    // 底部信息栏
                    VStack(spacing: 1) {
                        // 大限信息
                        if let decadal = palace["decadal"] as? [String: Any],
                           let range = decadal["range"] as? [Int], range.count >= 2 {
                            HStack(spacing: 2) {
                                Text("限")
                                    .font(.system(size: 7))
                                    .foregroundColor(.orange)
                                Text("\(range[0])-\(range[1])")
                                    .font(.system(size: 8))
                                    .foregroundColor(.black)
                            }
                        }
                        
                        // 小限年龄
                        if let ages = palace["ages"] as? [Int], !ages.isEmpty {
                            HStack(spacing: 1) {
                                Text("岁")
                                    .font(.system(size: 7))
                                    .foregroundColor(.gray)
                                Text(ages.map { String($0) }.joined(separator: ","))
                                    .font(.system(size: 7))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, 3)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .frame(width: cellWidth - 1, height: cellHeight - 1)
    }
}

// 中央信息视图
struct CenterInfoView: View {
    let json: [String: Any]
    
    var body: some View {
        VStack(spacing: 8) {
            Text("文墨天机基础版")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.purple)
            
            Divider()
            
            // 基本信息
            if let solarDate = json["solarDate"] as? String {
                Text("阳历: \(solarDate)")
                    .font(.system(size: 11))
            }
            
            if let lunarDate = json["lunarDate"] as? String {
                Text("阴历: \(lunarDate)")
                    .font(.system(size: 11))
            }
            
            // 命主信息
            if let soulPalace = json["soulPalace"] as? [String: Any] {
                Divider()
                
                if let fiveElements = soulPalace["fiveElements"] as? [[String: Any]],
                   let firstElement = fiveElements.first,
                   let elementName = firstElement["name"] as? String {
                    Text("五行局: \(elementName)")
                        .font(.system(size: 11))
                }
                
                if let heavenlyStem = soulPalace["heavenlyStem"] as? String,
                   let earthlyBranch = soulPalace["earthlyBranch"] as? String {
                    Text("命主: \(heavenlyStem)\(earthlyBranch)")
                        .font(.system(size: 11))
                }
            }
            
            Spacer()
            
            // 当前时间
            Text("排盘时间: \(Date(), formatter: dateFormatter)")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.95))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }
}

// 星曜信息结构
struct ZiWeiStarItem {
    let name: String
    let color: Color
}

// 星曜类别结构
struct StarCategoryInfo {
    let fieldName: String
    let displayName: String
    let stars: [ZiWeiStarItem]
}

// 宫位完整数据结构 - 增强版
struct CompletePalaceData {
    var majorStars: [StarInfo] = []
    var minorStars: [StarInfo] = []
    var adjectiveStars: [StarInfo] = []
    var mutagens: [String] = []
    var shensha: [(type: String, name: String)] = []
    var horoscopeStars: [(type: String, stars: [StarInfo], color: Color)] = []
}

// 收集宫位的完整数据
func collectCompletePalaceData(_ palace: [String: Any]?) -> CompletePalaceData {
    guard let palace = palace else { return CompletePalaceData() }
    
    var data = CompletePalaceData()
    
    // 所有可能的星曜字段映射 - 更全面
    let knownMappings: [(field: String, display: String, color: Color)] = [
        ("majorStars", "主", .red),
        ("minorStars", "辅", .purple),
        ("adjectiveStars", "佐", .blue),
        ("changsheng12", "长生", .green),
        ("boshi12", "博士", .brown),
        ("jiangqian12", "将前", .orange),
        ("suiqian12", "岁前", .teal),
        ("decadal", "限", .orange),
        ("yearly", "年", .pink),
        ("monthly", "月", .indigo),
        ("daily", "日", .brown),
        ("hourly", "时", .gray),
        ("horoscope", "命", .cyan),
        ("lunarDate", "阴", .mint),
        ("solarDate", "阳", .yellow),
        ("tianyi", "天", .blue),
        ("taibai", "太", .gray),
        ("wenchang", "文", .purple),
        ("wenqu", "曲", .indigo),
        ("tiankui", "魁", .red),
        ("tianyue", "钺", .orange),
        ("youbi", "右", .green),
        ("zuofu", "左", .yellow),
    ]
    
    // 1. 收集主星（包含亮度信息）
    if let majorStars = palace["majorStars"] as? [[String: Any]] {
        for star in majorStars {
            if let name = star["name"] as? String {
                let brightness = star["brightness"] as? String
                let type = star["type"] as? String
                data.majorStars.append(StarInfo(name: name, brightness: brightness, type: type))
            }
        }
    }
    
    // 2. 收集辅星（包含亮度信息）
    if let minorStars = palace["minorStars"] as? [[String: Any]] {
        for star in minorStars {
            if let name = star["name"] as? String {
                let brightness = star["brightness"] as? String
                let type = star["type"] as? String
                data.minorStars.append(StarInfo(name: name, brightness: brightness, type: type))
            }
        }
    }
    
    // 3. 收集杂曜（包含亮度信息）
    if let adjectiveStars = palace["adjectiveStars"] as? [[String: Any]] {
        for star in adjectiveStars {
            if let name = star["name"] as? String {
                let brightness = star["brightness"] as? String
                let type = star["type"] as? String
                data.adjectiveStars.append(StarInfo(name: name, brightness: brightness, type: type))
            }
        }
    }
    
    // 4. 收集四化
    if let mutagen = palace["mutagen"] as? [String] {
        data.mutagens = mutagen
    }
    
    // 5. 收集神煞系统
    // 长生十二神
    if let changsheng = palace["changsheng12"] as? String {
        data.shensha.append((type: "长生", name: changsheng))
    }
    // 博士十二神
    if let boshi = palace["boshi12"] as? String {
        data.shensha.append((type: "博士", name: boshi))
    }
    // 将前十二神
    if let jiangqian = palace["jiangqian12"] as? String {
        data.shensha.append((type: "将前", name: jiangqian))
    }
    // 岁前十二神
    if let suiqian = palace["suiqian12"] as? String {
        data.shensha.append((type: "岁前", name: suiqian))
    }
    
    // 6. 收集运限星曜（包含亮度信息）
    // 大限星曜
    if let decadal = palace["decadal"] as? [String: Any] {
        if let stars = decadal["stars"] as? [[String: Any]] {
            var decadalStars: [StarInfo] = []
            for star in stars {
                if let name = star["name"] as? String {
                    let brightness = star["brightness"] as? String
                    let type = star["type"] as? String
                    decadalStars.append(StarInfo(name: name, brightness: brightness, type: type))
                }
            }
            if !decadalStars.isEmpty {
                data.horoscopeStars.append((type: "大限", stars: decadalStars, color: .orange))
            }
        }
    }
    
    // 流年星曜
    if let yearly = palace["yearly"] as? [[String: Any]] {
        var yearlyStars: [StarInfo] = []
        for star in yearly {
            if let name = star["name"] as? String {
                let brightness = star["brightness"] as? String
                let type = star["type"] as? String
                yearlyStars.append(StarInfo(name: name, brightness: brightness, type: type))
            }
        }
        if !yearlyStars.isEmpty {
            data.horoscopeStars.append((type: "流年", stars: yearlyStars, color: .pink))
        }
    }
    
    // 流月星曜
    if let monthly = palace["monthly"] as? [[String: Any]] {
        var monthlyStars: [StarInfo] = []
        for star in monthly {
            if let name = star["name"] as? String {
                let brightness = star["brightness"] as? String
                let type = star["type"] as? String
                monthlyStars.append(StarInfo(name: name, brightness: brightness, type: type))
            }
        }
        if !monthlyStars.isEmpty {
            data.horoscopeStars.append((type: "流月", stars: monthlyStars, color: .indigo))
        }
    }
    
    // 流日星曜
    if let daily = palace["daily"] as? [[String: Any]] {
        var dailyStars: [StarInfo] = []
        for star in daily {
            if let name = star["name"] as? String {
                let brightness = star["brightness"] as? String
                let type = star["type"] as? String
                dailyStars.append(StarInfo(name: name, brightness: brightness, type: type))
            }
        }
        if !dailyStars.isEmpty {
            data.horoscopeStars.append((type: "流日", stars: dailyStars, color: .brown))
        }
    }
    
    // 流时星曜
    if let hourly = palace["hourly"] as? [[String: Any]] {
        var hourlyStars: [StarInfo] = []
        for star in hourly {
            if let name = star["name"] as? String {
                let brightness = star["brightness"] as? String
                let type = star["type"] as? String
                hourlyStars.append(StarInfo(name: name, brightness: brightness, type: type))
            }
        }
        if !hourlyStars.isEmpty {
            data.horoscopeStars.append((type: "流时", stars: hourlyStars, color: .gray))
        }
    }
    
    // 7. 查找其他未知字段
    let knownFields = ["name", "index", "heavenlyStem", "earthlyBranch", "isBodyPalace", "isOriginalPalace", 
                       "ages", "decadal", "majorStars", "minorStars", "adjectiveStars", 
                       "changsheng12", "boshi12", "jiangqian12", "suiqian12",
                       "yearly", "monthly", "daily", "hourly", "mutagen"]
    
    for (key, value) in palace {
        if !knownFields.contains(key) {
            // 尝试作为星曜数组
            if let starArray = value as? [[String: Any]] {
                var unknownStars: [StarInfo] = []
                for star in starArray {
                    if let name = star["name"] as? String {
                        let brightness = star["brightness"] as? String
                        let type = star["type"] as? String
                        unknownStars.append(StarInfo(name: name, brightness: brightness, type: type))
                    }
                }
                if !unknownStars.isEmpty {
                    data.horoscopeStars.append((type: key, stars: unknownStars, color: .gray))
                }
            }
        }
    }
    
    return data
}

// 星曜信息结构
struct StarInfo: Identifiable {
    let id = UUID()
    let name: String
    let brightness: String?
    let type: String?
}

// 星曜行视图 - 增强版，显示亮度
struct StarRowView: View {
    let stars: [String]
    let color: Color
    let prefix: String
    let starInfos: [StarInfo]?
    
    init(stars: [String], color: Color, prefix: String, starInfos: [StarInfo]? = nil) {
        self.stars = stars
        self.color = color
        self.prefix = prefix
        self.starInfos = starInfos
    }
    
    var body: some View {
        HStack(spacing: 2) {
            // 类别标签
            Text(prefix)
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(color.opacity(0.8))
                .frame(width: 15)
            
            // 星曜列表
            if let infos = starInfos {
                ForEach(infos) { info in
                    VStack(spacing: 0) {
                        Text(info.name)
                            .font(.system(size: 8))
                            .foregroundColor(color)
                        if let brightness = info.brightness, !brightness.isEmpty {
                            Text(brightnessToSymbol(brightness))
                                .font(.system(size: 6))
                                .foregroundColor(brightnessColor(brightness))
                        }
                    }
                    .padding(.horizontal, 2)
                    .background(color.opacity(0.1))
                    .cornerRadius(2)
                }
            } else {
                ForEach(stars, id: \.self) { star in
                    Text(star)
                        .font(.system(size: 8))
                        .foregroundColor(color)
                        .padding(.horizontal, 2)
                        .background(color.opacity(0.1))
                        .cornerRadius(2)
                }
            }
            Spacer()
        }
    }
    
    // 亮度转符号
    func brightnessToSymbol(_ brightness: String) -> String {
        switch brightness {
        case "wang", "旺": return "◎" // 最亮
        case "miao", "庙": return "●" // 次亮
        case "de", "得": return "○" // 正常
        case "li", "利": return "◐" // 稍弱
        case "ping", "平": return "◯" // 平常
        case "bu", "不": return "◔" // 不得地
        case "xian", "陷": return "×" // 落陷
        default: return ""
        }
    }
    
    // 亮度对应颜色
    func brightnessColor(_ brightness: String) -> Color {
        switch brightness {
        case "wang", "旺": return .yellow
        case "miao", "庙": return .orange
        case "de", "得": return .green
        case "li", "利": return .blue
        case "ping", "平": return .gray
        case "bu", "不": return .brown
        case "xian", "陷": return .red
        default: return .gray
        }
    }
}

// 保留的辅助函数 - 根据星曜名称和类型确定颜色
func determineStarColor(name: String, type: String?, field: String) -> Color {
    // 主星 - 红色
    if field.contains("major") || ["紫微", "天机", "太阳", "武曲", "天同", "廉贞", "天府", "太阴", "贪狼", "巨门", "天相", "天梁", "七杀", "破军"].contains(name) {
        return .red
    }
    // 辅星 - 紫色
    else if field.contains("minor") || ["天魁", "天钺", "左辅", "右弼", "文昌", "文曲"].contains(name) {
        return .purple
    }
    // 煞星 - 橙色
    else if ["擎羊", "陀罗", "火星", "铃星", "地劫", "地空"].contains(name) {
        return .orange
    }
    // 流年系列
    else if field.contains("year") {
        return .pink
    }
    else if field.contains("month") {
        return .indigo
    }
    else if field.contains("day") || field.contains("daily") {
        return .brown
    }
    else if field.contains("hour") {
        return .gray
    }
    // 化曜
    else if name.contains("化") {
        if name.contains("禄") { return .yellow }
        if name.contains("权") { return .orange }
        if name.contains("科") { return .blue }
        if name.contains("忌") { return .red }
    }
    // 桃花星
    else if ["红鸾", "天喜", "咸池", "天姚"].contains(name) {
        return .pink
    }
    // 根据type判断
    else if let type = type {
        return getStarColor(type: type)
    }
    
    // 默认颜色
    return .gray
}

// 根据星曜类型获取颜色
func getStarColor(type: String) -> Color {
    // 红鸾、天喜等桃花星
    if type.contains("红鸾") || type.contains("天喜") || type.contains("咸池") {
        return Color.pink // 粉色 - 桃花星
    }
    // 吉星
    else if type.contains("吉") || type.contains("禄") || type.contains("贵") || type.contains("恩") || type.contains("天魁") || type.contains("天钺") {
        return Color(red: 34/255, green: 139/255, blue: 34/255) // 绿色 - 吉星
    }
    // 凶星
    else if type.contains("凶") || type.contains("煞") || type.contains("忌") || type.contains("破") || type.contains("孤") || type.contains("寡") {
        return Color.red.opacity(0.8) // 红色 - 凶星
    }
    // 文星
    else if type.contains("文") || type.contains("科") || type.contains("化科") {
        return Color.blue.opacity(0.8) // 蓝色 - 文星
    }
    // 财星
    else if type.contains("财") || type.contains("禄") || type.contains("化禄") {
        return Color.yellow.opacity(0.8) // 黄色 - 财星
    }
    // 月马、天马等动星
    else if type.contains("马") || type.contains("迁") || type.contains("动") {
        return Color.orange.opacity(0.8) // 橙色 - 动星
    }
    // 其他辅星
    else {
        return Color(red: 147/255, green: 112/255, blue: 219/255) // 紫色 - 一般辅星
    }
}

// 宫位详情卡片
struct PalaceDetailCard: View {
    let palace: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(palace["name"] as? String ?? "")
                .font(.system(size: 18, weight: .bold))
            
            if let majorStars = palace["majorStars"] as? [[String: Any]], !majorStars.isEmpty {
                Text("主星")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                FlowLayout {
                    ForEach(0..<majorStars.count, id: \.self) { i in
                        if let star = majorStars[i]["name"] as? String {
                            StarChip(name: star, type: .major)
                        }
                    }
                }
            }
            
            if let minorStars = palace["minorStars"] as? [[String: Any]], !minorStars.isEmpty {
                Text("辅星")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                FlowLayout {
                    ForEach(0..<minorStars.count, id: \.self) { i in
                        if let star = minorStars[i]["name"] as? String {
                            StarChip(name: star, type: .minor)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
}

// 星耀标签
struct StarChip: View {
    let name: String
    enum ChipType { case major, minor }
    let type: ChipType
    
    var body: some View {
        Text(name)
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(type == .major ? Color.purple.opacity(0.2) : Color.gray.opacity(0.2))
            .foregroundColor(type == .major ? .purple : .gray)
            .cornerRadius(12)
    }
}

// 流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangement(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangement(proposal: proposal, subviews: subviews)
        for (view, position) in zip(subviews, result.positions) {
            view.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrangement(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > (proposal.width ?? .infinity) && currentX > 0 {
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, currentX)
        }
        
        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

#Preview {
    ZiWeiContentView()
}