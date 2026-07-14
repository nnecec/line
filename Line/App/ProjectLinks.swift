//
//  ProjectLinks.swift
//  Line
//

import Foundation

enum ProjectLinks {
    static let repositoryURLString = "https://github.com/nnecec/Line"

    static var repositoryURL: URL? {
        URL(string: repositoryURLString)
    }
}
