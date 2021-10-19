import Fluent
import Vapor
import SwiftOracle

let prefetchSize: Int = 100

func routes(_ app: Application) throws {

    app.get("get") { req -> String in
        var responseString = ""
        req.logger.debug("get request received")
        // getting the connection pool descriptor from the request
        let conn = req.oraConnPool.pool.getConnection(tag: "")
        // making sure to return the connection upon exit
        defer {
            req.oraConnPool.pool.returnConnection(conn: conn)
        }
        req.logger.debug("got connection from the pool; active connections: \(req.oraConnPool.pool.openedCount)")
        let cursor: SwiftOracle.Cursor
        do {
            cursor = try conn.cursor()
        } catch {
            responseString = "get API DB connection failure: \(error)"
            req.logger.error(Logger.Message(stringLiteral: responseString))
            return responseString
        }
        // setting up the context
        do {
            let sqlStr = "select object_name, object_type from user_objects order by object_type, object_name"
            req.logger.debug("get API running a query")
            try cursor.execute(sqlStr, prefetchSize: prefetchSize)
            // fetch the data
            while let row = cursor.nextSwifty() {
                for f in row.fields {
                    responseString += "\(f.toString)\t"
                }
                responseString += "\n"
            }
            
        } catch {
            responseString = "get API failed to execute a query, error: \(error)"
            req.logger.error(Logger.Message(stringLiteral: responseString))
            return responseString
        }
        return responseString
    }

    
    
}
