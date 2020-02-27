import Foundation

func assertMainThread(_ file: StaticString = #file, line: UInt = #line) {
    assert(Thread.isMainThread, "\(file):\(line) must run on the main thread!")
}
