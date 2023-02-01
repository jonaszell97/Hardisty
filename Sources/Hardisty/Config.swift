
import SwiftUI
import Toolbox
import Uncharted

public enum TimeSeriesAggregationStrategy {
    /// Use the sum of all existing values in an interval.
    case sumExistingValues
    
    /// Use the average of existing values and interpolate between values.
    case interpolateAndAverage
}

public enum HardistyConfigDetail {
    /// Config for a time series.
    case timeSeries(aggregationStrategy: TimeSeriesAggregationStrategy = .sumExistingValues,
                    initialScope: TimeSeriesScope? = nil,
                    selectableScopes: [TimeSeriesScope]? = nil,
                    scrollToEnd: Bool = true,
                    showTrends: Bool = false,
                    higherIsBetter: Bool = true)
    
    /// Config for a chart.
    case chart(scrollToEnd: Bool)
    
    /// Config for a KPI with trends.
    case trendingKPI(scope: TimeSeriesScope, higherIsBetter: Bool)
    
    /// Config for a list.
    case list(visibleValuesLimit: Int = 10)
}

public struct HardistyConfig {
    /// The accent color for this visualisation.
    public let accentColor: Color
    
    /// The first day of the week.
    public let firstDayOfWeek: Date.FirstDayOfWeek
    
    /// The spcific config for a visualization type.
    public let detail: HardistyConfigDetail?
    
    /// Memberwise initializer.
    public init(accentColor: Color, weekStartsOn firstDayOfWeek: Date.FirstDayOfWeek = .monday, detail: HardistyConfigDetail? = nil) {
        self.accentColor = accentColor
        self.firstDayOfWeek = firstDayOfWeek
        self.detail = detail
    }
    
    /// Return a new config with the given details.
    public func withDetail(_ detail: HardistyConfigDetail) -> HardistyConfig {
        .init(accentColor: self.accentColor, weekStartsOn: self.firstDayOfWeek, detail: detail)
    }
}
