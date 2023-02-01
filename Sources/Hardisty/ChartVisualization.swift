
import Keystone
import Toolbox
import SwiftUI
import Uncharted

internal func createChartData(sortedData: [(String, Int)],
                              config: HardistyConfig,
                              tapActions: [ChartTapAction],
                              scrollingBehaviour: ChartScrollingBehaviour? = nil) -> (ChartData, ChartConfig) {
    let labels = sortedData.map { $0.0 }
    let values = sortedData.map { $0.1 }
    
    let scrolling: ChartScrollingBehaviour
    if let scrollingBehaviour {
        scrolling = scrollingBehaviour
    }
    else if values.count <= 5 {
        scrolling = .noScrolling
    }
    else {
        scrolling = .segmented(visibleValueRange: 4)
    }
    
    let scrollToEnd: Bool
    if case .chart(let scrollToEnd_) = config.detail {
        scrollToEnd = scrollToEnd_
    }
    else {
        scrollToEnd = false
    }
    
    let chartConfig = ChartConfig(
        xAxisConfig: .xAxis(title: "X",
                            visible: true,
                            baseline: .minimumValue,
                            topline: .maximumValue,
                            step: .fixed(1),
                            scrollingBehaviour: scrolling,
                            labelFormatter: CustomDataFormatter { value in
                                if value.rounded(.toNearestOrEven).isEqual(to: value) {
                                    return labels.tryGet(Int(value.rounded(.down))) ?? ""
                                }
                                else {
                                    return ""
                                }
                            }),
        yAxisConfig: .yAxis(title: "Y",
                            visible: true,
                            baseline: .zero,
                            topline: .maximumValue,
                            step: .automatic(),
                            labelFormatter: FloatingPointFormatter.standard),
        tapActions: tapActions,
        initialXValue: scrollToEnd ? Double(values.count-1) : nil,
        noDataAvailableText: "No Data")
    
    let chartData = ChartData(config: chartConfig, series: [
        .init(name: "Data",
              yValues: values.map { Double($0) },
              color: .solid(config.accentColor),
              pointStyle: .standard(color: config.accentColor),
              lineStyle: .straight(color: config.accentColor))
    ])
    
    return (chartData, chartConfig)
}

fileprivate struct AnyChartVisualization<Content: View>: View {
    /// The chart name.
    let name: String
    
    /// The configuration.
    let config: HardistyConfig
    
    /// The aggregator this visualization is for.
    let aggregator: AnyGroupingAggregator
    
    /// Formatter function for a data value.
    let formatEventData: (KeystoneEventData) -> String
    
    /// The chart builder.
    let buildChart: (ChartData) -> Content
    
    /// The chart data.
    @State var chartData: ChartData? = nil
    
    /// The chart config.
    @State var chartConfig: ChartConfig? = nil
    
    /// The currently selected value.
    @State var selectedDataPoint: DataPoint? = nil
    
    /// Default initializer.
    public init(name: String,
                config: HardistyConfig,
                aggregator: AnyGroupingAggregator,
                formatEventData: @escaping (KeystoneEventData) -> String,
                @ViewBuilder buildChart: @escaping (ChartData) -> Content) {
        self.name = name
        self.config = config
        self.aggregator = aggregator
        self.formatEventData = formatEventData
        self.buildChart = buildChart
    }
    
    public var body: some View {
        Section {
            VStack {
                HStack {
                    Spacer()
                    if let selectedDataPoint, let chartConfig {
                        let label = chartConfig.xAxisConfig.labelFormatter(selectedDataPoint.x)
                        let value = chartConfig.yAxisConfig.labelFormatter(selectedDataPoint.y)
                        
                        Text(verbatim: label)
                        Image(systemName: "circle.fill").font(.system(size: 5)).opacity(0.75)
                        Text(verbatim: value)
                    }
                    else {
                        Text(verbatim: " ")
                    }
                    
                    Spacer()
                }
                .font(.headline)
                .foregroundColor(.init(uiColor: .secondaryLabel))
                
                if let chartData {
                    buildChart(chartData)
                        .frame(height: 175)
                        .padding(.horizontal, 10)
                }
            }
        } header: {
            Text(verbatim: self.name)
        }
        .onAppear {
            let sortedData = aggregator.valueCountsByGroup.map { (formatEventData($0.key), $0.value) }.sorted { $0.1 > $1.1 }
            let (chartData, chartConfig) = createChartData(sortedData: sortedData, config: config, tapActions: [
                .highlightSingle,
                .custom { series, pt in
                    if let selectedDataPoint {
                        if selectedDataPoint == pt {
                            self.selectedDataPoint = nil
                            return
                        }
                    }
                    
                    self.selectedDataPoint = pt
                }
            ])
            
            self.chartData = chartData
            self.chartConfig = chartConfig
        }
    }
}

public struct LineChartVisualization: View {
    /// The chart name.
    let name: String
    
    /// The configuration.
    let config: HardistyConfig
    
    /// The aggregator this visualization is for.
    let aggregator: AnyGroupingAggregator
    
    /// Formatter function for a data value.
    let formatEventData: (KeystoneEventData) -> String

    /// Default initializer.
    public init(name: String,
                config: HardistyConfig,
                aggregator: AnyGroupingAggregator,
                formatEventData: @escaping (KeystoneEventData) -> String) {
        self.name = name
        self.config = config
        self.aggregator = aggregator
        self.formatEventData = formatEventData
    }
    
    public var body: some View {
        AnyChartVisualization(name: name, config: config, aggregator: aggregator, formatEventData: formatEventData) {
            let data = ChartData(config: LineChartConfig(config: $0.config), series: $0.series)
            LineChart(data: data)
        }
    }
}

public struct BarChartVisualization: View {
    /// The chart name.
    let name: String
    
    /// The configuration.
    let config: HardistyConfig
    
    /// The aggregator this visualization is for.
    let aggregator: AnyGroupingAggregator
    
    /// Formatter function for a data value.
    let formatEventData: (KeystoneEventData) -> String

    /// Default initializer.
    public init(name: String,
                config: HardistyConfig,
                aggregator: AnyGroupingAggregator,
                formatEventData: @escaping (KeystoneEventData) -> String) {
        self.name = name
        self.config = config
        self.aggregator = aggregator
        self.formatEventData = formatEventData
    }
    
    public var body: some View {
        AnyChartVisualization(name: name, config: config, aggregator: aggregator, formatEventData: formatEventData) {
            let data = ChartData(config: BarChartConfig(isStacked: false, maxBarWidth: 30, centerBars: true, config: $0.config),
                                 series: $0.series)
            
            BarChart(data: data)
        }
    }
}
