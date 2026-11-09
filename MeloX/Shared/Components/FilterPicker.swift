import SwiftUI

struct FilterPicker<Selection: Hashable, Options: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: LocalizedStringKey
    @Binding var selection: Selection
    var maximumWidth: CGFloat = 480
    var usesMenu = false
    @ViewBuilder let options: () -> Options

    var body: some View {
        let picker = Picker(title, selection: $selection, content: options)

        Group {
            if usesMenu || dynamicTypeSize.isAccessibilitySize {
                picker.pickerStyle(.menu)
            } else {
                picker.pickerStyle(.segmented)
            }
        }
        .controlSize(.large)
        .frame(maxWidth: maximumWidth, minHeight: 44, alignment: .leading)
    }
}
