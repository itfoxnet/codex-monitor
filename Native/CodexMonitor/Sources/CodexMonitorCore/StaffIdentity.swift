import Foundation

public enum StaffIdentity {
  private static let names = [
    "陈序", "林简", "周衡", "许澄", "沈知", "顾言", "苏木", "程野",
    "陆遥", "唐宁", "叶舟", "江屿", "闻川", "宋一", "白榆", "乔安",
  ]

  public static func name(for threadID: String) -> String {
    names[Int(stableHash(threadID) % UInt64(names.count))]
  }

  public static func shortID(for threadID: String) -> String {
    let compact = threadID.replacingOccurrences(of: "-", with: "").uppercased()
    return String(compact.suffix(6))
  }

  public static func deskNumber(for threadID: String) -> String {
    String(format: "%02d", Int(stableHash(threadID + "desk") % 90) + 10)
  }

  public static func privateReference(for value: String) -> String {
    String(format: "%04X", Int(stableHash(value) % 65_536))
  }

  private static func stableHash(_ value: String) -> UInt64 {
    value.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
      (hash ^ UInt64(byte)) &* 1_099_511_628_211
    }
  }
}
