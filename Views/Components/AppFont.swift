import SwiftUI

/// 全局字体管理器 — 默认老人友好大字体，支持 Cmd+/Cmd- 动态调整
class AppFont: ObservableObject {
    static let shared = AppFont()

    /// 缩放等级：0=标准，1=大(默认)，2=更大，3=最大
    @Published var scale: Int {
        didSet { save() }
    }

    init() {
        self.scale = AppFont.loadScale()
    }

    // MARK: - 字体尺寸映射

    /// 大标题（卡片数值）
    var largeTitle: Font { .system(size: base(28)) }
    /// 标题2（卡片数值）
    var title2: Font { .system(size: base(24), weight: .semibold, design: .rounded) }
    /// 标题3（图标）
    var title3: Font { .system(size: base(20)) }
    /// 正文（节点名、列表主文本）
    var body: Font { .system(size: base(16)) }
    /// 副标题（Section header、工具栏文字）
    var subheadline: Font { .system(size: base(15)) }
    /// 标题（空页面标题）
    var headline: Font { .system(size: base(17), weight: .semibold) }
    /// 小字（搜索框、按钮、标签）
    var caption: Font { .system(size: base(14)) }
    /// 极小字（地址、时间、延迟标签）
    var caption2: Font { .system(size: base(12)) }
    /// 等宽小字（日志、地址）
    var monoCaption: Font { .system(size: base(13), design: .monospaced) }
    /// 等宽极小字
    var monoCaption2: Font { .system(size: base(11), design: .monospaced) }
    /// 图标尺寸
    var iconLarge: CGFloat { base(40) }
    /// 状态灯尺寸
    var statusDot: CGFloat { base(10) }

    // MARK: - 快捷操作

    func increase() { scale = min(3, scale + 1) }
    func decrease() { scale = max(0, scale - 1) }

    var scaleLabel: String {
        switch scale {
        case 0: return "标准"
        case 1: return "大"
        case 2: return "更大"
        case 3: return "最大"
        default: return "标准"
        }
    }

    // MARK: - Private

    private func base(_ standard: CGFloat) -> CGFloat {
        // 每级增大 4pt，老人默认 scale=1 即比标准大 4pt
        return standard + CGFloat(scale) * 4
    }

    private func save() {
        UserDefaults.standard.set(scale, forKey: "AppFontScale")
    }

    private static func loadScale() -> Int {
        let saved = UserDefaults.standard.integer(forKey: "AppFontScale")
        return saved == 0 ? 1 : saved  // 默认大字体
    }
}

// MARK: - View Extension 方便使用

extension View {
    func withAppFont() -> some View {
        self.environmentObject(AppFont.shared)
    }
}
