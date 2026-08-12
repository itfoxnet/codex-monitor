import Foundation

enum RelativeTimeText {
  static func string(since date: Date, now: Date = .now) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    switch seconds {
    case ..<60:
      return "\(seconds)秒前"
    case ..<3_600:
      return "\(seconds / 60)分钟前"
    case ..<86_400:
      return "\(seconds / 3_600)小时前"
    default:
      return "\(seconds / 86_400)天前"
    }
  }
}
