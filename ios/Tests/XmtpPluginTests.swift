import Flutter
import UIKit
import XCTest

@testable import xmtp_plugin

class XmtpPluginTests: XCTestCase {

  func testGetPlatformVersion() {
    let plugin = XmtpPlugin()

    let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: nil)

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertEqual(result as! String, "iOS " + UIDevice.current.systemVersion)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testGeneratePrivateKey() {
    let plugin = XmtpPlugin()

    let call = FlutterMethodCall(methodName: "generatePrivateKey", arguments: nil)

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      // Should return FlutterStandardTypedData containing private key bytes
      XCTAssertTrue(result is FlutterStandardTypedData, "Should return private key data")
      let keyData = result as! FlutterStandardTypedData
      XCTAssertEqual(keyData.data.count, 32, "Private key should be 32 bytes")
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  func testClientNotInitializedError() {
    let plugin = XmtpPlugin()

    let call = FlutterMethodCall(methodName: "getClientAddress", arguments: nil)

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertTrue(result is FlutterError, "Should return FlutterError when client not initialized")
      let error = result as! FlutterError
      XCTAssertEqual(error.code, "CLIENT_NOT_INITIALIZED")
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testInvalidMethodCall() {
    let plugin = XmtpPlugin()

    let call = FlutterMethodCall(methodName: "nonExistentMethod", arguments: nil)

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertEqual(result as! FlutterMethodNotImplemented, FlutterMethodNotImplemented)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }
}