import SwiftUI

struct SliderWidgetView: View {

    let rootWidgetID: String
    let minValue: Double
    let maxValue: Double
    let step: Double
    let externalValue: Double
    let tint: Color
    let width: CGFloat?

    @State private var value: Double
    @State private var isEditing = false

    init(
        rootWidgetID: String,
        minValue: Double,
        maxValue: Double,
        step: Double,
        value: Double,
        tint: Color,
        width: CGFloat? = nil
    ) {
        self.rootWidgetID = rootWidgetID
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.externalValue = value
        self.tint = tint
        self.width = width
        _value = State(initialValue: value)
    }

    var body: some View {
        Slider(
            value: Binding(
                get: { value },
                set: { newValue in
                    value = newValue

                    EventBus.shared.emitWidgetEvent(
                        .sliderPreview,
                        widgetID: rootWidgetID,
                        value: newValue
                    )
                }
            ),
            in: minValue...maxValue,
            step: max(step, 0.0001),
            onEditingChanged: { editing in
                isEditing = editing

                if !editing {
                    EventBus.shared.emitWidgetEvent(
                        .sliderChanged,
                        widgetID: rootWidgetID,
                        value: value
                    )
                }
            }
        )
        .tint(tint)
        .frame(width: resolvedWidth)
        .onChange(of: externalValue) { _, newValue in
            if !isEditing {
                value = newValue
            }
        }
    }

    private var resolvedWidth: CGFloat {
        SliderWidthResolver.resolve(
            explicitWidth: width,
            rootWidgetID: rootWidgetID,
            fallback: 140
        )
    }
}
