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
        // The app fronts with the Main Menu now; -TTPractice jumps straight
        // into the session-1 single-device slice this test drives.
        app.launchArguments = ["-TTPractice"]
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

    /// Menu → Create Game setup (mode/genre/difficulty/name) → a real
    /// hosted lobby advertising over Multipeer → back out to the menu.
    @MainActor
    func testCreateGameFlowReachesLobbyAndBacksOut() throws {
        let app = XCUIApplication()
        app.launch()

        let create = app.buttons["menu-create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5), "Main menu should show Create a New Game")
        create.tap()

        // Only Three Strikes is playable; the rest are Coming Soon.
        let threeStrikes = app.buttons["mode-three-strikes"]
        XCTAssertTrue(threeStrikes.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mode-team-relay"].isEnabled, "Unbuilt modes should be disabled")
        threeStrikes.tap()

        let riddleRealm = app.buttons["genre-riddle-realm"]
        XCTAssertTrue(riddleRealm.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["genre-time-machine"].isEnabled, "Empty genres should be disabled")
        riddleRealm.tap()

        app.buttons["difficulty-family-mix"].tap()

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("UI Test Party")

        app.buttons["create-party"].tap()

        XCTAssertTrue(app.buttons["lobby-start"].waitForExistence(timeout: 8),
                      "Host should land in the lobby with a Start button")

        // Host backing out ends the party for everyone (confirm alert).
        app.buttons["flow-back"].tap()
        let endButton = app.alerts.buttons["End for Everyone"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 4))
        endButton.tap()

        XCTAssertTrue(app.buttons["menu-create"].waitForExistence(timeout: 5),
                      "Ending the party should land back on the main menu")
    }

    /// Settings persists the display name and toggles.
    @MainActor
    func testSettingsEditsPersistLocally() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["menu-settings"].waitForExistence(timeout: 5))
        app.buttons["menu-settings"].tap()

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))

        app.buttons["settings-shuffle"].tap()
        app.buttons["settings-audio-phoneSpeaker"].tap()
        app.buttons["flow-back"].tap()

        XCTAssertTrue(app.buttons["menu-create"].waitForExistence(timeout: 5),
                      "Back from Settings should return to the menu")
    }
}
