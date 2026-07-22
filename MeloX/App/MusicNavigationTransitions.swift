import SwiftUI

private struct MusicNavigationNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var musicNavigationNamespace: Namespace.ID? {
        get { self[MusicNavigationNamespaceKey.self] }
        set { self[MusicNavigationNamespaceKey.self] = newValue }
    }
}

extension View {
    func musicMatchedTransitionSource(for route: MusicRoute) -> some View {
        modifier(MusicMatchedTransitionSourceModifier(route: route))
    }

    func musicNavigationTransition(
        for route: MusicRoute,
        in namespace: Namespace.ID
    ) -> some View {
        modifier(
            MusicNavigationTransitionModifier(
                route: route,
                namespace: namespace
            )
        )
    }
}

private struct MusicMatchedTransitionSourceModifier: ViewModifier {
    let route: MusicRoute

    @Environment(\.musicNavigationNamespace) private var namespace

    @ViewBuilder
    func body(content: Content) -> some View {
        if route.usesCardExpansionTransition, let namespace {
            content.matchedTransitionSource(
                id: route.transitionID,
                in: namespace
            )
        } else {
            content
        }
    }
}

private struct MusicNavigationTransitionModifier: ViewModifier {
    let route: MusicRoute
    let namespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        if route.usesCardExpansionTransition {
            content.navigationTransition(
                .zoom(sourceID: route.transitionID, in: namespace)
            )
        } else {
            content
        }
    }
}

