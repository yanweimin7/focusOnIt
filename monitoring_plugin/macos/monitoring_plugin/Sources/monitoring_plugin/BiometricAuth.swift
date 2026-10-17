import Foundation
import LocalAuthentication

/// Touch ID（macOS 生物识别）封装。
///
/// 通过 LocalAuthentication 弹出系统验证框；硬件不支持或未录入指纹时
/// `isAvailable` 为 false，调用方应回退到密码验证。
final class BiometricAuth {
    /// 当前设备是否可用生物识别（硬件存在且已录入）。
    var isAvailable: Bool {
        if #available(macOS 10.12, *) {
            var error: NSError?
            return LAContext().canEvaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                error: &error
            )
        }
        return false
    }

    /// 生物识别类型：touchID / faceID / none。
    var type: String {
        if #available(macOS 10.12.2, *) {
            let context = LAContext()
            var error: NSError?
            guard context.canEvaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                error: &error
            ) else { return "none" }
            switch context.biometryType {
            case .touchID: return "touchID"
            case .faceID: return "faceID"
            default: return "none"
            }
        }
        return "none"
    }

    /// 状态字典，供 Flutter 层判断是否展示指纹入口。
    var status: [String: Any] {
        let available = isAvailable
        return ["available": available, "type": available ? type : "none"]
    }

    /// 弹出系统验证框。回调在主线程执行：
    /// - ok：是否验证通过
    /// - code：ok / userCancel / authenticationFailed / lockout / notAvailable / notEnrolled / unknown
    func authenticate(
        reason: String,
        completion: @escaping (_ ok: Bool, _ code: String) -> Void
    ) {
        guard #available(macOS 10.12, *) else {
            completion(false, "notAvailable")
            return
        }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) else {
            let code = Self.code(for: error)
            DispatchQueue.main.async { completion(false, code) }
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        ) { success, evalError in
            let code = success ? "ok" : Self.code(for: evalError)
            DispatchQueue.main.async { completion(success, code) }
        }
    }

    @available(macOS 10.12, *)
    private static func code(for error: Error?) -> String {
        guard let laError = error as? LAError else {
            return error == nil ? "ok" : "unknown"
        }
        switch laError.code {
        case .userCancel, .appCancel, .systemCancel, .userFallback:
            return "userCancel"
        case .authenticationFailed:
            return "authenticationFailed"
        case .biometryLockout:
            return "lockout"
        case .biometryNotAvailable:
            return "notAvailable"
        case .biometryNotEnrolled:
            return "notEnrolled"
        default:
            return "unknown"
        }
    }
}
