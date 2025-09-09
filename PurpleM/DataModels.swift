//
//  DataModels.swift
//  PurpleM
//
//  数据模型定义
//

import SwiftUI

// MARK: - 完整星盘数据
struct FullAstrolabe {
    let success: Bool
    let gender: String
    let solarDate: String
    let lunarDate: String
    let chineseDate: String
    let time: String?
    let timeRange: String?
    let sign: String
    let zodiac: String
    let earthlyBranchOfSoulPalace: String?
    let earthlyBranchOfBodyPalace: String?
    let soul: String?
    let body: String?
    let fiveElementsClass: String
    let palaces: [FullPalace]
}

// MARK: - 宫位数据
struct FullPalace {
    let index: Int
    let name: String
    let isBodyPalace: Bool
    let isSoulPalace: Bool?
    let isOriginalPalace: Bool?
    let heavenlyStem: String
    let earthlyBranch: String
    let majorStars: [SquareStarInfo]?
    let minorStars: [SquareStarInfo]?
    let adjectiveStars: [String]?
    let changsheng12: [String]?
    let boshi12: [String]?
    let jiangqian12: [String]?
    let suiqian12: [String]?
    let decadal: Decadal?
    let ages: [Int]?
}

// MARK: - 星耀信息
struct SquareStarInfo {
    let name: String
    let brightness: String?
    let mutagen: String?
}

// MARK: - 大运信息
struct Decadal {
    let range: [Int]
    let heavenlyStem: String
    let earthlyBranch: String
    let palaceNames: [String]
    let stars: [[SquareStarInfo]]?
}

// MARK: - 颜色扩展
extension Color {
    // 星语时光主题色
    static let cosmicPurple = Color(red: 88/255, green: 86/255, blue: 214/255)
    static let starGold = Color(red: 255/255, green: 215/255, blue: 0/255)
    static let mysticPink = Color(red: 255/255, green: 105/255, blue: 180/255)
    static let moonSilver = Color(red: 192/255, green: 192/255, blue: 192/255)
    static let crystalWhite = Color.white.opacity(0.95)
    static let deepSpace = Color.black.opacity(0.85)
}

// MARK: - 动画背景
struct AnimatedBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 44/255, green: 43/255, blue: 107/255),
                    Color(red: 88/255, green: 86/255, blue: 214/255).opacity(0.8),
                    Color(red: 255/255, green: 105/255, blue: 180/255).opacity(0.5)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 闪烁星星效果
            ForEach(0..<20, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.3...0.8)))
                    .frame(width: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .opacity(animate ? 0.2 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: Double.random(in: 1...3))
                            .repeatForever(autoreverses: true),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}