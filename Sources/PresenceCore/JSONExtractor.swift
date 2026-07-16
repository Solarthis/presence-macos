public enum JSONObjectExtractionError: Error, Equatable {
    case noJSONObject
    case unbalancedJSONObject

    public var reason: String {
        switch self {
        case .noJSONObject:
            return "Codex output did not contain a JSON object."
        case .unbalancedJSONObject:
            return "Codex output contained an unbalanced JSON object."
        }
    }
}

public func extractLastJSONObject(
    from input: String
) -> Result<String, JSONObjectExtractionError> {
    var depth = 0
    var start: String.Index?
    var lastObject: String?
    var isInsideString = false
    var isEscaping = false
    var sawObjectStart = false

    var index = input.startIndex
    while index < input.endIndex {
        let character = input[index]

        if depth > 0, isInsideString {
            if isEscaping {
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else if character == "\"" {
                isInsideString = false
            }
        } else if depth > 0, character == "\"" {
            isInsideString = true
        } else if character == "{" {
            if depth == 0 {
                start = index
                sawObjectStart = true
            }
            depth += 1
        } else if character == "}", depth > 0 {
            depth -= 1
            if depth == 0, let start {
                let end = input.index(after: index)
                lastObject = String(input[start..<end])
                isInsideString = false
                isEscaping = false
            }
        }

        index = input.index(after: index)
    }

    if let lastObject {
        return .success(lastObject)
    }
    return .failure(sawObjectStart ? .unbalancedJSONObject : .noJSONObject)
}
