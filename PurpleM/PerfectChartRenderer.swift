//
//  PerfectChartRenderer.swift
//  PurpleM
//
//  完美版星盘 - 竖向文字横向排列
//

import SwiftUI

// MARK: - 完美版星盘渲染器
struct PerfectChartRenderer: View {
    let jsonData: String
    @State private var astrolabe: FullAstrolabe?
    @State private var selectedPalaceIndex: Int? = nil
    
    // 12宫格位置映射 - 根据地支固定位置
    // 标准紫微斗数布局：申在右上角，顺时针排列
    let earthlyBranchPositions: [String: (row: Int, col: Int)] = [
        "申": (0, 3), // 右上角
        "酉": (1, 3), // 右边
        "戌": (2, 3), // 右边
        "亥": (3, 3), // 右下角
        "子": (3, 2), // 下边
        "丑": (3, 1), // 下边
        "寅": (3, 0), // 左下角
        "卯": (2, 0), // 左边
        "辰": (1, 0), // 左边
        "巳": (0, 0), // 左上角
        "午": (0, 1), // 上边
        "未": (0, 2), // 上边
    ]
    
    
    var body: some View {
        ZStack {
            // 星语时光主题背景
            AnimatedBackground()
            
            if let astrolabe = astrolabe {
                VStack(spacing: 10) {
                    // 完美方形12宫格
                    PerfectSquareChart(
                        astrolabe: astrolabe,
                        palaces: astrolabe.palaces,
                        earthlyBranchPositions: earthlyBranchPositions,
                        selectedIndex: $selectedPalaceIndex
                    )
                    .padding(.horizontal, 5)
                    .padding(.bottom, 10)
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .starGold))
                    .onAppear {
                        parseJSON()
                    }
            }
        }
    }
    
    private func parseJSON() {
        guard let data = jsonData.data(using: .utf8) else { return }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            parseManually(json: json)
        }
    }
    
    private func parseManually(json: [String: Any]) {
        var palaces: [FullPalace] = []
        
        if let palacesArray = json["palaces"] as? [[String: Any]] {
            for dict in palacesArray {
                // 解析主星
                var majorStars: [SquareStarInfo] = []
                if let stars = dict["majorStars"] as? [[String: Any]] {
                    for starDict in stars {
                        majorStars.append(SquareStarInfo(
                            name: starDict["name"] as? String ?? "",
                            brightness: starDict["brightness"] as? String,
                            mutagen: starDict["mutagen"] as? String
                        ))
                    }
                }
                
                // 解析辅星
                var minorStars: [SquareStarInfo] = []
                if let stars = dict["minorStars"] as? [[String: Any]] {
                    for starDict in stars {
                        minorStars.append(SquareStarInfo(
                            name: starDict["name"] as? String ?? "",
                            brightness: starDict["brightness"] as? String,
                            mutagen: starDict["mutagen"] as? String
                        ))
                    }
                }
                
                // 解析杂曜 - 重要！确保获取
                var adjectiveStars: [String] = []
                
                // 尝试多种可能的数据格式
                if let adjStars = dict["adjectiveStars"] as? [String] {
                    adjectiveStars = adjStars
                } else if let adjStars = dict["adjectiveStars"] as? [[String: Any]] {
                    // 如果是对象数组，提取名称
                    adjectiveStars = adjStars.compactMap { $0["name"] as? String }
                }
                
                // 调试：打印杂曜数据
                if !adjectiveStars.isEmpty {
                    print("宫位 \(dict["name"] ?? ""): 杂曜 = \(adjectiveStars)")
                }
                
                let palace = FullPalace(
                    index: dict["index"] as? Int ?? 0,
                    name: dict["name"] as? String ?? "",
                    isBodyPalace: dict["isBodyPalace"] as? Bool ?? false,
                    isSoulPalace: dict["isSoulPalace"] as? Bool,
                    isOriginalPalace: dict["isOriginalPalace"] as? Bool,
                    heavenlyStem: dict["heavenlyStem"] as? String ?? "",
                    earthlyBranch: dict["earthlyBranch"] as? String ?? "",
                    majorStars: majorStars.isEmpty ? nil : majorStars,
                    minorStars: minorStars.isEmpty ? nil : minorStars,
                    adjectiveStars: adjectiveStars.isEmpty ? nil : adjectiveStars,
                    changsheng12: dict["changsheng12"] as? [String],
                    boshi12: dict["boshi12"] as? [String],
                    jiangqian12: dict["jiangqian12"] as? [String],
                    suiqian12: dict["suiqian12"] as? [String],
                    decadal: nil,
                    ages: dict["ages"] as? [Int]
                )
                
                palaces.append(palace)
            }
        }
        
        astrolabe = FullAstrolabe(
            success: json["success"] as? Bool ?? true,
            gender: json["gender"] as? String ?? "",
            solarDate: json["solarDate"] as? String ?? "",
            lunarDate: json["lunarDate"] as? String ?? "",
            chineseDate: json["chineseDate"] as? String ?? "",
            time: json["time"] as? String,
            timeRange: json["timeRange"] as? String,
            sign: json["sign"] as? String ?? "",
            zodiac: json["zodiac"] as? String ?? "",
            earthlyBranchOfSoulPalace: json["earthlyBranchOfSoulPalace"] as? String,
            earthlyBranchOfBodyPalace: json["earthlyBranchOfBodyPalace"] as? String,
            soul: json["soul"] as? String,
            body: json["body"] as? String,
            fiveElementsClass: json["fiveElementsClass"] as? String ?? "",
            palaces: palaces
        )
    }
}

// MARK: - 信息栏
struct PerfectInfoBar: View {
    let astrolabe: FullAstrolabe
    
    var body: some View {
        HStack(spacing: 15) {
            Text("\(astrolabe.lunarDate)")
                .font(.system(size: 14))
                .foregroundColor(.crystalWhite)
            
            Text("|")
                .foregroundColor(.moonSilver.opacity(0.5))
            
            Text("\(astrolabe.gender)")
                .font(.system(size: 14))
                .foregroundColor(.crystalWhite)
            
            Text("|")
                .foregroundColor(.moonSilver.opacity(0.5))
            
            Text("\(astrolabe.zodiac)")
                .font(.system(size: 14))
                .foregroundColor(.crystalWhite)
            
            Text("|")
                .foregroundColor(.moonSilver.opacity(0.5))
            
            Text("\(astrolabe.fiveElementsClass)")
                .font(.system(size: 14))
                .foregroundColor(.starGold)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - 完美方形星盘
struct PerfectSquareChart: View {
    let astrolabe: FullAstrolabe
    let palaces: [FullPalace]
    let earthlyBranchPositions: [String: (row: Int, col: Int)]
    @Binding var selectedIndex: Int?
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - 10
            let height = width * 1.4  // 高度为宽度的1.4倍
            let cellWidth = width / 4
            let cellHeight = height / 4  // 4等分高度
            
            ZStack {
                // 外框
                Rectangle()
                    .stroke(Color.moonSilver.opacity(0.3), lineWidth: 1)
                    .frame(width: width, height: height)
                
                // 绘制网格线
                // 横线
                ForEach(1..<4) { i in
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: CGFloat(i) * cellHeight))
                        path.addLine(to: CGPoint(x: width, y: CGFloat(i) * cellHeight))
                    }
                    .stroke(Color.moonSilver.opacity(0.3), lineWidth: 0.5)
                }
                
                // 竖线
                ForEach(1..<4) { i in
                    Path { path in
                        path.move(to: CGPoint(x: CGFloat(i) * cellWidth, y: 0))
                        path.addLine(to: CGPoint(x: CGFloat(i) * cellWidth, y: height))
                    }
                    .stroke(Color.moonSilver.opacity(0.3), lineWidth: 0.5)
                }
                
                // 中宫 - 显示个人信息
                VStack(spacing: 6) {
                    // 性别和生肖
                    HStack(spacing: 8) {
                        Text(astrolabe.gender)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.starGold)
                        Text(astrolabe.zodiac)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.mysticPink)
                    }
                    
                    // 农历日期
                    Text(astrolabe.lunarDate)
                        .font(.system(size: 12))
                        .foregroundColor(.crystalWhite)
                    
                    // 时辰
                    if let time = astrolabe.time {
                        Text("\(time)时")
                            .font(.system(size: 12))
                            .foregroundColor(.moonSilver)
                    }
                    
                    // 五行局
                    Text(astrolabe.fiveElementsClass)
                        .font(.system(size: 11))
                        .foregroundColor(.cyan.opacity(0.8))
                    
                    // 命身宫位
                    if let soul = astrolabe.earthlyBranchOfSoulPalace,
                       let body = astrolabe.earthlyBranchOfBodyPalace {
                        HStack(spacing: 6) {
                            Text("命:\(soul)")
                                .font(.system(size: 10))
                                .foregroundColor(.starGold.opacity(0.8))
                            Text("身:\(body)")
                                .font(.system(size: 10))
                                .foregroundColor(.mysticPink.opacity(0.8))
                        }
                    }
                }
                .frame(width: cellWidth * 2 - 4, height: cellHeight * 2 - 4)
                .background(Color.cosmicPurple.opacity(0.05))
                .position(x: width/2, y: height/2)
                
                // 12宫位
                ForEach(0..<min(12, palaces.count), id: \.self) { index in
                    let palace = palaces[index]
                    // 根据地支获取位置
                    let position = earthlyBranchPositions[palace.earthlyBranch] ?? (0, 0)
                    
                    PerfectPalaceCell(
                        palace: palace,
                        isSelected: selectedIndex == index,
                        cellWidth: cellWidth,
                        cellHeight: cellHeight
                    )
                    .frame(width: cellWidth - 2, height: cellHeight - 2)
                    .position(
                        x: CGFloat(position.col) * cellWidth + cellWidth/2,
                        y: CGFloat(position.row) * cellHeight + cellHeight/2
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedIndex = selectedIndex == index ? nil : index
                        }
                    }
                }
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(1/1.4, contentMode: .fit)  // 调整宽高比为1:1.4
    }
}

// MARK: - 完美宫位单元格
struct PerfectPalaceCell: View {
    let palace: FullPalace
    let isSelected: Bool
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    
    var body: some View {
        ZStack {
            // 背景 - 移除单独的边框，因为已经在主网格中绘制
            Rectangle()
                .fill(Color.black.opacity(0.01))
            
            VStack(alignment: .leading, spacing: 2) {
                // 顶部区域：宫位名、干支、命身标记
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(palace.name)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.crystalWhite)
                        
                        // 命身标记
                        if palace.isSoulPalace == true {
                            Text("命")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.starGold)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.starGold.opacity(0.2))
                                )
                        }
                        if palace.isBodyPalace {
                            Text("身")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.mysticPink)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.mysticPink.opacity(0.2))
                                )
                        }
                        
                        Spacer()
                        
                        Text("\(palace.heavenlyStem)\(palace.earthlyBranch)")
                            .font(.system(size: 9))
                            .foregroundColor(.moonSilver.opacity(0.7))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 3)
                
                // 星耀显示区域 - 使用固定5列布局
                let allStars = collectAllStars(palace: palace)
                if !allStars.isEmpty {
                    FixedColumnsLayout(stars: allStars, 
                                     horizontalSpacing: 1, 
                                     verticalSpacing: 10)
                        .padding(.horizontal, 3)
                        .padding(.top, 3)
                        .padding(.bottom, 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .clipped() // 防止内容溢出
                }
                
                Spacer(minLength: 0)
            }
        }
    }
    
    // 收集所有星耀
    private func collectAllStars(palace: FullPalace) -> [StarItem] {
        var items: [StarItem] = []
        
        // 主星
        if let majorStars = palace.majorStars {
            for star in majorStars {
                items.append(StarItem(
                    id: UUID().uuidString,
                    name: star.name,
                    brightness: star.brightness,
                    mutagen: star.mutagen,
                    type: .major
                ))
            }
        }
        
        // 辅星
        if let minorStars = palace.minorStars {
            for star in minorStars {
                items.append(StarItem(
                    id: UUID().uuidString,
                    name: star.name,
                    brightness: star.brightness,
                    mutagen: star.mutagen,
                    type: .minor
                ))
            }
        }
        
        // 杂曜 - 重要！
        if let adjectiveStars = palace.adjectiveStars {
            for star in adjectiveStars {
                items.append(StarItem(
                    id: UUID().uuidString,
                    name: star,
                    brightness: nil,
                    mutagen: nil,
                    type: .adjective
                ))
            }
        }
        
        return items
    }
}

// MARK: - 星耀数据项
struct StarItem {
    let id: String
    let name: String
    let brightness: String?
    let mutagen: String?
    let type: StarType
    
    enum StarType {
        case major, minor, adjective
    }
}

// MARK: - 竖向星耀视图
struct VerticalStarView: View {
    let item: StarItem
    
    var body: some View {
        VStack(spacing: 0) {
            // 星耀名称（竖向排列）
            ForEach(Array(item.name.enumerated()), id: \.offset) { _, char in
                Text(String(char))
                    .font(.system(size: 9, weight: item.type == .major ? .semibold : .regular))
                    .foregroundColor(getStarColor())
                    .lineLimit(1)
                    .frame(width: 10)
            }
            
            // 亮度
            if let brightness = item.brightness, !brightness.isEmpty {
                Text(brightness)
                    .font(.system(size: 7))
                    .foregroundColor(.gray.opacity(0.6))
                    .frame(width: 10)
            }
            
            // 四化
            if let mutagen = item.mutagen, !mutagen.isEmpty {
                Text(mutagen)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(getMutagenColor(mutagen))
                    .frame(width: 10)
            }
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 0)
    }
    
    private func getStarColor() -> Color {
        switch item.type {
        case .major:
            // 紫微系
            if ["紫微", "天机", "太阳", "武曲", "天同", "廉贞"].contains(item.name) {
                return .purple
            }
            // 天府系
            if ["天府", "太阴", "贪狼", "巨门", "天相", "天梁", "七杀", "破军"].contains(item.name) {
                return .yellow
            }
            return .starGold
        case .minor:
            return .cyan
        case .adjective:
            return .gray.opacity(0.8)
        }
    }
    
    private func getMutagenColor(_ mutagen: String) -> Color {
        switch mutagen {
        case "禄": return .green
        case "权": return .orange
        case "科": return .blue
        case "忌": return .red
        default: return .gray
        }
    }
}

// MARK: - 固定列数布局
struct FixedColumnsLayout: View {
    let stars: [StarItem]
    let columnsPerRow: Int = 5
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    
    init(stars: [StarItem], horizontalSpacing: CGFloat = 3, verticalSpacing: CGFloat = 8) {
        self.stars = stars
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: verticalSpacing) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(alignment: .top, spacing: horizontalSpacing) {
                    ForEach(0..<columnsInRow(row), id: \.self) { col in
                        let index = row * columnsPerRow + col
                        if index < stars.count {
                            VerticalStarView(item: stars[index])
                        }
                    }
                    Spacer() // 确保左对齐
                }
            }
        }
    }
    
    private var rowCount: Int {
        (stars.count + columnsPerRow - 1) / columnsPerRow
    }
    
    private func columnsInRow(_ row: Int) -> Int {
        let startIndex = row * columnsPerRow
        let remaining = stars.count - startIndex
        return min(remaining, columnsPerRow)
    }
}