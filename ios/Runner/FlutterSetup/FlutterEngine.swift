import Foundation

class MeditoFlutterEngine {
    static var shared: FlutterEngine? = {
        let result = FlutterEngine.init(
            name: "medito_flutter_engine",
            project: nil,
            allowHeadlessExecution: true
        )
        
        result.run()
        return result
    }()
}
