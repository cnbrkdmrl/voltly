import Foundation

@MainActor
public final class VehicleSetupViewModel: ObservableObject {
    private enum Catalog {
        static let defaultTrimLabel = "Standart"
    }

    @Published public private(set) var vehicles: [Vehicle] = []
    @Published public var selectedBrand: String = ""
    @Published public var selectedModel: String = ""
    @Published public var selectedTrim: String = Catalog.defaultTrimLabel
    @Published public var selectedYear: Int = Calendar.current.component(.year, from: .now)
    @Published public var colorCode: String = ""
    @Published public private(set) var message: String?

    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
        bootstrapDefaults()
        loadVehicles()
    }

    public var availableBrands: [String] {
        Array(Set(environment.vehicleCatalog.all().map(\.brand))).sorted()
    }

    public var pickerBrands: [String] {
        mergedPickerItems(availableBrands, selected: selectedBrand, allowEmptySelection: false)
    }

    public var availableModels: [String] {
        Array(Set(environment.vehicleCatalog
            .all()
            .filter { $0.brand == selectedBrand }
            .map(\.model)))
            .sorted()
    }

    public var pickerModels: [String] {
        mergedPickerItems(availableModels, selected: selectedModel, allowEmptySelection: false)
    }

    public var availableTrims: [String] {
        let trims = Array(Set(environment.vehicleCatalog
            .all()
            .filter { $0.brand == selectedBrand && $0.model == selectedModel }
            .map { normalizedTrimLabel(for: $0) }))
        return sortTrims(trims)
    }

    public var pickerTrims: [String] {
        mergedPickerItems(availableTrims, selected: selectedTrim, allowEmptySelection: false)
    }

    public var availableYears: [Int] {
        Array(Set(environment.vehicleCatalog
            .all()
            .filter {
                $0.brand == selectedBrand &&
                $0.model == selectedModel &&
                normalizedTrimLabel(for: $0) == selectedTrim
            }
            .map(\.year)))
            .sorted(by: >)
    }

    public var pickerYears: [Int] {
        mergedPickerItems(availableYears, selected: selectedYear)
    }

    public var selectedSpec: ReferenceVehicleSpec? {
        environment.vehicleCatalog.find(
            brand: selectedBrand,
            model: selectedModel,
            trim: selectedTrim == Catalog.defaultTrimLabel ? nil : selectedTrim,
            year: selectedYear
        )
    }

    public var resolvedBatteryCapacityKWh: Double? {
        selectedSpec?.batteryCapacityKWh
    }

    public var resolvedACMaxChargingKW: Double? {
        selectedSpec?.acMaxChargingKW
    }

    public var resolvedDCMaxChargingKW: Double? {
        selectedSpec?.dcMaxChargingKW
    }

    public var resolvedAverageConsumptionKWhPer100KM: Double? {
        selectedSpec?.factoryConsumptionKWh100km
    }

    public func onBrandChanged() {
        if !availableModels.contains(selectedModel) {
            selectedModel = availableModels.first ?? ""
        }
        if !availableTrims.contains(selectedTrim) {
            selectedTrim = availableTrims.first ?? Catalog.defaultTrimLabel
        }
        if !availableYears.contains(selectedYear) {
            selectedYear = availableYears.first ?? Calendar.current.component(.year, from: .now)
        }
    }

    public func onModelChanged() {
        if !availableTrims.contains(selectedTrim) {
            selectedTrim = availableTrims.first ?? Catalog.defaultTrimLabel
        }
        if !availableYears.contains(selectedYear) {
            selectedYear = availableYears.first ?? Calendar.current.component(.year, from: .now)
        }
    }

    public func onTrimChanged() {
        if !availableYears.contains(selectedYear) {
            selectedYear = availableYears.first ?? Calendar.current.component(.year, from: .now)
        }
    }

    public func onYearChanged() {
        // Model yılı değişiminde selectedSpec otomatik güncellenir.
    }

    public func loadVehicles() {
        do {
            vehicles = try environment.vehicleRepository.fetchVehicles()
        } catch {
            message = error.localizedDescription
        }
    }

    public func saveVehicle() {
        guard let spec = selectedSpec else {
            message = "Seçilen araç için teknik veri bulunamadı"
            Haptics.error()
            return
        }

        let persistedModel = persistedModelName()
        let vehicle = Vehicle(
            brand: selectedBrand,
            model: persistedModel,
            year: selectedYear,
            enginePowerHP: spec.enginePowerHP,
            enginePowerKW: spec.enginePowerKW,
            acMaxChargingKW: spec.acMaxChargingKW,
            dcMaxChargingKW: spec.dcMaxChargingKW,
            batteryCapacityKWh: spec.batteryCapacityKWh,
            factoryConsumptionKWh100km: spec.factoryConsumptionKWh100km,
            colorCode: colorCode.isEmpty ? nil : colorCode,
            silhouetteKey: spec.silhouetteKey
        )

        do {
            try environment.createVehicleUseCase.execute(vehicle)
            environment.analytics.track(.vehicleCreated)
            message = "Araç kaydedildi."
            Haptics.success()
            loadVehicles()
        } catch {
            message = error.localizedDescription
            Haptics.error()
        }
    }

    public func setActive(_ vehicle: Vehicle) {
        do {
            try environment.setActiveVehicleUseCase.execute(id: vehicle.id)
            Haptics.selection()
            loadVehicles()
        } catch {
            message = error.localizedDescription
            Haptics.error()
        }
    }

    public func delete(_ vehicle: Vehicle) {
        do {
            try environment.deleteVehicleUseCase.execute(vehicleID: vehicle.id)
            message = nil
            Haptics.success()
            loadVehicles()
        } catch DeleteVehicleError.hasSessions {
            message = "Bu araca ait sarj kaydi oldugu icin silinemez"
            Haptics.error()
        } catch {
            message = error.localizedDescription
            Haptics.error()
        }
    }

    private func normalizedTrimLabel(for spec: ReferenceVehicleSpec) -> String {
        let raw = spec.trim?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (raw?.isEmpty ?? true) ? Catalog.defaultTrimLabel : raw!
    }

    private func sortTrims(_ trims: [String]) -> [String] {
        trims.sorted { lhs, rhs in
            if lhs == Catalog.defaultTrimLabel { return true }
            if rhs == Catalog.defaultTrimLabel { return false }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private func persistedModelName() -> String {
        selectedTrim == Catalog.defaultTrimLabel ? selectedModel : "\(selectedModel) \(selectedTrim)"
    }

    private func bootstrapDefaults() {
        selectedBrand = availableBrands.first ?? ""
        selectedModel = availableModels.first ?? ""
        selectedTrim = availableTrims.first ?? Catalog.defaultTrimLabel
        selectedYear = availableYears.first ?? Calendar.current.component(.year, from: .now)
    }

    private func mergedPickerItems<T: Equatable>(_ items: [T], selected: T) -> [T] {
        guard !items.contains(selected) else { return items }
        return [selected] + items
    }

    private func mergedPickerItems(_ items: [String], selected: String, allowEmptySelection: Bool) -> [String] {
        let normalized = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty && !allowEmptySelection {
            return items
        }
        guard !items.contains(selected) else { return items }
        return [selected] + items
    }
}
