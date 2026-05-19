import SwiftUI
import SwiftData

/// アプリのルートビュー
/// - Note: タブバーで各機能画面を切り替える
struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                CategoryListView()
            }
            .tabItem {
                Label("分類", systemImage: "folder")
            }

            APITestView()
                .tabItem {
                    Label("API 測試", systemImage: "ladybug")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Category.self, inMemory: true)
}
