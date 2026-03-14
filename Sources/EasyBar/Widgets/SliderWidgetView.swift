import SwiftUI

struct SliderWidgetView: View {

    let rootWidgetID: String
    let minValue: Double
    let maxValue: Double
    let step: Double
    let tint: Color

    @State private var value: Double

    init(
        rootWidgetID: String,
        minValue: Double,
        maxValue: Double,
        step: Double,
        value: Double,
        tint: Color
    ) {
        self.rootWidgetID = rootWidgetID
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.tint = tint
        _value = State(initialValue: value)
    }

    var body: some View {
        Slider(
            value: Binding(
                get: { value },
                set: { newValue in
                    value = newValue

                    EventBus.shared.emitWidgetEvent(
                        "slider.preview",
                        widgetID: rootWidgetID,
                        data: [
                            "value": String(Int(newValue.rounded()))
                        ]
                    )
                }
            ),
            in: minValue...maxValue,
            step: step,
            onEditingChanged: { editing in
                if !editing {
                    EventBus.shared.emitWidgetEvent(
                        "slider.changed",
                        widgetID: rootWidgetID,
                        data: [
                            "value": String(Int(value.rounded()))
                        ]
                    )
                }
            }
        )
        .tint(tint)
        .frame(width: 140)
    }
}
