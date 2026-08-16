import XCTest
@testable import macTablaPro

final class SPSCRingBufferTests: XCTestCase {

    func testRingBufferPushPopBasic() {
        let buffer = SPSCRingBuffer<Int>(capacity: 4)
        XCTAssertEqual(buffer.count, 0)
        XCTAssertNil(buffer.pop())

        XCTAssertTrue(buffer.push(10))
        XCTAssertTrue(buffer.push(20))
        XCTAssertEqual(buffer.count, 2)
        XCTAssertEqual(buffer.peek(), 10)

        XCTAssertEqual(buffer.pop(), 10)
        XCTAssertEqual(buffer.pop(), 20)
        XCTAssertNil(buffer.pop())
        XCTAssertEqual(buffer.count, 0)
    }

    func testRingBufferCapacityOverflow() {
        let buffer = SPSCRingBuffer<String>(capacity: 4)

        XCTAssertTrue(buffer.push("A"))
        XCTAssertTrue(buffer.push("B"))
        XCTAssertTrue(buffer.push("C"))
        XCTAssertTrue(buffer.push("D"))
        XCTAssertEqual(buffer.count, 4)

        // 5th push should fail as buffer is full
        XCTAssertFalse(buffer.push("E"))
        XCTAssertEqual(buffer.count, 4)

        XCTAssertEqual(buffer.pop(), "A")
        XCTAssertEqual(buffer.count, 3)

        // Now push should succeed
        XCTAssertTrue(buffer.push("E"))
        XCTAssertEqual(buffer.count, 4)
    }

    func testRingBufferWrapAroundMasking() {
        let buffer = SPSCRingBuffer<Int>(capacity: 4)

        for i in 0..<100 {
            XCTAssertTrue(buffer.push(i))
            XCTAssertEqual(buffer.pop(), i)
        }

        XCTAssertEqual(buffer.count, 0)
        XCTAssertNil(buffer.pop())
    }

    func testRingBufferClear() {
        let buffer = SPSCRingBuffer<String>(capacity: 8)
        buffer.push("1")
        buffer.push("2")
        buffer.push("3")
        XCTAssertEqual(buffer.count, 3)

        buffer.clear()
        XCTAssertEqual(buffer.count, 0)
        XCTAssertNil(buffer.pop())
    }

    func testVisualBeatEventCreation() {
        let event = VisualBeatEvent(
            matra: 1,
            subStep: 0,
            bolName: "Dha",
            taalSymbol: "X",
            targetHostTime: 123456789
        )
        XCTAssertEqual(event.matra, 1)
        XCTAssertEqual(event.bolName, "Dha")
        XCTAssertEqual(event.taalSymbol, "X")
        XCTAssertEqual(event.targetHostTime, 123456789)

        let subPulseEvent = VisualBeatEvent(
            matra: 1,
            subStep: 1,
            bolName: nil,
            taalSymbol: "X",
            targetHostTime: 123456999
        )
        XCTAssertNil(subPulseEvent.bolName)
    }

    @MainActor
    func testCoreAudioLatencyQuery() {
        let latency = VisualPresentationEngine.detectCoreAudioOutputLatencyMs()
        XCTAssertGreaterThanOrEqual(latency, 0.0)
    }
}
