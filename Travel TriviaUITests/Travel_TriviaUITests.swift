//
//  Travel_TriviaUITests.swift
//  Travel TriviaUITests
//
//  Drives the full vertical slice end to end: Our Ride → join the open
//  seat → play Three Strikes through the Riddle Realm questions → victory.
//

import XCTest

final class Travel_TriviaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFullRoundFromSeatPickerToVictory() throws {
        let app = XCUIApplication()
        app.launch()

        // Our Ride: the open seat joins the 4th player
        let openSeat = app.buttons["seat-open"]
        XCTAssertTrue(openSeat.waitForExistence(timeout: 5), "Open seat should be visible on Our Ride")
        openSeat.tap()
        XCTAssertFalse(openSeat.waitForExistence(timeout: 2), "Open seat should be filled after joining")

        app.buttons["start-trip"].tap()

        // Question loop: answer whenever the grid is interactive; the round
        // ends by elimination or after all 16 questions.
        let victoryTitle = app.staticTexts["victory-title"]
        let scoreboardToggle = app.buttons["scoreboard-toggle"]
        XCTAssertTrue(scoreboardToggle.waitForExistence(timeout: 5), "Question screen should appear")

        // Peek at the scoreboard dropdown once, then close it
        scoreboardToggle.tap()
        XCTAssertTrue(app.descendants(matching: .any)["scoreboard-panel"].firstMatch.waitForExistence(timeout: 3),
                      "Scoreboard dropdown should open")
        scoreboardToggle.tap()

        let deadline = Date().addingTimeInterval(180)
        while !victoryTitle.exists, Date() < deadline {
            let answer = app.buttons["answer-0"]
            if answer.exists, answer.isEnabled, answer.isHittable {
                answer.tap()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }

        XCTAssertTrue(victoryTitle.exists, "Round should end on the victory screen")

        // Back to Our Ride for another round
        app.buttons["back-to-ride"].tap()
        XCTAssertTrue(app.buttons["start-trip"].waitForExistence(timeout: 5),
                      "Back to the Ride should return to the seat picker")
    }
}
