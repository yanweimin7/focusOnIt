import Foundation
import CryptoKit

/// 密码门：白名单 / 监控开关等敏感操作前需要验证密码。
///
/// 只存 SHA-256 摘要（加盐），不保存明文；储存在 UserDefaults。
final class PasswordGate {
    private let defaults = UserDefaults.standard
    private let key = "focusOnIt.passwordHash"
    private let salt = "focusOnIt.v1"

    /// 是否已设置密码。
    var isSet: Bool {
        defaults.string(forKey: key) != nil
    }

    /// 首次设置密码。
    func set(_ password: String) {
        defaults.set(hash(password), forKey: key)
    }

    /// 验证密码。未设置密码时视为通过。
    func verify(_ password: String) -> Bool {
        guard let stored = defaults.string(forKey: key) else { return true }
        return stored == hash(password)
    }

    private func hash(_ password: String) -> String {
        let data = Data(("\(salt)#\(password)").utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}