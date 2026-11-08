import Foundation

public enum LaTeXMarkdownPreprocessor {
    public static func preprocess(_ markdown: String) -> String {
        // Fast path
        if !markdown.contains("$") && !markdown.contains("\\(") && !markdown.contains("\\[") {
            return markdown
        }

        var result = ""
        let codePattern = #"(`{3,}|~{3,})[\s\S]*?\1|`+[^`\n]+`+"#
        guard let codeRegex = try? NSRegularExpression(pattern: codePattern) else {
            return markdown
        }

        let nsString = markdown as NSString
        let matches = codeRegex.matches(in: markdown, range: NSRange(location: 0, length: nsString.length))

        var lastEnd = 0
        for match in matches {
            let matchRange = match.range
            if matchRange.location > lastEnd {
                let textRange = NSRange(location: lastEnd, length: matchRange.location - lastEnd)
                let textChunk = nsString.substring(with: textRange)
                result += processTextChunk(textChunk)
            }
            let codeChunk = nsString.substring(with: matchRange)
            result += codeChunk
            lastEnd = matchRange.location + matchRange.length
        }

        if lastEnd < nsString.length {
            let textRange = NSRange(location: lastEnd, length: nsString.length - lastEnd)
            let textChunk = nsString.substring(with: textRange)
            result += processTextChunk(textChunk)
        }

        return result
    }

    private static func processTextChunk(_ text: String) -> String {
        var processed = text

        // 1. Process display math: $$...$$ or \[...\]
        let displayPatterns = [
            #"(?<!\\)\$\$(.+?)(?<!\\)\$\$"#,
            #"(?<!\\)\\\[(.+?)(?<!\\)\\\]"#
        ]
        for pattern in displayPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let ns = processed as NSString
                let matches = regex.matches(in: processed, range: NSRange(location: 0, length: ns.length)).reversed()
                for match in matches {
                    let fullRange = match.range
                    let contentRange = match.range(at: 1)
                    let content = ns.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    let replacement = "\n\n```math\n\(content)\n```\n\n"
                    processed = (processed as NSString).replacingCharacters(in: fullRange, with: replacement)
                }
            }
        }

        // 2. Process inline math: \(...\) or $...$
        let inlinePatterns = [
            #"(?<!\\)\\\((.+?)(?<!\\)\\\)"#,
            #"(?<!\\)\$(?!\s)([^\$\n]+?)(?<!\s)(?<!\\)\$"#
        ]
        for pattern in inlinePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let ns = processed as NSString
                let matches = regex.matches(in: processed, range: NSRange(location: 0, length: ns.length)).reversed()
                for match in matches {
                    let contentRange = match.range(at: 1)
                    let content = ns.substring(with: contentRange)
                    
                    if pattern.contains("$") && isLikelyCurrency(content) {
                        continue
                    }
                    
                    let base64 = Data(content.utf8).base64EncodedString()
                    let replacement = "![\(content)](latex://inline/\(base64))"
                    processed = (processed as NSString).replacingCharacters(in: match.range, with: replacement)
                }
            }
        }

        return processed
    }

    private static func isLikelyCurrency(_ str: String) -> Bool {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        let numberPattern = #"^\d+(\.\d+)?(k|m|b)?$"#
        return trimmed.range(of: numberPattern, options: .regularExpression, range: nil, locale: nil) != nil
    }
}
