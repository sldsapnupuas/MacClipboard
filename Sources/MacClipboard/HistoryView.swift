import SwiftUI

final class PanelState: ObservableObject {
    @Published var selectedIndex = 0
}

struct HistoryView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var state: PanelState

    var onSelect: (ClipboardItem) -> Void
    var onDelete: (ClipboardItem) -> Void
    var onPin: (ClipboardItem) -> Void
    var onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.items.isEmpty {
                emptyState
            } else {
                list
            }
            Divider()
            footer
        }
        .frame(width: 380, height: 440)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.15))
        )
    }

    private var header: some View {
        HStack {
            Text("Clipboard History")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button("Clear all", action: onClear)
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Nothing here yet")
                .foregroundStyle(.secondary)
            Text("Copy something (⌘C) and it will show up here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                        ItemRow(
                            item: item,
                            index: index,
                            isSelected: index == state.selectedIndex,
                            onSelect: { onSelect(item) },
                            onDelete: { onDelete(item) },
                            onPin: { onPin(item) }
                        )
                        .id(item.id)
                    }
                }
                .padding(6)
            }
            .onChange(of: state.selectedIndex) { newIndex in
                guard store.items.indices.contains(newIndex) else { return }
                proxy.scrollTo(store.items[newIndex].id)
            }
        }
    }

    private var footer: some View {
        Text("↑↓ navigate   ↩ paste   1–9 quick paste   P pin   ⌫ delete   esc close")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
    }
}

private struct ItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    var onSelect: () -> Void
    var onDelete: () -> Void
    var onPin: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if index < 9 {
                Text("\(index + 1)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12, alignment: .trailing)
                    .padding(.top, 3)
            } else {
                Spacer().frame(width: 12)
            }

            content

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    if isHovered || item.pinned {
                        Button(action: onPin) {
                            Image(systemName: item.pinned ? "pin.fill" : "pin")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(item.pinned ? Color.accentColor : .secondary)
                        .help(item.pinned ? "Unpin" : "Pin")
                    }
                    if isHovered {
                        Button(action: onDelete) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Delete")
                    }
                }
                Text(item.date, format: Date.RelativeFormatStyle(presentation: .named, unitsStyle: .narrow))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.25)
                      : isHovered ? Color.primary.opacity(0.06)
                      : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            Text(item.preview)
                .font(.system(size: 12))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .image:
            if let data = item.imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 64, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Label("Image", systemImage: "photo")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
