import XCTest

@MainActor
final class MeloXTabletUITests: XCTestCase {
    private func launch(page: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MELOX_UI_PREVIEW"] = "1"
        if let page { app.launchEnvironment["MELOX_UI_PAGE"] = page }
        app.launch()
        return app
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertExploreRowsAlign(app: XCUIApplication) {
        let firstGrid = app.descendants(matching: .any)["explore-grid-902004"].firstMatch
        let secondGrid = app.descendants(matching: .any)["explore-grid-902005"].firstMatch
        XCTAssertTrue(firstGrid.exists && secondGrid.exists)
        XCTAssertEqual(firstGrid.frame.minY, secondGrid.frame.minY, accuracy: 1.5, "Short and long playlist titles must leave covers aligned at the top.")
        let gridElements = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "explore-grid-"))
            .allElementsBoundByIndex
            .filter { abs($0.frame.minY - firstGrid.frame.minY) < 1.5 }
        let featuredElements = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "explore-featured-"))
            .allElementsBoundByIndex
        let gridRight = gridElements.map { $0.frame.maxX }.max() ?? 0
        let visibleFeatured = featuredElements.filter {
            $0.frame.minX >= firstGrid.frame.minX - 1.5 && $0.frame.maxX <= gridRight + 1.5
        }
        XCTAssertGreaterThan(visibleFeatured.count, 1)
        XCTAssertEqual(visibleFeatured.map { $0.frame.minX }.min() ?? 0, firstGrid.frame.minX, accuracy: 1.5)
        XCTAssertEqual(visibleFeatured.map { $0.frame.maxX }.max() ?? 0, gridRight, accuracy: 1.5, "The feature row and playlist grid must share their right edge.")
    }

    func testIPadNavigationAndPlayerRotation() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch()
        XCTAssertTrue(app.buttons["tablet-mini-open"].waitForExistence(timeout: 20))
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        XCTAssertTrue(app.buttons["tablet-sidebar-account"].waitForExistence(timeout: 10), "The iPad should open with the sidebar visible.")
        let search = app.cells["magnifyingglass"].firstMatch
        XCTAssertTrue(search.exists)
        XCTAssertLessThan(search.frame.minY, 160, "Sidebar navigation should start near the native toolbar.")
        XCTAssertTrue(app.buttons["navigation-recognition"].exists, "Song recognition must stay available in the primary toolbar.")
        Thread.sleep(forTimeInterval: 3)
        capture("ipad-landscape-home", app: app)

        app.buttons["tablet-mini-lyrics"].tap()
        XCTAssertTrue(app.buttons["tablet-player-collapse"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["tablet-page-lyrics"].isSelected, "The lyrics shortcut must open the lyrics page.")
        Thread.sleep(forTimeInterval: 2)
        capture("ipad-landscape-lyrics", app: app)

        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 3)
        XCTAssertLessThan(app.frame.width, app.frame.height)
        XCTAssertTrue(app.buttons["tablet-player-collapse"].isHittable)
        XCTAssertTrue(app.buttons["tablet-page-lyrics"].isSelected)
        capture("ipad-portrait-lyrics", app: app)

        app.buttons["tablet-player-collapse"].tap()
        XCTAssertTrue(app.buttons["tablet-mini-queue"].waitForExistence(timeout: 10))
        app.buttons["tablet-mini-queue"].tap()
        XCTAssertTrue(app.buttons["tablet-player-collapse"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["tablet-page-queue"].isSelected, "The queue shortcut must open the queue page.")
        Thread.sleep(forTimeInterval: 2)
        capture("ipad-portrait-queue", app: app)
    }

    func testLargeTextKeepsPlayerControlsReachable() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchEnvironment["MELOX_UI_PREVIEW"] = "1"
        app.launchEnvironment["MELOX_UI_PAGE"] = "lyrics"
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        XCTAssertTrue(app.buttons["tablet-player-collapse"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["tablet-player-collapse"].isHittable)
        XCTAssertTrue(app.buttons["tablet-page-lyrics"].isSelected)
        capture("ipad-accessibility-lyrics", app: app)
    }

    func testSidebarKeepsHomeLibraryCategoriesAccessible() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchEnvironment["MELOX_UI_PREVIEW"] = "1"
        app.launchEnvironment["MELOX_UI_LIBRARY_HOME"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["tablet-mini-open"].waitForExistence(timeout: 20))
        let albums = app.descendants(matching: .any)["专辑"].firstMatch
        XCTAssertTrue(albums.waitForExistence(timeout: 10), "A library category placed on Home must remain in the iPad sidebar.")
        albums.tap()
        XCTAssertTrue(app.staticTexts["收藏专辑"].waitForExistence(timeout: 10))
    }

    func testSidebarAccountStaysPinnedWhileCategoriesScroll() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchEnvironment["MELOX_UI_PREVIEW"] = "1"
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        XCTAssertTrue(app.buttons["tablet-mini-open"].waitForExistence(timeout: 20))
        let account = app.buttons["tablet-sidebar-account"]
        XCTAssertTrue(account.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "tablet-sidebar-account").count, 1)
        XCTAssertTrue(account.isHittable, "The account must remain visible even with a long sidebar.")
        XCTAssertLessThan(app.frame.maxY - account.frame.maxY, 100, "The account belongs in the fixed bottom bar.")
        let originalFrame = account.frame
        let search = app.cells["magnifyingglass"].firstMatch
        XCTAssertTrue(search.isHittable)
        let sidebar = app.collectionViews.firstMatch
        XCTAssertTrue(sidebar.exists)
        XCTAssertLessThan(sidebar.frame.maxX, app.frame.width / 2)
        sidebar.swipeUp()
        sidebar.swipeUp()
        XCTAssertFalse(search.isHittable, "The sidebar categories must actually scroll for this check.")
        XCTAssertTrue(account.isHittable)
        XCTAssertEqual(account.frame.minY, originalFrame.minY, accuracy: 1.5)
        XCTAssertEqual(account.frame.maxY, originalFrame.maxY, accuracy: 1.5)
        capture("ipad-landscape-sidebar-scrolled", app: app)
        account.tap()
        XCTAssertTrue(app.navigationBars["MeloX"].waitForExistence(timeout: 10))
    }

    func testToplistKeepsTracksVisibleInBothOrientations() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch()
        let chart = app.buttons["home-action-hotSongs"]
        XCTAssertTrue(chart.waitForExistence(timeout: 20))
        chart.tap()
        let firstTrack = app.buttons["collection-track-901000"]
        XCTAssertTrue(firstTrack.waitForExistence(timeout: 20))
        XCTAssertTrue(firstTrack.isHittable, "The first track must be visible without scrolling past the cover.")
        let artwork = app.descendants(matching: .any)["collection-detail-artwork"].firstMatch
        XCTAssertTrue(artwork.exists)
        XCTAssertLessThanOrEqual(artwork.frame.width, 340)
        XCTAssertLessThan(artwork.frame.maxY, firstTrack.frame.minY, "Tracks should span the page below the artwork and metadata.")
        let share = app.buttons["collection-toolbar-share"]
        let more = app.buttons["collection-toolbar-more"]
        XCTAssertTrue(share.exists && more.exists)
        XCTAssertEqual(share.frame.midY, more.frame.midY, accuracy: 1.5)
        XCTAssertEqual(share.frame.height, more.frame.height, accuracy: 1.5)
        Thread.sleep(forTimeInterval: 2)
        capture("ipad-landscape-toplist", app: app)

        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 3)
        XCTAssertTrue(firstTrack.isHittable)
        XCTAssertLessThanOrEqual(artwork.frame.width, 340)
        capture("ipad-portrait-toplist", app: app)
    }

    func testExploreFeaturedShelfLeavesRoomForMorePlaylists() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch()
        let discover = app.cells["safari"].firstMatch
        XCTAssertTrue(discover.waitForExistence(timeout: 20))
        discover.tap()
        let featured = app.descendants(matching: .any)["explore-featured-902000"].firstMatch
        let nextFeatured = app.descendants(matching: .any)["explore-featured-902001"].firstMatch
        let gridCard = app.descendants(matching: .any)["explore-grid-902004"].firstMatch
        XCTAssertTrue(featured.waitForExistence(timeout: 20))
        XCTAssertLessThanOrEqual(featured.frame.width, 300)
        XCTAssertLessThanOrEqual(featured.frame.height, 390)
        XCTAssertTrue(nextFeatured.isHittable, "The iPad should display a row of feature cards.")
        XCTAssertTrue(gridCard.isHittable, "The next section must remain visible without scrolling past the feature.")
        assertExploreRowsAlign(app: app)
        Thread.sleep(forTimeInterval: 2)
        capture("ipad-landscape-discover", app: app)

        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 3)
        XCTAssertLessThanOrEqual(featured.frame.height, 390)
        XCTAssertTrue(gridCard.isHittable)
        assertExploreRowsAlign(app: app)
        capture("ipad-portrait-discover", app: app)
    }
}
