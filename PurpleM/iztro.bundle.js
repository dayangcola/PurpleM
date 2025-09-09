
// iztro bundle for iOS
(function(global) {
    const exports = {};
    const module = { exports: exports };
    const require = function(moduleName) {
        // 简单的模块解析
        if (modules[moduleName]) {
            return modules[moduleName];
        }
        return {};
    };
    
    const modules = {};
    

    // Module: index
    modules['index'] = (function() {
        "use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.astro = exports.util = exports.star = exports.data = void 0;
exports.data = __importStar(require("./data"));
exports.star = __importStar(require("./star"));
exports.util = __importStar(require("./utils"));
exports.astro = __importStar(require("./astro"));

        return exports;
    })();
    
    // Module: data/index
    modules['data/index'] = (function() {
        "use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
__exportStar(require("./constants"), exports);
__exportStar(require("./stars"), exports);
__exportStar(require("./heavenlyStems"), exports);
__exportStar(require("./earthlyBranches"), exports);

        return exports;
    })();
    
    // Module: astro/astro
    modules['astro/astro'] = (function() {
        "use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getMajorStarByLunarDate = exports.getMajorStarBySolarDate = exports.getSignByLunarDate = exports.getSignBySolarDate = exports.getZodiacBySolarDate = exports.withOptions = exports.rearrangeAstrolable = exports.byLunar = exports.astrolabeByLunarDate = exports.bySolar = exports.astrolabeBySolarDate = exports.getConfig = exports.config = exports.loadPlugin = exports.loadPlugins = void 0;
var lunar_lite_1 = require("lunar-lite");
var data_1 = require("../data");
var i18n_1 = require("../i18n");
var star_1 = require("../star");
var utils_1 = require("../utils");
var FunctionalAstrolabe_1 = __importDefault(require("./FunctionalAstrolabe"));
var FunctionalPalace_1 = __importDefault(require("./FunctionalPalace"));
var palace_1 = require("./palace");
var _plugins = [];
var _mutagens = {};
var _brightness = {};
/**
 * 年分界点参数，默认为立春分界。
 *
 * @version v2.4.0
 *
 * normal：正月初一分界
 * exact：立春分界
 */
var _yearDivide = 'exact';
var _horoscopeDivide = 'exact';
/**
 * 小限分割点，默认为生日。
 *
 * @version v2.4.5
 * @default 'normal'
 *
 * normal: 只考虑年份，不考虑生日
 * birthday: 以生日为分界点
 */
var _ageDivide = 'normal';
var _dayDivide = 'forward';
/**
 * 排盘派别设置。
 *
 * @version v2.5.0
 * @default 'default'
 *
 * default: 以《紫微斗数全书》为基础安星
 * zhongzhou: 以中州派安星法为基础安星
 */
var _algorithm = 'default';
/**
 * 批量加载插件
 *
 * @version v2.3.0
 *
 * @param plugins 插件方法数组
 */
var loadPlugins = function (plugins) {
    Array.prototype.push.apply(_plugins, plugins);
};
exports.loadPlugins = loadPlugins;
/**
 * 加载单个插件
 *
 * @version v2.3.0
 *
 * @param plugin 插件方法
 */
var loadPlugin = function (plugin) {
    _plugins.push(plugin);
};
exports.loadPlugin = loadPlugin;
/**
 * 全局配置四化和亮度
 *
 * 由于key和value都有可能是不同语言传进来的，
 * 所以需会将key和value转化为对应的i18n key。
 *
 * @version 2.3.0
 *
 * @param {Config} param0 自定义配置
 */
var config = function (_a) {
    var mutagens = _a.mutagens, brightness = _a.brightness, _b = _a.yearDivide, yearDivide = _b === void 0 ? _yearDivide : _b, _c = _a.ageDivide, ageDivide = _c === void 0 ? _ageDivide : _c, _d = _a.horoscopeDivide, horoscopeDivide = _d === void 0 ? _horoscopeDivide : _d, _e = _a.dayDivide, dayDivide = _e === void 0 ? _dayDivide : _e, _f = _a.algorithm, algorithm = _f === void 0 ? _algorithm : _f;
    if (mutagens) {
        Object.entries(mutagens).forEach(function (_a) {
            var _b;
            var key = _a[0], value = _a[1];
            _mutagens[(0, i18n_1.kot)(key)] = (_b = value.map(function (item) { return (0, i18n_1.kot)(item); })) !== null && _b !== void 0 ? _b : [];
        });
    }
    if (brightness) {
        Object.entries(brightness).forEach(function (_a) {
            var _b;
            var key = _a[0], value = _a[1];
            _brightness[(0, i18n_1.kot)(key)] = (_b = value.map(function (item) { return (0, i18n_1.kot)(item); })) !== null && _b !== void 0 ? _b : [];
        });
    }
    _yearDivide = yearDivide;
    _horoscopeDivide = horoscopeDivide;
    _ageDivide = ageDivide;
    _algorithm = algorithm;
    _dayDivide = dayDivide;
};
exports.config = config;
var getConfig = function () { return ({
    mutagens: _mutagens,
    brightness: _brightness,
    yearDivide: _yearDivide,
    ageDivide: _ageDivide,
    dayDivide: _dayDivide,
    horoscopeDivide: _horoscopeDivide,
    algorithm: _algorithm,
}); };
exports.getConfig = getConfig;
/**
 * 通过阳历获取星盘信息
 *
 * @deprecated 此方法已在`v2.0.5`废弃，请用 `bySolar` 方法替换，参数不变
 *
 * @param solarDateStr 阳历日期【YYYY-M-D】
 * @param timeIndex 出生时辰序号【0~12】
 * @param gender 性别【男|女】
 * @param fixLeap 是否调整闰月情况【默认 true】，假入调整闰月，则闰月的前半个月算上个月，后半个月算下个月
 * @param language 输出语言
 * @returns 星盘信息
 */
function astrolabeBySolarDate(solarDateStr, timeIndex, gender, fixLeap, language) {
    if (fixLeap === void 0) { fixLeap = true; }
    return bySolar(solarDateStr, timeIndex, gender, fixLeap, language);
}
exports.astrolabeBySolarDate = astrolabeBySolarDate;
/**
 * 通过阳历获取星盘信息
 *
 * @param solarDate 阳历日期【YYYY-M-D】
 * @param timeIndex 出生时辰序号【0~12】
 * @param gender 性别【男|女】
 * @param fixLeap 是否调整闰月情况【默认 true】，假入调整闰月，则闰月的前半个月算上个月，后半个月算下个月
 * @param language 输出语言
 * @returns 星盘信息
 */
function bySolar(solarDate, timeIndex, gender, fixLeap, language) {
    if (fixLeap === void 0) { fixLeap = true; }
    language && (0, i18n_1.setLanguage)(language);
    var palaces = [];
    var dayDivide = (0, exports.getConfig)().dayDivide;
    var tIndex = timeIndex;
    if (dayDivide === 'current' && tIndex >= 12) {
        // 如果当前时辰为晚子时并且晚子时算当天时，将时辰调整为当日子时
        tIndex = 0;
    }
    var yearly = (0, lunar_lite_1.getHeavenlyStemAndEarthlyBranchBySolarDate)(solarDate, tIndex, {
        year: (0, exports.getConfig)().yearDivide,
    }).yearly;
    var earthlyBranchOfYear = (0, i18n_1.kot)(yearly[1], 'Earthly');
    var heavenlyStemOfYear = (0, i18n_1.kot)(yearly[0], 'Heavenly');
    var _a = (0, palace_1.getSoulAndBody)({
        solarDate: solarDate,
        timeIndex: tIndex,
        fixLeap: fixLeap,
    }), bodyIndex = _a.bodyIndex, soulIndex = _a.soulIndex, heavenlyStemOfSoul = _a.heavenlyStemOfSoul, earthlyBranchOfSoul = _a.earthlyBranchOfSoul;
    var palaceNames = (0, palace_1.getPalaceNames)(soulIndex);
    var majorStars = (0, star_1.getMajorStar)({ solarDate: solarDate, timeIndex: tIndex, fixLeap: fixLeap });
    var minorStars = (0, star_1.getMinorStar)(solarDate, tIndex, fixLeap);
    var adjectiveStars = (0, star_1.getAdjectiveStar)({
        solarDate: solarDate,
        timeIndex: tIndex,
        gender: gender,
        fixLeap: fixLeap,
    });
    var changsheng12 = (0, star_1.getchangsheng12)({
        solarDate: solarDate,
        timeIndex: tIndex,
        gender: gender,
        fixLeap: fixLeap,
    });
    var boshi12 = (0, star_1.getBoShi12)(solarDate, gender);
    var _b = (0, star_1.getYearly12)(solarDate), jiangqian12 = _b.jiangqian12, suiqian12 = _b.suiqian12;
    var _c = (0, palace_1.getHoroscope)({ solarDate: solarDate, timeIndex: tIndex, gender: gender, fixLeap: fixLeap }), decadals = _c.decadals, ages = _c.ages;
    for (var i = 0; i < 12; i++) {
        var heavenlyStemOfPalace = data_1.HEAVENLY_STEMS[(0, utils_1.fixIndex)(data_1.HEAVENLY_STEMS.indexOf((0, i18n_1.kot)(heavenlyStemOfSoul, 'Heavenly')) - soulIndex + i, 10)];
        var earthlyBranchOfPalace = data_1.EARTHLY_BRANCHES[(0, utils_1.fixIndex)(2 + i)];
        palaces.push(new FunctionalPalace_1.default({
            index: i,
            name: palaceNames[i],
            isBodyPalace: bodyIndex === i,
            isOriginalPalace: !['ziEarthly', 'chouEarthly'].includes(earthlyBranchOfPalace) && heavenlyStemOfPalace === heavenlyStemOfYear,
            heavenlyStem: (0, i18n_1.t)(heavenlyStemOfPalace),
            earthlyBranch: (0, i18n_1.t)(earthlyBranchOfPalace),
            majorStars: majorStars[i],
            minorStars: minorStars[i],
            adjectiveStars: adjectiveStars[i],
            changsheng12: changsheng12[i],
            boshi12: boshi12[i],
            jiangqian12: jiangqian12[i],
            suiqian12: suiqian12[i],
            decadal: decadals[i],
            ages: ages[i],
        }));
    }
    // 宫位是从寅宫开始，而寅的索引是2，所以需要+2
    var earthlyBranchOfSoulPalace = data_1.EARTHLY_BRANCHES[(0, utils_1.fixIndex)(soulIndex + 2)];
    var earthlyBranchOfBodyPalace = (0, i18n_1.t)(data_1.EARTHLY_BRANCHES[(0, utils_1.fixIndex)(bodyIndex + 2)]);
    var chineseDate = (0, lunar_lite_1.getHeavenlyStemAndEarthlyBranchBySolarDate)(solarDate, timeIndex, {
        year: (0, exports.getConfig)().yearDivide,
        month: (0, exports.getConfig)().horoscopeDivide,
    });
    var lunarDate = (0, lunar_lite_1.solar2lunar)(solarDate);
    var result = new FunctionalAstrolabe_1.default({
        gender: (0, i18n_1.t)((0, i18n_1.kot)(gender)),
        solarDate: solarDate,
        lunarDate: lunarDate.toString(true),
        chineseDate: (0, utils_1.translateChineseDate)(chineseDate),
        rawDates: { lunarDate: lunarDate, chineseDate: chineseDate },
        time: (0, i18n_1.t)(data_1.CHINESE_TIME[timeIndex]),
        timeRange: data_1.TIME_RANGE[timeIndex],
        sign: (0, exports.getSignBySolarDate)(solarDate, language),
        zodiac: (0, exports.getZodiacBySolarDate)(solarDate, language),
        earthlyBranchOfSoulPalace: (0, i18n_1.t)(earthlyBranchOfSoulPalace),
        earthlyBranchOfBodyPalace: earthlyBranchOfBodyPalace,
        soul: (0, i18n_1.t)(data_1.earthlyBranches[earthlyBranchOfSoulPalace].soul),
        body: (0, i18n_1.t)(data_1.earthlyBranches[earthlyBranchOfYear].body),
        fiveElementsClass: (0, palace_1.getFiveElementsClass)(heavenlyStemOfSoul, earthlyBranchOfSoul),
        palaces: palaces,
        copyright: "copyright \u00A9 2023-".concat(new Date().getFullYear(), " iztro (https://github.com/SylarLong/iztro)"),
    });
    _plugins.map(function (plugin) { return result.use(plugin); });
    return result;
}
exports.bySolar = bySolar;
/**
 * 通过农历获取星盘信息
 *
 * @deprecated 此方法已在`v2.0.5`废弃，请用 `byLunar` 方法替换，参数不变
 *
 * @param lunarDateStr 农历日期【YYYY-M-D】，例如2000年七月十七则传入 2000-7-17
 * @param timeIndex 出生时辰序号【0~12】
 * @param gender 性别【男|女】
 * @param isLeapMonth 是否闰月【默认 false】，当实际月份没有闰月时该参数不生效
 * @param fixLeap 是否调整闰月情况【默认 true】，假入调整闰月，则闰月的前半个月算上个月，后半个月算下个月
 * @param language 输出语言
 * @returns 星盘数据
 */
function astrolabeByLunarDate(lunarDateStr, timeIndex, gender, isLeapMonth, fixLeap, language) {
    if (isLeapMonth === void 0) { isLeapMonth = false; }
    if (fixLeap === void 0) { fixLeap = true; }
    return byLunar(lunarDateStr, timeIndex, gender, isLeapMonth, fixLeap, language);
}
exports.astrolabeByLunarDate = astrolabeByLunarDate;
/**
 * 通过农历获取星盘信息
 *
 * @param lunarDateStr 农历日期【YYYY-M-D】，例如2000年七月十七则传入 2000-7-17
 * @param timeIndex 出生时辰序号【0~12】
 * @param gender 性别【男|女】
 * @param isLeapMonth 是否闰月【默认 false】，当实际月份没有闰月时该参数不生效
 * @param fixLeap 是否调整闰月情况【默认 true】，假入调整闰月，则闰月的前半个月算上个月，后半个月算下个月
 * @param language 输出语言
 * @returns 星盘数据
 */
function byLunar(lunarDateStr, timeIndex, gender, isLeapMonth, fixLeap, language) {
    if (isLeapMonth === void 0) { isLeapMonth = false; }
    if (fixLeap === void 0) { fixLeap = true; }
    var solarDate = (0, lunar_lite_1.lunar2solar)(lunarDateStr, isLeapMonth);
    return bySolar(solarDate.toString(), timeIndex, gender, fixLeap, language);
}
exports.byLunar = byLunar;
function rearrangeAstrolable(_a) {
    var from = _a.from, astrolable = _a.astrolable, option = _a.option;
    var timeIndex = option.timeIndex, fixLeap = option.fixLeap;
    // 以传入地支为命宫
    var _b = (0, palace_1.getSoulAndBody)({
        solarDate: astrolable.solarDate,
        timeIndex: timeIndex,
        fixLeap: fixLeap,
        from: from,
    }), soulIndex = _b.soulIndex, bodyIndex = _b.bodyIndex;
    var fiveElementsClass = (0, palace_1.getFiveElementsClass)(from.heavenlyStem, from.earthlyBranch);
    var palaceNames = (0, palace_1.getPalaceNames)(soulIndex);
    var majorStars = (0, star_1.getMajorStar)({ solarDate: astrolable.solarDate, timeIndex: timeIndex, fixLeap: fixLeap, from: from });
    var changsheng12 = (0, star_1.getchangsheng12)({ solarDate: astrolable.solarDate, timeIndex: timeIndex, fixLeap: fixLeap, from: from });
    var _c = (0, palace_1.getHoroscope)({
        solarDate: astrolable.solarDate,
        timeIndex: timeIndex,
        gender: astrolable.gender,
        fixLeap: fixLeap,
        from: from,
    }), decadals = _c.decadals, ages = _c.ages;
    astrolable.fiveElementsClass = fiveElementsClass;
    astrolable.palaces.forEach(function (palace, i) {
        palace.name = palaceNames[i];
        palace.majorStars = majorStars[i];
        palace.changsheng12 = changsheng12[i];
        palace.decadal = decadals[i];
        palace.ages = ages[i];
        palace.isBodyPalace = bodyIndex === i;
    });
    astrolable.earthlyBranchOfSoulPalace = (0, i18n_1.t)(astrolable.palace('命宫').earthlyBranch);
    return astrolable;
}
exports.rearrangeAstrolable = rearrangeAstrolable;
/**
 * 获取排盘信息。
 *
 * @param param0 排盘参数
 * @returns 星盘信息
 */
function withOptions(option) {
    var _a = option.type, type = _a === void 0 ? 'solar' : _a, dateStr = option.dateStr, timeIndex = option.timeIndex, gender = option.gender, isLeapMonth = option.isLeapMonth, fixLeap = option.fixLeap, language = option.language, astroType = option.astroType, cfg = option.config;
    if (cfg) {
        (0, exports.config)(cfg);
    }
    var result;
    if (type === 'solar') {
        result = bySolar(dateStr, timeIndex, gender, fixLeap, language);
    }
    else {
        result = byLunar(dateStr, timeIndex, gender, isLeapMonth, fixLeap, language);
    }
    switch (astroType) {
        case 'earth': {
            // 以身宫干支起五行局重排，身宫为命宫
            var bodyPalace = result.palace('身宫');
            var _b = bodyPalace, heavenlyStem = _b.heavenlyStem, earthlyBranch = _b.earthlyBranch;
            return rearrangeAstrolable({ from: { heavenlyStem: heavenlyStem, earthlyBranch: earthlyBranch }, astrolable: result, option: option });
        }
        case 'human': {
            // 以福德宫干支起五行局重排，福德宫为命宫
            var bodyPalace = result.palace('福德');
            var _c = bodyPalace, heavenlyStem = _c.heavenlyStem, earthlyBranch = _c.earthlyBranch;
            return rearrangeAstrolable({ from: { heavenlyStem: heavenlyStem, earthlyBranch: earthlyBranch }, astrolable: result, option: option });
        }
        default: {
            // 直接返回天盘
            return result;
        }
    }
}
exports.withOptions = withOptions;
/**
 * 通过公历获取十二生肖
 *
 * @version v1.2.1
 *
 * @param solarDateStr 阳历日期【YYYY-M-D】
 * @param language 输出语言，默认为中文
 * @returns 十二生肖
 */
var getZodiacBySolarDate = function (solarDateStr, language) {
    language && (0, i18n_1.setLanguage)(language);
    var yearly = (0, lunar_lite_1.getHeavenlyStemAndEarthlyBranchBySolarDate)(solarDateStr, 0, {
        year: (0, exports.getConfig)().yearDivide,
    }).yearly;
    return (0, i18n_1.t)((0, i18n_1.kot)((0, lunar_lite_1.getZodiac)(yearly[1])));
};
exports.getZodiacBySolarDate = getZodiacBySolarDate;
/**
 * 通过阳历获取星座
 *
 * @version v1.2.1
 *
 * @param solarDateStr 阳历日期【YYYY-M-D】
 * @param language 输出语言，默认为中文
 * @returns 星座
 */
var getSignBySolarDate = function (solarDateStr, language) {
    language && (0, i18n_1.setLanguage)(language);
    return (0, i18n_1.t)((0, i18n_1.kot)((0, lunar_lite_1.getSign)(solarDateStr)));
};
exports.getSignBySolarDate = getSignBySolarDate;
/**
 * 通过农历获取星座
 *
 * @version v1.2.1
 *
 * @param lunarDateStr 农历日期【YYYY-M-D】
 * @param isLeapMonth 是否闰月，如果该月没有闰月则此字段不生效
 * @param language 输出语言，默认为中文
 * @returns 星座
 */
var getSignByLunarDate = function (lunarDateStr, isLeapMonth, language) {
    language && (0, i18n_1.setLanguage)(language);
    var solarDate = (0, lunar_lite_1.lunar2solar)(lunarDateStr, isLeapMonth);
    return (0, exports.getSignBySolarDate)(solarDate.toString(), language);
};
exports.getSignByLunarDate = getSignByLunarDate;
/**
 * 通过阳历获取命宫主星
 *
 * @version v1.2.1
 *
 * @param solarDateStr 阳历日期【YYYY-M-D】
 * @param timeIndex 出生时辰序号【0~12】
 * @param fixLeap 是否调整闰月情况【默认 true】，假入调整闰月，则闰月的前半个月算上个月，后半个月算下个月
 * @param language 输出语言，默认为中文
 * @returns 命宫主星
 */
var getMajorStarBySolarDate = function (solarDateStr, timeIndex, fixLeap, language) {
    if (fixLeap === void 0) { fixLeap = true; }
    language && (0, i18n_1.setLanguage)(language);
    var bodyIndex = (0, palace_1.getSoulAndBody)({ solarDate: solarDateStr, timeIndex: timeIndex, fixLeap: fixLeap }).bodyIndex;
    var majorStars = (0, star_1.getMajorStar)({ solarDate: solarDateStr, timeIndex: timeIndex, fixLeap: fixLeap });
    var stars = majorStars[bodyIndex].filter(function (star) { return star.type === 'major'; });
    if (stars.length) {
        return stars.map(function (star) { return (0, i18n_1.t)(star.name); }).join(',');
    }
    // 如果命宫为空宫，则借对宫主星
    return majorStars[(0, utils_1.fixIndex)(bodyIndex + 6)]
        .filter(function (star) { return star.type === 'major'; })
        .map(function (star) { return (0, i18n_1.t)(star.name); })
        .join(',');
};
exports.getMajorStarBySolarDate = getMajorStarBySolarDate;
/**
 * 通过农历获取命宫主星
 *
 * @version v1.2.1
 *
 * @param lunarDateStr 农历日期【YYYY-M-D】，例如2000年七月十七则传入 2000-7-17
 * @param timeIndex 出生时辰序号【0~12】
 * @param isLeapMonth 是否闰月，如果该月没有闰月则此字段不生效
 * @param fixLeap 是否调整闰月情况【默认 true】，假入调整闰月，则闰月的前半个月算上个月，后半个月算下个月
 * @param language 输出语言，默认为中文
 * @returns 命宫主星
 */
var getMajorStarByLunarDate = function (lunarDateStr, timeIndex, isLeapMonth, fixLeap, language) {
    if (isLeapMonth === void 0) { isLeapMonth = false; }
    if (fixLeap === void 0) { fixLeap = true; }
    var solarDate = (0, lunar_lite_1.lunar2solar)(lunarDateStr, isLeapMonth);
    return (0, exports.getMajorStarBySolarDate)(solarDate.toString(), timeIndex, fixLeap, language);
};
exports.getMajorStarByLunarDate = getMajorStarByLunarDate;

        return exports;
    })();
    
    // Module: astro/palace
    modules['astro/palace'] = (function() {
        "use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getHoroscope = exports.getPalaceNames = exports.getFiveElementsClass = exports.getSoulAndBody = void 0;
var lunar_lite_1 = require("lunar-lite");
var data_1 = require("../data");
var i18n_1 = require("../i18n");
var utils_1 = require("../utils");
var astro_1 = require("./astro");
/**
 * 获取命宫以及身宫数据
 *
 * 1. 定寅首
 * - 甲己年生起丙寅，乙庚年生起戊寅，
 * - 丙辛年生起庚寅，丁壬年生起壬寅，
 * - 戊癸年生起甲寅。
 *
 * 2. 安命身宫诀
 * - 寅起正月，顺数至生月，逆数生时为命宫。
 * - 寅起正月，顺数至生月，顺数生时为身宫。
 *
 * @param {AstrolabeParam} param 通用排盘参数
 * @returns {SoulAndBody} 命宫和身宫数据
 */
var getSoulAndBody = function (param) {
    var solarDate = param.solarDate, timeIndex = param.timeIndex, fixLeap = param.fixLeap, from = param.from;
    var _a = (0, lunar_lite_1.getHeavenlyStemAndEarthlyBranchBySolarDate)(solarDate, timeIndex, {
        year: (0, astro_1.getConfig)().yearDivide,
        month: (0, astro_1.getConfig)().horoscopeDivide,
    }), yearly = _a.yearly, hourly = _a.hourly;
    var earthlyBranchOfTime = (0, i18n_1.kot)(hourly[1], 'Earthly');
    var heavenlyStemOfYear = (0, i18n_1.kot)(yearly[0], 'Heavenly');
    // 紫微斗数以`寅`宫为第一个宫位
    var firstIndex = data_1.EARTHLY_BRANCHES.indexOf('yinEarthly');
    var monthIndex = (0, utils_1.fixLunarMonthIndex)(solarDate, timeIndex, fixLeap);
    // 命宫索引，以寅宫为0，顺时针数到生月地支索引，再逆时针数到生时地支索引
    // 此处数到生月地支索引其实就是农历月份，所以不再计算生月地支索引
    var soulIndex = (0, utils_1.fixIndex)(monthIndex - data_1.EARTHLY_BRANCHES.indexOf(earthlyBranchOfTime));
    // 身宫索引，以寅宫为0，顺时针数到生月地支索引，再顺时针数到生时地支索引
    // 与命宫索引一样，不再赘述
    var bodyIndex = (0, utils_1.fixIndex)(monthIndex + data_1.EARTHLY_BRANCHES.indexOf(earthlyBranchOfTime));
    if ((from === null || from === void 0 ? void 0 : from.heavenlyStem) && (from === null || from === void 0 ? void 0 : from.earthlyBranch)) {
        // 以传入地支为命宫
        soulIndex = (0, utils_1.fixEarthlyBranchIndex)(from.earthlyBranch);
        var bodyOffset = [0, 2, 4, 6, 8, 10, 0, 2, 4, 6, 8, 10, 0];
        bodyIndex = (0, utils_1.fixIndex)(bodyOffset[timeIndex] + soulIndex);
    }
    // 用五虎遁取得寅宫的天干
    var startHevenlyStem = data_1.TIGER_RULE[heavenlyStemOfYear];
    // 获取命宫天干索引，起始天干索引加上命宫的索引即是
    // 天干循环数为10
    var heavenlyStemOfSoulIndex = (0, utils_1.fixIndex)(data_1.HEAVENLY_STEMS.indexOf(startHevenlyStem) + soulIndex, 10);
    // 命宫的天干
    var heavenlyStemOfSoul = (0, i18n_1.t)(data_1.HEAVENLY_STEMS[heavenlyStemOfSoulIndex]);
    // 命宫地支，命宫索引 + `寅`的索引（因为紫微斗数里寅宫是第一个宫位）
    var earthlyBranchOfSoul = (0, i18n_1.t)(data_1.EARTHLY_BRANCHES[(0, utils_1.fixIndex)(soulIndex + firstIndex)]);
    return {
        soulIndex: soulIndex,
        bodyIndex: bodyIndex,
        heavenlyStemOfSoul: heavenlyStemOfSoul,
        earthlyBranchOfSoul: earthlyBranchOfSoul,
    };
};
exports.getSoulAndBody = getSoulAndBody;
/**
 * 定五行局法（以命宫天干地支而定）
 *
 * 纳音五行计算取数巧记口诀：
 *
 * - 甲乙丙丁一到五，子丑午未一来数，
 * - 寅卯申酉二上走，辰巳戌亥三为足。
 * - 干支相加多减五，五行木金水火土。
 *
 * 注解：
 *
 * 1、五行取数：木1 金2 水3 火4 土5
 *
 *  天干取数：
 *  - 甲乙 ——> 1
 *  - 丙丁 ——> 2
 *  - 戊己 ——> 3
 *  - 庚辛 ——> 4
 *  - 壬癸 ——> 5
 *
 *  地支取数：
 *  - 子午丑未 ——> 1
 *  - 寅申卯酉 ——> 2
 *  - 辰戌巳亥 ——> 3
 *
 * 2、计算方法：
 *
 *  干支数相加，超过5者减去5，以差论之。
 *  - 若差为1则五行属木
 *  - 若差为2则五行属金
 *  - 若差为3则五行属水
 *  - 若差为4则五行属火
 *  - 若差为5则五行属土
 *
 * 3、举例：
 *  - 丙子：丙2 子1=3 ——> 水 ——> 水二局
 *  - 辛未：辛4 未1=5 ——> 土 ——> 土五局
 *  - 庚申：庚4 申2=6 ——> 6-5=1 ——> 木 ——> 木三局
 *
 * @param heavenlyStemName 天干
 * @param earthlyBranchName 地支
 * @returns 水二局 ｜ 木三局 ｜ 金四局 ｜ 土五局 ｜ 火六局
 */
var getFiveElementsClass = function (heavenlyStemName, earthlyBranchName) {
    var fiveElementsTable = ['wood3rd', 'metal4th', 'water2nd', 'fire6th', 'earth5th'];
    var heavenlyStem = (0, i18n_1.kot)(heavenlyStemName, 'Heavenly');
    var earthlyBranch = (0, i18n_1.kot)(earthlyBranchName, 'Earthly');
    var heavenlyStemNumber = Math.floor(data_1.HEAVENLY_STEMS.indexOf(heavenlyStem) / 2) + 1;
    var earthlyBranchNumber = Math.floor((0, utils_1.fixIndex)(data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch), 6) / 2) + 1;
    var index = heavenlyStemNumber + earthlyBranchNumber;
    while (index > 5) {
        index -= 5;
    }
    return (0, i18n_1.t)(fiveElementsTable[index - 1]);
};
exports.getFiveElementsClass = getFiveElementsClass;
/**
 * 获取从寅宫开始的各个宫名
 *
 * @param fromIndex 命宫索引
 * @returns 从寅宫开始的各个宫名
 */
var getPalaceNames = function (fromIndex) {
    var names = [];
    for (var i = 0; i < data_1.PALACES.length; i++) {
        var idx = (0, utils_1.fixIndex)(i - fromIndex);
        names[i] = (0, i18n_1.t)(data_1.PALACES[idx]);
    }
    return names;
};
exports.getPalaceNames = getPalaceNames;
/**
 * 起大限
 *
 * - 大限由命宫起，阳男阴女顺行；
 * - 阴男阳女逆行，每十年过一宫限。
 *
 * @param solarDateStr 公历日期
 * @param timeIndex 出生时索引
 * @param gender 性别
 * @param fixLeap 是否修正闰月，若修正，则闰月前15天按上月算，后15天按下月算
 * @returns 从寅宫开始的大限年龄段
 */
var getHoroscope = function (param) {
    var _a, _b;
    var solarDate = param.solarDate, timeIndex = param.timeIndex, gender = param.gender, from = param.from;
    var decadals = [];
    var genderKey = (0, i18n_1.kot)(gender);
    var yearly = (0, lunar_lite_1.getHeavenlyStemAndEarthlyBranchBySolarDate)(solarDate, timeIndex, {
        // 起大限应该与配置同步
        year: (0, astro_1.getConfig)().yearDivide,
    }).yearly;
    var heavenlyStem = (0, i18n_1.kot)(yearly[0], 'Heavenly');
    var earthlyBranch = (0, i18n_1.kot)(yearly[1], 'Earthly');
    var _c = (0, exports.getSoulAndBody)(param), soulIndex = _c.soulIndex, heavenlyStemOfSoul = _c.heavenlyStemOfSoul, earthlyBranchOfSoul = _c.earthlyBranchOfSoul;
    var fiveElementsClass = (0, i18n_1.kot)((0, exports.getFiveElementsClass)((_a = from === null || from === void 0 ? void 0 : from.heavenlyStem) !== null && _a !== void 0 ? _a : heavenlyStemOfSoul, (_b = from === null || from === void 0 ? void 0 : from.earthlyBranch) !== null && _b !== void 0 ? _b : earthlyBranchOfSoul));
    // 用五虎遁获取大限起始天干
    var startHeavenlyStem = data_1.TIGER_RULE[heavenlyStem];
    for (var i = 0; i < 12; i++) {
        var idx = data_1.GENDER[genderKey] === data_1.earthlyBranches[earthlyBranch].yinYang ? (0, utils_1.fixIndex)(soulIndex + i) : (0, utils_1.fixIndex)(soulIndex - i);
        var start = data_1.FiveElementsClass[fiveElementsClass] + 10 * i;
        var heavenlyStemIndex = (0, utils_1.fixIndex)(data_1.HEAVENLY_STEMS.indexOf(startHeavenlyStem) + idx, 10);
        var earthlyBranchIndex = (0, utils_1.fixIndex)(data_1.EARTHLY_BRANCHES.indexOf('yinEarthly') + idx);
        decadals[idx] = {
            range: [start, start + 9],
            heavenlyStem: (0, i18n_1.t)(data_1.HEAVENLY_STEMS[heavenlyStemIndex]),
            earthlyBranch: (0, i18n_1.t)(data_1.EARTHLY_BRANCHES[earthlyBranchIndex]),
        };
    }
    var ageIdx = (0, utils_1.getAgeIndex)(yearly[1]);
    var ages = [];
    for (var i = 0; i < 12; i++) {
        var age = [];
        for (var j = 0; j < 10; j++) {
            age.push(12 * j + i + 1);
        }
        var idx = (0, i18n_1.kot)(gender) === 'male' ? (0, utils_1.fixIndex)(ageIdx + i) : (0, utils_1.fixIndex)(ageIdx - i);
        ages[idx] = age;
    }
    return { decadals: decadals, ages: ages };
};
exports.getHoroscope = getHoroscope;

        return exports;
    })();
    
    // Module: astro/FunctionalAstrolabe
    modules['astro/FunctionalAstrolabe'] = (function() {
        "use strict";
var __spreadArray = (this && this.__spreadArray) || function (to, from, pack) {
    if (pack || arguments.length === 2) for (var i = 0, l = from.length, ar; i < l; i++) {
        if (ar || !(i in from)) {
            if (!ar) ar = Array.prototype.slice.call(from, 0, i);
            ar[i] = from[i];
        }
    }
    return to.concat(ar || Array.prototype.slice.call(from));
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
var dayjs_1 = __importDefault(require("dayjs"));
var lunar_lite_1 = require("lunar-lite");
var data_1 = require("../data");
var i18n_1 = require("../i18n");
var star_1 = require("../star");
var utils_1 = require("../utils");
var analyzer_1 = require("./analyzer");
var palace_1 = require("./palace");
var FunctionalHoroscope_1 = __importDefault(require("./FunctionalHoroscope"));
var astro_1 = require("./astro");
/**
 * 获取运限数据
 *
 * @version v0.2.1
 *
 * @private 私有方法
 *
 * @param $ 星盘对象
 * @param targetDate 阳历日期【可选】，默认为调用时日期
 * @param timeIndex 时辰序号【可选】，若不传会返回 `targetDate` 中时间所在的时辰
 * @returns 运限数据
 */
var _getHoroscopeBySolarDate = function ($, targetDate, timeIndex) {
    if (targetDate === void 0) { targetDate = new Date(); }
    var _birthday = (0, lunar_lite_1.solar2lunar)($.solarDate);
    var _date = (0, lunar_lite_1.solar2lunar)(targetDate);
    var convertTimeIndex = (0, utils_1.timeToIndex)((0, dayjs_1.default)(targetDate).hour());
    var _a = (0, lunar_lite_1.getHeavenlyStemAndEarthlyBranchBySolarDate)(targetDate, timeIndex || convertTimeIndex, {
        // 运限是以立春为界，但为了满足部分流派允许配置
        year: (0, astro_1.getConfig)().horoscopeDivide,
        month: (0, astro_1.getConfig)().horoscopeDivide,
    }), yearly = _a.yearly, monthly = _a.monthly, daily = _a.daily, hourly = _a.hourly;
    // 虚岁
    var nominalAge = _date.lunarYear - _birthday.lunarYear;
    // 是否童限
    var isChildhood = false;
    if ((0, astro_1.getConfig)().ageDivide === 'birthday') {
        // 假如目标日期已经过了生日，则需要加1岁
        // 比如 2022年九月初一 出生的人，在出生后虚岁为 1 岁
        // 但在 2023年九月初二 以后，虚岁则为 2 岁
        if ((_date.lunarYear === _birthday.lunarYear &&
            _date.lunarMonth === _birthday.lunarMonth &&
            _date.lunarDay > _birthday.lunarDay) ||
            _date.lunarMonth > _birthday.lunarMonth) {
            nominalAge += 1;
        }
    }
    else {
        // 以自然年为界，直接加1岁
        nominalAge += 1;
    }
    // 大限索引
    var decadalIndex = -1;
    // 大限天干
    var heavenlyStemOfDecade = 'jia';
    // 大限地支
    var earthlyBranchOfDecade = 'zi';
    // 小限索引
    var ageIndex = -1;
    // 流年索引
    var yearlyIndex = (0, utils_1.fixEarthlyBranchIndex)(yearly[1]);
    // 流月索引
    var monthlyIndex = -1;
    // 流日索引
    var dailyIndex = -1;
    // 流时索引
    var hourlyIndex = -1;
    // 小限天干
    var heavenlyStemOfAge = 'jia';
    // 小限地支
    var earthlyBranchOfAge = 'zi';
    // 查询大限索引
    $.palaces.some(function (_a, index) {
        var decadal = _a.decadal;
        if (nominalAge >= decadal.range[0] && nominalAge <= decadal.range[1]) {
            decadalIndex = index;
            heavenlyStemOfDecade = decadal.heavenlyStem;
            earthlyBranchOfDecade = decadal.earthlyBranch;
            return true;
        }
    });
    if (decadalIndex < 0) {
        // 如果大限索引小于0则证明还没有开始起运
        // 此时应该取小限运
        // 一命二财三疾厄	四岁夫妻五福德
        // 六岁事业为童限	专就宫垣视吉凶
        var palaces = ['命宫', '财帛', '疾厄', '夫妻', '福德', '官禄'];
        var targetIndex = palaces[nominalAge - 1];
        var targetPalace = $.palace(targetIndex);
        if (targetPalace) {
            isChildhood = true;
            decadalIndex = targetPalace.index;
            heavenlyStemOfDecade = targetPalace.heavenlyStem;
            earthlyBranchOfDecade = targetPalace.earthlyBranch;
        }
    }
    // 查询小限索引
    $.palaces.some(function (_a, index) {
        var ages = _a.ages, heavenlyStem = _a.heavenlyStem, earthlyBranch = _a.earthlyBranch;
        if (ages.includes(nominalAge)) {
            ageIndex = index;
            heavenlyStemOfAge = heavenlyStem;
            earthlyBranchOfAge = earthlyBranch;
            return true;
        }
    });
    // 获取流月索引, 流年地支逆数到生月所在宫位，再从该宫位顺数到生时，为正月所在宫位，之后每月一宫
    // 计算流月时需要考虑生月闰月情况，如果是后15天则计算时需要加1月
    var leapAddition = _birthday.isLeap && _birthday.lunarDay > 15 ? 1 : 0;
    // 流月当月的闰月情况也需要考虑
    var dateLeapAddition = _date.isLeap && _date.lunarDay > 15 ? 1 : 0;
    monthlyIndex = (0, utils_1.fixIndex)(yearlyIndex -
        (_birthday.lunarMonth + leapAddition) +
        data_1.EARTHLY_BRANCHES.indexOf((0, i18n_1.kot)($.rawDates.chineseDate.hourly[1])) +
        (_date.lunarMonth + dateLeapAddition));
    // 获取流日索引
    dailyIndex = (0, utils_1.fixIndex)(monthlyIndex + _date.lunarDay - 1);
    // 获取流时索引
    hourlyIndex = (0, utils_1.fixIndex)(dailyIndex + data_1.EARTHLY_BRANCHES.indexOf((0, i18n_1.kot)(hourly[1], 'Earthly')));
    var scope = {
        solarDate: (0, lunar_lite_1.normalizeDateStr)(targetDate).slice(0, 3).join('-'),
        lunarDate: _date.toString(true),
        decadal: {
            index: decadalIndex,
            name: isChildhood ? (0, i18n_1.t)('childhood') : (0, i18n_1.t)('decadal'),
            heavenlyStem: (0, i18n_1.t)((0, i18n_1.kot)(heavenlyStemOfDecade, 'Heavnly')),
            earthlyBranch: (0, i18n_1.t)((0, i18n_1.kot)(earthlyBranchOfDecade, 'Earthly')),
            palaceNames: (0, palace_1.getPalaceNames)(decadalIndex),
            mutagen: (0, utils_1.getMutagensByHeavenlyStem)(heavenlyStemOfDecade),
            stars: (0, star_1.getHoroscopeStar)(heavenlyStemOfDecade, earthlyBranchOfDecade, 'decadal'),
        },
        age: {
            index: ageIndex,
            nominalAge: nominalAge,
            name: (0, i18n_1.t)('turn'),
            heavenlyStem: heavenlyStemOfAge,
            earthlyBranch: earthlyBranchOfAge,
            palaceNames: (0, palace_1.getPalaceNames)(ageIndex),
            mutagen: (0, utils_1.getMutagensByHeavenlyStem)(heavenlyStemOfAge),
        },
        yearly: {
            index: yearlyIndex,
            name: (0, i18n_1.t)('yearly'),
            heavenlyStem: (0, i18n_1.t)((0, i18n_1.kot)(yearly[0], 'Heavenly')),
            earthlyBranch: (0, i18n_1.t)((0, i18n_1.kot)(yearly[1], 'Earthly')),
            palaceNames: (0, palace_1.getPalaceNames)(yearlyIndex),
            mutagen: (0, utils_1.getMutagensByHeavenlyStem)(yearly[0]),
            stars: (0, star_1.getHoroscopeStar)(yearly[0], yearly[1], 'yearly'),
            yearlyDecStar: (0, star_1.getYearly12)(targetDate),
        },
        monthly: {
            index: monthlyIndex,
            name: (0, i18n_1.t)('monthly'),
            heavenlyStem: (0, i18n_1.t)((0, i18n_1.kot)(monthly[0], 'Heavenly')),
            earthlyBranch: (0, i18n_1.t)((0, i18n_1.kot)(monthly[1], 'Earthly')),
            palaceNames: (0, palace_1.getPalaceNames)(monthlyIndex),
            mutagen: (0, utils_1.getMutagensByHeavenlyStem)(monthly[0]),
            stars: (0, star_1.getHoroscopeStar)(monthly[0], monthly[1], 'monthly'),
        },
        daily: {
            index: dailyIndex,
            name: (0, i18n_1.t)('daily'),
            heavenlyStem: (0, i18n_1.t)((0, i18n_1.kot)(daily[0], 'Heavenly')),
            earthlyBranch: (0, i18n_1.t)((0, i18n_1.kot)(daily[1], 'Earthly')),
            palaceNames: (0, palace_1.getPalaceNames)(dailyIndex),
            mutagen: (0, utils_1.getMutagensByHeavenlyStem)(daily[0]),
            stars: (0, star_1.getHoroscopeStar)(daily[0], daily[1], 'daily'),
        },
        hourly: {
            index: hourlyIndex,
            name: (0, i18n_1.t)('hourly'),
            heavenlyStem: (0, i18n_1.t)((0, i18n_1.kot)(hourly[0], 'Heavenly')),
            earthlyBranch: (0, i18n_1.t)((0, i18n_1.kot)(hourly[1], 'Earthly')),
            palaceNames: (0, palace_1.getPalaceNames)(hourlyIndex),
            mutagen: (0, utils_1.getMutagensByHeavenlyStem)(hourly[0]),
            stars: (0, star_1.getHoroscopeStar)(hourly[0], hourly[1], 'hourly'),
        },
    };
    return new FunctionalHoroscope_1.default(scope, $);
};
/**
 * 星盘类。
 *
 * 文档地址：https://docs.iztro.com/posts/astrolabe.html#functionalastrolabe
 */
var FunctionalAstrolabe = /** @class */ (function () {
    function FunctionalAstrolabe(data) {
        var _this = this;
        // 保存插件列表
        this.plugins = [];
        this.star = function (starName) {
            var targetStar;
            _this.palaces.some(function (p) {
                __spreadArray(__spreadArray(__spreadArray([], p.majorStars, true), p.minorStars, true), p.adjectiveStars, true).some(function (item) {
                    if ((0, i18n_1.kot)(item.name) === (0, i18n_1.kot)(starName)) {
                        targetStar = item;
                        targetStar.setPalace(p);
                        targetStar.setAstrolabe(_this);
                    }
                });
            });
            if (!targetStar) {
                throw new Error('invalid star name.');
            }
            return targetStar;
        };
        this.horoscope = function (targetDate, timeIndexOfTarget) {
            if (targetDate === void 0) { targetDate = new Date(); }
            return _getHoroscopeBySolarDate(_this, targetDate, timeIndexOfTarget);
        };
        this.palace = function (indexOrName) { return (0, analyzer_1.getPalace)(_this, indexOrName); };
        this.surroundedPalaces = function (indexOrName) {
            return (0, analyzer_1.getSurroundedPalaces)(_this, indexOrName);
        };
        /**
         * @deprecated 此方法已在`v1.2.0`废弃，请用下列方法替换
         *
         * @example
         *  // AS IS
         *  astrolabe.isSurrounded(0, ["紫微"]);
         *
         *  // TO BE
         *  astrolabe.surroundedPalaces(0).have(["紫微"]);
         */
        this.isSurrounded = function (indexOrName, stars) {
            return _this.surroundedPalaces(indexOrName).have(stars);
        };
        /**
         * @deprecated 此方法已在`v1.2.0`废弃，请用下列方法替换
         *
         * @example
         *  // AS IS
         *  astrolabe.isSurroundedOneOf(0, ["紫微"]);
         *
         *  // TO BE
         *  astrolabe.surroundedPalaces(0).haveOneOf(["紫微"]);
         */
        this.isSurroundedOneOf = function (indexOrName, stars) {
            return _this.surroundedPalaces(indexOrName).haveOneOf(stars);
        };
        /**
         * @deprecated 此方法已在`v1.2.0`废弃，请用下列方法替换
         *
         * @example
         *  // AS IS
         *  astrolabe.notSurrounded(0, ["紫微"]);
         *
         *  // TO BE
         *  astrolabe.surroundedPalaces(0).notHave(["紫微"]);
         */
        this.notSurrounded = function (indexOrName, stars) {
            return _this.surroundedPalaces(indexOrName).notHave(stars);
        };
        this.gender = data.gender;
        this.solarDate = data.solarDate;
        this.lunarDate = data.lunarDate;
        this.chineseDate = data.chineseDate;
        this.rawDates = data.rawDates;
        this.time = data.time;
        this.timeRange = data.timeRange;
        this.sign = data.sign;
        this.zodiac = data.zodiac;
        this.earthlyBranchOfBodyPalace = data.earthlyBranchOfBodyPalace;
        this.earthlyBranchOfSoulPalace = data.earthlyBranchOfSoulPalace;
        this.soul = data.soul;
        this.body = data.body;
        this.fiveElementsClass = data.fiveElementsClass;
        this.palaces = data.palaces;
        this.copyright = data.copyright;
        return this;
    }
    FunctionalAstrolabe.prototype.use = function (plugin) {
        this.plugins.push(plugin);
        plugin.apply(this);
    };
    return FunctionalAstrolabe;
}());
exports.default = FunctionalAstrolabe;

        return exports;
    })();
    
    // Module: astro/FunctionalPalace
    modules['astro/FunctionalPalace'] = (function() {
        "use strict";
Object.defineProperty(exports, "__esModule", { value: true });
var analyzer_1 = require("./analyzer");
/**
 * 宫位类。
 *
 * 文档地址：https://docs.iztro.com/posts/palace.html#functionalastrolabe
 */
var FunctionalPalace = /** @class */ (function () {
    function FunctionalPalace(data) {
        var _this = this;
        this.has = function (stars) { return (0, analyzer_1.hasStars)(_this, stars); };
        this.notHave = function (stars) { return (0, analyzer_1.notHaveStars)(_this, stars); };
        this.hasOneOf = function (stars) { return (0, analyzer_1.hasOneOfStars)(_this, stars); };
        this.hasMutagen = function (mutagen) { return (0, analyzer_1.hasMutagenInPlace)(_this, mutagen); };
        this.notHaveMutagen = function (mutagen) { return (0, analyzer_1.notHaveMutagenInPalce)(_this, mutagen); };
        this.isEmpty = function (excludeStars) {
            var _a;
            if ((_a = _this.majorStars) === null || _a === void 0 ? void 0 : _a.filter(function (star) { return star.type === 'major'; }).length) {
                return false;
            }
            if ((excludeStars === null || excludeStars === void 0 ? void 0 : excludeStars.length) && _this.hasOneOf(excludeStars)) {
                return false;
            }
            return true;
        };
        this.setAstrolabe = function (astro) { return (_this._astrolabe = astro); };
        this.astrolabe = function () { return _this._astrolabe; };
        this.fliesTo = function (to, withMutagens) {
            var _a;
            var toPalace = (_a = _this.astrolabe()) === null || _a === void 0 ? void 0 : _a.palace(to);
            if (!toPalace) {
                return false;
            }
            var heavenlyStem = _this.heavenlyStem;
            var stars = (0, analyzer_1.mutagensToStars)(heavenlyStem, withMutagens);
            if (!stars || !stars.length) {
                return false;
            }
            return toPalace.has(stars);
        };
        this.fliesOneOfTo = function (to, withMutagens) {
            var _a;
            var toPalace = (_a = _this.astrolabe()) === null || _a === void 0 ? void 0 : _a.palace(to);
            if (!toPalace) {
                return false;
            }
            var heavenlyStem = _this.heavenlyStem;
            var stars = (0, analyzer_1.mutagensToStars)(heavenlyStem, withMutagens);
            if (!stars || !stars.length) {
                return true;
            }
            return toPalace.hasOneOf(stars);
        };
        this.notFlyTo = function (to, withMutagens) {
            var _a;
            var toPalace = (_a = _this.astrolabe()) === null || _a === void 0 ? void 0 : _a.palace(to);
            if (!toPalace) {
                return false;
            }
            var heavenlyStem = _this.heavenlyStem;
            var stars = (0, analyzer_1.mutagensToStars)(heavenlyStem, withMutagens);
            if (!stars || !stars.length) {
                return true;
            }
            return toPalace.notHave(stars);
        };
        this.selfMutaged = function (withMutagens) {
            var heavenlyStem = _this.heavenlyStem;
            var stars = (0, analyzer_1.mutagensToStars)(heavenlyStem, withMutagens);
            return _this.has(stars);
        };
        this.selfMutagedOneOf = function (withMutagens) {
            var muts = [];
            if (!withMutagens || !withMutagens.length) {
                muts = ['禄', '权', '科', '忌'];
            }
            else {
                muts = withMutagens;
            }
            var heavenlyStem = _this.heavenlyStem;
            var stars = (0, analyzer_1.mutagensToStars)(heavenlyStem, muts);
            return _this.hasOneOf(stars);
        };
        this.notSelfMutaged = function (withMutagens) {
            var muts = [];
            if (!withMutagens || !withMutagens.length) {
                muts = ['禄', '权', '科', '忌'];
            }
            else {
                muts = withMutagens;
            }
            var heavenlyStem = _this.heavenlyStem;
            var stars = (0, analyzer_1.mutagensToStars)(heavenlyStem, muts);
            return _this.notHave(stars);
        };
        this.mutagedPlaces = function () {
            var heavenlyStem = _this.heavenlyStem;
            var astrolabe = _this.astrolabe();
            if (!astrolabe) {
                return [];
            }
            var stars = (0, analyzer_1.mutagensToStars)(heavenlyStem, ['禄', '权', '科', '忌']);
            return stars.map(function (star) { return astrolabe.star(star).palace(); });
        };
        this.index = data.index;
        this.name = data.name;
        this.isBodyPalace = data.isBodyPalace;
        this.isOriginalPalace = data.isOriginalPalace;
        this.heavenlyStem = data.heavenlyStem;
        this.earthlyBranch = data.earthlyBranch;
        this.majorStars = data.majorStars;
        this.minorStars = data.minorStars;
        this.adjectiveStars = data.adjectiveStars;
        this.changsheng12 = data.changsheng12;
        this.boshi12 = data.boshi12;
        this.jiangqian12 = data.jiangqian12;
        this.suiqian12 = data.suiqian12;
        this.decadal = data.decadal;
        this.ages = data.ages;
        return this;
    }
    return FunctionalPalace;
}());
exports.default = FunctionalPalace;

        return exports;
    })();
    
    // Module: astro/FunctionalSurpalaces
    modules['astro/FunctionalSurpalaces'] = (function() {
        "use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.FunctionalSurpalaces = void 0;
var analyzer_1 = require("./analyzer");
var FunctionalSurpalaces = /** @class */ (function () {
    function FunctionalSurpalaces(_a) {
        var _this = this;
        var target = _a.target, opposite = _a.opposite, wealth = _a.wealth, career = _a.career;
        this.have = function (stars) { return (0, analyzer_1.isSurroundedByStars)(_this, stars); };
        this.notHave = function (stars) { return (0, analyzer_1.notSurroundedByStars)(_this, stars); };
        this.haveOneOf = function (stars) { return (0, analyzer_1.isSurroundedByOneOfStars)(_this, stars); };
        this.haveMutagen = function (mutagen) {
            return _this.target.hasMutagen(mutagen) ||
                _this.opposite.hasMutagen(mutagen) ||
                _this.wealth.hasMutagen(mutagen) ||
                _this.career.hasMutagen(mutagen);
        };
        this.notHaveMutagen = function (mutagen) { return !_this.haveMutagen(mutagen); };
        this.target = target;
        this.opposite = opposite;
        this.wealth = wealth;
        this.career = career;
    }
    return FunctionalSurpalaces;
}());
exports.FunctionalSurpalaces = FunctionalSurpalaces;

        return exports;
    })();
    
    // Module: star/index
    modules['star/index'] = (function() {
        "use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.initStars = void 0;
var initStars = function () { return [[], [], [], [], [], [], [], [], [], [], [], []]; };
exports.initStars = initStars;
__exportStar(require("./location"), exports);
__exportStar(require("./majorStar"), exports);
__exportStar(require("./minorStar"), exports);
__exportStar(require("./adjectiveStar"), exports);
__exportStar(require("./decorativeStar"), exports);
__exportStar(require("./horoscopeStar"), exports);

        return exports;
    })();
    
    // Module: star/location
    modules['star/location'] = (function() {
        "use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getChangQuIndexByHeavenlyStem = exports.getMonthlyStarIndex = exports.getNianjieIndex = exports.getYearlyStarIndex = exports.getDahaoIndex = exports.getJieshaAdjIndex = exports.getGuGuaIndex = exports.getHuagaiXianchiIndex = exports.getLuanXiIndex = exports.getHuoLingIndex = exports.getKongJieIndex = exports.getTimelyStarIndex = exports.getDailyStarIndex = exports.getChangQuIndex = exports.getZuoYouIndex = exports.getKuiYueIndex = exports.getLuYangTuoMaIndex = exports.getStartIndex = void 0;
var lunar_lite_1 = require("lunar-lite");
var astro_1 = require("../astro");
var data_1 = require("../data");
var i18n_1 = require("../i18n");
var utils_1 = require("../utils");
/**
 * 起紫微星诀算法
 *
 * - 六五四三二，酉午亥辰丑，
 * - 局数除日数，商数宫前走；
 * - 若见数无余，便要起虎口，
 * - 日数小於局，还直宫中守。
 *
 * 举例：
 * - 例一：27日出生木三局，以三除27，循环0次就可以整除，27➗3=9，从寅进9格，在戍安紫微。
 * - 例二：13日出生火六局，以六除13，最少需要加5才能整除， 18➗8=3，从寅进3格为辰，添加数为5（奇数），故要逆回五宫，在亥安紫微。
 * - 例三：6日出生土五局，以五除6，最少需要加4才能整除，10➗5=2，从寅进2格为卯，添加数为4（偶数），顺行4格为未，在未安紫微。
 *
 * @param solarDateStr 公历日期 YYYY-MM-DD
 * @param timeIndex 时辰索引【0～12】
 * @param fixLeap 是否调整农历闰月（若该月不是闰月则不会生效）
 * @param from 根据传入的干支起五行局来计算紫微星和天府星位置
 * @returns 紫微和天府星所在宫位索引
 */
var getStartIndex = function (param) {
    var _a, _b;
    var solarDate = param.solarDate, timeIndex = param.timeIndex, fixLeap = param.fixLeap, from = param.from;
    var _c = (0, astro_1.getSoulAndBody)({ solarDate: solarDate, timeIndex: timeIndex, fixLeap: fixLeap }), heavenlyStemOfSoul = _c.heavenlyStemOfSoul, earthlyBranchOfSoul = _c.earthlyBranchOfSoul;
    var lunarDay = (0, lunar_lite_1.solar2lunar)(solarDate).lunarDay;
    // 如果已传入干支，则用传入干支起五行局
    // 确定用于起五行局的地盘干支
    var baseHeavenlyStem = (_a = from === null || from === void 0 ? void 0 : from.heavenlyStem) !== null && _a !== void 0 ? _a : heavenlyStemOfSoul;
    var baseEarthlyBranch = (_b = from === null || from === void 0 ? void 0 : from.earthlyBranch) !== null && _b !== void 0 ? _b : earthlyBranchOfSoul;
    // 获取五行局
    var fiveElements = (0, i18n_1.kot)((0, astro_1.getFiveElementsClass)(baseHeavenlyStem, baseEarthlyBranch));
    var fiveElementsValue = data_1.FiveElementsClass[fiveElements];
    var remainder = -1; // 余数
    var quotient; // 商
    var offset = -1; // 循环次数
    // 获取当月最大天数
    var maxDays = (0, lunar_lite_1.getTotalDaysOfLunarMonth)(solarDate);
    // 如果timeIndex等于12说明是晚子时，需要加一天
    var _day = timeIndex === 12 ? lunarDay + 1 : lunarDay;
    if (_day > maxDays) {
        // 假如日期超过当月最大天数，说明跨月了，需要处理为合法日期
        _day -= maxDays;
    }
    do {
        // 农历出生日（初一为1，以此类推）加上偏移量作为除数，以这个数处以五行局的数向下取整
        // 需要一直运算到余数为0为止
        offset++;
        var divisor = _day + offset;
        quotient = Math.floor(divisor / fiveElementsValue);
        remainder = divisor % fiveElementsValue;
    } while (remainder !== 0);
    // 将商除以12取余数
    quotient %= 12;
    // 以商减一（因为需要从0开始）作为起始位置
    var ziweiIndex = quotient - 1;
    if (offset % 2 === 0) {
        // 若循环次数为偶数，则索引逆时针数到循环数
        ziweiIndex += offset;
    }
    else {
        // 若循环次数为偶数，则索引顺时针数到循环数
        ziweiIndex -= offset;
    }
    ziweiIndex = (0, utils_1.fixIndex)(ziweiIndex);
    // 天府星位置与紫微星相对
    var tianfuIndex = (0, utils_1.fixIndex)(12 - ziweiIndex);
    return { ziweiIndex: ziweiIndex, tianfuIndex: tianfuIndex };
};
exports.getStartIndex = getStartIndex;
/**
 * 按年干支计算禄存、擎羊，陀罗、天马的索引
 *
 * 定禄存、羊、陀诀（按年干）
 *
 * - 甲禄到寅宫，乙禄居卯府。
 * - 丙戊禄在巳，丁己禄在午。
 * - 庚禄定居申，辛禄酉上补。
 * - 壬禄亥中藏，癸禄居子户。
 * - 禄前羊刃当，禄后陀罗府。
 *
 * 安天马（按年支），天马只会出现在四马地【寅申巳亥】
 *
 * - 寅午戍流马在申，申子辰流马在寅。
 * - 巳酉丑流马在亥，亥卯未流马在巳。
 *
 * @param heavenlyStemName 天干
 * @param earthlyBranchName 地支
 * @returns 禄存、擎羊，陀罗、天马的索引
 */
var getLuYangTuoMaIndex = function (heavenlyStemName, earthlyBranchName) {
    var luIndex = -1; // 禄存索引
    var maIndex = 0; // 天马索引
    var heavenlyStem = (0, i18n_1.kot)(heavenlyStemName, 'Heavenly');
    var earthlyBranch = (0, i18n_1.kot)(earthlyBranchName, 'Earthly');
    switch (earthlyBranch) {
        case 'yinEarthly':
        case 'wuEarthly':
        case 'xuEarthly':
            maIndex = (0, utils_1.fixEarthlyBranchIndex)('shen');
            break;
        case 'shenEarthly':
        case 'ziEarthly':
        case 'chenEarthly':
            maIndex = (0, utils_1.fixEarthlyBranchIndex)('yin');
            break;
        case 'siEarthly':
        case 'youEarthly':
        case 'chouEarthly':
            maIndex = (0, utils_1.fixEarthlyBranchIndex)('hai');
            break;
        case 'haiEarthly':
        case 'maoEarthly':
        case 'weiEarthly':
            maIndex = (0, utils_1.fixEarthlyBranchIndex)('si');
            break;
    }
    switch (heavenlyStem) {
        case 'jiaHeavenly': {
            luIndex = (0, utils_1.fixEarthlyBranchIndex)('yin');
            break;
        }
        case 'yiHeavenly': {
            luIndex = (0, utils_1.fixEarthlyBranchIndex)('mao');
            break;
        }
        case 'bingHeavenly':
        case 'wuHeavenly': {
            luIndex = (0, utils_1.fixEarthlyBranchIndex)('si');
            break;
        }
        case 'dingHeavenly':
        case 'jiHeavenly': {
            luIndex = (0, utils_1.fixEarthlyBranchIndex)('woo');
            break;
        }
        case 'gengHeavenly': {
            luIndex = (0, utils_1.fixEarthlyBranchIndex)('shen');
            break;
        }
        case 'xinHeavenly': {
            luIndex = (0, utils_1.fixEarthlyBranchIndex)('you');
            break;
        }
        case 'renHeavenly': {
            luIndex = (0, utils_1.fixEarthlyBranchIndex)('hai');
            break;
        }
        case 'guiHeavenly': {
            luIndex = (0, utils_1.fixEarthlyBranchIndex)('zi');
            break;
        }
    }
    return {
        luIndex: luIndex,
        maIndex: maIndex,
        yangIndex: (0, utils_1.fixIndex)(luIndex + 1),
        tuoIndex: (0, utils_1.fixIndex)(luIndex - 1),
    };
};
exports.getLuYangTuoMaIndex = getLuYangTuoMaIndex;
/**
 * 获取天魁天钺所在宫位索引（按年干）
 *
 * - 甲戊庚之年丑未
 * - 乙己之年子申
 * - 辛年午寅
 * - 壬癸之年卯巳
 * - 丙丁之年亥酉
 *
 * @param heavenlyStemName 天干
 * @returns
 */
var getKuiYueIndex = function (heavenlyStemName) {
    var kuiIndex = -1;
    var yueIndex = -1;
    var heavenlyStem = (0, i18n_1.kot)(heavenlyStemName, 'Heavenly');
    switch (heavenlyStem) {
        case 'jiaHeavenly':
        case 'wuHeavenly':
        case 'gengHeavenly':
            kuiIndex = (0, utils_1.fixEarthlyBranchIndex)('chou');
            yueIndex = (0, utils_1.fixEarthlyBranchIndex)('wei');
            break;
        case 'yiHeavenly':
        case 'jiHeavenly':
            kuiIndex = (0, utils_1.fixEarthlyBranchIndex)('zi');
            yueIndex = (0, utils_1.fixEarthlyBranchIndex)('shen');
            break;
        case 'xinHeavenly':
            kuiIndex = (0, utils_1.fixEarthlyBranchIndex)('woo');
            yueIndex = (0, utils_1.fixEarthlyBranchIndex)('yin');
            break;
        case 'bingHeavenly':
        case 'dingHeavenly':
            kuiIndex = (0, utils_1.fixEarthlyBranchIndex)('hai');
            yueIndex = (0, utils_1.fixEarthlyBranchIndex)('you');
            break;
        case 'renHeavenly':
        case 'guiHeavenly':
            kuiIndex = (0, utils_1.fixEarthlyBranchIndex)('mao');
            yueIndex = (0, utils_1.fixEarthlyBranchIndex)('si');
            break;
    }
    return { kuiIndex: kuiIndex, yueIndex: yueIndex };
};
exports.getKuiYueIndex = getKuiYueIndex;
/**
 * 获取左辅右弼的索引（按生月）
 *
 * - 辰上顺正寻左辅
 * - 戌上逆正右弼当
 *
 * 解释：
 *
 * - 从辰顺数农历月份数是左辅的索引
 * - 从戌逆数农历月份数是右弼的索引
 *
 * @param lunarMonth 农历月份
 * @returns 左辅、右弼索引
 */
var getZuoYouIndex = function (lunarMonth) {
    var zuoIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('chen') + (lunarMonth - 1));
    var youIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('xu') - (lunarMonth - 1));
    return { zuoIndex: zuoIndex, youIndex: youIndex };
};
exports.getZuoYouIndex = getZuoYouIndex;
/**
 * 获取文昌文曲的索引（按时支）
 *
 * - 辰上顺时文曲位
 * - 戌上逆时觅文昌
 *
 * 解释：
 *
 * - 从辰顺数到时辰地支索引是文曲的索引
 * - 从戌逆数到时辰地支索引是文昌的索引
 *
 * 由于时辰地支的索引即是时辰的序号，所以可以直接使用时辰的序号
 *
 * @param timeIndex 时辰索引【0～12】
 * @returns 文昌、文曲索引
 */
var getChangQuIndex = function (timeIndex) {
    var changIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('xu') - (0, utils_1.fixIndex)(timeIndex));
    var quIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('chen') + (0, utils_1.fixIndex)(timeIndex));
    return { changIndex: changIndex, quIndex: quIndex };
};
exports.getChangQuIndex = getChangQuIndex;
/**
 * 获取日系星索引，包括
 *
 * 三台，八座，恩光，天贵
 *
 * - 安三台八座
 *   - 由左辅之宫位起初一，顺行至生日安三台。
 *   - 由右弼之宫位起初一，逆行至生日安八座。
 *
 * - 安恩光天贵
 *   - 由文昌之宫位起初一，顺行至生日再退一步起恩光。
 *   - 由文曲之宫位起初一，顺行至生日再退一步起天贵。
 *
 * @param solarDateStr 阳历日期
 * @param timeIndex 时辰索引【0～12】
 * @returns 三台，八座索引
 */
var getDailyStarIndex = function (solarDateStr, timeIndex, fixLeap) {
    var lunarDay = (0, lunar_lite_1.solar2lunar)(solarDateStr).lunarDay;
    var monthIndex = (0, utils_1.fixLunarMonthIndex)(solarDateStr, timeIndex, fixLeap);
    // 此处获取到的是索引，下标是从0开始的，所以需要加1
    var _a = (0, exports.getZuoYouIndex)(monthIndex + 1), zuoIndex = _a.zuoIndex, youIndex = _a.youIndex;
    var _b = (0, exports.getChangQuIndex)(timeIndex), changIndex = _b.changIndex, quIndex = _b.quIndex;
    var dayIndex = (0, utils_1.fixLunarDayIndex)(lunarDay, timeIndex);
    var santaiIndex = (0, utils_1.fixIndex)((zuoIndex + dayIndex) % 12);
    var bazuoIndex = (0, utils_1.fixIndex)((youIndex - dayIndex) % 12);
    var enguangIndex = (0, utils_1.fixIndex)(((changIndex + dayIndex) % 12) - 1);
    var tianguiIndex = (0, utils_1.fixIndex)(((quIndex + dayIndex) % 12) - 1);
    return { santaiIndex: santaiIndex, bazuoIndex: bazuoIndex, enguangIndex: enguangIndex, tianguiIndex: tianguiIndex };
};
exports.getDailyStarIndex = getDailyStarIndex;
/**
 * 获取时系星耀索引，包括台辅，封诰
 *
 * @param timeIndex 时辰序号【0～12】
 * @returns 台辅，封诰索引
 */
var getTimelyStarIndex = function (timeIndex) {
    var taifuIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('woo') + (0, utils_1.fixIndex)(timeIndex));
    var fenggaoIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('yin') + (0, utils_1.fixIndex)(timeIndex));
    return { taifuIndex: taifuIndex, fenggaoIndex: fenggaoIndex };
};
exports.getTimelyStarIndex = getTimelyStarIndex;
/**
 * 获取地空地劫的索引（按时支）
 *
 * - 亥上子时顺安劫
 * - 逆回便是地空亡
 *
 * 解释：
 *
 * - 从亥顺数到时辰地支索引是地劫的索引
 * - 从亥逆数到时辰地支索引是地空的索引
 *
 * 由于时辰地支的索引即是时辰的序号，所以可以直接使用时辰的序号
 *
 * @param timeIndex 时辰索引【0～12】
 * @returns 地空、地劫索引
 */
var getKongJieIndex = function (timeIndex) {
    var fixedTimeIndex = (0, utils_1.fixIndex)(timeIndex);
    var haiIndex = (0, utils_1.fixEarthlyBranchIndex)('hai');
    var kongIndex = (0, utils_1.fixIndex)(haiIndex - fixedTimeIndex);
    var jieIndex = (0, utils_1.fixIndex)(haiIndex + fixedTimeIndex);
    return { kongIndex: kongIndex, jieIndex: jieIndex };
};
exports.getKongJieIndex = getKongJieIndex;
/**
 * 获取火星铃星索引（按年支以及时支）
 *
 * - 申子辰人寅戌扬
 * - 寅午戌人丑卯方
 * - 巳酉丑人卯戌位
 * - 亥卯未人酉戌房
 *
 * 起火铃二耀先据出生年支，依口诀定火铃起子时位。
 *
 * 例如壬辰年卯时生人，据[申子辰人寅戌扬]口诀，故火星在寅宫起子时，铃星在戌宫起子时，顺数至卯时，即火星在巳，铃星在丑。
 *
 * @param earthlyBranchName 地支
 * @param timeIndex 时辰序号
 * @returns 火星、铃星索引
 */
var getHuoLingIndex = function (earthlyBranchName, timeIndex) {
    var huoIndex = -1;
    var lingIndex = -1;
    var fixedTimeIndex = (0, utils_1.fixIndex)(timeIndex);
    var earthlyBranch = (0, i18n_1.kot)(earthlyBranchName, 'Earthly');
    switch (earthlyBranch) {
        case 'yinEarthly':
        case 'wuEarthly':
        case 'xuEarthly': {
            huoIndex = (0, utils_1.fixEarthlyBranchIndex)('chou') + fixedTimeIndex;
            lingIndex = (0, utils_1.fixEarthlyBranchIndex)('mao') + fixedTimeIndex;
            break;
        }
        case 'shenEarthly':
        case 'ziEarthly':
        case 'chenEarthly': {
            huoIndex = (0, utils_1.fixEarthlyBranchIndex)('yin') + fixedTimeIndex;
            lingIndex = (0, utils_1.fixEarthlyBranchIndex)('xu') + fixedTimeIndex;
            break;
        }
        case 'siEarthly':
        case 'youEarthly':
        case 'chouEarthly': {
            huoIndex = (0, utils_1.fixEarthlyBranchIndex)('mao') + fixedTimeIndex;
            lingIndex = (0, utils_1.fixEarthlyBranchIndex)('xu') + fixedTimeIndex;
            break;
        }
        case 'haiEarthly':
        case 'weiEarthly':
        case 'maoEarthly': {
            huoIndex = (0, utils_1.fixEarthlyBranchIndex)('you') + fixedTimeIndex;
            lingIndex = (0, utils_1.fixEarthlyBranchIndex)('xu') + fixedTimeIndex;
            break;
        }
    }
    return {
        huoIndex: (0, utils_1.fixIndex)(huoIndex),
        lingIndex: (0, utils_1.fixIndex)(lingIndex),
    };
};
exports.getHuoLingIndex = getHuoLingIndex;
/**
 * 获取红鸾天喜所在宫位索引
 *
 * - 卯上起子逆数之
 * - 数到当生太岁支
 * - 坐守此宫红鸾位
 * - 对宫天喜不差移
 *
 * @param earthlyBranchName 年支
 * @returns 红鸾、天喜索引
 */
var getLuanXiIndex = function (earthlyBranchName) {
    var earthlyBranch = (0, i18n_1.kot)(earthlyBranchName, 'Earthly');
    var hongluanIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('mao') - data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch));
    var tianxiIndex = (0, utils_1.fixIndex)(hongluanIndex + 6);
    return { hongluanIndex: hongluanIndex, tianxiIndex: tianxiIndex };
};
exports.getLuanXiIndex = getLuanXiIndex;
/**
 * 安华盖
 * - 子辰申年在辰，丑巳酉年在丑
 * - 寅午戍年在戍，卯未亥年在未。
 *
 * 安咸池
 * - 子辰申年在酉，丑巳酉年在午
 * - 寅午戍年在卯，卯未亥年在子。
 *
 * @param earthlyBranchName 地支
 * @returns 华盖、咸池索引
 */
var getHuagaiXianchiIndex = function (earthlyBranchName) {
    var hgIdx = -1;
    var xcIdx = -1;
    var earthlyBranch = (0, i18n_1.kot)(earthlyBranchName, 'Earthly');
    switch (earthlyBranch) {
        case 'yinEarthly':
        case 'wuEarthly':
        case 'xuEarthly': {
            hgIdx = (0, utils_1.fixEarthlyBranchIndex)('xu');
            xcIdx = (0, utils_1.fixEarthlyBranchIndex)('mao');
            break;
        }
        case 'shenEarthly':
        case 'ziEarthly':
        case 'chenEarthly': {
            hgIdx = (0, utils_1.fixEarthlyBranchIndex)('chen');
            xcIdx = (0, utils_1.fixEarthlyBranchIndex)('you');
            break;
        }
        case 'siEarthly':
        case 'youEarthly':
        case 'chouEarthly': {
            hgIdx = (0, utils_1.fixEarthlyBranchIndex)('chou');
            xcIdx = (0, utils_1.fixEarthlyBranchIndex)('woo');
            break;
        }
        case 'haiEarthly':
        case 'weiEarthly':
        case 'maoEarthly': {
            hgIdx = (0, utils_1.fixEarthlyBranchIndex)('wei');
            xcIdx = (0, utils_1.fixEarthlyBranchIndex)('zi');
            break;
        }
    }
    return {
        huagaiIndex: (0, utils_1.fixIndex)(hgIdx),
        xianchiIndex: (0, utils_1.fixIndex)(xcIdx),
    };
};
exports.getHuagaiXianchiIndex = getHuagaiXianchiIndex;
/**
 * 安孤辰寡宿
 * - 寅卯辰年安巳丑
 * - 巳午未年安申辰
 * - 申酉戍年安亥未
 * - 亥子丑年安寅戍。
 *
 * @param earthlyBranchName 地支
 * @returns 孤辰、寡宿索引
 */
var getGuGuaIndex = function (earthlyBranchName) {
    var guIdx = -1;
    var guaIdx = -1;
    var earthlyBranch = (0, i18n_1.kot)(earthlyBranchName, 'Earthly');
    switch (earthlyBranch) {
        case 'yinEarthly':
        case 'maoEarthly':
        case 'chenEarthly': {
            guIdx = (0, utils_1.fixEarthlyBranchIndex)('si');
            guaIdx = (0, utils_1.fixEarthlyBranchIndex)('chou');
            break;
        }
        case 'siEarthly':
        case 'wuEarthly':
        case 'weiEarthly': {
            guIdx = (0, utils_1.fixEarthlyBranchIndex)('shen');
            guaIdx = (0, utils_1.fixEarthlyBranchIndex)('chen');
            break;
        }
        case 'shenEarthly':
        case 'youEarthly':
        case 'xuEarthly': {
            guIdx = (0, utils_1.fixEarthlyBranchIndex)('hai');
            guaIdx = (0, utils_1.fixEarthlyBranchIndex)('wei');
            break;
        }
        case 'haiEarthly':
        case 'ziEarthly':
        case 'chouEarthly': {
            guIdx = (0, utils_1.fixEarthlyBranchIndex)('yin');
            guaIdx = (0, utils_1.fixEarthlyBranchIndex)('xu');
            break;
        }
    }
    return {
        guchenIndex: (0, utils_1.fixIndex)(guIdx),
        guasuIndex: (0, utils_1.fixIndex)(guaIdx),
    };
};
exports.getGuGuaIndex = getGuGuaIndex;
/**
 * 安劫杀诀（年支）
 * 申子辰人蛇开口、亥卯未人猴速走
 * 寅午戌人猪面黑、巳酉丑人虎咆哮
 *
 * @version v2.5.0
 *
 * @param earthlyBranchKey 生年地支
 * @returns {number} 劫杀索引
 */
var getJieshaAdjIndex = function (earthlyBranchKey) {
    switch (earthlyBranchKey) {
        case 'shenEarthly':
        case 'ziEarthly':
        case 'chenEarthly':
            return 3;
        case 'haiEarthly':
        case 'maoEarthly':
        case 'weiEarthly':
            return 6;
        case 'yinEarthly':
        case 'wuEarthly':
        case 'xuEarthly':
            return 9;
        case 'siEarthly':
        case 'youEarthly':
        case 'chouEarthly':
            return 0;
    }
};
exports.getJieshaAdjIndex = getJieshaAdjIndex;
/**
 * 安大耗诀（年支）
 * 但用年支去对冲、阴阳移位过一宫
 * 阳顺阴逆移其位、大耗原来不可逢
 *
 * 大耗安法，是在年支之对宫，前一位或后一位安星。阳支顺行前一位，阴支逆行后一位。
 *
 * @param earthlyBranchKey 生年地支
 * @returns {number} 大耗索引
 */
var getDahaoIndex = function (earthlyBranchKey) {
    var matched = [
        'weiEarthly',
        'wuEarthly',
        'youEarthly',
        'shenEarthly',
        'haiEarthly',
        'xuEarthly',
        'chouEarthly',
        'ziEarthly',
        'maoEarthly',
        'yinEarthly',
        'siEarthly',
        'chenEarthly',
    ][data_1.EARTHLY_BRANCHES.indexOf(earthlyBranchKey)];
    // 因为宫位是以寅宫开始排的，所以需要 -2 来对齐
    return (0, utils_1.fixIndex)(data_1.EARTHLY_BRANCHES.indexOf(matched) - 2);
};
exports.getDahaoIndex = getDahaoIndex;
/**
 * 获取年系星的索引，包括
 * 咸池，华盖，孤辰，寡宿, 天厨，破碎，天才，天寿，蜚蠊, 龙池，凤阁，天哭，天虚，
 * 天官，天福
 *
 * - 安天才天寿
 *   - 天才由命宫起子，顺行至本生年支安之。天寿由身宫起子，顺行至本生年支安之。
 *
 * - 安破碎
 *   - 子午卯酉年安巳宫，寅申巳亥年安酉宫，辰戍丑未年安丑宫。
 *
 * - 安天厨
 *   - 甲丁食蛇口，乙戊辛马方。丙从鼠口得，己食于猴房。庚食虎头上，壬鸡癸猪堂。
 *
 * - 安蜚蠊
 *   - 子丑寅年在申酉戍，卯辰巳年在巳午未，午未申年在寅卯辰，酉戍亥年在亥子丑。
 *
 * - 安龙池凤阁
 *   - 龙池从辰宫起子，顺至本生年支安之。凤阁从戍宫起子，逆行至本生年支安之。
 *
 * - 安天哭天虚
 *   - 天哭天虚起午宫，午宫起子两分踪，哭逆行兮虚顺转，数到生年便停留。
 *
 * - 安天官天福
 *   - 甲喜羊鸡乙龙猴，丙年蛇鼠一窝谋。丁虎擒猪戊玉兔，
 *   - 己鸡居然与虎俦。庚猪马辛鸡蛇走，壬犬马癸马蛇游。
 *
 * - 安截路空亡（截空）
 *   - 甲己之年申酉，乙庚之年午未，
 *   - 丙辛之年辰巳，丁壬之年寅卯，
 *   - 戊癸之年子丑。
 *
 * - 安天空
 *   - 生年支顺数的前一位就是。
 * @param solarDate 阳历日期
 * @param timeIndex 时辰序号
 * @param gender 性别
 * @param fixLeap 是否修复闰月，假如当月不是闰月则不生效
 */
var getYearlyStarIndex = function (param) {
    var _a;
    var solarDate = param.solarDate, timeIndex = param.timeIndex, gender = param.gender, fixLeap = param.fixLeap;
    var _b = (0, astro_1.getConfig)(), horoscopeDivide = _b.horoscopeDivide, algorithm = _b.algorithm;
    var yearly = (0, lunar_lite_1.getHeavenlyStemAndEarthlyBranchBySolarDate)(solarDate, timeIndex, {
        // 流耀应该用立春为界，但为了满足不同流派的需求允许配置
        year: horoscopeDivide,
    }).yearly;
    var _c = (0, astro_1.getSoulAndBody)({ solarDate: solarDate, timeIndex: timeIndex, fixLeap: fixLeap }), soulIndex = _c.soulIndex, bodyIndex = _c.bodyIndex;
    var heavenlyStem = (0, i18n_1.kot)(yearly[0], 'Heavenly');
    var earthlyBranch = (0, i18n_1.kot)(yearly[1], 'Earthly');
    var _d = (0, exports.getHuagaiXianchiIndex)(yearly[1]), huagaiIndex = _d.huagaiIndex, xianchiIndex = _d.xianchiIndex;
    var _e = (0, exports.getGuGuaIndex)(yearly[1]), guchenIndex = _e.guchenIndex, guasuIndex = _e.guasuIndex;
    var tiancaiIndex = (0, utils_1.fixIndex)(soulIndex + data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch));
    var tianshouIndex = (0, utils_1.fixIndex)(bodyIndex + data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch));
    var tianchuIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(['si', 'woo', 'zi', 'si', 'woo', 'shen', 'yin', 'woo', 'you', 'hai'][data_1.HEAVENLY_STEMS.indexOf(heavenlyStem)]));
    var posuiIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(['si', 'chou', 'you'][data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch) % 3]));
    var feilianIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(['shen', 'you', 'xu', 'si', 'woo', 'wei', 'yin', 'mao', 'chen', 'hai', 'zi', 'chou'][data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch)]));
    var longchiIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('chen') + data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch));
    var fenggeIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('xu') - data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch));
    var tiankuIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('woo') - data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch));
    var tianxuIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('woo') + data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch));
    var tianguanIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(['wei', 'chen', 'si', 'yin', 'mao', 'you', 'hai', 'you', 'xu', 'woo'][data_1.HEAVENLY_STEMS.indexOf(heavenlyStem)]));
    var tianfuIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(['you', 'shen', 'zi', 'hai', 'mao', 'yin', 'woo', 'si', 'woo', 'si'][data_1.HEAVENLY_STEMS.indexOf(heavenlyStem)]));
    var tiandeIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('you') + data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch));
    var yuedeIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('si') + data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch));
    var tiankongIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(yearly[1]) + 1);
    var jieluIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(['shen', 'woo', 'chen', 'yin', 'zi'][data_1.HEAVENLY_STEMS.indexOf(heavenlyStem) % 5]));
    var kongwangIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(['you', 'wei', 'si', 'mao', 'chou'][data_1.HEAVENLY_STEMS.indexOf(heavenlyStem) % 5]));
    var xunkongIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(yearly[1]) + data_1.HEAVENLY_STEMS.indexOf('guiHeavenly') - data_1.HEAVENLY_STEMS.indexOf(heavenlyStem) + 1);
    // 判断命主出生年年支阴阳属性，如果结果为 0 则为阳，否则为阴
    var yinyang = data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch) % 2;
    if (yinyang !== xunkongIndex % 2) {
        // 若命主出生年支阴阳属性与初始旬空宫位的阴阳属性不同，则+1
        xunkongIndex = (0, utils_1.fixIndex)(xunkongIndex + 1);
    }
    // 中州派没有截路空亡，只有一颗截空星
    // 生年阳干在阳宫，阴干在阴宫
    var jiekongIndex = yinyang === 0 ? jieluIndex : kongwangIndex;
    var jieshaAdjIndex = (0, exports.getJieshaAdjIndex)(earthlyBranch);
    var nianjieIndex = (0, exports.getNianjieIndex)(yearly[1]);
    var dahaoAdjIndex = (0, exports.getDahaoIndex)(earthlyBranch);
    var genderYinyang = ['male', 'female'];
    var sameYinyang = yinyang === genderYinyang.indexOf((0, i18n_1.kot)(gender));
    var tianshangIndex = (0, utils_1.fixIndex)(data_1.PALACES.indexOf('friendsPalace') + soulIndex);
    var tianshiIndex = (0, utils_1.fixIndex)(data_1.PALACES.indexOf('healthPalace') + soulIndex);
    if (algorithm === 'zhongzhou' && !sameYinyang) {
        // 中州派的天使天伤与通行版本不一样
        // 天伤奴仆、天使疾厄、夹迁移宫最易寻得
        // 凡阳男阴女，皆依此诀，但若为阴男阳女，则改为天伤居疾厄、天使居奴仆。
        _a = [tianshangIndex, tianshiIndex], tianshiIndex = _a[0], tianshangIndex = _a[1];
    }
    return {
        xianchiIndex: xianchiIndex,
        huagaiIndex: huagaiIndex,
        guchenIndex: guchenIndex,
        guasuIndex: guasuIndex,
        tiancaiIndex: tiancaiIndex,
        tianshouIndex: tianshouIndex,
        tianchuIndex: tianchuIndex,
        posuiIndex: posuiIndex,
        feilianIndex: feilianIndex,
        longchiIndex: longchiIndex,
        fenggeIndex: fenggeIndex,
        tiankuIndex: tiankuIndex,
        tianxuIndex: tianxuIndex,
        tianguanIndex: tianguanIndex,
        tianfuIndex: tianfuIndex,
        tiandeIndex: tiandeIndex,
        yuedeIndex: yuedeIndex,
        tiankongIndex: tiankongIndex,
        jieluIndex: jieluIndex,
        kongwangIndex: kongwangIndex,
        xunkongIndex: xunkongIndex,
        tianshangIndex: tianshangIndex,
        tianshiIndex: tianshiIndex,
        jiekongIndex: jiekongIndex,
        jieshaAdjIndex: jieshaAdjIndex,
        nianjieIndex: nianjieIndex,
        dahaoAdjIndex: dahaoAdjIndex,
    };
};
exports.getYearlyStarIndex = getYearlyStarIndex;
/**
 * 获取年解的索引
 *
 * - 年解（按年支）
 *   - 解神从戌上起子，逆数至当生年太岁上是也
 *
 * @param earthlyBranch 地支（年）
 * @returns 年解索引
 */
var getNianjieIndex = function (earthlyBranchName) {
    var earthlyBranch = (0, i18n_1.kot)(earthlyBranchName, 'Earthly');
    return (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(['xu', 'you', 'shen', 'wei', 'woo', 'si', 'chen', 'mao', 'yin', 'chou', 'zi', 'hai'][data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch)]));
};
exports.getNianjieIndex = getNianjieIndex;
/**
 * 获取以月份索引为基准的星耀索引，包括解神，天姚，天刑，阴煞，天月，天巫
 * 解神分为年解和月解，月解作用更加直接快速，年解稍迟钝，且作用力没有月解那么大
 *
 * - 月解（按生月）
 *   - 正二在申三四在戍，五六在子七八在寅，九十月坐於辰宫，十一十二在午宫。
 *
 * - 安天刑天姚（三合必见）
 *   - 天刑从酉起正月，顺至生月便安之。天姚丑宫起正月，顺到生月即停留。
 *
 * - 安阴煞
 *   - 正七月在寅，二八月在子，三九月在戍，四十月在申，五十一在午，六十二在辰。
 *
 * - 安天月
 *   - 一犬二蛇三在龙，四虎五羊六兔宫。七猪八羊九在虎，十马冬犬腊寅中。
 *
 * - 安天巫
 *   - 正五九月在巳，二六十月在申，三七十一在寅，四八十二在亥。
 *
 * @param solarDate 阳历日期
 * @param timeIndex 时辰序号
 * @param fixLeap 是否修复闰月，假如当月不是闰月则不生效
 * @returns
 */
var getMonthlyStarIndex = function (solarDate, timeIndex, fixLeap) {
    var monthIndex = (0, utils_1.fixLunarMonthIndex)(solarDate, timeIndex, fixLeap);
    var jieshenIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(['shen', 'xu', 'zi', 'yin', 'chen', 'woo'][Math.floor(monthIndex / 2)]));
    var tianyaoIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('chou') + monthIndex);
    var tianxingIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('you') + monthIndex);
    var yinshaIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(['yin', 'zi', 'xu', 'shen', 'woo', 'chen'][monthIndex % 6]));
    var tianyueIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(['xu', 'si', 'chen', 'yin', 'wei', 'mao', 'hai', 'wei', 'yin', 'woo', 'xu', 'yin'][monthIndex]));
    var tianwuIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)(['si', 'shen', 'yin', 'hai'][monthIndex % 4]));
    return {
        yuejieIndex: jieshenIndex,
        tianyaoIndex: tianyaoIndex,
        tianxingIndex: tianxingIndex,
        yinshaIndex: yinshaIndex,
        tianyueIndex: tianyueIndex,
        tianwuIndex: tianwuIndex,
    };
};
exports.getMonthlyStarIndex = getMonthlyStarIndex;
/**
 * 通过 大限/流年 天干获取流昌流曲
 *
 * - 流昌起巳位	甲乙顺流去
 * - 不用四墓宫	日月同年岁
 * - 流曲起酉位	甲乙逆行踪
 * - 亦不用四墓	年日月相同
 *
 * @param heavenlyStemName 天干
 * @returns 文昌、文曲索引
 */
var getChangQuIndexByHeavenlyStem = function (heavenlyStemName) {
    var changIndex = -1;
    var quIndex = -1;
    var heavenlyStem = (0, i18n_1.kot)(heavenlyStemName, 'Heavenly');
    switch (heavenlyStem) {
        case 'jiaHeavenly':
            changIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('si'));
            quIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('you'));
            break;
        case 'yiHeavenly':
            changIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('woo'));
            quIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('shen'));
            break;
        case 'bingHeavenly':
        case 'wuHeavenly':
            changIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('shen'));
            quIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('woo'));
            break;
        case 'dingHeavenly':
        case 'jiHeavenly':
            changIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('you'));
            quIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('si'));
            break;
        case 'gengHeavenly':
            changIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('hai'));
            quIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('mao'));
            break;
        case 'xinHeavenly':
            changIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('zi'));
            quIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('yin'));
            break;
        case 'renHeavenly':
            changIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('yin'));
            quIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('zi'));
            break;
        case 'guiHeavenly':
            changIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('mao'));
            quIndex = (0, utils_1.fixIndex)((0, utils_1.fixEarthlyBranchIndex)('hai'));
            break;
    }
    return { changIndex: changIndex, quIndex: quIndex };
};
exports.getChangQuIndexByHeavenlyStem = getChangQuIndexByHeavenlyStem;

        return exports;
    })();
    
    // Module: star/majorStar
    modules['star/majorStar'] = (function() {
        "use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getMajorStar = void 0;
var lunar_lite_1 = require("lunar-lite");
var _1 = require(".");
var i18n_1 = require("../i18n");
var utils_1 = require("../utils");
var FunctionalStar_1 = __importDefault(require("./FunctionalStar"));
var location_1 = require("./location");
var astro_1 = require("../astro");
/**
 * 安主星，寅宫下标为0，若下标对应的数组为空数组则表示没有星耀
 *
 * 安紫微诸星诀
 * - 紫微逆去天机星，隔一太阳武曲辰，
 * - 连接天同空二宫，廉贞居处方是真。
 *
 * 安天府诸星诀
 * - 天府顺行有太阴，贪狼而后巨门临，
 * - 随来天相天梁继，七杀空三是破军。
 *
 * @param {AstrolabeParam} param 通用排盘参数
 * @returns {Array<Star[]>} 从寅宫开始每一个宫的星耀
 */
var getMajorStar = function (param) {
    var solarDate = param.solarDate, timeIndex = param.timeIndex;
    var _a = (0, location_1.getStartIndex)(param), ziweiIndex = _a.ziweiIndex, tianfuIndex = _a.tianfuIndex;
    var yearly = (0, lunar_lite_1.getHeavenlyStemAndEarthlyBranchBySolarDate)(solarDate, timeIndex, {
        year: (0, astro_1.getConfig)().yearDivide,
    }).yearly;
    var stars = (0, _1.initStars)();
    var ziweiGroup = [
        'ziweiMaj',
        'tianjiMaj',
        '',
        'taiyangMaj',
        'wuquMaj',
        'tiantongMaj',
        '',
        '',
        'lianzhenMaj',
    ];
    var tianfuGroup = [
        'tianfuMaj',
        'taiyinMaj',
        'tanlangMaj',
        'jumenMaj',
        'tianxiangMaj',
        'tianliangMaj',
        'qishaMaj',
        '',
        '',
        '',
        'pojunMaj',
    ];
    ziweiGroup.forEach(function (s, i) {
        // 安紫微星系，起始宫逆时针安
        if (s !== '') {
            stars[(0, utils_1.fixIndex)(ziweiIndex - i)].push(new FunctionalStar_1.default({
                name: (0, i18n_1.t)(s),
                type: 'major',
                scope: 'origin',
                brightness: (0, utils_1.getBrightness)((0, i18n_1.t)(s), (0, utils_1.fixIndex)(ziweiIndex - i)),
                mutagen: (0, utils_1.getMutagen)((0, i18n_1.t)(s), yearly[0]),
            }));
        }
    });
    tianfuGroup.forEach(function (s, i) {
        if (s !== '') {
            stars[(0, utils_1.fixIndex)(tianfuIndex + i)].push(new FunctionalStar_1.default({
                name: (0, i18n_1.t)(s),
                type: 'major',
                scope: 'origin',
                brightness: (0, utils_1.getBrightness)((0, i18n_1.t)(s), (0, utils_1.fixIndex)(tianfuIndex + i)),
                mutagen: (0, utils_1.getMutagen)((0, i18n_1.t)(s), yearly[0]),
            }));
        }
    });
    return stars;
};
exports.getMajorStar = getMajorStar;

        return exports;
    })();
    
    // Module: star/minorStar
    modules['star/minorStar'] = (function() {
        "use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getMinorStar = void 0;
var lunar_lite_1 = require("lunar-lite");
var _1 = require(".");
var i18n_1 = require("../i18n");
var utils_1 = require("../utils");
var FunctionalStar_1 = __importDefault(require("./FunctionalStar"));
var location_1 = require("./location");
var astro_1 = require("../astro");
/**
 * 安14辅星，寅宫下标为0，若下标对应的数组为空数组则表示没有星耀
 *
 * @param solarDateStr 阳历日期字符串
 * @param timeIndex 时辰索引【0～12】
 * @param fixLeap 是否修复闰月，假如当月不是闰月则不生效
 * @returns 14辅星
 */
var getMinorStar = function (solarDateStr, timeIndex, fixLeap) {
    var stars = (0, _1.initStars)();
    var yearly = (0, lunar_lite_1.getHeavenlyStemAndEarthlyBranchBySolarDate)(solarDateStr, timeIndex, {
        year: (0, astro_1.getConfig)().yearDivide,
    }).yearly;
    var monthIndex = (0, utils_1.fixLunarMonthIndex)(solarDateStr, timeIndex, fixLeap);
    // 此处获取到的是索引，下标是从0开始的，所以需要加1
    var _a = (0, location_1.getZuoYouIndex)(monthIndex + 1), zuoIndex = _a.zuoIndex, youIndex = _a.youIndex;
    var _b = (0, location_1.getChangQuIndex)(timeIndex), changIndex = _b.changIndex, quIndex = _b.quIndex;
    var _c = (0, location_1.getKuiYueIndex)(yearly[0]), kuiIndex = _c.kuiIndex, yueIndex = _c.yueIndex;
    var _d = (0, location_1.getHuoLingIndex)(yearly[1], timeIndex), huoIndex = _d.huoIndex, lingIndex = _d.lingIndex;
    var _e = (0, location_1.getKongJieIndex)(timeIndex), kongIndex = _e.kongIndex, jieIndex = _e.jieIndex;
    var _f = (0, location_1.getLuYangTuoMaIndex)(yearly[0], yearly[1]), luIndex = _f.luIndex, yangIndex = _f.yangIndex, tuoIndex = _f.tuoIndex, maIndex = _f.maIndex;
    stars[zuoIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('zuofuMin'),
        type: 'soft',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('左辅', zuoIndex),
        mutagen: (0, utils_1.getMutagen)('左辅', yearly[0]),
    }));
    stars[youIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('youbiMin'),
        type: 'soft',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('右弼', youIndex),
        mutagen: (0, utils_1.getMutagen)('右弼', yearly[0]),
    }));
    stars[changIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('wenchangMin'),
        type: 'soft',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('文昌', changIndex),
        mutagen: (0, utils_1.getMutagen)('文昌', yearly[0]),
    }));
    stars[quIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('wenquMin'),
        type: 'soft',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('文曲', quIndex),
        mutagen: (0, utils_1.getMutagen)('文曲', yearly[0]),
    }));
    stars[kuiIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('tiankuiMin'),
        type: 'soft',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('天魁', kuiIndex),
    }));
    stars[yueIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('tianyueMin'),
        type: 'soft',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('天钺', yueIndex),
    }));
    stars[luIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('lucunMin'),
        type: 'lucun',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('禄存', luIndex),
    }));
    stars[maIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('tianmaMin'),
        type: 'tianma',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('天马', maIndex),
    }));
    stars[kongIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('dikongMin'),
        type: 'tough',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('地空', kongIndex),
    }));
    stars[jieIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('dijieMin'),
        type: 'tough',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('地劫', jieIndex),
    }));
    stars[huoIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('huoxingMin'),
        type: 'tough',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('火星', huoIndex),
    }));
    stars[lingIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('lingxingMin'),
        type: 'tough',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('铃星', lingIndex),
    }));
    stars[yangIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('qingyangMin'),
        type: 'tough',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('擎羊', yangIndex),
    }));
    stars[tuoIndex].push(new FunctionalStar_1.default({
        name: (0, i18n_1.t)('tuoluoMin'),
        type: 'tough',
        scope: 'origin',
        brightness: (0, utils_1.getBrightness)('陀罗', tuoIndex),
    }));
    return stars;
};
exports.getMinorStar = getMinorStar;

        return exports;
    })();
    
    // Module: utils/index
    modules['utils/index'] = (function() {
        "use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.translateChineseDate = exports.getAgeIndex = exports.timeToIndex = exports.mergeStars = exports.fixLunarDayIndex = exports.fixLunarMonthIndex = exports.fixEarthlyBranchIndex = exports.getMutagensByHeavenlyStem = exports.getMutagen = exports.getBrightness = exports.earthlyBranchIndexToPalaceIndex = exports.fixIndex = void 0;
var data_1 = require("../data");
var star_1 = require("../star");
var i18n_1 = require("../i18n");
var lunar_lite_1 = require("lunar-lite");
var astro_1 = require("../astro");
var getTargetMutagens = function (heavenlyStem) {
    var _a, _b;
    var mutagens = (0, astro_1.getConfig)().mutagens;
    var result;
    if (mutagens && mutagens[heavenlyStem]) {
        result = (_a = mutagens[heavenlyStem]) !== null && _a !== void 0 ? _a : [];
    }
    else {
        result = (_b = data_1.heavenlyStems[heavenlyStem].mutagen) !== null && _b !== void 0 ? _b : [];
    }
    return result;
};
/**
 * 用于处理索引，将索引锁定在 0~max 范围内
 *
 * @param index 当前索引
 * @param max 最大循环数，默认为12【因为12用得最多，宫位数量以及十二地支数量都为12，所以将12作为默认值】
 * @returns {number} 处理后的索引
 */
var fixIndex = function (index, max) {
    if (max === void 0) { max = 12; }
    if (index < 0) {
        return (0, exports.fixIndex)(index + max, max);
    }
    if (index > max - 1) {
        return (0, exports.fixIndex)(index - max, max);
    }
    var res = 1 / index === -Infinity ? 0 : index;
    return res;
};
exports.fixIndex = fixIndex;
/**
 * 因为宫位是从寅宫开始的排列的，所以需要将目标地支的序号减去寅的序号才能得到宫位的序号
 *
 * @param {EarthlyBranchName} earthlyBranch 地支
 * @returns {number} 该地支对应的宫位索引序号
 */
var earthlyBranchIndexToPalaceIndex = function (earthlyBranchName) {
    var earthlyBranch = (0, i18n_1.kot)(earthlyBranchName, 'Earthly');
    var yin = (0, i18n_1.kot)('yinEarthly', 'Earthly');
    return (0, exports.fixIndex)(data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch) - data_1.EARTHLY_BRANCHES.indexOf(yin));
};
exports.earthlyBranchIndexToPalaceIndex = earthlyBranchIndexToPalaceIndex;
/**
 * 配置星耀亮度
 *
 * @param {StarName} starName 星耀名字
 * @param {number} index 所在宫位索引
 */
var getBrightness = function (starName, index) {
    var _a;
    var star = (0, i18n_1.kot)(starName);
    var brightness = (0, astro_1.getConfig)().brightness;
    var targetBrightness = brightness[star] ? brightness[star] : (_a = data_1.STARS_INFO[star]) === null || _a === void 0 ? void 0 : _a.brightness;
    if (!targetBrightness) {
        return '';
    }
    return (0, i18n_1.t)(targetBrightness[(0, exports.fixIndex)(index)]);
};
exports.getBrightness = getBrightness;
var getMutagen = function (starName, heavenlyStemName) {
    var heavenlyStem = (0, i18n_1.kot)(heavenlyStemName, 'Heavenly');
    var starKey = (0, i18n_1.kot)(starName);
    var target = getTargetMutagens(heavenlyStem);
    return (0, i18n_1.t)(data_1.MUTAGEN[target.indexOf(starKey)]);
};
exports.getMutagen = getMutagen;
var getMutagensByHeavenlyStem = function (heavenlyStemName) {
    var heavenlyStem = (0, i18n_1.kot)(heavenlyStemName, 'Heavenly');
    var target = getTargetMutagens(heavenlyStem);
    return target.map(function (star) { return (0, i18n_1.t)(star); });
};
exports.getMutagensByHeavenlyStem = getMutagensByHeavenlyStem;
/**
 * 处理地支相对于十二宫的索引，因为十二宫是以寅宫开始，所以下标需要减去地支寅的索引
 *
 * @param {EarthlyBranchName} earthlyBranch 地支
 * @returns {number} Number(0~11)
 */
var fixEarthlyBranchIndex = function (earthlyBranchName) {
    var earthlyBranch = (0, i18n_1.kot)(earthlyBranchName, 'Earthly');
    return (0, exports.fixIndex)(data_1.EARTHLY_BRANCHES.indexOf(earthlyBranch) - data_1.EARTHLY_BRANCHES.indexOf('yinEarthly'));
};
exports.fixEarthlyBranchIndex = fixEarthlyBranchIndex;
/**
 * 调整农历月份的索引
 *
 * 正月建寅（正月地支为寅），fixLeap为是否调整闰月情况
 * 若调整闰月，则闰月的前15天按上月算，后面天数按下月算
 * 比如 闰二月 时，fixLeap 为 true 时 闰二月十五(含)前
 * 的月份按二月算，之后的按三月算
 *
 * @param {string} solarDateStr 阳历日期
 * @param {number} timeIndex 时辰序号
 * @param {vboolean} fixLeap 是否调整闰月
 * @returns {number} 月份索引
 */
var fixLunarMonthIndex = function (solarDateStr, timeIndex, fixLeap) {
    var _a = (0, lunar_lite_1.solar2lunar)(solarDateStr), lunarMonth = _a.lunarMonth, lunarDay = _a.lunarDay, isLeap = _a.isLeap;
    // 紫微斗数以`寅`宫为第一个宫位
    var firstIndex = data_1.EARTHLY_BRANCHES.indexOf('yinEarthly');
    var needToAdd = isLeap && fixLeap && lunarDay > 15 && timeIndex !== 12;
    return (0, exports.fixIndex)(lunarMonth + 1 - firstIndex + (needToAdd ? 1 : 0));
};
exports.fixLunarMonthIndex = fixLunarMonthIndex;
/**
 * 获取农历日期【天】的索引，晚子时将加一天，所以如果是晚子时下标不需要减一
 *
 * @param lunarDay 农历日期【天】
 * @param timeIndex 时辰索引
 * @returns {number} 农历日期【天】
 */
var fixLunarDayIndex = function (lunarDay, timeIndex) { return (timeIndex >= 12 ? lunarDay : lunarDay - 1); };
exports.fixLunarDayIndex = fixLunarDayIndex;
/**
 * 将多个星耀数组合并到一起
 *
 * @param {FunctionalStar[][][]} stars 星耀数组
 * @returns {FunctionalStar[][]} 合并后的星耀
 */
var mergeStars = function () {
    var stars = [];
    for (var _i = 0; _i < arguments.length; _i++) {
        stars[_i] = arguments[_i];
    }
    var finalStars = (0, star_1.initStars)();
    stars.forEach(function (item) {
        item.forEach(function (subItem, index) {
            Array.prototype.push.apply(finalStars[index], subItem);
        });
    });
    return finalStars;
};
exports.mergeStars = mergeStars;
/**
 * 将时间的小时转化为时辰的索引
 *
 * @param {number} hour 当前时间的小时数
 * @returns {number} 时辰的索引
 */
var timeToIndex = function (hour) {
    if (hour === 0) {
        // 00:00～01:00 为早子时
        return 0;
    }
    if (hour === 23) {
        // 23:00～00:00 为晚子时
        return 12;
    }
    return Math.floor((hour + 1) / 2);
};
exports.timeToIndex = timeToIndex;
/**
 * 起小限
 *
 * - 小限一年一度逢，男顺女逆不相同，
 * - 寅午戍人辰上起，申子辰人自戍宫，
 * - 巳酉丑人未宫始，亥卯未人起丑宫。
 *
 * @param {EarthlyBranchName} earthlyBranchName 地支
 * @returns {number} 小限开始的宫位索引
 */
var getAgeIndex = function (earthlyBranchName) {
    var earthlyBranch = (0, i18n_1.kot)(earthlyBranchName, 'Earthly');
    var ageIdx = -1;
    if (['yinEarthly', 'wuEarthly', 'xuEarthly'].includes(earthlyBranch)) {
        ageIdx = (0, exports.fixEarthlyBranchIndex)('chen');
    }
    else if (['shenEarthly', 'ziEarthly', 'chenEarthly'].includes(earthlyBranch)) {
        ageIdx = (0, exports.fixEarthlyBranchIndex)('xu');
    }
    else if (['siEarthly', 'youEarthly', 'chouEarthly'].includes(earthlyBranch)) {
        ageIdx = (0, exports.fixEarthlyBranchIndex)('wei');
    }
    else if (['haiEarthly', 'maoEarthly', 'weiEarthly'].includes(earthlyBranch)) {
        ageIdx = (0, exports.fixIndex)((0, exports.fixEarthlyBranchIndex)('chou'));
    }
    return ageIdx;
};
exports.getAgeIndex = getAgeIndex;
/**
 * 返回翻译后的干支纪年字符串
 *
 * @param chineseDate 干支纪年日期对象
 * @returns 干支纪年字符串
 */
var translateChineseDate = function (chineseDate) {
    var yearly = chineseDate.yearly, monthly = chineseDate.monthly, daily = chineseDate.daily, hourly = chineseDate.hourly;
    if (yearly.some(function (item) { return (0, i18n_1.t)((0, i18n_1.kot)(item)).length > 1; }) ||
        monthly.some(function (item) { return (0, i18n_1.t)((0, i18n_1.kot)(item)).length > 1; }) ||
        daily.some(function (item) { return (0, i18n_1.t)((0, i18n_1.kot)(item)).length > 1; }) ||
        hourly.some(function (item) { return (0, i18n_1.t)((0, i18n_1.kot)(item)).length > 1; })) {
        return "".concat(yearly.map(function (item) { return (0, i18n_1.t)((0, i18n_1.kot)(item)); }).join(' '), " - ").concat(monthly.map(function (item) { return (0, i18n_1.t)((0, i18n_1.kot)(item)); }).join(' '), " - ").concat(daily
            .map(function (item) { return (0, i18n_1.t)((0, i18n_1.kot)(item)); })
            .join(' '), " - ").concat(hourly.map(function (item) { return (0, i18n_1.t)((0, i18n_1.kot)(item)); }).join(' '));
    }
    return "".concat(yearly.map(function (item) { return (0, i18n_1.t)((0, i18n_1.kot)(item)); }).join(''), " ").concat(monthly.map(function (item) { return (0, i18n_1.t)((0, i18n_1.kot)(item)); }).join(''), " ").concat(daily
        .map(function (item) { return (0, i18n_1.t)((0, i18n_1.kot)(item)); })
        .join(''), " ").concat(hourly.map(function (item) { return (0, i18n_1.t)((0, i18n_1.kot)(item)); }).join(''));
};
exports.translateChineseDate = translateChineseDate;

        return exports;
    })();
    
    // Module: i18n/index
    modules['i18n/index'] = (function() {
        "use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.kot = exports.t = exports.setLanguage = void 0;
var i18next_1 = __importDefault(require("i18next"));
var zh_CN_1 = __importDefault(require("./locales/zh-CN"));
var zh_TW_1 = __importDefault(require("./locales/zh-TW"));
var ko_KR_1 = __importDefault(require("./locales/ko-KR"));
var ja_JP_1 = __importDefault(require("./locales/ja-JP"));
var en_US_1 = __importDefault(require("./locales/en-US"));
var vi_VN_1 = __importDefault(require("./locales/vi-VN"));
var resources = {
    'en-US': {
        translation: en_US_1.default,
    },
    'ja-JP': {
        translation: ja_JP_1.default,
    },
    'ko-KR': {
        translation: ko_KR_1.default,
    },
    'zh-CN': {
        translation: zh_CN_1.default,
    },
    'zh-TW': {
        translation: zh_TW_1.default,
    },
    'vi-VN': {
        translation: vi_VN_1.default,
    },
};
// 设置默认语言和加载翻译文件
i18next_1.default.init({ lng: 'zh-CN', resources: resources });
/**
 * 设置国际化语言。
 * 支持的语言见 type.ts -> Language
 *
 * @param language 需要设置的语言【默认为zh-CN】
 */
var setLanguage = function (language) {
    i18next_1.default.changeLanguage(language);
};
exports.setLanguage = setLanguage;
/**
 * 输出国际化文本。
 *
 * @param str 待翻译的字符串
 * @returns 翻译后的字符串
 */
var t = function (str) {
    if (!str) {
        return '';
    }
    return i18next_1.default.t(str);
};
exports.t = t;
/**
 * kot(Key of Translation).
 *
 * 通过翻译文本反查Key的值，用于各种计算。
 * 若没有找到则会返回Value本身。
 *
 * @param value 翻译后的字符串
 * @returns 翻译文本的Key值
 */
var kot = function (value, k) {
    var res = value;
    for (var _i = 0, _a = Object.entries(resources); _i < _a.length; _i++) {
        var _b = _a[_i], item = _b[1];
        for (var _c = 0, _d = Object.entries(item.translation); _c < _d.length; _c++) {
            var _e = _d[_c], transKey = _e[0], trans = _e[1];
            if (((k && transKey.includes(k)) || !k) && trans === value) {
                res = transKey;
                return res;
            }
        }
    }
    return res;
};
exports.kot = kot;
__exportStar(require("./types"), exports);
exports.default = i18next_1.default;

        return exports;
    })();
    
    // 导出主模块
    global.iztro = modules['index'];
})(window || global);
