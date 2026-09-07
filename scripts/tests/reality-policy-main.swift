import XCTest
import Darwin

// Executes the same pure-policy XCTest methods compiled into the iPhoneOS test bundle.
// This checks policy behavior, not ARKit, rendering, or physical-device acceptance.
@main
enum RealityPolicyTests {
    static func main() {
        let suite = XCTestSuite(name: "Reality host policies")
        suite.addTest(RealityScanTelemetryTests.defaultTestSuite)
        suite.addTest(RealityTargetPreviewTests.defaultTestSuite)
        suite.addTest(RealityWalkRouteTests.defaultTestSuite)
        suite.addTest(RealityWalkTimelineTests.defaultTestSuite)
        suite.addTest(PigOcclusionSamplerTests.defaultTestSuite)
        suite.addTest(OcclusionSampleStateTests.defaultTestSuite)
        suite.addTest(StableHideMonitorTests.defaultTestSuite)
        suite.addTest(RealityRevealMonitorObservationTests.defaultTestSuite)
        suite.run()
        guard let result = suite.testRun, result.executionCount > 0 else { exit(2) }
        print("Host policy XCTest: \(result.executionCount) executed, \(result.totalFailureCount) failures")
        exit(result.totalFailureCount == 0 ? 0 : 1)
    }
}
