import Foundation
import SwiftUI
import MarkdownUI

public struct LaTeXInlineImageProvider: InlineImageProvider, Sendable {
    public static let shared = LaTeXInlineImageProvider()
    
    private init() {}
    
    @MainActor
    public func image(with url: URL, label: String) async throws -> Image {
        guard url.scheme == "latex" else {
            return Image(systemName: "function")
        }
        
        let isDisplay = url.host == "display"
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let data = Data(base64Encoded: path),
              let latex = String(data: data, encoding: .utf8) else {
            return Image(systemName: "exclamationmark.triangle")
        }
        
        if let nsImg = LaTeXRenderer.render(latex: latex, fontSize: 13.5, textColor: .white, isDisplay: isDisplay) {
            return Image(nsImage: nsImg)
        }
        
        return Image(systemName: "xmark")
    }
}
