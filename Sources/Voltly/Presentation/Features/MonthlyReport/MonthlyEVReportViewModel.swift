import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#endif

public struct MonthlyChargeDistribution: Equatable {
    public let homeRatio: Double
    public let acRatio: Double
    public let dcRatio: Double

    public init(
        homeRatio: Double,
        acRatio: Double,
        dcRatio: Double
    ) {
        self.homeRatio = homeRatio
        self.acRatio = acRatio
        self.dcRatio = dcRatio
    }
}

public struct MonthlyEVReportSummary: Equatable {
    public let month: Date
    public let monthTitle: String
    public let totalEnergyKWh: Double
    public let sessionCount: Int
    public let totalCost: Double
    public let averageTLPerKWh: Double?
    public let tlPer100Km: MeasuredValue<Double>?
    public let chargeDistribution: MonthlyChargeDistribution
    public let gasolineSavingsPercent: Double?
    public let gasolineSavingsAmount: Double?
    public let currencyCode: String
}

@MainActor
public final class MonthlyEVReportViewModel: ObservableObject {
    @Published public private(set) var hasActiveVehicle = false
    @Published public private(set) var availableMonths: [Date] = []
    @Published public private(set) var selectedMonth: Date = Date().startOfMonth
    @Published public private(set) var summary: MonthlyEVReportSummary?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var exportPDFEnabled = false

    #if os(iOS)
    @Published public private(set) var shareImage: UIImage?
    @Published public private(set) var exportAspectRatio: MonthlySummaryExportAspectRatio = .story
    #endif

    private let environment: AppEnvironment
    #if os(iOS)
    private let shareRenderer = MonthlySummaryShareRenderer()
    #endif

    public init(environment: AppEnvironment) {
        self.environment = environment
        refreshFeatureFlags()
    }

    public func load() {
        do {
            refreshFeatureFlags()
            guard let vehicle = try environment.vehicleRepository.fetchActiveVehicle() else {
                hasActiveVehicle = false
                availableMonths = []
                summary = nil
                errorMessage = nil
                #if os(iOS)
                shareImage = nil
                #endif
                return
            }

            hasActiveVehicle = true

            let allSessions = try environment.chargingSessionRepository.fetchAll(vehicleID: vehicle.id)
            var uniqueMonths = Set(allSessions.map { $0.sessionDate.startOfMonth })
            uniqueMonths.insert(Date().startOfMonth)
            availableMonths = uniqueMonths.sorted(by: >)

            if !availableMonths.contains(selectedMonth.startOfMonth) {
                selectedMonth = availableMonths.first ?? Date().startOfMonth
            } else {
                selectedMonth = selectedMonth.startOfMonth
            }

            try reloadSummary()
            errorMessage = nil
        } catch {
            hasActiveVehicle = false
            summary = nil
            errorMessage = error.localizedDescription
            #if os(iOS)
            shareImage = nil
            #endif
        }
    }

    private func refreshFeatureFlags() {
        exportPDFEnabled = environment.featureAccessChecker.isEnabled(.exportPDF)
    }

    public func selectMonth(_ month: Date) {
        selectedMonth = month.startOfMonth
        do {
            try reloadSummary()
            errorMessage = nil
        } catch {
            summary = nil
            errorMessage = error.localizedDescription
            #if os(iOS)
            shareImage = nil
            #endif
        }
    }

    public func monthLabel(for month: Date) -> String {
        Self.monthYearFormatter.string(from: month).capitalized(with: Locale.autoupdatingCurrent)
    }

    public func trackReportShared() {
        environment.analytics.track(.monthlyReportShared)
    }

    #if os(iOS)
    public func setExportAspectRatio(_ ratio: MonthlySummaryExportAspectRatio) {
        exportAspectRatio = ratio
        renderShareCard()
    }
    #endif

    private func reloadSummary() throws {
        let snapshot = try environment.getDashboardSnapshotUseCase.execute(referenceDate: selectedMonth)
        let totalEnergy = snapshot.monthlyTotalEnergy
        let averageTLPerKWh = totalEnergy > 0
            ? snapshot.monthlyTotalCost / totalEnergy
            : nil
        let monthlyDistribution = buildDistribution(from: snapshot.breakdown)

        summary = MonthlyEVReportSummary(
            month: selectedMonth,
            monthTitle: monthLabel(for: selectedMonth),
            totalEnergyKWh: snapshot.monthlyTotalEnergy,
            sessionCount: snapshot.monthlySessionCount,
            totalCost: snapshot.monthlyTotalCost,
            averageTLPerKWh: averageTLPerKWh,
            tlPer100Km: snapshot.tlPer100Km,
            chargeDistribution: monthlyDistribution,
            gasolineSavingsPercent: snapshot.gasolineSavingsPercent,
            gasolineSavingsAmount: snapshot.gasolineSavingsAmount,
            currencyCode: snapshot.currencyCode
        )

        #if os(iOS)
        renderShareCard()
        #endif
    }

    #if os(iOS)
    public func renderShareCard() {
        guard let summary else {
            shareImage = nil
            return
        }

        shareImage = shareRenderer.render(
            summary: summary,
            configuration: MonthlySummaryRenderConfiguration(
                aspectRatio: exportAspectRatio,
                colorScheme: .dark
            )
        )
    }
    #endif

    private func buildDistribution(from breakdown: [CostBreakdown]) -> MonthlyChargeDistribution {
        let totalSessions = breakdown.reduce(0) { $0 + $1.sessionCount }
        guard totalSessions > 0 else {
            return MonthlyChargeDistribution(homeRatio: 0, acRatio: 0, dcRatio: 0)
        }

        let homeCount = breakdown.first(where: { $0.method == .home })?.sessionCount ?? 0
        let acCount = breakdown.first(where: { $0.method == .publicAC })?.sessionCount ?? 0
        let dcCount = breakdown.first(where: { $0.method == .publicDC })?.sessionCount ?? 0

        return MonthlyChargeDistribution(
            homeRatio: (Double(homeCount) / Double(totalSessions)) * 100,
            acRatio: (Double(acCount) / Double(totalSessions)) * 100,
            dcRatio: (Double(dcCount) / Double(totalSessions)) * 100
        )
    }

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
}
