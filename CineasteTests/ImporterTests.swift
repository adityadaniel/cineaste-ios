//
//  ImporterTests.swift
//  CineasteTests
//
//  Created by Felizia Bernutz on 26.12.18.
//  Copyright © 2018 spacepandas.de. All rights reserved.
//

import XCTest
import ReSwift
@testable import Cineaste_App

class ImporterTests: XCTestCase {

    func testImportMoviesFromUrlShouldImportMovies() {
        XCTAssertNoThrow(
            try cleanImportOfMovies(
                from: "Import",
                expectedNumberOfMovies: 2
            )
        )
    }

    func testImportMoviesFromUrlShouldImportMoviesFromAndroidExport() {
        XCTAssertNoThrow(
            try cleanImportOfMovies(
                from: "AndroidExport",
                expectedNumberOfMovies: 3
            )
        )
    }

    func testImportMoviesFromUrlShouldResultInErrorWhenImportingFailingJson() {
        // Given
        guard let path = Bundle(for: ImporterTests.self)
            .path(forResource: "FailingImport", ofType: "json")
            else {
                fatalError("Could not load file for resource FailingImport.json")
        }
        let urlToFailingImport = URL(fileURLWithPath: path)
        var actions: [MovieAction] = []
        store.dispatchFunction = { action in
            if let action = action as? MovieAction {
                actions.append(action)
            }
        }

        // When
        XCTAssertThrowsError(try Importer.importMovies(from: urlToFailingImport))

        // Then
        XCTAssertEqual(actions.count, 0)
    }
}

extension ImporterTests {
    private func cleanImportOfMovies(from file: String, expectedNumberOfMovies: Int) throws {
        // Given
        guard let path = Bundle(for: ImporterTests.self)
            .path(forResource: file, ofType: "json")
            else {
                fatalError("Could not load file for resource \(file).json")
        }
        let urlToImport = URL(fileURLWithPath: path)
        var actions: [MovieAction] = []
        store.dispatchFunction = { action in
            if let action = action as? MovieAction {
                actions.append(action)
            }
        }

        // When
        let amountOfImportedMovies = try Importer.importMovies(from: urlToImport)

        // Then
        XCTAssertEqual(actions.count, expectedNumberOfMovies)
        XCTAssertEqual(amountOfImportedMovies, expectedNumberOfMovies)
    }
}
