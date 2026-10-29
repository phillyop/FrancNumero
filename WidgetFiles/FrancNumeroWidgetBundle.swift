import SwiftUI
import WidgetKit

@main
struct FrancNumeroWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayPageWidget()
        NumberWidget()
        TableauWidget()
    }
}
