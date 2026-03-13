import Foundation
import SwiftUI

final class WidgetStore: ObservableObject {

    static let shared = WidgetStore()

    @Published private(set) var widgets: [WidgetState] = []

    private var state: [String: WidgetState] = [:]

    func apply(_ updates: [WidgetState]) {

        var changed = false

        for widget in updates {
            if state[widget.id] != widget {
                state[widget.id] = widget
                changed = true
            }
        }

        guard changed else { return }

        render()
    }

    func clear() {
        state.removeAll()

        DispatchQueue.main.async {
            self.widgets = []
        }
    }

    private func render() {

        let sorted = state.values.sorted {

            if $0.position == $1.position {
                if $0.order == $1.order {
                    return $0.id < $1.id
                }
                return $0.order < $1.order
            }

            return $0.position < $1.position
        }

        DispatchQueue.main.async {
            withAnimation(.linear(duration: 0.08)) {
                self.widgets = sorted
            }
        }
    }
}
