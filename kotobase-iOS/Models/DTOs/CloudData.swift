import Foundation

/// 從雲端下載資料的容器
struct CloudData {
    let words: [WordDTO]
    let categoriesRaw: [String: Any]?
}
