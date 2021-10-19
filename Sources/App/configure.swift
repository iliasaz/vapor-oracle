import Fluent
import FluentSQLiteDriver
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    
    let port: Int = 8080
    app.http.server.configuration.port = port
    
    // register Database connection pool
    let tnsName: String = Environment.get("TNS_NAME") ?? "default_tns_alias"
    let dbUser: String = Environment.get("DATABASE_USER") ?? "default_user_name"
    let dbPassword: String = Environment.get("DATABASE_PASSW") ?? "default_password"
    let maxConn: Int = Int( Environment.get("ORAPOOL_MAXCONN") ?? "3" ) ?? 3
    
    app.oraConnPool = OraConnectionPool(tnsAlias: tnsName, username: dbUser, password: dbPassword, maxConn: maxConn)
    app.oraConnPool.pool.statementCacheSize = 10
    app.routes.defaultMaxBodySize = "10mb"
    app.http.server.configuration.responseCompression = .enabled
    app.http.server.configuration.requestDecompression = .enabled
    // register routes
    try routes(app)
}
