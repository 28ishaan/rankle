import XCTest

final class UIFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testCreateListFlow() {
        // Tap + to create a new list
        let addButton = app.buttons["plus"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // Enter list name
        let nameField = app.textFields["e.g., Favorite Movies"].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("UI Test List")

        // Add one item
        let itemField = app.textFields["Item name"].firstMatch
        XCTAssertTrue(itemField.waitForExistence(timeout: 5))
        itemField.tap()
        itemField.typeText("Item A")

        let addItemButton = app.buttons["Add"].firstMatch
        XCTAssertTrue(addItemButton.waitForExistence(timeout: 5))
        addItemButton.tap()

        // Create the list
        let createButton = app.buttons["Create"].firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        // Verify the new list appears on Home
        let createdList = app.staticTexts["UI Test List"].firstMatch
        XCTAssertTrue(createdList.waitForExistence(timeout: 5))
    }

    func testThemeToggle() {
        // Find the theme toggle button (sun/moon)
        let sunButton = app.buttons["sun.max.fill"].firstMatch
        let moonButton = app.buttons["moon.fill"].firstMatch
        let toggle = sunButton.exists ? sunButton : moonButton
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))

        // Toggle twice to ensure both directions work
        toggle.tap()
        toggle.tap()
    }
}
