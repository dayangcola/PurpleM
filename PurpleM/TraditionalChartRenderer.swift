//
//  TraditionalChartRenderer.swift
//  PurpleM
//
//  传统方形12宫格星盘 - 大格子竖向排列
//

import SwiftUI

// MARK: - 传统星盘渲染器
struct TraditionalChartRenderer: View {
    let jsonData: String
    @State private var astrolabe: FullAstrolabe?
    @State private var selectedPalaceIndex: Int? = nil
    
    // 12宫格位置映射（传统方形布局）
    let palacePositions: [(row: Int, col: Int)] = [
        (2, 3), // 0: 巳
        (3, 3), // 1: 午  
        (3, 2), // 2: 未
        (3, 1), // 3: 申
        (3, 0), // 4: 酉
        (2, 0), // 5: 戌
        (1, 0), // 6: 亥
        (0, 0), // 7: 子
        (0, 1), // 8: 丑
        (0, 2), // 9: 寅
        (0, 3), // 10: 卯
        (1, 3), // 11: 辰
    ]
    
    var body: some View {
        if let astrolabe = astrolabe {
            ScrollView {
                VStack(spacing: 15) {
                    // 基本信息面板
                    TraditionalInfoPanel(astrolabe: astrolabe)
                        .padding(.horizontal)
                    
                    // 传统方形12宫格
                    TraditionalSquareChart(
                        palaces: astrolabe.palaces,
                        positions: palacePositions,
                        selectedIndex: $selectedPalaceIndex
                    )
                    .frame(height: UIScreen.main.bounds.width * 1.2) // 增大格子
                    .padding(.horizontal, 10)
                }
            }
            .background(Color.black)
        } else {
            Color.black.onAppear {
                parseJSON()
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
                palaces.append(parsePalace(dict))
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
    
    private func parsePalace(_ dict: [String: Any]) -> FullPalace {
        var majorStars: [SquareStarInfo] = []
        if let stars = dict["majorStars"] as? [[String: Any]] {
            majorStars = stars.map { parseStarInfo($0) }
        }
        
        var minorStars: [SquareStarInfo] = []
        if let stars = dict["minorStars"] as? [[String: Any]] {
            minorStars = stars.map { parseStarInfo($0) }
        }
        
        return FullPalace(
            index: dict["index"] as? Int ?? 0,
            name: dict["name"] as? String ?? "",
            isBodyPalace: dict["isBodyPalace"] as? Bool ?? false,
            isSoulPalace: dict["isSoulPalace"] as? Bool,
            isOriginalPalace: dict["isOriginalPalace"] as? Bool,
            heavenlyStem: dict["heavenlyStem"] as? String ?? "",
            earthlyBranch: dict["earthlyBranch"] as? String ?? "",
            majorStars: majorStars.isEmpty ? nil : majorStars,
            minorStars: minorStars.isEmpty ? nil : minorStars,
            adjectiveStars: dict["adjectiveStars"] as? [String],
            changsheng12: dict["changsheng12"] as? [String],
            boshi12: dict["boshi12"] as? [String],
            jiangqian12: dict["jiangqian12"] as? [String],
            suiqian12: dict["suiqian12"] as? [String],
            decadal: nil,
            ages: dict["ages"] as? [Int]
        )
    }
    
    private func parseStarInfo(_ dict: [String: Any]) -> SquareStarInfo {
        SquareStarInfo(
            name: dict["name"] as? String ?? "",
            brightness: dict["brightness"] as? String,
            mutagen: dict["mutagen"] as? String
        )
    }
}

// MARK: - 传统信息面板
struct TraditionalInfoPanel: View {
    let astrolabe: FullAstrolabe
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(astrolabe.solarDate) | \(astrolabe.lunarDate)")
                .font(.system(size: 14))
                .foregroundColor(.white)
            
            Text("\(astrolabe.chineseDate) \(astrolabe.gender) \(astrolabe.zodiac) \(astrolabe.fiveElementsClass)")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 传统方形星盘
struct TraditionalSquareChart: View {
    let palaces: [FullPalace]
    let positions: [(row: Int, col: Int)]
    @Binding var selectedIndex: Int?
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = min(geometry.size.width / 4, geometry.size.height / 4)
            
            ZStack {
                // 背景网格
                ForEach(0..<4) { row in
                    ForEach(0..<4) { col in
                        Rectangle()
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            .frame(width: cellSize, height: cellSize)
                            .position(
                                x: CGFloat(col) * cellSize + cellSize/2,
                                y: CGFloat(row) * cellSize + cellSize/2
                            )
                    }
                }
                
                // 中宫标题
                VStack(spacing: 8) {
                    Text("紫微斗数")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.purple)
                    
                    Text(palaces.first?.heavenlyStem ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(width: cellSize * 2 - 2, height: cellSize * 2 - 2)
                .background(Color.black)
                .overlay(
                    Rectangle()
                        .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                )
                .position(x: cellSize * 2, y: cellSize * 2)
                
                // 12宫位
                ForEach(0..<min(12, palaces.count), id: \.self) { index in
                    let palace = palaces[index]
                    let position = positions[index]
                    
                    TraditionalPalaceCell(
                        palace: palace,
                        isSelected: selectedIndex == index
                    )
                    .frame(width: cellSize - 2, height: cellSize - 2)
                    .position(
                        x: CGFloat(position.col) * cellSize + cellSize/2,
                        y: CGFloat(position.row) * cellSize + cellSize/2
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedIndex = selectedIndex == index ? nil : index
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 传统宫位单元格（大格子）
struct TraditionalPalaceCell: View {
    let palace: FullPalace
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // 背景
            Rectangle()
                .fill(Color.black)
                .overlay(
                    Rectangle()
                        .stroke(
                            palace.isSoulPalace == true ? Color.red :
                            palace.isBodyPalace ? Color.blue :
                            isSelected ? Color.yellow :
                            Color.gray,
                            lineWidth: palace.isSoulPalace == true || palace.isBodyPalace ? 2 : 1
                        )
                )
            
            // 内容布局
            VStack(spacing: 0) {
                // 顶部：宫位名称和干支
                HStack {
                    Text(palace.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(palace.heavenlyStem)\(palace.earthlyBranch)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)
                
                // 命身标记
                if palace.isSoulPalace == true || palace.isBodyPalace {
                    HStack {
                        if palace.isSoulPalace == true {
                            Text("命")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                        if palace.isBodyPalace {
                            Text("身")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                }
                
                // 运限信息（如果有）
                if let ages = palace.ages, !ages.isEmpty {
                    HStack {
                        Text("\(ages.first ?? 0)~\(ages.last ?? 0)")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                }
                
                Spacer()
                
                // 星耀竖向排列区域
                HStack(alignment: .top, spacing: 2) {
                    // 主星列（第一列）
                    if let majorStars = palace.majorStars, !majorStars.isEmpty {
                        VStack(spacing: 1) {
                            ForEach(majorStars, id: \.name) { star in
                                StarVerticalText(
                                    name: star.name,
                                    brightness: star.brightness,
                                    mutagen: star.mutagen,
                                    isMajor: true
                                )
                            }
                        }
                    }
                    
                    // 辅星列（第二列）
                    if let minorStars = palace.minorStars, !minorStars.isEmpty {
                        VStack(spacing: 1) {
                            ForEach(minorStars.prefix(8), id: \.name) { star in
                                StarVerticalText(
                                    name: star.name,
                                    brightness: star.brightness,
                                    mutagen: star.mutagen,
                                    isMajor: false
                                )
                            }
                        }
                    }
                    
                    // 杂曜列（第三列）
                    if let adjectiveStars = palace.adjectiveStars, !adjectiveStars.isEmpty {
                        VStack(spacing: 1) {
                            ForEach(adjectiveStars.prefix(8), id: \.self) { star in
                                Text(star)
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
                
                // 小限年龄（底部）
                if let ages = palace.ages, ages.count > 2 {
                    HStack {
                        Text("小限: \(ages.map { String($0) }.joined(separator: ","))")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 2)
                }
            }
        }
    }
}

// MARK: - 竖向星耀文本
struct StarVerticalText: View {
    let name: String
    let brightness: String?
    let mutagen: String?
    let isMajor: Bool
    
    var body: some View {
        HStack(spacing: 1) {
            // 星耀名称
            Text(name)
                .font(.system(size: isMajor ? 11 : 10))
                .foregroundColor(isMajor ? starColor : .cyan)
                .lineLimit(1)
            
            // 亮度
            if let brightness = brightness, !brightness.isEmpty {
                Text(brightness)
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
            
            // 四化
            if let mutagen = mutagen, !mutagen.isEmpty {
                Text(mutagen)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(mutagenColor(mutagen))
            }
        }
    }
    
    private var starColor: Color {
        // 紫微系主星
        if ["紫微", "天机", "太阳", "武曲", "天同", "廉贞"].contains(name) {
            return .purple
        }
        // 天府系主星
        if ["天府", "太阴", "贪狼", "巨门", "天相", "天梁", "七杀", "破军"].contains(name) {
            return .yellow
        }
        return .white
    }
    
    private func mutagenColor(_ mutagen: String) -> Color {
        switch mutagen {
        case "禄": return .green
        case "权": return .orange
        case "科": return .blue
        case "忌": return .red
        default: return .gray
        }
    }
}

// MARK: - 预览
struct TraditionalChartRenderer_Previews: PreviewProvider {
    static var previews: some View {
        TraditionalChartRenderer(jsonData: "{}")
            .preferredColorScheme(.dark)
    }
}