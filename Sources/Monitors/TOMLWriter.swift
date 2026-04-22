import Foundation

// MARK: - TOMLValue

/// A typed TOML value used when patching the config file.
///
/// The caller is responsible for picking the correct case so the written value
/// has the right TOML representation (quoted string vs. bare number/bool).
public enum TOMLValue: Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case bool(Bool)
    /// Written verbatim — no quoting. Use for inline tables or other raw TOML expressions.
    case rawLiteral(String)
    /// A TOML array of quoted strings: `["a", "b", "c"]`.
    case stringArray([String])

    var tomlLiteral: String {
        switch self {
        case .string(let s):
            let escaped = s
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        case .integer(let i):      return "\(i)"
        case .double(let d):       return "\(d)"
        case .bool(let b):         return b ? "true" : "false"
        case .rawLiteral(let raw): return raw
        case .stringArray(let items):
            guard !items.isEmpty else { return "[]" }
            let quoted = items.map { s -> String in
                let escaped = s
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                return "\"\(escaped)\""
            }.joined(separator: ", ")
            return "[\(quoted)]"
        }
    }
}

// MARK: - TOMLWriter

/// String-patch TOML writer that updates individual keys without round-tripping
/// through an encoder, preserving all comments and formatting in unmodified sections.
public enum TOMLWriter {

    /// Patch (or insert) a single key within a named section.
    ///
    /// - Parameters:
    ///   - raw:     The full TOML document string.
    ///   - section: The section path, e.g. `"plugins.clock"`, `"bar"`, `"plugins.clock.pill"`.
    ///   - key:     The key to update, e.g. `"format"`.
    ///   - value:   The new value.
    /// - Returns:   The updated document string.
    public static func patch(raw: String, section: String, key: String, value: TOMLValue) -> String {
        var lines = raw.components(separatedBy: "\n")

        let header = "[\(section)]"
        let headerIdx = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == header
        })

        if let start = headerIdx {
            // Section exists — find the key line within it
            let contentStart = start + 1
            let contentEnd   = sectionEnd(lines: lines, after: contentStart)
            let keyLine      = findKeyLine(in: lines, range: contentStart..<contentEnd, key: key)
            let newLine      = "\(key) = \(value.tomlLiteral)"

            if let idx = keyLine {
                lines[idx] = newLine
            } else {
                // Insert before the section's closing boundary (blank line or next header)
                let insertAt = insertionPoint(lines: lines, sectionContentEnd: contentEnd)
                lines.insert(newLine, at: insertAt)
            }
        } else {
            // Section missing — append at end of file
            if lines.last?.isEmpty == false { lines.append("") }
            lines.append(header)
            lines.append("\(key) = \(value.tomlLiteral)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Remove section

    /// Remove a TOML section (header + content) from a raw TOML document.
    ///
    /// - Parameters:
    ///   - raw:     The full TOML document string.
    ///   - section: The section path to remove, e.g. `"bar"`, `"plugins.clock.pill"`.
    /// - Returns:   The document with the section removed and double blank lines collapsed.
    public static func removeSection(raw: String, section: String) -> String {
        var lines = raw.components(separatedBy: "\n")
        let header = "[\(section)]"

        guard let start = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == header
        }) else {
            return raw  // section not found — no-op
        }

        // Find the end: the next section header line, or end of file.
        let end = sectionEnd(lines: lines, after: start + 1)

        // Remove lines from `start` up to (not including) `end`.
        lines.removeSubrange(start..<end)

        // Collapse any resulting triple-or-more blank lines into double blanks,
        // then strip leading blank lines.
        let joined = lines.joined(separator: "\n")
        let collapsed = joined
            .replacingOccurrences(of: "\n\n\n", with: "\n\n",
                                   options: [], range: nil)
        // Iteratively collapse until stable (handles 4+ consecutive newlines).
        var previous = ""
        var current = collapsed
        while current != previous {
            previous = current
            current = current.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        // Strip leading blank lines.
        return current.replacingOccurrences(of: "^\n+", with: "", options: .regularExpression)
    }

    // MARK: - Private helpers

    /// Index of the first section-header line at or after `after`, or `lines.count`.
    private static func sectionEnd(lines: [String], after start: Int) -> Int {
        for i in start..<lines.count {
            if isSectionHeader(lines[i]) { return i }
        }
        return lines.count
    }

    /// The best insertion point: just before any trailing blank lines in the section.
    private static func insertionPoint(lines: [String], sectionContentEnd end: Int) -> Int {
        var i = end
        while i > 0 && lines[i - 1].trimmingCharacters(in: .whitespaces).isEmpty {
            i -= 1
        }
        return i
    }

    /// Returns the index of the line `key = ...` (any whitespace around `=`) in the given range.
    private static func findKeyLine(in lines: [String], range: Range<Int>, key: String) -> Int? {
        for i in range {
            let stripped = lines[i].trimmingCharacters(in: .whitespaces)
            // Skip comments and blank lines
            guard !stripped.hasPrefix("#"), !stripped.isEmpty else { continue }
            // Match "key =..." or "key=..." but NOT "keyFoo =..." (prefix collision)
            let rest = stripped.dropFirst(key.count)
            let nextChar = rest.first
            if stripped.hasPrefix(key) && (nextChar == "=" || nextChar == " ") {
                // Confirm there's an = somewhere at the start (handle "key = value")
                if rest.trimmingCharacters(in: .whitespaces).hasPrefix("=") {
                    return i
                }
            }
        }
        return nil
    }

    /// True if the line (trimmed) is a TOML section header like `[foo.bar]`.
    private static func isSectionHeader(_ line: String) -> Bool {
        let s = line.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, !s.hasPrefix("#") else { return false }
        guard s.hasPrefix("["), !s.hasPrefix("[[") else { return false }
        return !s.contains("=")
    }
}
