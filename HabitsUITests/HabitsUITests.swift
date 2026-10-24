import XCTest

/// Every flow on the simulator, a screenshot of every screen
final class HabitsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
    }

    func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func cell(_ habit: String, _ day: Int = 0) -> XCUIElement {
        app.descendants(matching: .any)["cell-\(habit)-\(day)"]
    }

    func emoji(_ habit: String) -> XCUIElement {
        app.descendants(matching: .any)["emoji-\(habit)"]
    }

    func value(_ element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    func testGrid() {
        XCTAssertTrue(cell("Water").waitForExistence(timeout: 5))
        shot("grid")
    }

    func testTapBinary() {
        let run = cell("Run")
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        XCTAssertEqual(value(run), "1")
        sleep(1)
        run.tap()
        XCTAssertEqual(value(run), "1")
    }

    func testTapCounter() {
        let reading = cell("Reading")
        XCTAssertTrue(reading.waitForExistence(timeout: 5))
        reading.tap()
        reading.tap()
        XCTAssertEqual(value(reading), "20")
        shot("tapped")
    }

    func testDoubleTap() {
        let reading = cell("Reading")
        XCTAssertTrue(reading.waitForExistence(timeout: 5))
        reading.tap()
        XCTAssertEqual(value(reading), "10")
        reading.doubleTap()
        XCTAssertEqual(value(reading), "0")
        sleep(1)
        reading.doubleTap()
        XCTAssertEqual(value(reading), "-1")
    }

    func testSkip() {
        let run = cell("Run")
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.doubleTap()
        XCTAssertEqual(value(run), "-1")
        shot("skipped")
        sleep(1)
        run.doubleTap()
        XCTAssertEqual(value(run), "0")
    }

    func testHoldMark() {
        let water = cell("Water")
        XCTAssertTrue(water.waitForExistence(timeout: 5))
        water.press(forDuration: 0.8)
        let plus = app.buttons["plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 3))
        plus.tap()
        plus.tap()
        plus.tap()
        app.buttons["minus"].tap()
        let note = app.descendants(matching: .any)["note"]
        note.tap()
        note.typeText("After lunch")
        shot("mark")
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(plus.waitForNonExistence(timeout: 3))
        XCTAssertEqual(value(water), "2")
    }

    func testHoldBinary() {
        let run = cell("Run")
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.press(forDuration: 0.8)
        let toggle = app.buttons["toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.tap()
        shot("mark-binary")
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(toggle.waitForNonExistence(timeout: 3))
        XCTAssertEqual(value(run), "1")
    }

    func testReset() {
        let water = cell("Water")
        XCTAssertTrue(water.waitForExistence(timeout: 5))
        water.tap()
        water.press(forDuration: 0.8)
        let reset = app.buttons["reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 3))
        shot("reset")
        reset.tap()
        XCTAssertTrue(reset.waitForNonExistence(timeout: 3))
        XCTAssertEqual(value(water), "0")
    }

    func testZoom() {
        let water = cell("Water")
        XCTAssertTrue(water.waitForExistence(timeout: 5))
        let grid = app.scrollViews["cells"]
        grid.pinch(withScale: 0.6, velocity: -1)
        let small = water.frame.width
        grid.pinch(withScale: 1.5, velocity: 1)
        XCTAssertGreaterThan(water.frame.width, small)
        shot("zoomed")
    }

    func testZoomButtons() {
        let water = cell("Water")
        XCTAssertTrue(water.waitForExistence(timeout: 5))
        app.buttons["zoom-out"].tap()
        let small = water.frame.width
        app.buttons["zoom-out"].tap()
        XCTAssertLessThan(water.frame.width, small)
        app.buttons["zoom-in"].tap()
        app.buttons["zoom-in"].tap()
        XCTAssertGreaterThan(water.frame.width, small)
    }

    func testReorder() {
        let water = emoji("Water")
        let meditation = emoji("Meditation")
        XCTAssertTrue(meditation.waitForExistence(timeout: 5))
        meditation.press(forDuration: 0.8, thenDragTo: water)
        XCTAssertLessThan(meditation.frame.minY, water.frame.minY)
    }

    func testResize() {
        let grip = app.descendants(matching: .any)["grip"]
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        let from = grip.frame.midX
        let drag = { (dx: Double) in
            let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: dx, dy: 0)))
        }
        drag(-30)
        XCTAssertEqual(grip.frame.midX, from - 30, accuracy: 3)
        drag(30)
        XCTAssertEqual(grip.frame.midX, from, accuracy: 3)
    }

    func testNewHabit() {
        app.buttons["new"].tap()
        let name = app.textFields["name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Yoga")
        app.buttons["icon"].tap()
        let search = app.textFields["emoji-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        shot("emoji")
        search.tap()
        search.typeText("lotus")
        app.buttons["pick-🧘"].tap()
        XCTAssertTrue(search.waitForNonExistence(timeout: 3))
        XCTAssertEqual(app.buttons["icon"].label, "🧘")
        app.segmentedControls["type"].buttons["Counter"].tap()
        app.steppers["step"].buttons.element(boundBy: 1).tap()
        app.steppers["weight"].buttons.element(boundBy: 1).tap()
        XCTAssertEqual(app.staticTexts["step-value"].label, "2")
        XCTAssertEqual(app.staticTexts["weight-value"].label, "1")
        shot("new")
        app.buttons["done"].tap()
        XCTAssertTrue(emoji("Yoga").waitForExistence(timeout: 3))
        cell("Yoga").tap()
        XCTAssertEqual(value(cell("Yoga")), "2")
    }

    func testArchiveAndRestore() {
        XCTAssertTrue(emoji("Run").waitForExistence(timeout: 5))
        emoji("Run").tap()
        let archive = app.buttons["archive"]
        XCTAssertTrue(archive.waitForExistence(timeout: 3))
        shot("edit")
        archive.tap()
        XCTAssertTrue(emoji("Run").waitForNonExistence(timeout: 3))

        app.buttons["settings"].tap()
        let link = app.buttons["archive"]
        XCTAssertTrue(link.waitForExistence(timeout: 3))
        shot("settings")
        link.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("Ru")
        XCTAssertFalse(app.buttons["restore-Piano"].exists)
        shot("archive")
        app.buttons["restore-Run"].tap()
        XCTAssertTrue(app.buttons["restore-Run"].waitForNonExistence(timeout: 3))
    }

    func testDelete() {
        XCTAssertTrue(emoji("Run").waitForExistence(timeout: 5))
        emoji("Run").tap()
        let delete = app.buttons["delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertTrue(app.buttons["confirm-delete"].waitForExistence(timeout: 3))
        shot("delete")
        app.buttons["confirm-delete"].firstMatch.tap()
        XCTAssertTrue(emoji("Run").waitForNonExistence(timeout: 3))

        app.buttons["settings"].tap()
        app.buttons["archive"].tap()
        let piano = app.buttons["delete-Piano"]
        XCTAssertTrue(piano.waitForExistence(timeout: 3))
        piano.tap()
        XCTAssertTrue(app.buttons["confirm-delete"].waitForExistence(timeout: 3))
        app.buttons["confirm-delete"].firstMatch.tap()
        XCTAssertTrue(piano.waitForNonExistence(timeout: 3))
    }

    func testColor() {
        app.buttons["settings"].tap()
        let orange = app.buttons["color-#ff9f0a"]
        XCTAssertTrue(orange.waitForExistence(timeout: 3))
        orange.tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(cell("Water").waitForExistence(timeout: 3))
        shot("orange")
    }

    func testStyleAndSound() {
        app.buttons["settings"].tap()
        let tiles = app.buttons["Tiles"]
        XCTAssertTrue(tiles.waitForExistence(timeout: 3))
        tiles.tap()
        app.buttons["sound"].tap()
        app.buttons["Kalimba"].tap()
        XCTAssertTrue(app.buttons["sound"].staticTexts["Kalimba"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.firstMatch.tap()
        let run = cell("Run", -1)
        XCTAssertTrue(run.waitForExistence(timeout: 3))
        run.doubleTap()
        cell("Run").tap()
        XCTAssertEqual(value(cell("Run")), "1")
        shot("tiles")
        app.buttons["settings"].tap()
        app.buttons["Pills"].tap()
        app.buttons["sound"].tap()
        app.buttons["Off"].tap()
    }

    func testExport() {
        app.buttons["settings"].tap()
        let export = app.buttons["export"]
        XCTAssertTrue(export.waitForExistence(timeout: 3))
        export.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5))
        shot("export")
    }
}
