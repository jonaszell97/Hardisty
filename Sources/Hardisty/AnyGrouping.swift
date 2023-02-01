
import Foundation
import Keystone
import Toolbox

public protocol AnyGroupingAggregator {
    /// The grouped value labels and counts.
    var valueCountsByGroup: [KeystoneEventData: Int] { get }
}

public protocol AnyDateAggregator {
    /// The date components kept for keying.
    var scope: DateAggregatorScope { get }
    
    /// The grouped value dates and counts.
    var valueCountsByDate: [Date: Int] { get }
}

extension CountingByGroupAggregator: AnyGroupingAggregator {
    public var valueCountsByGroup: [KeystoneEventData: Int] {
        groupedValues
    }
}

extension CountingByDateAggregator: AnyGroupingAggregator, AnyDateAggregator {
    public var valueCountsByGroup: [KeystoneEventData: Int] {
        var result = [KeystoneEventData: Int]()
        for (date, value) in groupedValues {
            result[.date(value: date)] = value
        }
        
        return result
    }
    
    public var valueCountsByDate: [Date: Int] {
        var result = [Date: Int]()
        for (date, value) in groupedValues {
            result[date] = value
        }
        
        return result
    }
}

extension GroupingAggregator: AnyGroupingAggregator {
    public var valueCountsByGroup: [KeystoneEventData: Int] {
        groupedValues.mapValues { $0.count }
    }
}

extension DateAggregator: AnyGroupingAggregator, AnyDateAggregator {
    public var valueCountsByGroup: [KeystoneEventData: Int] {
        var result = [KeystoneEventData: Int]()
        for (date, value) in groupedValues {
            result[.date(value: date)] = value.count
        }
        
        return result
    }
    
    public var valueCountsByDate: [Date: Int] {
        var result = [Date: Int]()
        for (date, value) in groupedValues {
            result[date] = value.count
        }
        
        return result
    }
}
