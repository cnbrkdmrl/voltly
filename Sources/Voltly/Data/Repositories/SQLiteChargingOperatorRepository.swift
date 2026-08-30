import Foundation

#if canImport(SQLite3)
import SQLite3

public final class SQLiteChargingOperatorRepository: ChargingOperatorRepository {
    private enum Constants {
        static let databaseFileName = "voltly.sqlite3"
        static let seedVersionMetaKey = "charging_operators_seed_version"
    }

    private enum SQLiteValue {
        case int(Int64)
        case text(String)
        case null
    }

    private struct SeedPayload: Decodable {
        let seedVersion: Int
        let operators: [SeedOperator]

        enum CodingKeys: String, CodingKey {
            case seedVersion = "seed_version"
            case operators
        }
    }

    private struct SeedOperator: Decodable {
        let operatorCode: String
        let displayName: String
        let searchAliases: [String]
        let countryCode: String
        let tier: Int
        let stationCountEstimate: Int?
        let stationCountConfidence: String?
        let supportsRoaming: Bool?
        let appRequired: Bool
        let isActive: Bool
        let sortOrder: Int
        let sourceBasis: String?
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case operatorCode = "operator_code"
            case displayName = "display_name"
            case searchAliases = "search_aliases"
            case countryCode = "country_code"
            case tier
            case stationCountEstimate = "station_count_estimate"
            case stationCountConfidence = "station_count_confidence"
            case supportsRoaming = "supports_roaming"
            case appRequired = "app_required"
            case isActive = "is_active"
            case sortOrder = "sort_order"
            case sourceBasis = "source_basis"
            case notes
        }
    }

    private var db: OpaquePointer?

    public init(databaseURL: URL? = nil) throws {
        let resolvedURL = try databaseURL ?? Self.defaultDatabaseURL()
        try Self.ensureParentDirectory(for: resolvedURL)
        try openDatabase(at: resolvedURL)
        try execute("PRAGMA foreign_keys = ON;")
        try runMigrations()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    public func visibleOperators() throws -> [ChargingOperator] {
        try loadOperators(
            whereClause: "WHERE is_active = 1 AND is_hidden = 0",
            bindings: []
        )
    }

    public func favoriteOperators() throws -> [ChargingOperator] {
        try loadOperators(
            whereClause: "WHERE is_active = 1 AND is_hidden = 0 AND is_favorite = 1",
            bindings: []
        )
    }

    public func hiddenOperators() throws -> [ChargingOperator] {
        try loadOperators(
            whereClause: "WHERE is_hidden = 1",
            bindings: []
        )
    }

    public func `operator`(byCode code: String) throws -> ChargingOperator? {
        let normalized = Self.normalizeCode(code)
        let sql = """
        SELECT id, operator_code, display_name, search_aliases_json, country_code, tier, station_count_estimate, station_count_confidence, supports_roaming, app_required, is_active, is_favorite, favorite_order, is_hidden, sort_order, source_basis, notes, created_at, updated_at
        FROM charging_operators
        WHERE lower(operator_code) = lower(?)
        LIMIT 1;
        """
        return try queryOperators(sql: sql, bindings: [.text(normalized)]).first
    }

    public func seedIfNeeded() throws {
        let seed = try loadSeed()
        let currentVersion = try seedVersion()
        guard seed.seedVersion > currentVersion else { return }

        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            for item in seed.operators {
                let aliasesData = try JSONEncoder().encode(item.searchAliases)
                let aliasesJSON = String(data: aliasesData, encoding: .utf8) ?? "[]"
                let sql = """
                INSERT INTO charging_operators (
                    operator_code,
                    display_name,
                    search_aliases_json,
                    country_code,
                    tier,
                    station_count_estimate,
                    station_count_confidence,
                    supports_roaming,
                    app_required,
                    is_active,
                    sort_order,
                    source_basis,
                    notes
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(operator_code) DO UPDATE SET
                    display_name = excluded.display_name,
                    search_aliases_json = excluded.search_aliases_json,
                    country_code = excluded.country_code,
                    tier = excluded.tier,
                    station_count_estimate = excluded.station_count_estimate,
                    station_count_confidence = excluded.station_count_confidence,
                    supports_roaming = excluded.supports_roaming,
                    app_required = excluded.app_required,
                    is_active = excluded.is_active,
                    sort_order = excluded.sort_order,
                    source_basis = excluded.source_basis,
                    notes = excluded.notes,
                    updated_at = CURRENT_TIMESTAMP;
                """

                try execute(
                    sql,
                    bindings: [
                        .text(Self.normalizeCode(item.operatorCode)),
                        .text(item.displayName),
                        .text(aliasesJSON),
                        .text(item.countryCode),
                        .int(Int64(item.tier)),
                        item.stationCountEstimate.map { .int(Int64($0)) } ?? .null,
                        item.stationCountConfidence.map { .text($0) } ?? .null,
                        item.supportsRoaming.map { .int($0 ? 1 : 0) } ?? .null,
                        .int(item.appRequired ? 1 : 0),
                        .int(item.isActive ? 1 : 0),
                        .int(Int64(item.sortOrder)),
                        item.sourceBasis.map { .text($0) } ?? .null,
                        item.notes.map { .text($0) } ?? .null
                    ]
                )
            }

            try setSeedVersion(seed.seedVersion)
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    public func setFavorite(operatorCode: String, isFavorite: Bool) throws {
        let code = Self.normalizeCode(operatorCode)
        if isFavorite {
            let nextOrder = try nextFavoriteOrder()
            let sql = """
            UPDATE charging_operators
            SET
                is_favorite = 1,
                favorite_order = COALESCE(favorite_order, ?),
                updated_at = CURRENT_TIMESTAMP
            WHERE operator_code = ?;
            """
            try execute(sql, bindings: [.int(Int64(nextOrder)), .text(code)])
        } else {
            let sql = """
            UPDATE charging_operators
            SET
                is_favorite = 0,
                favorite_order = NULL,
                updated_at = CURRENT_TIMESTAMP
            WHERE operator_code = ?;
            """
            try execute(sql, bindings: [.text(code)])
        }
    }

    public func setHidden(operatorCode: String, isHidden: Bool) throws {
        let code = Self.normalizeCode(operatorCode)
        let sql = """
        UPDATE charging_operators
        SET
            is_hidden = ?,
            is_favorite = CASE WHEN ? = 1 THEN 0 ELSE is_favorite END,
            favorite_order = CASE WHEN ? = 1 THEN NULL ELSE favorite_order END,
            updated_at = CURRENT_TIMESTAMP
        WHERE operator_code = ?;
        """
        let hiddenFlag: Int64 = isHidden ? 1 : 0
        try execute(
            sql,
            bindings: [
                .int(hiddenFlag),
                .int(hiddenFlag),
                .int(hiddenFlag),
                .text(code)
            ]
        )
    }

    private func runMigrations() throws {
        let sqlURL = Self.resourceURL(
            forResource: "001_create_charging_operators",
            withExtension: "sql",
            subdirectory: "SQL"
        )
        guard let sqlURL else {
            throw NSError(domain: "SQLiteChargingOperatorRepository", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "Migration dosyasi bulunamadi."
            ])
        }

        let sql = try String(contentsOf: sqlURL, encoding: .utf8)
        try executeScript(sql)
    }

    private func loadSeed() throws -> SeedPayload {
        let seedURL = Self.resourceURL(
            forResource: "charging_operators_seed_v1",
            withExtension: "json",
            subdirectory: "Seeds"
        )
        guard let seedURL else {
            throw NSError(domain: "SQLiteChargingOperatorRepository", code: 1002, userInfo: [
                NSLocalizedDescriptionKey: "Operator seed dosyasi bulunamadi."
            ])
        }
        let data = try Data(contentsOf: seedURL)
        return try JSONDecoder().decode(SeedPayload.self, from: data)
    }

    private func seedVersion() throws -> Int {
        let sql = "SELECT value FROM app_meta WHERE key = ? LIMIT 1;"
        let values = try queryText(sql: sql, bindings: [.text(Constants.seedVersionMetaKey)])
        guard let value = values.first, let intValue = Int(value) else { return 0 }
        return intValue
    }

    private func setSeedVersion(_ version: Int) throws {
        let sql = """
        INSERT INTO app_meta (key, value, updated_at)
        VALUES (?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(key) DO UPDATE SET
            value = excluded.value,
            updated_at = CURRENT_TIMESTAMP;
        """
        try execute(sql, bindings: [.text(Constants.seedVersionMetaKey), .text(String(version))])
    }

    private func nextFavoriteOrder() throws -> Int {
        let sql = "SELECT COALESCE(MAX(favorite_order), 0) + 1 FROM charging_operators WHERE is_favorite = 1;"
        guard let value = try queryInt(sql: sql, bindings: []).first else { return 1 }
        return Int(value)
    }

    private func loadOperators(whereClause: String, bindings: [SQLiteValue]) throws -> [ChargingOperator] {
        let sql = """
        SELECT id, operator_code, display_name, search_aliases_json, country_code, tier, station_count_estimate, station_count_confidence, supports_roaming, app_required, is_active, is_favorite, favorite_order, is_hidden, sort_order, source_basis, notes, created_at, updated_at
        FROM charging_operators
        \(whereClause)
        ORDER BY
            is_favorite DESC,
            CASE WHEN favorite_order IS NULL THEN 1 ELSE 0 END ASC,
            favorite_order ASC,
            tier ASC,
            sort_order ASC,
            display_name COLLATE NOCASE ASC;
        """
        return try queryOperators(sql: sql, bindings: bindings)
    }

    private func queryOperators(sql: String, bindings: [SQLiteValue]) throws -> [ChargingOperator] {
        var statement: OpaquePointer?
        try prepare(sql: sql, statement: &statement)
        defer { sqlite3_finalize(statement) }
        try bind(values: bindings, to: statement)

        var operators: [ChargingOperator] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int64(statement, 0)
            let operatorCode = textValue(statement: statement, index: 1) ?? ""
            let displayName = textValue(statement: statement, index: 2) ?? ""
            let aliasesJSON = textValue(statement: statement, index: 3) ?? "[]"
            let countryCode = textValue(statement: statement, index: 4) ?? "TR"
            let tier = Int(sqlite3_column_int(statement, 5))
            let stationCountEstimate = intValue(statement: statement, index: 6).map(Int.init)
            let stationCountConfidence = textValue(statement: statement, index: 7)
            let supportsRoaming = intValue(statement: statement, index: 8).map { $0 == 1 }
            let appRequired = sqlite3_column_int(statement, 9) == 1
            let isActive = sqlite3_column_int(statement, 10) == 1
            let isFavorite = sqlite3_column_int(statement, 11) == 1
            let favoriteOrder = intValue(statement: statement, index: 12).map(Int.init)
            let isHidden = sqlite3_column_int(statement, 13) == 1
            let sortOrder = Int(sqlite3_column_int(statement, 14))
            let sourceBasis = textValue(statement: statement, index: 15)
            let notes = textValue(statement: statement, index: 16)
            let createdAt = textValue(statement: statement, index: 17) ?? ""
            let updatedAt = textValue(statement: statement, index: 18) ?? ""

            let aliases = (try? JSONDecoder().decode([String].self, from: Data(aliasesJSON.utf8))) ?? []

            operators.append(
                ChargingOperator(
                    id: id,
                    operatorCode: operatorCode,
                    displayName: displayName,
                    searchAliases: aliases,
                    countryCode: countryCode,
                    tier: tier,
                    stationCountEstimate: stationCountEstimate,
                    stationCountConfidence: stationCountConfidence,
                    supportsRoaming: supportsRoaming,
                    appRequired: appRequired,
                    isActive: isActive,
                    isFavorite: isFavorite,
                    favoriteOrder: favoriteOrder,
                    isHidden: isHidden,
                    sortOrder: sortOrder,
                    sourceBasis: sourceBasis,
                    notes: notes,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            )
        }
        return operators
    }

    private func queryText(sql: String, bindings: [SQLiteValue]) throws -> [String] {
        var statement: OpaquePointer?
        try prepare(sql: sql, statement: &statement)
        defer { sqlite3_finalize(statement) }
        try bind(values: bindings, to: statement)

        var result: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = textValue(statement: statement, index: 0) {
                result.append(text)
            }
        }
        return result
    }

    private func queryInt(sql: String, bindings: [SQLiteValue]) throws -> [Int64] {
        var statement: OpaquePointer?
        try prepare(sql: sql, statement: &statement)
        defer { sqlite3_finalize(statement) }
        try bind(values: bindings, to: statement)

        var result: [Int64] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(sqlite3_column_int64(statement, 0))
        }
        return result
    }

    private func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
        var statement: OpaquePointer?
        try prepare(sql: sql, statement: &statement)
        defer { sqlite3_finalize(statement) }
        try bind(values: bindings, to: statement)

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_DONE || stepResult == SQLITE_ROW else {
            throw sqliteError(code: stepResult, sql: sql)
        }
    }

    private func executeScript(_ sql: String) throws {
        guard let db else {
            throw NSError(domain: "SQLiteChargingOperatorRepository", code: 1003, userInfo: [
                NSLocalizedDescriptionKey: "SQLite baglantisi acik degil."
            ])
        }

        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorPointer)
        guard result == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? "Bilinmeyen SQLite script hatasi"
            sqlite3_free(errorPointer)
            throw NSError(
                domain: "SQLiteChargingOperatorRepository",
                code: Int(result),
                userInfo: [
                    NSLocalizedDescriptionKey: "SQLite script hata (\(result)): \(message)"
                ]
            )
        }
    }

    private func prepare(sql: String, statement: inout OpaquePointer?) throws {
        guard let db else {
            throw NSError(domain: "SQLiteChargingOperatorRepository", code: 1003, userInfo: [
                NSLocalizedDescriptionKey: "SQLite baglantisi acik degil."
            ])
        }

        let prepareResult = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK else {
            throw sqliteError(code: prepareResult, sql: sql)
        }
    }

    private func bind(values: [SQLiteValue], to statement: OpaquePointer?) throws {
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case .int(let number):
                result = sqlite3_bind_int64(statement, index, number)
            case .text(let string):
                result = sqlite3_bind_text(statement, index, string, -1, SQLITE_TRANSIENT)
            case .null:
                result = sqlite3_bind_null(statement, index)
            }

            guard result == SQLITE_OK else {
                throw sqliteError(code: result, sql: "bind")
            }
        }
    }

    private func textValue(statement: OpaquePointer?, index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }

    private func intValue(statement: OpaquePointer?, index: Int32) -> Int64? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_int64(statement, index)
    }

    private func openDatabase(at url: URL) throws {
        var handle: OpaquePointer?
        let result = sqlite3_open_v2(
            url.path,
            &handle,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard result == SQLITE_OK else {
            if let handle {
                sqlite3_close(handle)
            }
            throw sqliteError(code: result, sql: "open")
        }

        db = handle
    }

    private static func defaultDatabaseURL() throws -> URL {
        let baseDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDirectory = baseDirectory.appendingPathComponent("Voltly", isDirectory: true)
        try ensureParentDirectory(for: appDirectory.appendingPathComponent(Constants.databaseFileName))
        return appDirectory.appendingPathComponent(Constants.databaseFileName)
    }

    private static func ensureParentDirectory(for url: URL) throws {
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private static func normalizeCode(_ code: String) -> String {
        code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func resourceURL(
        forResource name: String,
        withExtension ext: String,
        subdirectory: String? = nil
    ) -> URL? {
        for bundle in resourceBundles {
            if let subdirectory,
               let url = bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private static var resourceBundles: [Bundle] {
        var bundles: [Bundle] = []
        #if SWIFT_PACKAGE
        bundles.append(.module)
        #else
        bundles.append(Bundle(for: SQLiteChargingOperatorRepository.self))
        #endif
        bundles.append(.main)
        return bundles
    }

    private func sqliteError(code: Int32, sql: String) -> Error {
        let message = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Bilinmeyen SQLite hatasi"
        return NSError(
            domain: "SQLiteChargingOperatorRepository",
            code: Int(code),
            userInfo: [
                NSLocalizedDescriptionKey: "SQLite hata (\(code)): \(message)",
                "sql": sql
            ]
        )
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

#else

public final class SQLiteChargingOperatorRepository: ChargingOperatorRepository {
    private let fallback = InMemoryChargingOperatorRepository()

    public init(databaseURL: URL? = nil) throws {
        _ = databaseURL
    }

    public func visibleOperators() throws -> [ChargingOperator] {
        try fallback.visibleOperators()
    }

    public func favoriteOperators() throws -> [ChargingOperator] {
        try fallback.favoriteOperators()
    }

    public func hiddenOperators() throws -> [ChargingOperator] {
        try fallback.hiddenOperators()
    }

    public func `operator`(byCode code: String) throws -> ChargingOperator? {
        try fallback.operator(byCode: code)
    }

    public func seedIfNeeded() throws {
        try fallback.seedIfNeeded()
    }

    public func setFavorite(operatorCode: String, isFavorite: Bool) throws {
        try fallback.setFavorite(operatorCode: operatorCode, isFavorite: isFavorite)
    }

    public func setHidden(operatorCode: String, isHidden: Bool) throws {
        try fallback.setHidden(operatorCode: operatorCode, isHidden: isHidden)
    }
}

#endif
