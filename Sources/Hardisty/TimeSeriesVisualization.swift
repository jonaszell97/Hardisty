
import Keystone
import Toolbox
import SwiftUI
import Uncharted

fileprivate func createChartData(timeSeriesData: TimeSeriesData,
                                 config: HardistyConfig,
                                 tapActions: [ChartTapAction]) -> (ChartData, ChartConfig) {
let scrollToEnd: Bool
    if case .timeSeries(_, _, _, let scrollToEnd_, _, _) = config.detail {
        scrollToEnd = scrollToEnd_
    }
    else {
        scrollToEnd = true
    }
    
    let chartConfig = timeSeriesData.configure(ChartConfig(
        xAxisConfig: .xAxis(labelFormatter: timeSeriesData.scope.createDefaultFormatter(data: timeSeriesData)),
        yAxisConfig: .yAxis(labelFormatter: FloatingPointFormatter.standard),
        tapActions: tapActions,
        initialXValue: scrollToEnd ? timeSeriesData.values.last?.x : nil,
        noDataAvailableText: "No Data"))
    
    let chartData = ChartData(config: chartConfig, series: [
        .init(name: "_data", data: timeSeriesData.values,
              color: .solid(config.accentColor),
              pointStyle: .standard(color: config.accentColor),
              lineStyle: .straight(color: config.accentColor))
    ])
    
    return (chartData, chartConfig)
}

fileprivate struct AnyTimeSeriesVisualization<Content: View>: View {
    /// The chart name.
    let name: String
    
    /// The configuration.
    let config: HardistyConfig
    
    /// The aggregator this visualization is for.
    let aggregator: AnyDateAggregator
    
    /// Formatter function for a date.
    let formatDate: (Date) -> String

    /// The chart builder.
    let buildChart: (ChartData) -> Content
    
    /// The data source.
    let source: TimeSeriesDataSource
    
    /// The selectable time series scopes.
    let selectableScopes: [TimeSeriesScope]
    
    /// The chart data.
    @State var chartData: ChartData? = nil
    
    /// The chart config.
    @State var chartConfig: ChartConfig? = nil
    
    /// The currently selected value.
    @State var selectedDataPoint: DataPoint? = nil

    /// The selected scope.
    @State var selectedScope: TimeSeriesScope
    
    /// The segment that is currently visible in the chart.
    @State var segmentIndex: Int = 0
    
    /// Default initializer.
    public init(name: String,
                config: HardistyConfig,
                aggregator: AnyDateAggregator,
                formatDate: @escaping (Date) -> String,
                @ViewBuilder buildChart: @escaping (ChartData) -> Content) {
        self.name = name
        self.config = config
        self.aggregator = aggregator
        self.formatDate = formatDate
        self.buildChart = buildChart
        
        let data = aggregator.valueCountsByDate.mapValues { Double($0) }
        if case .timeSeries(let aggregationStrategy, let initialScope, let selectableScopes, _, _, _) = config.detail {
            switch aggregationStrategy {
            case .sumExistingValues:
                self.source = SummingTimeSeriesDataSource(data: data)
            case .interpolateAndAverage:
                self.source = AveragingTimeSeriesDataSource(data: data)
            }
            
            self._selectedScope = .init(initialValue: initialScope ?? .week)
            self.selectableScopes = selectableScopes ?? [.day,.week,.month,.year]
        }
        else {
            self.source = SummingTimeSeriesDataSource(data: data)
            self._selectedScope = .init(initialValue: .week)
            self.selectableScopes = [.day,.week,.month,.year]
        }
    }
    
    func trendView(combinedValue: Double, timeSeriesData: TimeSeriesData, higherIsBetter: Bool) -> some View {
        let trend: HardistyTrend?
        if segmentIndex > 0 {
            let currentInterval = timeSeriesData.interval(forSegment: segmentIndex)
            let previousInterval: DateInterval
            let now = Date.now
            
            if currentInterval.end > now, currentInterval.start < now {
                let progress = (now.timeIntervalSinceReferenceDate - currentInterval.start.timeIntervalSinceReferenceDate) / currentInterval.duration
                let previousIntervalFull = timeSeriesData.interval(forSegment: segmentIndex - 1)
                
                previousInterval = .init(start: previousIntervalFull.start,
                                         end: previousIntervalFull.start.addingTimeInterval(previousIntervalFull.duration * progress))
            }
            else {
                previousInterval = timeSeriesData.interval(forSegment: segmentIndex - 1)
            }
            
            if let previousValue = source.combinedValue(in: previousInterval) {
                trend = .init(earlierValue: previousValue, laterValue: combinedValue)
            }
            else {
                trend = nil
            }
        }
        else {
            trend = nil
        }
        
        return ZStack {
            if let trend {
                TrendArrowView(trend: trend, higherIsBetter: higherIsBetter, accentColor: config.accentColor,
                               size: UIFont.preferredFont(forTextStyle: .body).pointSize * 0.75,
                               shouldAnimate: true)
            }
        }
    }
    
    public var body: some View {
        Section {
            TimeSeriesView(source: source, scope: $selectedScope) { timeSeriesData in
                let (chartData, chartConfig) = createChartData(timeSeriesData: timeSeriesData, config: config, tapActions: [
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
                
                VStack {
                    HStack {
                        Spacer()

                        if let selectedDataPoint {
                            let label = chartConfig.xAxisConfig.labelFormatter(selectedDataPoint.x)
                            let value = chartConfig.yAxisConfig.labelFormatter(selectedDataPoint.y)
                            let index = Int(selectedDataPoint.x.rounded(.down))
                            
                            if timeSeriesData.dates.count > index, let date = timeSeriesData.dates[index] {
                                Text(verbatim: formatDate(date))
                            }
                            else {
                                Text(verbatim: label)
                            }
                            
                            Image(systemName: "circle.fill").font(.system(size: 5)).opacity(0.75)
                            Text(verbatim: value)
                        }
                        else {
                            Text(verbatim: timeSeriesData.scope.formatTimeInterval(timeSeriesData.interval, segmentIndex: self.segmentIndex))
                            
                            if let combinedValue = source.combinedValue(in: timeSeriesData.interval(forSegment: segmentIndex)) {
                                Image(systemName: "circle.fill").font(.system(size: 5)).opacity(0.75)
                                
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(verbatim: chartConfig.yAxisConfig.labelFormatter(combinedValue))
                                    
                                    if case .timeSeries(_, _, _, _, let showTrends, let higherIsBetter) = config.detail, showTrends {
                                        self.trendView(combinedValue: combinedValue, timeSeriesData: timeSeriesData, higherIsBetter: higherIsBetter)
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .font(.headline)
                    .foregroundColor(.init(uiColor: .secondaryLabel))

                    buildChart(chartData)
                        .frame(height: 175)
                        .padding(.horizontal, 10)
                        .id(chartData.dataHash)
                    
                    TimeSeriesDefaultIntervalPickerView(currentScope: $selectedScope, supportedScopes: self.selectableScopes)
                        .padding(10)
                }
                .observeChart { proxy in
                    self.segmentIndex = proxy.currentSegmentIndex
                }
            }
        } header: {
            Text(verbatim: self.name)
        }
    }
}

public struct LineChartTimeSeriesVisualization: View {
    /// The chart name.
    let name: String
    
    /// The configuration.
    let config: HardistyConfig
    
    /// The aggregator this visualization is for.
    let aggregator: AnyDateAggregator
    
    /// Formatter function for a date.
    let formatDate: (Date) -> String

    /// Default initializer.
    public init(name: String,
                config: HardistyConfig,
                aggregator: AnyDateAggregator,
                formatDate: @escaping (Date) -> String) {
        self.name = name
        self.config = config
        self.aggregator = aggregator
        self.formatDate = formatDate
    }
    
    public var body: some View {
        AnyTimeSeriesVisualization(name: name, config: config, aggregator: aggregator, formatDate: formatDate) {
            let data = ChartData(config: LineChartConfig(config: $0.config), series: $0.series)
            LineChart(data: data)
        }
    }
}

public struct BarChartTimeSeriesVisualization: View {
    /// The chart name.
    let name: String
    
    /// The configuration.
    let config: HardistyConfig
    
    /// The aggregator this visualization is for.
    let aggregator: AnyDateAggregator
    
    /// Formatter function for a date.
    let formatDate: (Date) -> String
    
    /// Default initializer.
    public init(name: String,
                config: HardistyConfig,
                aggregator: AnyDateAggregator,
                formatDate: @escaping (Date) -> String) {
        self.name = name
        self.config = config
        self.aggregator = aggregator
        self.formatDate = formatDate
    }
    
    public var body: some View {
        AnyTimeSeriesVisualization(name: name, config: config, aggregator: aggregator, formatDate: formatDate) {
            let data = ChartData(config: BarChartConfig(isStacked: false, maxBarWidth: 30, centerBars: true, config: $0.config),
                                 series: $0.series)
            
            BarChart(data: data)
        }
    }
}
