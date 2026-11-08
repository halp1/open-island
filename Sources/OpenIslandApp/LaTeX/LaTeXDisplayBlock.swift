import Foundation
import SwiftUI
import SwiftMath

public struct LaTeXDisplayBlock: View {
    let latex: String
    
    public init(latex: String) {
        self.latex = latex
    }
    
    public var body: some View {
        if let img = LaTeXRenderer.render(latex: latex, fontSize: 15, textColor: .white, isDisplay: true) {
            HStack {
                Spacer()
                Image(nsImage: img)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            // Fallback for rendering error
            Text(latex)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(.white.opacity(0.88))
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
