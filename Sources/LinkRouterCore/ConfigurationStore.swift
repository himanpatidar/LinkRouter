import Foundation
import CSQLite

/// Stores configuration only. URLs and routing history are never written to disk.
public final class ConfigurationStore {
    private var db: OpaquePointer?
    public init(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK { throw failure() }
        guard sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS configuration (id INTEGER PRIMARY KEY CHECK(id = 1), payload BLOB NOT NULL)", nil, nil, nil) == SQLITE_OK else { throw failure() }
        if path != ":memory:" { try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path) }
    }
    deinit { sqlite3_close(db) }
    public func load() throws -> Configuration {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT payload FROM configuration WHERE id = 1", -1, &stmt, nil) == SQLITE_OK else { throw failure() }
        defer { sqlite3_finalize(stmt) }
        let step = sqlite3_step(stmt)
        if step == SQLITE_DONE { return Configuration() }
        guard step == SQLITE_ROW, let bytes = sqlite3_column_blob(stmt, 0) else { throw failure() }
        return try JSONDecoder().decode(Configuration.self, from: Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 0))))
    }
    public func save(_ value: Configuration) throws {
        let data = try JSONEncoder().encode(value)
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO configuration (id, payload) VALUES (1, ?)", -1, &stmt, nil) == SQLITE_OK else { throw failure() }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let bound = data.withUnsafeBytes { sqlite3_bind_blob(stmt, 1, $0.baseAddress, Int32(data.count), transient) }
        guard bound == SQLITE_OK, sqlite3_step(stmt) == SQLITE_DONE else { throw failure() }
    }
    private func failure() -> NSError { NSError(domain: "LinkRouter.Storage", code: Int(sqlite3_errcode(db)), userInfo: [NSLocalizedDescriptionKey: db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open local settings"]) }
}
