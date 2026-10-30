import WidgetKit
import SwiftUI

@main
struct JoltWidgetBundle: WidgetBundle {
    var body: some Widget {
        JoltWidget()
        JoltListWidget()
    }
}
