//
//  URLCommandParser.swift
//  Line
//
//  Pure parse of line:// URLs into a command + parameters, or a reject reason.
//  Security limits (URL length / parameter length) live here so they are testable
//  without opening windows or writing temp files.
//

import Foundation

enum URLCommandParser {
    static let maxURLLength = 1024
    static let maxParameterLength = 256

    enum Reject: Equatable {
        case unsupportedScheme
        case urlTooLong
        case parameterTooLong
        case unknownCommand
    }

    struct Parsed: Equatable {
        let command: URLCommandHandler.Command
        let parameters: [String]
    }

    enum Result: Equatable {
        case accept(Parsed)
        case reject(Reject)
    }

    /// Parse a URL without side effects.
    static func parse(_ url: URL) -> Result {
        guard url.scheme.map({ URLCommandHandler.Scheme.supported.contains($0.lowercased()) }) == true else {
            return .reject(.unsupportedScheme)
        }

        guard url.absoluteString.count < maxURLLength else {
            return .reject(.urlTooLong)
        }

        let components = (url.host.map { [$0] } ?? []) + url.pathComponents.filter { $0 != "/" && !$0.isEmpty }

        guard let commandString = components.first,
              let command = URLCommandHandler.Command(rawValue: commandString.lowercased()) else {
            return .reject(.unknownCommand)
        }

        let parameters = Array(components.dropFirst())
        for parameter in parameters {
            if parameter.count > maxParameterLength {
                return .reject(.parameterTooLong)
            }
        }

        return .accept(Parsed(command: command, parameters: parameters))
    }
}
