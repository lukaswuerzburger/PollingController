//
//  PollingControllerTests.swift
//  PollingControllerTests
//
//  Created by Lukas Würzburger on 8/13/20.
//  Copyright © 2020 Lukas Würzburger. All rights reserved.
//

import XCTest
@testable import PollingController

class PollingControllerTests: XCTestCase {

    func testTakesArguments() {
        let polling = PollingController(interval: 4) { _ in }
        XCTAssertEqual(polling.interval, 4)
        XCTAssertNotNil(polling.handler)
    }

    func testIsRunningRepresentsBehavior() {
        let polling = PollingController() { _ in }
        XCTAssert(polling.state == .idle)
        polling.start()
        XCTAssertTrue(polling.isRunning)
        polling.stop()
        XCTAssertFalse(polling.isRunning)
    }

    func testIsCallingCallbackAtLeastSevenTimes() {
        let expect = expectation(description: "polling to be called seven times")
        expect.expectedFulfillmentCount = 7
        var polling: PollingController!
        polling = PollingController(interval: 0.1) { callback in
            callback()
            expect.fulfill()
        }
        polling.start()
        wait(for: [expect], timeout: 1)
    }

    func testBelatedCallbackContinuesPolling() {
        let expectStoppedTimer = expectation(description: "expect stopped timer")
        let expectRestartedTimerAfterCallback = expectation(description: "expect restarted timer after callback")
        expectRestartedTimerAfterCallback.expectedFulfillmentCount = 2
        var count = 0
        var polling: PollingController!
        polling = PollingController(interval: 0.1) { callback in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                count += 1
                callback()
                if count == 1 {
                    XCTAssertTrue(polling.isRunning)
                    XCTAssertEqual(polling.state, .waitingWithActiveTimerForHandlerCallingBack)
                    XCTAssertNotNil(polling.timer)
                    polling.stop()
                } else if count == 2 {
                    XCTAssertFalse(polling.isRunning)
                    XCTAssertEqual(polling.state, .idle)
                    XCTAssertNil(polling.timer)
                }
                expectRestartedTimerAfterCallback.fulfill()
            }
        }
        XCTAssertEqual(polling.state, .idle)
        polling.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertNil(polling.timer)
            XCTAssertTrue(polling.isRunning)
            XCTAssertEqual(polling.state, .waitingWithInactiveTimerForHandlerCallingBack)
            expectStoppedTimer.fulfill()
        }
        XCTAssertTrue(polling.isRunning)
        XCTAssertEqual(polling.state, .waitingWithActiveTimerForHandlerCallingBack)
        wait(for: [expectStoppedTimer, expectRestartedTimerAfterCallback], timeout: 1)
    }

    func testCanNotStartPollingWithActiveTimer() {
        let polling = PollingController(interval: 4) { _ in }
        polling.start()
        let timer = polling.timer
        polling.start()
        XCTAssertEqual(timer, polling.timer)
    }

    func testReactivatesTimerAfterBelatedCallback() {
        let polling = PollingController(interval: 0.02) { callback in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                callback()
            }
        }
        polling.start()
        let timer = polling.timer
        let expectTimerToInvalidateAndReassign = expectation(description: "timer to invalidate and reassign")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertNotEqual(timer, polling.timer)
            XCTAssertNotNil(polling.timer)
            expectTimerToInvalidateAndReassign.fulfill()
        }
        wait(for: [expectTimerToInvalidateAndReassign], timeout: 1)
    }
}
