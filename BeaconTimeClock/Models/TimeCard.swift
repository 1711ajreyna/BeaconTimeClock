import Foundation
import SwiftData

/// Local SwiftData copy of employee punch
///
/// The backend is the production source of truth,
/// but keeping a local record will provide immediate UI feedback a
@Model
final class TimeCard {
    
    @Attribute(.unique)
    var id: UUID
    
    /// Optional server ID returned after successful synchronization.
    var remoteID: UUID?
    
    var employeeID: String
    var employeeName: String
    var punchTypeRawValue: String
    var timestamp: Date
    
    /// Evidence captured when the punch was made.
    var beaconUUID: String
    var rssi: Int
    var estimatedDistanceMeters: Double?
    
    /// 'pending',  'synced', or 'failed'
    var syncStatus: String
    
    var type: PunchType {
        get {
            PunchType(rawValue: punchTypeRawValue) ?? .clockIn
        }
        set {
            punchTypeRawValue = newValue.rawValue
        }
    }
    
    init(
            id: UUID = UUID(),
            remoteID: UUID? = nil,
            employeeID: String,
            employeeName: String,
            type: PunchType,
            timestamp: Date,
            beaconUUID: String,
            rssi: Int,
            estimatedDistanceMeters: Double?,
            syncStatus: String = "pending"
        ) {
            self.id = id
            self.remoteID = remoteID
            self.employeeID = employeeID
            self.employeeName = employeeName
            self.punchTypeRawValue = type.rawValue
            self.timestamp = timestamp
            self.beaconUUID = beaconUUID
            self.rssi = rssi
            self.estimatedDistanceMeters = estimatedDistanceMeters
            self.syncStatus = syncStatus
        }
    }
