import SwiftUI
import SwiftData

/// アプリのルートビュー
/// - Note: タブバーで各機能画面を切り替える
struct ContentView: View {
    var body: some View {
        NavigationStack {
            CategoryListView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Category.self, inMemory: true)
}
