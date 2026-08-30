import Foundation

public enum SessionCSVExportError: LocalizedError, Equatable {
    case noSessions

    public var errorDescription: String? {
        switch self {
        case .noSessions:
            return "Dışa aktarılacak şarj kaydı bulunamadı."
        }
    }
}

public final class SessionsCSVExportService: SessionsCSVExportServiceProtocol {
    private let listSessionsUseCase: ListChargingSessionsUseCase
    private let vehicleRepository: any VehicleRepository
    private let rowMapper: SessionCSVRowMapper
    private let csvBuilder: CSVExportBuilder
    private let fileExportManager: FileExportManager
    private let dateProvider: () -> Date

    public init(
        listSessionsUseCase: ListChargingSessionsUseCase,
        vehicleRepository: any VehicleRepository,
        rowMapper: SessionCSVRowMapper = SessionCSVRowMapper(),
        csvBuilder: CSVExportBuilder = CSVExportBuilder(),
        fileExportManager: FileExportManager = FileExportManager(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.listSessionsUseCase = listSessionsUseCase
        self.vehicleRepository = vehicleRepository
        self.rowMapper = rowMapper
        self.csvBuilder = csvBuilder
        self.fileExportManager = fileExportManager
        self.dateProvider = dateProvider
    }

    public func exportChargingSessionsCSV(to directoryURL: URL? = nil) throws -> URL {
        // Repository yalnizca aktif (silinmemis) kayitlari dondurdugu icin direkt export edilir.
        let sessions = try listSessionsUseCase.execute(vehicleID: nil)
        guard !sessions.isEmpty else {
            throw SessionCSVExportError.noSessions
        }

        let vehicles = try vehicleRepository.fetchVehicles()
        let vehicleNamesByID = Dictionary(uniqueKeysWithValues: vehicles.map { vehicle in
            (vehicle.id, CSVValueFormatter.vehicleName(vehicle))
        })

        let sortedSessions = sessions.sorted {
            if $0.sessionDate == $1.sessionDate {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.sessionDate > $1.sessionDate
        }

        let rows = sortedSessions.map { session in
            rowMapper.makeRow(
                session: session,
                vehicleDisplayName: vehicleNamesByID[session.vehicleID]
            )
        }

        let csvText = csvBuilder.buildCSV(header: rowMapper.header, rows: rows)

        let descriptor = ExportFileDescriptor.sessionsCSV(at: dateProvider())
        let fileURL = try fileExportManager.makeFileURL(for: descriptor, in: directoryURL)
        try fileExportManager.write(csvText, to: fileURL)

        return fileURL
    }
}
