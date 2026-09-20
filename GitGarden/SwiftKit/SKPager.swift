import SwiftUI

enum SKPaging {
    static let pageSize = 40

    static func pageCount(total: Int, pageSize: Int = pageSize) -> Int {
        max(1, Int(ceil(Double(max(total, 0)) / Double(max(pageSize, 1)))))
    }

    static func slice<T>(_ items: [T], page: Int, pageSize: Int = pageSize) -> [T] {
        let pages = pageCount(total: items.count, pageSize: pageSize)
        let safe = min(max(page, 0), pages - 1)
        let start = safe * pageSize
        guard start < items.count else { return [] }
        return Array(items[start..<min(start + pageSize, items.count)])
    }
}

struct SKPagerBar: View {
    @Binding var page: Int
    var total: Int
    var pageSize: Int = SKPaging.pageSize
    var noun: String = "items"

    private var pages: Int { SKPaging.pageCount(total: total, pageSize: pageSize) }

    var body: some View {
        if total > pageSize {
            HStack(spacing: 10) {
                SKQuietButton(title: "Previous") {
                    page = max(0, page - 1)
                }
                .disabled(page <= 0)
                Text("\(min(page + 1, pages)) / \(pages) · \(total) \(noun)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
                SKQuietButton(title: "Next") {
                    page = min(pages - 1, page + 1)
                }
                .disabled(page >= pages - 1)
                Spacer()
            }
        }
    }
}
