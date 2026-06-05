import Foundation

enum LaunchpadCalculatorState {
    case result(LaunchpadCalculationResult)
    case error(String)
}

struct LaunchpadCalculationResult {
    let expression: String
    let displayValue: String
    let copyValue: String
}

enum LaunchpadCalculator {
    static func evaluate(_ input: String) -> LaunchpadCalculatorState? {
        let normalized = normalize(input)
        guard isProbablyCalculation(normalized) else { return nil }

        do {
            let tokens = try Tokenizer(input: normalized).tokenize()
            let parser = Parser(tokens: tokens)
            let quantity = try parser.parseExpression()
            try parser.expectEnd()
            let displayValue = quantity.formattedDisplay
            return .result(
                LaunchpadCalculationResult(
                    expression: input.trimmingCharacters(in: .whitespacesAndNewlines),
                    displayValue: displayValue,
                    copyValue: displayValue
                )
            )
        } catch let error as CalculatorError {
            return .error(error.message)
        } catch {
            return .error("Unable to evaluate expression.")
        }
    }

    private static func normalize(_ input: String) -> String {
        let folded = input.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: ",", with: ".")

        let replacements: [(String, String)] = [
            ("divise par", " / "),
            ("divide by", " / "),
            ("divided by", " / "),
            ("multiplied by", " * "),
            ("plus", " + "),
            ("moins", " - "),
            ("minus", " - "),
            ("fois", " * "),
            ("x", " * ")
        ]

        return replacements.reduce(folded) { current, replacement in
            current.replacingOccurrences(of: replacement.0, with: replacement.1)
        }
    }

    private static func isProbablyCalculation(_ input: String) -> Bool {
        let hasDigits = input.rangeOfCharacter(from: .decimalDigits) != nil
        let hasOperator = input.contains("+")
            || input.contains("-")
            || input.contains("*")
            || input.contains("/")
            || input.contains("(")
            || input.contains(")")
        let hasUnit = UnitRegistry.matchesKnownUnit(in: input)
        return hasDigits && (hasOperator || hasUnit)
    }
}

private enum CalculatorError: Error {
    case invalidToken(String)
    case unexpectedEnd
    case expectedClosingParen
    case incompatibleUnits
    case invalidOperation

    var message: String {
        switch self {
        case .invalidToken(let token): "Unknown token: \(token)"
        case .unexpectedEnd: "Incomplete expression."
        case .expectedClosingParen: "Missing closing parenthesis."
        case .incompatibleUnits: "Units must be compatible."
        case .invalidOperation: "Unsupported operation."
        }
    }
}

private enum Token: Equatable {
    case number(Double)
    case unit(UnitRegistry.Entry)
    case op(Operator)
    case lparen
    case rparen
}

private enum Operator: Equatable {
    case add
    case subtract
    case multiply
    case divide
}

private enum Quantity {
    case scalar(Double)
    case measurement(MeasurementDimension, Double)

    var formattedDisplay: String {
        switch self {
        case .scalar(let value):
            return NumberFormatting.displayNumber(value)
        case .measurement(let dimension, let baseValue):
            let unitSymbol: String
            switch dimension {
            case .length: unitSymbol = "m"
            case .volume: unitSymbol = "L"
            case .mass: unitSymbol = "kg"
            }
            return "\(NumberFormatting.displayNumber(baseValue)) \(unitSymbol)"
        }
    }
}

private enum MeasurementDimension: Hashable {
    case length
    case volume
    case mass
}

private enum UnitRegistry {
    struct Entry: Equatable {
        let normalizedName: String
        let dimension: MeasurementDimension
        let factorToBase: Double
    }

    private static let entries: [String: Entry] = {
        func entry(_ names: [String], dimension: MeasurementDimension, factorToBase: Double) -> [String: Entry] {
            Dictionary(uniqueKeysWithValues: names.map {
                ($0, Entry(normalizedName: $0, dimension: dimension, factorToBase: factorToBase))
            })
        }

        var result: [String: Entry] = [:]
        result.merge(entry(["m", "meter", "meters", "metre", "metres"], dimension: .length, factorToBase: 1), uniquingKeysWith: { $1 })
        result.merge(entry(["cm", "centimeter", "centimeters", "centimetre", "centimetres"], dimension: .length, factorToBase: 0.01), uniquingKeysWith: { $1 })
        result.merge(entry(["mm", "millimeter", "millimeters", "millimetre", "millimetres"], dimension: .length, factorToBase: 0.001), uniquingKeysWith: { $1 })
        result.merge(entry(["km", "kilometer", "kilometers", "kilometre", "kilometres"], dimension: .length, factorToBase: 1000), uniquingKeysWith: { $1 })
        result.merge(entry(["in", "inch", "inches"], dimension: .length, factorToBase: 0.0254), uniquingKeysWith: { $1 })
        result.merge(entry(["ft", "foot", "feet"], dimension: .length, factorToBase: 0.3048), uniquingKeysWith: { $1 })
        result.merge(entry(["yd", "yard", "yards"], dimension: .length, factorToBase: 0.9144), uniquingKeysWith: { $1 })
        result.merge(entry(["l", "liter", "liters", "litre", "litres"], dimension: .volume, factorToBase: 1), uniquingKeysWith: { $1 })
        result.merge(entry(["ml", "milliliter", "milliliters", "millilitre", "millilitres"], dimension: .volume, factorToBase: 0.001), uniquingKeysWith: { $1 })
        result.merge(entry(["cl", "centiliter", "centiliters", "centilitre", "centilitres"], dimension: .volume, factorToBase: 0.01), uniquingKeysWith: { $1 })
        result.merge(entry(["dl", "deciliter", "deciliters", "decilitre", "decilitres"], dimension: .volume, factorToBase: 0.1), uniquingKeysWith: { $1 })
        result.merge(entry(["kg", "kilogram", "kilograms"], dimension: .mass, factorToBase: 1), uniquingKeysWith: { $1 })
        result.merge(entry(["g", "gram", "grams"], dimension: .mass, factorToBase: 0.001), uniquingKeysWith: { $1 })
        result.merge(entry(["mg", "milligram", "milligrams"], dimension: .mass, factorToBase: 0.000001), uniquingKeysWith: { $1 })
        return result
    }()

    static func matchesKnownUnit(in input: String) -> Bool {
        entries.keys.contains { input.contains($0) }
    }

    static func entry(for name: String) -> Entry? {
        entries[name]
    }
}

private struct Tokenizer {
    let input: String

    func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        var index = input.startIndex

        while index < input.endIndex {
            let character = input[index]

            if character.isWhitespace {
                index = input.index(after: index)
                continue
            }

            if character == "+" {
                tokens.append(.op(.add))
                index = input.index(after: index)
                continue
            }

            if character == "-" {
                tokens.append(.op(.subtract))
                index = input.index(after: index)
                continue
            }

            if character == "*" {
                tokens.append(.op(.multiply))
                index = input.index(after: index)
                continue
            }

            if character == "/" {
                tokens.append(.op(.divide))
                index = input.index(after: index)
                continue
            }

            if character == "(" {
                tokens.append(.lparen)
                index = input.index(after: index)
                continue
            }

            if character == ")" {
                tokens.append(.rparen)
                index = input.index(after: index)
                continue
            }

            if character.isNumber || character == "." {
                let number = readNumber(from: &index)
                tokens.append(.number(number))
                continue
            }

            if character.isLetter {
                let word = readWord(from: &index)
                if let unit = UnitRegistry.entry(for: word) {
                    tokens.append(.unit(unit))
                    continue
                }
                if let op = wordOperator(for: word) {
                    tokens.append(.op(op))
                    continue
                }
                throw CalculatorError.invalidToken(word)
            }

            throw CalculatorError.invalidToken(String(character))
        }

        return tokens
    }

    private func wordOperator(for word: String) -> Operator? {
        switch word {
        case "plus": .add
        case "moins", "minus": .subtract
        case "fois": .multiply
        case "divise", "divide", "divided": .divide
        case "x": .multiply
        default: nil
        }
    }

    private func readNumber(from index: inout String.Index) -> Double {
        let start = index
        var hasDecimal = false

        while index < input.endIndex {
            let character = input[index]
            if character.isNumber {
                index = input.index(after: index)
            } else if character == "." && !hasDecimal {
                hasDecimal = true
                index = input.index(after: index)
            } else {
                break
            }
        }

        let slice = String(input[start..<index])
        return Double(slice) ?? 0
    }

    private func readWord(from index: inout String.Index) -> String {
        let start = index
        while index < input.endIndex, input[index].isLetter {
            index = input.index(after: index)
        }
        return String(input[start..<index])
    }
}

private final class Parser {
    private let tokens: [Token]
    private var index = 0

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    func parseExpression() throws -> Quantity {
        var value = try parseTerm()

        while let token = peek(), case .op(let op) = token, op == .add || op == .subtract {
            _ = advance()
            let rhs = try parseTerm()
            switch op {
            case .add:
                value = try add(value, rhs)
            case .subtract:
                value = try subtract(value, rhs)
            default:
                break
            }
        }

        return value
    }

    func expectEnd() throws {
        guard peek() == nil else { throw CalculatorError.invalidOperation }
    }

    private func parseTerm() throws -> Quantity {
        var value = try parsePrimary()

        while let token = peek(), case .op(let op) = token, op == .multiply || op == .divide {
            _ = advance()
            let rhs = try parsePrimary()
            switch op {
            case .multiply:
                value = try multiply(value, rhs)
            case .divide:
                value = try divide(value, rhs)
            default:
                break
            }
        }

        return value
    }

    private func parsePrimary() throws -> Quantity {
        guard let token = peek() else { throw CalculatorError.unexpectedEnd }

        switch token {
        case .op(.subtract):
            _ = advance()
            let value = try parsePrimary()
            return try negate(value)
        case .op(.add):
            _ = advance()
            return try parsePrimary()
        case .number(let value):
            _ = advance()
            if case let .unit(unit)? = peek() {
                _ = advance()
                return .measurement(unit.dimension, value * unit.factorToBase)
            }
            return .scalar(value)
        case .lparen:
            _ = advance()
            let value = try parseExpression()
            guard case .rparen? = peek() else { throw CalculatorError.expectedClosingParen }
            _ = advance()
            return value
        case .unit(_):
            throw CalculatorError.invalidOperation
        case .rparen:
            throw CalculatorError.expectedClosingParen
        case .op:
            throw CalculatorError.invalidOperation
        }
    }

    private func add(_ lhs: Quantity, _ rhs: Quantity) throws -> Quantity {
        switch (lhs, rhs) {
        case (.scalar(let left), .scalar(let right)):
            return .scalar(left + right)
        case (.measurement(let dimension, let left), .measurement(let otherDimension, let right)) where dimension == otherDimension:
            return .measurement(dimension, left + right)
        default:
            throw CalculatorError.incompatibleUnits
        }
    }

    private func subtract(_ lhs: Quantity, _ rhs: Quantity) throws -> Quantity {
        switch (lhs, rhs) {
        case (.scalar(let left), .scalar(let right)):
            return .scalar(left - right)
        case (.measurement(let dimension, let left), .measurement(let otherDimension, let right)) where dimension == otherDimension:
            return .measurement(dimension, left - right)
        default:
            throw CalculatorError.incompatibleUnits
        }
    }

    private func multiply(_ lhs: Quantity, _ rhs: Quantity) throws -> Quantity {
        switch (lhs, rhs) {
        case (.scalar(let left), .scalar(let right)):
            return .scalar(left * right)
        case (.scalar(let scalar), .measurement(let dimension, let baseValue)):
            return .measurement(dimension, scalar * baseValue)
        case (.measurement(let dimension, let baseValue), .scalar(let scalar)):
            return .measurement(dimension, baseValue * scalar)
        default:
            throw CalculatorError.invalidOperation
        }
    }

    private func divide(_ lhs: Quantity, _ rhs: Quantity) throws -> Quantity {
        switch (lhs, rhs) {
        case (.scalar(let left), .scalar(let right)):
            return .scalar(left / right)
        case (.measurement(let dimension, let baseValue), .scalar(let scalar)):
            return .measurement(dimension, baseValue / scalar)
        case (.measurement(let leftDimension, let leftValue), .measurement(let rightDimension, let rightValue)) where leftDimension == rightDimension:
            return .scalar(leftValue / rightValue)
        default:
            throw CalculatorError.invalidOperation
        }
    }

    private func negate(_ value: Quantity) throws -> Quantity {
        switch value {
        case .scalar(let scalar):
            return .scalar(-scalar)
        case .measurement(let dimension, let baseValue):
            return .measurement(dimension, -baseValue)
        }
    }

    private func peek() -> Token? {
        guard index < tokens.count else { return nil }
        return tokens[index]
    }

    @discardableResult
    private func advance() -> Token? {
        guard index < tokens.count else { return nil }
        defer { index += 1 }
        return tokens[index]
    }
}

private enum NumberFormatting {
    static func displayNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.minimumIntegerDigits = 1
        let number = NSNumber(value: value.roundedIfClose)
        return formatter.string(from: number) ?? String(value.roundedIfClose)
    }
}

private extension Double {
    var roundedIfClose: Double {
        let rounded = rounded(.toNearestOrAwayFromZero)
        return abs(self - rounded) < 0.0000001 ? rounded : self
    }
}
