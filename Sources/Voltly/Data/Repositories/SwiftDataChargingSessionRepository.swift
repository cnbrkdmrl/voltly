import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

public final class SwiftDataChargingSessionRepository: ChargingSessionRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func save(session: ChargingSession) throws {
        let existing = try findRecord(by: session.id) ?? ChargingSessionRecord(
            id: session.id,
            vehicleID: session.vehicleID,
            sessionDate: session.sessionDate,
            chargeMethodRaw: session.chargeMethod.rawValue,
            stationBrand: session.stationBrand,
            locationName: session.locationName,
            priceTotal: session.priceTotal,
            currencyCode: session.currencyCode,
            energyKWh: session.energyKWh,
            energyIsEstimated: session.energyIsEstimated,
            socStart: session.socStart,
            socEnd: session.socEnd,
            isFullCharge: session.isFullCharge,
            durationMin: session.durationMin,
            odometerKM: session.odometerKM,
            outsideTempC: session.outsideTempC,
            weatherCondition: session.weatherCondition,
            rangeGainedKmEstimate: session.rangeGainedKmEstimate,
            contextTagsRaw: encodeContextTags(session.contextTags),
            notes: session.notes,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt
        )

        existing.vehicleID = session.vehicleID
        existing.sessionDate = session.sessionDate
        existing.chargeMethodRaw = session.chargeMethod.rawValue
        existing.stationBrand = session.stationBrand
        existing.locationName = session.locationName
        existing.priceTotal = session.priceTotal
        existing.currencyCode = session.currencyCode
        existing.energyKWh = session.energyKWh
        existing.energyIsEstimated = session.energyIsEstimated
        existing.socStart = session.socStart
        existing.socEnd = session.socEnd
        existing.isFullCharge = session.isFullCharge
        existing.durationMin = session.durationMin
        existing.odometerKM = session.odometerKM
        existing.outsideTempC = session.outsideTempC
        existing.weatherCondition = session.weatherCondition
        existing.rangeGainedKmEstimate = session.rangeGainedKmEstimate
        existing.contextTagsRaw = encodeContextTags(session.contextTags)
        existing.notes = session.notes
        existing.updatedAt = .now

        if existing.modelContext == nil {
            context.insert(existing)
        }

        try context.save()
    }

    public func delete(sessionID: UUID) throws {
        guard let existing = try findRecord(by: sessionID) else {
            return
        }
        context.delete(existing)
        try context.save()
    }

    public func fetchAll(vehicleID: UUID?) throws -> [ChargingSession] {
        let descriptor = FetchDescriptor<ChargingSessionRecord>(sortBy: [SortDescriptor(\ChargingSessionRecord.sessionDate, order: .reverse)])
        let records = try context.fetch(descriptor)
        return records
            .filter { vehicleID == nil || $0.vehicleID == vehicleID }
            .map(DomainMappers.map)
    }

    public func fetchRecent(vehicleID: UUID?, limit: Int) throws -> [ChargingSession] {
        Array(try fetchAll(vehicleID: vehicleID).prefix(limit))
    }

    public func fetchInRange(vehicleID: UUID?, from: Date, to: Date) throws -> [ChargingSession] {
        try fetchAll(vehicleID: vehicleID)
            .filter { $0.sessionDate >= from && $0.sessionDate <= to }
    }

    public func count(vehicleID: UUID) throws -> Int {
        try fetchAll(vehicleID: vehicleID).count
    }

    private func findRecord(by id: UUID) throws -> ChargingSessionRecord? {
        let descriptor = FetchDescriptor<ChargingSessionRecord>()
        return try context.fetch(descriptor).first(where: { $0.id == id })
    }

    private func encodeContextTags(_ tags: [ChargeContextTag]) -> String? {
        guard !tags.isEmpty,
              let data = try? JSONEncoder().encode(tags) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
#endif
