
#if DEBUG
#if canImport(UIKit)

import Keystone
import SwiftUI
import Toolbox

internal final class PreviewUtility: ObservableObject {
    @Published var debugMessage: String? = nil
    static let shared = PreviewUtility()
    
    init() { }
}

fileprivate let exampleAggregator1 = CountingByGroupAggregator(groupedValues: [
    .text(value: "group1"): 10,
    .text(value: "group2"): 6,
    .text(value: "group3"): 1,
    .text(value: "group4"): 13,
    .text(value: "group5"): 5,
    .text(value: "group6"): 19,
    .text(value: "group7"): 25,
    .text(value: "group8"): 1,
    .text(value: "group9"): 6,
    .text(value: "group10"): 5,
    .text(value: "group11"): 3,
    .text(value: "group12"): 17,
])

fileprivate let dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    dateFormatter.timeZone = .utc
    
    return dateFormatter
}()

fileprivate func date(from string: String) -> Date {
    dateFormatter.date(from: string)!
}

fileprivate let exampleAggregator2 = CountingByDateAggregator(scope: .day, groupedValues: [
    date(from: "2023-01-01T00:00:01+0000"): 10,
    date(from: "2023-01-02T00:01:00+0000"): 6,
    date(from: "2023-01-03T00:01:00+0000"): 1,
    date(from: "2023-01-04T00:00:00+0000"): 13,
    date(from: "2023-01-05T00:01:00+0000"): 5,
    date(from: "2023-01-06T00:00:20+0000"): 19,
    date(from: "2023-01-13T00:01:00+0000"): 25,
    date(from: "2023-01-14T00:00:30+0000"): 1,
    date(from: "2023-01-15T00:04:00+0000"): 6,
    date(from: "2023-01-20T00:00:00+0000"): 5,
    date(from: "2023-01-22T00:50:00+0000"): 3,
    date(from: "2023-01-23T00:01:00+0000"): 17,
    date(from: "2023-03-10T00:00:00+0000"): 15,
    date(from: "2023-04-10T00:00:00+0000"): 16,
    date(from: "2023-05-10T00:00:00+0000"): 17,
    date(from: "2023-06-10T00:00:00+0000"): 18,
    date(from: "2023-07-10T00:00:00+0000"): 19,
])

fileprivate final class DistributionAggregator: AnyDistributionAggregator {
    func addEvent(_ event: Keystone.KeystoneEvent, column: Keystone.EventColumn?) -> Keystone.EventProcessingResult { fatalError() }
    func encode() throws -> Data? { fatalError() }
    func decode(from data: Data) throws { fatalError() }
    func reset() { fatalError() }
    var debugDescription: String { "" }
    
    let valueDistribution: [Double] = [4,6,6,8,8,10,10,10,10,11,12,12,13,13,13,13,14,14,15,16,16,17,17,18,18,18,19,19,19,20,20,20,21,21,21,29,0,0,1,1,1,2,3,4,4,4,5,5,5,6,7,8,8,9,9,10,10,10,10,10,10,10,10,11,11,11,11,11,11,12,12,12,13,13,13,13,14,14,14,14,15,16,16,17,17,17,17,18,19,20,20,20,21,22,24,26,26,26,7,10,26,9,10,15,11,2,4,2,5,11,15,15,1,15,8,12,18,10,5,22,11,3,10,6,14,16,14,10,17,10,10,13,17,1,17,21,11,19,14,8,18,10,17,12,17,17,16,21,15,3,10,12,24,12,12,9,16,19,16,2,10,9,11,16,10,1,23,14,16,11,26,10,24,20,29,11,25,18,25,10,16,9,10,3,13,17,21,1,13,1,17,5,10,9,20,13,12,11,5,11,5,17,19,12,20,10,1,15,8,23,4,22,19,1,11,3,13,5,12,2,13,11,5,28,19,2,19,17,7,12,1,7,1,22,11,17,10,12,10,8,12,19,18,11,12,11,16,22]
    
    init() { }
}

struct VisualizationPreviews: PreviewProvider {
    struct PreviewView: View {
        let chartConfig: HardistyConfig = .init(accentColor: .cyan, detail: .chart(scrollToEnd: false))
        let timeSeriesConfig: HardistyConfig = .init(accentColor: .cyan, detail: .timeSeries(scrollToEnd: true, showTrends: true))
        
        static let formatEventData: (KeystoneEventData) -> String = { value in
            switch value {
            case .number(let value):
                return FormatToolbox.format(value)
            case .text(let value):
                return value
            case .date(let value):
                return FormatToolbox.formatDateTime(value)
            case .bool(let value):
                return value ? "Yes" : "No"
            case .codable:
                return "<codable data>"
            case .noValue:
                return "<no value>"
            }
        }
        
        static let formatDate: (Date) -> String = { date in
            if Calendar.reference.component(.hour, from: date) != 0 {
                return FormatToolbox.formatDateTime(date)
            }
            
            return FormatToolbox.formatDate(date)
        }
        
        @ObservedObject var previewUtility: PreviewUtility = .shared
        
        var body: some View {
            List {
                KPITrendVisualization(name: "Trend",
                                      config: .init(accentColor: .cyan,
                                                    detail: .trendingKPI(scope: .week,
                                                                         higherIsBetter: true)),
                                      aggregator: exampleAggregator2) { interval, scope in
                    switch scope {
                    case .day:
                        if Date.now >= interval.end {
                            return "Today"
                        }
                        
                        let dateFormatter = dateFormatter
                        dateFormatter.timeStyle = .none
                        dateFormatter.dateStyle = .long
                        
                        return dateFormatter.string(from: interval.start)
                    case .week:
                        if Date.now >= interval.end {
                            return "This Week"
                        }
                        
                        let dateFormatter = dateFormatter
                        dateFormatter.timeStyle = .none
                        dateFormatter.dateStyle = .long
                        
                        return "\(dateFormatter.string(from: interval.start)) - \(dateFormatter.string(from: interval.end.addingTimeInterval(1)))"
                    case .month:
                        if Date.now >= interval.end {
                            return "This Month"
                        }
                        
                        let comonents = Calendar.reference.dateComponents([.month,.year], from: interval.start)
                        return "\(comonents.month!)/\(comonents.year!)"
                    case .threeMonths:
                        fallthrough
                    case .sixMonths:
                        fallthrough
                    case .year:
                        if Date.now >= interval.end {
                            return "This Year"
                        }
                        
                        return "\(Calendar.reference.component(.year, from: interval.start))"
                    }
                }
                
                KPIVisualization(name: "KPI", config: chartConfig, values: [("X", "1"), ("Y", "2")])
                KPIVisualization(name: "KPI", config: chartConfig, values: [("X", "1")])
                
                if let msg = previewUtility.debugMessage {
                    Section {
                        Text(verbatim: msg)
                    } header: {
                        Text("DEBUG")
                    }
                }
                
                BarChartTimeSeriesVisualization(name: "Bar Lines", config: timeSeriesConfig, aggregator: exampleAggregator2, formatDate: Self.formatDate)
                GaussianDistributionVisualization(name: "Gaussian", config: chartConfig, aggregator: DistributionAggregator())
                LineChartTimeSeriesVisualization(name: "Time Lines", config: timeSeriesConfig, aggregator: exampleAggregator2, formatDate: Self.formatDate)
                LineChartVisualization(name: "Lines", config: chartConfig, aggregator: exampleAggregator1, formatEventData: Self.formatEventData)
                BarChartVisualization(name: "Bars", config: chartConfig, aggregator: exampleAggregator1, formatEventData: Self.formatEventData)
                ListVisualization(name: "List", config: chartConfig, aggregator: exampleAggregator1, formatEventData: Self.formatEventData)
            }
            .listStyle(.insetGrouped)
            .edgesIgnoringSafeArea(.bottom)
        }
    }
    
    static var previews: some View {
        PreviewView()
    }
}

#endif
#endif
