
import Keystone
import Toolbox
import SwiftUI
import Uncharted

public protocol AnyDistributionAggregator {
    /// The distribution of values.
    var valueDistribution: [Double] { get }
}

fileprivate func createChartData(mean: Double, stdDev: Double,
                                 config: HardistyConfig,
                                 tapActions: [ChartTapAction]) -> (ChartData, ChartConfig) {
    let maxXValue = 3*stdDev
    let minXValue = -3*stdDev
    
    let values = (Int(minXValue)...Int(maxXValue)).map {
        DataPoint(x: Double($0), y: StatsUtilities.normalDistribution(Double($0), mean: 0, std: stdDev))
    }
    
    let chartConfig = ChartConfig(
        xAxisConfig: .xAxis(
            title: "x",
            visible: true,
            baseline: .clamp(upperBound: minXValue),
            topline: .clamp(lowerBound: maxXValue),
            scrollingBehaviour: .noScrolling,
            gridStyle: .defaultXAxisStyle,
            labelFormatter: CustomDataFormatter { value in
                FloatingPointFormatter.standard(value + mean)
            }
        ),
        yAxisConfig: .yAxis(
            title: "y",
            visible: false,
            baseline: .zero,
            topline: .maximumValue,
            step: .automatic(preferredSteps: 2),
            gridStyle: .defaultYAxisStyle
        ),
        tapActions: [],
        animation: .easeInOut(duration: 1),
        noDataAvailableText: NSLocalizedString("statistics.no-data-available")
    )
    
    let chartData = ChartData(config: chartConfig, series: [
        .init(name: "distribution",
              data: values,
              markers: [
                // Average line
                .line(style: StrokeStyle(lineWidth: 2, dash: [10], dashPhase: 7),
                      color: config.accentColor.opacity(0.5),
                      start: .init(x: 0, y: 0), end: .init(x: 0, y: 0.1))
              ],
              color: .solid(config.accentColor),
              pointStyle: nil,
              lineStyle: .init(type: .straight,
                               fillType: .fillAndStroke,
                               stroke: .init(),
                               color: .solid(config.accentColor.opacity(0.75)),
                               fillColor: .solid(config.accentColor.opacity(0.1)),
                               ignoreZero: false))
    ])
    
    return (chartData, chartConfig)
}

public struct GaussianDistributionVisualization: View {
    /// The name of the visualization
    let name: String
    
    /// The configuration.
    let config: HardistyConfig
    
    /// The aggregator.
    let aggregator: AnyDistributionAggregator
    
    /// Whether or not the estimated gaussian distribution is visible.
    @State var estimatedDistributionVisible: Bool = true
    
    /// The chart data.
    @State var chartData: ChartData? = nil
    
    /// The chart config.
    @State var chartConfig: ChartConfig? = nil
    
    /// The currently selected value.
    @State var selectedDataPoint: DataPoint? = nil
    
    /// Distribution mean and standard deviation.
    @State var distribution: (n: Int, mean: Double, stdDev: Double)? = nil
    
    public init(name: String, config: HardistyConfig, aggregator: AnyDistributionAggregator) {
        self.name = name
        self.config = config
        self.aggregator = aggregator
    }
    
    func updateChartData() {
        let values = aggregator.valueDistribution
        let tapActions: [ChartTapAction] = [
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
        ]
        
        if estimatedDistributionVisible {
            guard let mean = values.mean, let stdDev = values.sampleStandardDeviation else {
                return
            }
            
            let (chartData, chartConfig) = createChartData(mean: mean, stdDev: stdDev, config: config, tapActions: tapActions)
            self.chartData = chartData
            self.chartConfig = chartConfig
            self.distribution = (n: values.count, mean: mean, stdDev: stdDev)
        }
        else {
            var valueCounts = [Int: Int]()
            for value in values {
                valueCounts.modify(key: Int(value), defaultValue: 0) { $0 += 1 }
            }
            
            let sortedValues = valueCounts.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }.map { ("\($0.0)", $0.1) }
            let (chartData, chartConfig) = createChartData(sortedData: sortedValues, config: config,
                                                           tapActions: tapActions, scrollingBehaviour: .noScrolling)
            
            chartConfig.xAxisConfig.step = .automatic(preferredSteps: 15)
            
            self.chartData = chartData
            self.chartConfig = chartConfig
            self.distribution = nil
        }
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
                    else if let (n, mean, stdDev) = distribution {
                        Text(verbatim: "n = \(n)")
                        Image(systemName: "circle.fill").font(.system(size: 5)).opacity(0.75)
                        Text(verbatim: "µ = \(FormatToolbox.format(mean, decimalPlaces: 2))")
                        Image(systemName: "circle.fill").font(.system(size: 5)).opacity(0.75)
                        Text(verbatim: "σ = \(FormatToolbox.format(stdDev, decimalPlaces: 2))")
                    }
                    else {
                        Text(verbatim: " ")
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.footnote)
                        .onTapGesture {
                            self.estimatedDistributionVisible.toggle()
                            self.updateChartData()
                        }
                }
                .font(.headline)
                .foregroundColor(.init(uiColor: .secondaryLabel))
                
                if let chartData {
                    if estimatedDistributionVisible {
                        LineChart(data: chartData)
                            .frame(height: 175)
                            .padding(.horizontal, 10)
                    }
                    else {
                        BarChart(data: chartData)
                            .frame(height: 175)
                            .padding(.horizontal, 10)
                    }
                }
            }
        } header: {
            Text(verbatim: self.name)
        }
        .onAppear {
            updateChartData()
        }
    }
}
