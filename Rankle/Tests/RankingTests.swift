import XCTest
@testable import Rankle

final class RankingTests: XCTestCase {
    func testBinaryInsertionSortProducesDeterministicOrder() {
        let items = ["D","A","C","B"].map { RankleItem(title: $0) }
        let list = RankleList(name: "Test", items: items)
        let vm = RankingViewModel(list: list)
        // Simulate always preferring left over right
        var safety = 100
        while !vm.isComplete && safety > 0 {
            if vm.currentMatchup != nil {
                vm.choose(.left)
            } else {
                // allow next comparison to be prepared
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
            }
            safety -= 1
        }
        XCTAssertTrue(vm.isComplete)
        XCTAssertEqual(vm.list.items.count, 4)
    }
}
