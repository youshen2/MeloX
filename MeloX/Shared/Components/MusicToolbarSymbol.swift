import SwiftUI

/// Give different SF Symbols the same centered canvas inside native toolbars.
struct MusicToolbarSymbol: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 18, weight: .regular))
            .imageScale(.medium)
            .frame(width: 26, height: 26, alignment: .center)
            .accessibilityHidden(true)
    }
}
