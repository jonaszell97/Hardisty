
import Keystone
import Panorama
import SwiftUI
import Toolbox
import Uncharted

public struct KPIVisualization: View {
    /// The name of this set of KPIs.
    let name: String
    
    /// The configuration.
    let config: HardistyConfig
    
    /// The value of the KPI.
    let values: [(String, String)]
    
    public init(name: String, config: HardistyConfig, values: [(String, String)]) {
        self.name = name
        self.config = config
        self.values = values
    }
    
    public var body: some View {
        Section {
            ForEach(values, id: \.0) { value in
                HStack {
                    Text(verbatim: value.0)
                    Spacer()
                    Text(verbatim: value.1).foregroundColor(.secondary)
                }
            }
        } header: {
            Text(verbatim: name)
        }
    }
}

public enum HardistyTrend {
    /// The KPI is trending upwards.
    case upwards
    
    /// The KPI is trending downwards.
    case downwards
    
    /// The KPI is not trending either way.
    case neutral
    
    /// Initialize by comparing two values.
    init<T>(earlierValue: T, laterValue: T) where T: Comparable {
        if earlierValue > laterValue {
            self = .downwards
        }
        else if earlierValue < laterValue {
            self = .upwards
        }
        else {
            self = .neutral
        }
    }
}

struct TrendArrowView: View {
    /// The target rotation angle.
    let targetAngle: Angle
    
    /// The arrow color.
    let color: Color
    
    /// The size of the arrow.
    let size: CGFloat
    
    /// Whether or not to invert the color of the arrow.
    let invertColors: Bool
    
    /// Whether or not to animate this view.
    let shouldAnimate: Bool
    
    /// The current rotation angle of the arrow.
    @State var rotationAngle: Angle = .zero
    
    init(trend: HardistyTrend, higherIsBetter: Bool, accentColor: Color, size: CGFloat, shouldAnimate: Bool) {
        switch trend {
        case .upwards:
            self.targetAngle = .init(degrees: -45)
            self.invertColors = !higherIsBetter
            self.color = accentColor
        case .downwards:
            self.targetAngle = .init(degrees: +45)
            self.invertColors = higherIsBetter
            self.color = accentColor
        case .neutral:
            self.targetAngle = .zero
            self.invertColors = false
            self.color = .primary
        }
        
        self.size = size
        self.shouldAnimate = shouldAnimate
    }
    
    var body: some View {
        Image(systemName: "arrow.forward")
            .font(.system(size: self.size))
            .rotationEffect(self.rotationAngle)
            .foregroundColor(self.color)
            .applyIf(self.invertColors) { $0.colorInvert() }
            .onAppear {
                guard shouldAnimate else { return }
                withAnimation(.easeInOut.delay(0.5)) {
                    self.rotationAngle = targetAngle
                }
            }
            // Required for the trend arrow to correctly reload after a view refresh
            .id(self.targetAngle.hashValue ^ self.color.hashValue)
    }
}

public struct KPITrendVisualization: View {
    /// The name of this KPI.
    let name: String
    
    /// The configuration.
    let config: HardistyConfig
    
    /// Formatting function for a date interval.
    let formatDateInterval: (DateInterval, TimeSeriesScope) -> String
    
    /// The interval scope.
    let scope: TimeSeriesScope
    
    /// Whether higher values are considered better for trends.
    let higherIsBetter: Bool
    
    /// The interval covered by the aggregator.
    let dataInterval: DateInterval
    
    /// The current interval, value, and trend..
    let data: [(DateInterval, Int?, HardistyTrend?)]
    
    /// The selected tab.
    @State var selectedTab: Int
    
    /// Public initializer.
    public init(name: String, config: HardistyConfig, aggregator: AnyDateAggregator,
                formatDateInterval: @escaping (DateInterval, TimeSeriesScope) -> String) {
        self.name = name
        self.config = config
        self.formatDateInterval = formatDateInterval
        
        if case .trendingKPI(let scope, let higherIsBetter) = config.detail {
            self.scope = scope
            self.higherIsBetter = higherIsBetter
        }
        else {
            self.scope = .week
            self.higherIsBetter = true
        }
        
        let valueCountsByDate = aggregator.valueCountsByDate
        
        var earliestDate: Date = .now
        var latestDate: Date = .now
        
        for (date, _) in valueCountsByDate {
            earliestDate = min(earliestDate, date)
            latestDate = max(latestDate, date)
        }
        
        self.dataInterval = .init(start: earliestDate, end: latestDate)
        
        let now = Date.now
        
        var currentInterval = Self.interval(containing: earliestDate, scope: scope, config: config)
        var data = [(DateInterval, Int, HardistyTrend?)]()
        var initialTab = 0
        var previousValue: Int? = nil
        
        while currentInterval.start <= latestDate {
            var sum = 0
            for (date, count) in valueCountsByDate {
                guard currentInterval.contains(date) else { continue }
                sum += count
            }
            
            if currentInterval.contains(now) {
                initialTab = data.count
            }
            
            let trend: HardistyTrend?
            if let previousValue {
                trend = .init(earlierValue: previousValue, laterValue: sum)
            }
            else {
                trend = nil
            }
            
            data.append((currentInterval, sum, trend))
            
            previousValue = sum
            currentInterval = Self.interval(after: currentInterval, scope: scope, config: config)
        }
        
        self.data = data
        self._selectedTab = .init(initialValue: initialTab)
    }
    
    static func interval(containing date: Date, scope: TimeSeriesScope, config: HardistyConfig) -> DateInterval {
        switch scope {
        case .day:
            return KeystoneAnalyzer.dayInterval(containing: date)
        case .week:
            return KeystoneAnalyzer.weekInterval(containing: date, weekStartsOnMonday: config.firstDayOfWeek == .monday)
        case .month:
            return KeystoneAnalyzer.interval(containing: date)
        case .threeMonths:
            fallthrough
        case .sixMonths:
            fallthrough
        case .year:
            return KeystoneAnalyzer.yearInterval(containing: date)
        }
    }
    
    static func interval(after other: DateInterval, scope: TimeSeriesScope, config: HardistyConfig) -> DateInterval {
        switch scope {
        case .day:
            return KeystoneAnalyzer.dayInterval(after: other)
        case .week:
            return KeystoneAnalyzer.weekInterval(after: other, weekStartsOnMonday: config.firstDayOfWeek == .monday)
        case .month:
            return KeystoneAnalyzer.interval(after: other)
        case .threeMonths:
            fallthrough
        case .sixMonths:
            fallthrough
        case .year:
            return KeystoneAnalyzer.yearInterval(after: other)
        }
    }
    
    func intervalView(interval: DateInterval, value: Int?, trend: HardistyTrend?, tag: Int) -> some View {
        HStack {
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(verbatim: formatDateInterval(interval, scope))
                    .font(.caption).foregroundColor(.init(uiColor: .secondaryLabel))
                
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(verbatim: FormatToolbox.format(value ?? 0))
                        .font(.largeTitle)
                        .opacity(value == nil ? 0 : 1)
                    
                    if let trend, selectedTab == tag {
                        TrendArrowView(trend: trend,
                                       higherIsBetter: higherIsBetter,
                                       accentColor: config.accentColor,
                                       size: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize * 0.6,
                                       shouldAnimate: true)
                        .opacity(0.5)
                        .id("arrow_\(tag)_animated")
                    }
                    else {
                        TrendArrowView(trend: trend ?? .neutral,
                                       higherIsBetter: higherIsBetter,
                                       accentColor: config.accentColor,
                                       size: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize * 0.6,
                                       shouldAnimate: false)
                        .opacity(0.5)
                        .id("arrow_\(tag)_static")
                    }
                }
            }
        }
        .tag(tag)
    }
    
    public var body: some View {
        Section {
            TabView(selection: $selectedTab) {
                ForEach(0..<data.count, id: \.self) { i in
                    self.intervalView(interval: data[i].0, value: data[i].1, trend: data[i].2, tag: i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(minHeight: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize * 1.5)
        } header: {
            Text(verbatim: name)
        }
    }
}
