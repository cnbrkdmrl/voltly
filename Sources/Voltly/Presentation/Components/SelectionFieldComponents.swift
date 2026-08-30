import SwiftUI

public struct SelectionFieldButton: View {
    private let title: String
    private let value: String
    private let placeholder: String
    private let action: () -> Void

    public init(
        title: String,
        value: String,
        placeholder: String = "Sec",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.value = value
        self.placeholder = placeholder
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Haptics.softImpact()
                action()
            } label: {
                HStack(spacing: 8) {
                    Text(displayValue)
                        .foregroundStyle(hasSelection ? .primary : .secondary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 12)
                .background(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.publicACColor.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private var hasSelection: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayValue: String {
        hasSelection ? value : placeholder
    }
}

public struct OptionSelectionSheet<Option: Hashable>: View {
    private let title: String
    private let options: [Option]
    private let selected: Option
    private let label: (Option) -> String
    private let onSelect: (Option) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentSelection: Option

    public init(
        title: String,
        options: [Option],
        selected: Option,
        label: @escaping (Option) -> String,
        onSelect: @escaping (Option) -> Void
    ) {
        self.title = title
        self.options = options
        self.selected = selected
        self.label = label
        self.onSelect = onSelect
        _currentSelection = State(initialValue: selected)
    }

    public var body: some View {
        NavigationStack {
            sheetContent
                .navigationTitle(title)
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .voltlyPrimaryAction) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
                #endif
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    @ViewBuilder
    private var sheetContent: some View {
        #if os(iOS)
        VStack(spacing: 0) {
            Picker(title, selection: $currentSelection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()

            Button("Seç") {
                Haptics.softImpact()
                onSelect(currentSelection)
                dismiss()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.publicACColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .onChange(of: currentSelection) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Haptics.selection()
        }
        #else
        List(options, id: \.self) { option in
            Button {
                onSelect(option)
                dismiss()
            } label: {
                HStack {
                    Text(label(option))
                        .foregroundStyle(.primary)
                    Spacer()
                    if option == selected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(AppTheme.publicACColor)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        #endif
    }
}

#if DEBUG
struct SelectionFieldComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            SelectionFieldButton(
                title: "Marka",
                value: "Tesla",
                action: {}
            )
            SelectionFieldButton(
                title: "Model",
                value: "",
                placeholder: "Marka sec",
                action: {}
            )
        }
        .padding()
        .background(AppTheme.surface)
    }
}
#endif
