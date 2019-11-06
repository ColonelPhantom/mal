import Foundation

private extension Func {
    private static func hashMapDataFrom(_ args: [Expr]) throws -> [String: Expr] {
        guard args.count.isMultiple(of: 2) else { throw MalError("invalid arguments") }

        var data: [String: Expr] = [:]
        for i in stride(from: 0, to: args.count - 1, by: 2) {
            guard case let .string(key) = args[i] else { throw MalError("invalid arguments") }
            let value = args[i + 1]
            data[key] = value
        }
        return data
    }

    static func infixOperation(_ op: @escaping (Int, Int) -> Int) -> Func {
        return Func { args in
            guard args.count == 2,
                case let .number(a) = args[0],
                case let .number(b) = args[1] else { throw MalError("invalid arguments") }

            return .number(op(a, b))
        }
    }

    static func comparisonOperation(_ op: @escaping (Int, Int) -> Bool) -> Func {
        return Func { args in
            guard args.count == 2,
                case let .number(a) = args[0],
                case let .number(b) = args[1] else { throw MalError("invalid arguments") }

            return .bool(op(a, b))
        }
    }

    static let prn = Func { args in
        let printFunc = curry(Expr.print)(true)
        let result = args.map(printFunc).joined(separator: " ")
        print(result)
        return .null
    }

    static let str = Func { args in
        let printFunc = curry(Expr.print)(false)
        let result = args.map(printFunc).joined(separator: "")
        return .string(result)
    }

    static let prStr = Func { args in
        let printFunc = curry(Expr.print)(true)
        let result = args.map(printFunc).joined(separator: " ")
        return .string(result)
    }

    static let println = Func { args in
        let printFunc = curry(Expr.print)(false)
        let result = args.map(printFunc).joined(separator: " ")
        print(result)
        return .null
    }

    static let list = Func { args in .list(args) }

    static let isList = Func { args in
        if case .list = args.first {
            return .bool(true)
        }
        return .bool(false)
    }

    static let isEmpty = Func { args in
        switch args.first {
        case let .list(xs), let .vector(xs):
            return .bool(xs.isEmpty)
        default:
            return .bool(false)
        }
    }

    static let count = Func { args in
        switch args.first {
        case let .list(xs), let .vector(xs):
            return .number(xs.count)
        default:
            return .number(0)
        }
    }

    static let eq = Func { args in
        guard args.count == 2 else { throw MalError.invalidArguments("eq") }
        return args[0] == args[1] ? .bool(true) : .bool(false)
    }

    static let readString = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("read-string") }
        guard case let .string(s) = args[0] else { throw MalError.invalidArguments("read-string") }
        return try Reader.read(s)
    }

    static let slurp = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("slurp") }
        guard case let .string(filename) = args[0] else { throw MalError.invalidArguments("slurp") }
        return .string(try String(contentsOfFile: filename))
    }

    static let atom = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("atom") }
        return .atom(Atom(args[0]))
    }

    static let isAtom = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("atom?") }
        if case .atom = args[0] {
            return .bool(true)
        } else {
            return .bool(false)
        }
    }

    static let deref = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("deref") }
        guard case let .atom(atom) = args[0] else { throw MalError.invalidArguments("deref") }
        return atom.val
    }

    static let reset = Func { args in
        guard args.count == 2 else { throw MalError.invalidArguments("reset!") }
        guard case let .atom(atom) = args[0] else { throw MalError.invalidArguments("reset!") }
        atom.val = args[1]
        return args[1]
    }

    static let swap = Func { args in
        guard args.count >= 2 else { throw MalError.invalidArguments("reset!") }
        guard case let .atom(atom) = args[0] else { throw MalError.invalidArguments("swap!") }
        guard case let .function(fn) = args[1] else { throw MalError.invalidArguments("swap!") }
        let otherArgs = args.dropFirst(2)
        atom.val = try fn.run([atom.val] + otherArgs)
        return atom.val
    }

    static let cons = Func { args in
        guard args.count == 2 else { throw MalError.invalidArguments("cons") }
        switch args[1] {
        case let .list(values), let .vector(values):
            return .list([args[0]] + values)
        default:
            throw MalError.invalidArguments("cons")
        }
    }

    static let concat = Func { args in
        let values = try args.flatMap { el throws -> [Expr] in
            switch el {
            case let .list(values), let .vector(values):
                return values
            default:
                throw MalError.invalidArguments("concat")
            }
        }
        return .list(values)
    }

    static let nth = Func { args in
        guard args.count == 2 else { throw MalError.invalidArguments("nth") }
        guard case let .number(index) = args[1] else { throw MalError.invalidArguments("nth") }

        switch args.first {
        case let .list(values), let .vector(values):
            guard values.indices ~= index else { throw MalError.outOfRange() }
            return values[index]
        default:
            throw MalError.invalidArguments("nth")
        }
    }

    static let first = Func { args in
        switch args.first {
        case let .list(values), let .vector(values):
            return values.first ?? .null
        case .null:
            return .null
        default:
            throw MalError.invalidArguments("first")
        }
    }

    static let rest = Func { args in
        switch args.first {
        case let .list(values), let .vector(values):
            return .list(Array(values.dropFirst()))
        case .null:
            return .list([])
        default:
            throw MalError.invalidArguments("rest")
        }
    }

    static let `throw` = Func { args in
        guard args.count > 0 else { throw MalError.invalidArguments("throw") }
        throw args[0]
    }

    static let apply = Func { args in
        guard args.count >= 2 else { throw MalError.invalidArguments("apply") }
        guard case let .function(fn) = args[0] else { throw MalError.invalidArguments("apply") }

        let lastArgs: [Expr]
        switch args.last! {
        case let .list(values), let .vector(values):
            lastArgs = values
        default:
            throw MalError.invalidArguments("apply")
        }


        let fnArgs = Array(args.dropFirst().dropLast()) + lastArgs
        return try fn.run(fnArgs)
    }

    static let map = Func { args in
        guard args.count == 2 else { throw MalError.invalidArguments("map") }
        guard case let .function(fn) = args[0] else { throw MalError.invalidArguments("map") }

        switch args[1] {
        case let .list(values), let .vector(values):
            return .list(try values.map { try fn.run([$0]) })
        default:
            throw MalError.invalidArguments("map")
        }
    }

    static let isNil = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("nil?") }
        if case .null = args[0] {
            return .bool(true)
        }
        return .bool(false)
    }

    static let isTrue = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("true?") }
        if case .bool(true) = args[0] {
            return .bool(true)
        }
        return .bool(false)
    }

    static let isFalse = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("false?") }
        if case .bool(false) = args[0] {
            return .bool(true)
        }
        return .bool(false)
    }

    static let isSymbol = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("symbol?") }
        if case .symbol = args[0] {
            return .bool(true)
        }
        return .bool(false)
    }

    static let symbol = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("symbol") }
        guard case let .string(name) = args[0] else { throw MalError.invalidArguments("symbol") }
        return .symbol(name)
    }

    static let keyword = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("keyword") }
        guard case let .string(name) = args[0] else { throw MalError.invalidArguments("keyword") }
        return name.first == keywordMagic
            ? .string(name)
            : .string(String(keywordMagic) + name)
    }

    static let isKeyword = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("keyword?") }
        if case let .string(name) = args[0] {
            return name.first == keywordMagic ? .bool(true) : .bool(false)
        }
        return .bool(false)
    }

    static let vector = Func { args in
        return .vector(args)
    }

    static let isVector = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("vector?") }
        if case .vector = args[0] {
            return .bool(true)
        }
        return .bool(false)
    }

    static let isSequential = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("sequential?") }
        switch args[0] {
        case .list, .vector:
            return .bool(true)
        default:
            return .bool(false)
        }
    }

    static let hashmap = Func { args in
        return .hashmap(try hashMapDataFrom(args))
    }

    static let isHashmap = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("map?") }
        if case .hashmap = args[0] {
            return .bool(true)
        }
        return .bool(false)
    }

    static let assoc = Func { args in
        guard args.count > 0 else { throw MalError.invalidArguments("assoc") }
        guard case let .hashmap(data) = args[0] else { throw MalError.invalidArguments("assoc") }

        let newData = try hashMapDataFrom(Array(args.dropFirst()))
        return .hashmap(data.merging(newData, uniquingKeysWith: { _, new in new }))
    }

    static let dissoc = Func { args in
        guard args.count > 0 else { throw MalError.invalidArguments("dissoc") }
        guard case var .hashmap(data) = args[0] else { throw MalError.invalidArguments("dissoc") }

        for key in args.dropFirst() {
            guard case let .string(name) = key else { throw MalError.invalidArguments("dissoc") }
            data.removeValue(forKey: name)
        }
        return .hashmap(data)
    }

    static let get = Func { args in
        guard args.count == 2 else { throw MalError.invalidArguments("get") }
        guard case let .string(key) = args[1] else { throw MalError.invalidArguments("get") }

        switch args[0] {
        case let .hashmap(data):
            return data[key] ?? .null
        case .null:
            return .null
        default:
            throw MalError.invalidArguments("get")
        }
    }

    static let contains = Func { args in
        guard args.count == 2 else { throw MalError.invalidArguments("contains?") }
        guard case let .hashmap(data) = args[0] else { throw MalError.invalidArguments("contains?") }
        guard case let .string(key) = args[1] else { throw MalError.invalidArguments("contains?") }
        return data.keys.contains(key) ? .bool(true) : .bool(false)
    }

    static let keys = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("keys") }
        guard case let .hashmap(data) = args[0] else { throw MalError.invalidArguments("keys") }
        return .list(data.keys.map(Expr.string))
    }

    static let vals = Func { args in
        guard args.count == 1 else { throw MalError.invalidArguments("vals") }
        guard case let .hashmap(data) = args[0] else { throw MalError.invalidArguments("vals") }
        return .list(Array(data.values))
    }
}

private let data: [String: Expr] = [
    "+": .function(.infixOperation(+)),
    "-": .function(.infixOperation(-)),
    "*": .function(.infixOperation(*)),
    "/": .function(.infixOperation(/)),
    "prn": .function(.prn),
    "println": .function(.println),
    "pr-str": .function(.prStr),
    "str": .function(.str),
    "list": .function(.list),
    "list?": .function(.isList),
    "empty?": .function(.isEmpty),
    "count": .function(.count),
    "=": .function(.eq),
    "<": .function(.comparisonOperation(<)),
    "<=": .function(.comparisonOperation(<=)),
    ">": .function(.comparisonOperation(>)),
    ">=": .function(.comparisonOperation(>=)),
    "read-string": .function(.readString),
    "slurp": .function(.slurp),
    "atom": .function(.atom),
    "atom?": .function(.isAtom),
    "deref": .function(.deref),
    "reset!": .function(.reset),
    "swap!": .function(.swap),
    "cons": .function(.cons),
    "concat": .function(.concat),
    "nth": .function(.nth),
    "first": .function(.first),
    "rest": .function(.rest),
    "throw": .function(.throw),
    "apply": .function(.apply),
    "map": .function(.map),
    "nil?": .function(.isNil),
    "true?": .function(.isTrue),
    "false?": .function(.isFalse),
    "symbol?": .function(.isSymbol),
    "symbol": .function(.symbol),
    "keyword": .function(.keyword),
    "keyword?": .function(.isKeyword),
    "vector": .function(.vector),
    "vector?": .function(.isVector),
    "sequential?": .function(.isSequential),
    "hash-map": .function(.hashmap),
    "map?": .function(.isHashmap),
    "assoc": .function(.assoc),
    "dissoc": .function(.dissoc),
    "get": .function(.get),
    "contains?": .function(.contains),
    "keys": .function(.keys),
    "vals": .function(.vals)
]

public enum Core {
    public static let ns: Env = Env.init(data: data, outer: nil)
}
