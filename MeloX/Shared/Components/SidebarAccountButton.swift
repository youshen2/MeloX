import SwiftUI
import UIKit

/// Keep the sidebar account accessible when SwiftUI hosts the bottom bar in a native toolbar.
struct SidebarAccountButton<Label: View>: UIViewRepresentable {
    let accessibilityLabel: String
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    func makeUIView(context: Context) -> SidebarAccountControl<Label> {
        SidebarAccountControl(label: label())
    }

    func updateUIView(_ control: SidebarAccountControl<Label>, context: Context) {
        control.update(label: label(), accessibilityLabel: accessibilityLabel, action: action)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: SidebarAccountControl<Label>,
        context: Context
    ) -> CGSize? {
        let width = proposal.width.flatMap { $0.isFinite ? max($0, 0) : nil } ?? 280
        let contentSize = uiView.hostingController.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(contentSize.height, 44))
    }
}

final class SidebarAccountControl<Label: View>: UIControl {
    let hostingController: UIHostingController<Label>
    private var action: (() -> Void)?
    private weak var accessibilityToolbar: UIToolbar?

    init(label: Label) {
        hostingController = UIHostingController(rootView: label)
        super.init(frame: .zero)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityIdentifier = "tablet-sidebar-account"
        accessibilityTraits = .button
        let content = hostingController.view!
        content.backgroundColor = .clear
        content.isUserInteractionEnabled = false
        content.accessibilityElementsHidden = true
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        addAction(UIAction { [weak self] _ in self?.action?() }, for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func update(label: Label, accessibilityLabel: String, action: @escaping () -> Void) {
        hostingController.rootView = label
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func accessibilityActivate() -> Bool {
        action?()
        return action != nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateToolbarAccessibility()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateToolbarAccessibility()
    }

    private func updateToolbarAccessibility() {
        var ancestor = superview
        var toolbar: UIToolbar?
        while let view = ancestor {
            if let candidate = view as? UIToolbar {
                toolbar = candidate
                break
            }
            ancestor = view.superview
        }
        if accessibilityToolbar !== toolbar {
            accessibilityToolbar?.accessibilityElements?.removeAll {
                ($0 as? UIView) === self
            }
            accessibilityToolbar = toolbar
        }
        guard window != nil, let toolbar else { return }
        // Native sidebar toolbars may omit custom hosted content from their item list.
        // Append this control while preserving any other native accessibility items.
        var elements = toolbar.accessibilityElements ?? []
        if !elements.contains(where: { ($0 as? UIView) === self }) {
            elements.append(self)
            toolbar.accessibilityElements = elements
        }
    }
}
