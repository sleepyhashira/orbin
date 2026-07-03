import Foundation

enum Formatters {
    static let bytes: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useAll]
        return formatter
    }()

    static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    static func fileSize(_ value: Int64) -> String {
        bytes.string(fromByteCount: value)
    }

    static func count(_ value: Int) -> String {
        integer.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
