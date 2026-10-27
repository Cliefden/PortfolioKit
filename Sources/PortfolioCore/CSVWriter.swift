import Foundation

/// RFC 4180 CSV output for data exports (GDPR "download my data", cellar/journal
/// exports). Replaces Jeroboam `DataExportFormatter.csv/escape` and Carpe Vitem
/// `ExportService.escapeCSV` (which missed `\r` and edge whitespace).
///
/// ```swift
/// let csv = CSVWriter.document(
///     header: ["Name", "Vintage", "Notes"],
///     rows: wines.map { [$0.name, String($0.vintage), $0.notes ?? ""] }
/// )
/// try csv.write(to: url, atomically: true, encoding: .utf8)
/// ```
///
/// Fields are quoted when they contain a comma, quote, CR/LF or leading/trailing
/// whitespace; embedded quotes are doubled. Lines end in CRLF.
public enum CSVWriter {
    /// Characters that make a spreadsheet treat a cell as a formula.
    public static let formulaTriggers: Set<Unicode.Scalar> = ["=", "+", "-", "@", "\t", "\r"]

    /// Escape one field.
    ///
    /// - Parameter formulaGuard: prefix fields starting with `= + - @ TAB CR`
    ///   with `'` so Excel/Numbers don't execute user text as a formula (CSV
    ///   injection). Off by default because it also prefixes negative numbers —
    ///   turn it on for free-text columns. Undo on import with
    ///   ``removingFormulaGuard(_:)``.
    public static func field(_ value: String, formulaGuard: Bool = false) -> String {
        let value = formulaGuard ? addingFormulaGuard(value) : value
        let needsQuotes = value.contains { $0 == "," || $0 == "\"" || $0.isNewline }
            || value.first?.isWhitespace == true
            || value.last?.isWhitespace == true
        guard needsQuotes else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// One CSV record (no line ending).
    public static func row(_ fields: [String], formulaGuard: Bool = false) -> String {
        fields.map { field($0, formulaGuard: formulaGuard) }.joined(separator: ",")
    }

    /// A whole document: header + rows, each line terminated by `lineEnding`.
    public static func document(
        header: [String]?,
        rows: [[String]],
        formulaGuard: Bool = false,
        lineEnding: String = "\r\n"
    ) -> String {
        let records = (header.map { [$0] } ?? []) + rows
        return records.map { row($0, formulaGuard: formulaGuard) + lineEnding }.joined()
    }

    /// `'`-prefix a field that starts with a formula trigger.
    public static func addingFormulaGuard(_ value: String) -> String {
        guard let first = value.unicodeScalars.first, formulaTriggers.contains(first) else { return value }
        return "'" + value
    }

    /// Undo ``addingFormulaGuard(_:)``: drops a leading `'` only when a trigger follows.
    public static func removingFormulaGuard(_ value: String) -> String {
        let scalars = value.unicodeScalars
        guard scalars.first == "'", scalars.count > 1,
              formulaTriggers.contains(scalars[scalars.index(after: scalars.startIndex)])
        else { return value }
        return String(scalars.dropFirst())
    }

    /// Locale-independent decimal (`"95.5"`, never `"95,5"`), no grouping.
    public static func number(_ value: Double) -> String {
        value.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).grouping(.never))
    }
}
