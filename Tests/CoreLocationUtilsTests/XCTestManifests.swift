import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(OneTimeLocationTest.allTests),
    ]
}
#endif
