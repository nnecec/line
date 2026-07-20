//
//  ProjectLinks.swift
//  Line
//

import Foundation

enum ProjectLinks {
    static let repositoryURLString = "https://github.com/nnecec/Line"
    static let issuesURLString = "https://github.com/nnecec/Line/issues"
    static let releasesURLString = "https://github.com/nnecec/Line/releases"
    static let urlSchemeDocsURLString = "https://github.com/nnecec/Line/blob/main/docs/URL_SCHEME.md"

    static var repositoryURL: URL? {
        URL(string: repositoryURLString)
    }

    static var issuesURL: URL? {
        URL(string: issuesURLString)
    }

    static var releasesURL: URL? {
        URL(string: releasesURLString)
    }

    static var urlSchemeDocsURL: URL? {
        URL(string: urlSchemeDocsURLString)
    }
}
