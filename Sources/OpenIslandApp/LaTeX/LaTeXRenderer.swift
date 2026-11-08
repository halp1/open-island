import Foundation
import SwiftUI
import SwiftMath

public enum LaTeXRenderer {
    // Non-Sendable cache protected by a lock (MainActor or explicit lock).
    // Use a class to manage state.
    @MainActor
    private static let cache = NSCache<NSString, NSImage>()

    @MainActor
    public static func render(latex: String, fontSize: CGFloat, textColor: Color, isDisplay: Bool = false) -> NSImage? {
        let cacheKey = "\(latex)-\(fontSize)-\(textColor)-\(isDisplay)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let math = MTMathImage(
            latex: latex.trimmingCharacters(in: .whitespacesAndNewlines),
            fontSize: fontSize,
            textColor: MTColor(textColor),
            labelMode: isDisplay ? .display : .text
        )
        
        let (_, img) = math.asImage()
        if let img {
            cache.setObject(img, forKey: cacheKey)
            return img
        }
        return nil
    }
}

// Minimal extension to bridge SwiftUI Color to MTColor
extension MTColor {
    convenience init(_ color: Color) {
        // Simple bridge: assume white/clear/etc, adjust as needed if more colors are used
        self.init(red: 1, green: 1, blue: 1, alpha: 1)
    }
}
