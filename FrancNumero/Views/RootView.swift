import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0

    var body: some View {
        ZStack {
            TabView(selection: $tab) {
                HomeView(openTableau: { tab = 1 })
                    .tabItem { Label("Today", systemImage: "pencil.line") }
                    .tag(0)
                TableauView()
                    .tabItem { Label("Tableau", systemImage: "square.grid.3x3.fill") }
                    .tag(1)
                CahierView()
                    .tabItem { Label("Cahier", systemImage: "books.vertical.fill") }
                    .tag(2)
            }
            .tint(Palette.ink)
            .fullScreenCover(item: $store.lessonRequest) { request in
                LessonFlowView(request: request)
                    .environmentObject(store)
            }
        }
        .fullScreenCover(isPresented: needsOnboarding) {
            OnboardingView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshDay()
                store.scheduleNotifications()
                store.refreshWidgets()
            }
        }
        .onOpenURL { url in
            handle(url)
        }
        .task {
            await store.syncNotifications()
        }
    }

    /// Where a widget tap lands.
    private func handle(_ url: URL) {
        guard store.data.hasOnboarded, let target = WidgetLink.parse(url) else { return }
        switch target {
        case .today:
            tab = 0
        case .lesson:
            tab = 0
            if store.lessonRequest == nil { store.lessonRequest = LessonRequest() }
        case .tableau:
            tab = 1
        case .cahier:
            tab = 2
        case .number(let n):
            tab = 1
            store.pendingNumber = n
        }
    }

    private var needsOnboarding: Binding<Bool> {
        Binding(
            get: { !store.data.hasOnboarded },
            set: { _ in }
        )
    }
}
