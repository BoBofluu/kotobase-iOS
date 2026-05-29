import SwiftUI
import SwiftData

/// アプリのルートビュー
struct ContentView: View {
    var body: some View {
        TabView {
            AddNoteView()
                .tabItem { Label("輸入", systemImage: "plus.square") }

            NoteListPlaceholderView()
                .tabItem { Label("清單", systemImage: "list.bullet") }

            SettingsPlaceholderView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .tint(.brandCyan)
        .dismissKeyboardOnTapOutside()
    }
}

private struct NoteListPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("清單", systemImage: "list.bullet", description: Text("建構中"))
                .navigationTitle("清單")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("設定", systemImage: "gearshape", description: Text("建構中"))
                .navigationTitle("設定")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Category.self, Subcategory.self, Word.self, NoteImage.self, PaletteColor.self], inMemory: true)
}
