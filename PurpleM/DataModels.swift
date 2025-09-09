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

// 颜色扩展和动画背景已在ModernZiWeiView.swift中定义