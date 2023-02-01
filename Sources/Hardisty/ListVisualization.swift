
import Keystone
import Toolbox
import SwiftUI
import Uncharted

public struct ListVisualization: View {
    /// The chart name.
    let name: String
    
    /// The configuration.
    let config: HardistyConfig
    
    /// The aggregator this visualization is for.
    let aggregator: AnyGroupingAggregator
    
    /// The default number of visible values.
    let visibleValuesLimit: Int
    
    /// Formatter function for a date.
    let formatEventData: (KeystoneEventData) -> String
    
    /// The grouped values.
    let values: [(String, Int)]
    
    /// Whether or not all data is shown.
    @State var showAll: Bool = false
    
    /// The number of visible values.
    var visibleValueCount: Int {
        showAll ? values.count : min(values.count, visibleValuesLimit)
    }
    
    /// Default initializer.
    public init(name: String,
                config: HardistyConfig,
                aggregator: AnyGroupingAggregator,
                visibleValuesLimit: Int = 10,
                formatEventData: @escaping (KeystoneEventData) -> String) {
        self.name = name
        self.config = config
        self.aggregator = aggregator
        self.formatEventData = formatEventData
        self.visibleValuesLimit = visibleValuesLimit
        self.values = aggregator.valueCountsByGroup
            .map { (formatEventData($0.key), $0.value )}
            .sorted { $0.1 >= $1.1 }
    }
    
    public var body: some View {
        Section {
            ForEach(0..<visibleValueCount, id: \.self) { i in
                HStack {
                    Text(verbatim: values[i].0)
                    Spacer()
                    Text(verbatim: "\(values[i].1)").foregroundColor(.secondary)
                }
            }
        } header: {
            HStack {
                Text(verbatim: self.name)
                Spacer()
                
                if values.count > visibleValuesLimit {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(showAll ? 90 : 0))
                        .animation(.easeInOut(duration: 0.1), value: showAll)
                        .onTapGesture {
                            self.showAll.toggle()
                        }
                }
            }
        }
    }
}
