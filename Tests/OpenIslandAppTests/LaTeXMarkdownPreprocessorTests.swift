import XCTest
import SwiftUI
@testable import OpenIslandApp

final class LaTeXMarkdownPreprocessorTests: XCTestCase {
    func testInlineMathTransformation() {
        let input = "The formula $E = mc^2$ is famous."
        let output = LaTeXMarkdownPreprocessor.preprocess(input)
        XCTAssertTrue(output.contains("![E = mc^2](latex://inline/"))
    }

    func testInlineParenMathTransformation() {
        let input = "The formula \\(x + y = z\\) is simple."
        let output = LaTeXMarkdownPreprocessor.preprocess(input)
        XCTAssertTrue(output.contains("![x + y = z](latex://inline/"))
    }

    func testDisplayMathTransformation() {
        let input = "Display:\n$$\n\\sum x\n$$\nDone."
        let output = LaTeXMarkdownPreprocessor.preprocess(input)
        XCTAssertTrue(output.contains("```math\n\\sum x\n```"))
    }

    func testDisplayBracketMathTransformation() {
        let input = "Display:\n\\[\n\\int_0^1 f(x) dx\n\\]\nDone."
        let output = LaTeXMarkdownPreprocessor.preprocess(input)
        XCTAssertTrue(output.contains("```math\n\\int_0^1 f(x) dx\n```"))
    }

    func testCodeBlockProtection() {
        let input = "Code block:\n```\n$x = 1\n```\nAnd formula $y = 2$."
        let output = LaTeXMarkdownPreprocessor.preprocess(input)
        XCTAssertTrue(output.contains("```\n$x = 1\n```"))
        XCTAssertTrue(output.contains("![y = 2](latex://inline/"))
    }

    func testInlineCodeProtection() {
        let input = "Inline code `$x` should stay code, but $y = 1$ is math."
        let output = LaTeXMarkdownPreprocessor.preprocess(input)
        XCTAssertTrue(output.contains("`$x`"))
        XCTAssertTrue(output.contains("![y = 1](latex://inline/"))
    }

    func testCurrencyPreserved() {
        let input = "This costs $50 and that costs $10.99 or $5k."
        let output = LaTeXMarkdownPreprocessor.preprocess(input)
        XCTAssertEqual(input, output)
    }

    func testEscapedDollarPreserved() {
        let input = "Price is \\$100 per unit."
        let output = LaTeXMarkdownPreprocessor.preprocess(input)
        XCTAssertEqual(input, output)
    }

    @MainActor
    func testLaTeXRendererValidMath() {
        let image = LaTeXRenderer.render(latex: "\\frac{a}{b}", fontSize: 14, textColor: .white)
        XCTAssertNotNil(image)
    }

    @MainActor
    func testLaTeXRendererInvalidMathFallsBack() {
        let image = LaTeXRenderer.render(latex: "\\frac{incomplete", fontSize: 14, textColor: .white)
        XCTAssertNil(image)
    }
}
