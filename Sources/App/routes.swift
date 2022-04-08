import Fluent
import Vapor
import SwiftOracle
import cocilib

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

    app.get("nestedcursor") { req -> String in
        var responseString = ""
        
        // Create a DB stored function that returns a REF cursor
        /*
         create or replace function get_refcursor(i_maxrows in number) return sys_refcursor as
         cv sys_refcursor;
         begin
         open cv for select object_name, object_id from user_objects where rownum <= i_maxrows;
         return cv;
         end;
         /
         */
        
        let sql = "select level as rnum, get_refcursor(level) as cv from dual connect by level < 6"
        
        let conn = req.oraConnPool.pool.getConnection(tag: "")
        // making sure to return the connection upon exit
        defer {
            req.oraConnPool.pool.returnConnection(conn: conn)
        }
        req.logger.debug("got connection from the pool; active connections: \(req.oraConnPool.pool.openedCount)")
        
        let mainCursor: SwiftOracle.Cursor
        do {
            mainCursor = try conn.cursor()
        } catch {
            responseString = "get API DB connection failure: \(error)"
            req.logger.error(Logger.Message(stringLiteral: responseString))
            return responseString
        }

        try mainCursor.execute(sql)
        req.logger.debug("executed main cursor")
        
        for r in mainCursor {
            responseString += "main cursor row number: \(r["RNUM"]!.int)\n"
            let cursorPtr = r["CV"]!.cursor
            let cur = try conn.cursor(statementPtr: cursorPtr)
            try cur.executePreparedStatement()
            responseString += "printing child cursor output\n"
            for r1 in cur {
                responseString += "object_name: \(r1["OBJECT_NAME"]!.string), object_id: \(r1["OBJECT_ID"]!.int)\n"
            }
        }
        
        return responseString
    }
    
    app.get("inoutbinds") { req -> String in
        // Create a DB stored procedure that returns a square of input value as an out variable
/*
        create or replace procedure squared(in_val in number, out_val out number) is
        begin
        out_val := in_val * in_val;
        end;
        /
*/
        var responseString = ""
        
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
        
        let value1 = 5 //this is the input code
        var value1var: Int32 = Int32(value1) // OCILIB call takes a mutable pointer, so need a var
        var value2: Int32 = 0 // value2 is the output code, currently set as 0 to initialize
        let sqlStr = "begin squared(:in_val, :out_val); end;" // my test proc returns value1*value1
        
        // using OCILIB manually
        cursor.reset()
        let prepared = OCI_Prepare(cursor.statementPointer, sqlStr)
        assert(prepared == 1)
        
        // bind variables, INOUT mode is the default in OCILIB
        OCI_BindInt(cursor.statementPointer, ":in_val", &value1var)
        OCI_BindInt(cursor.statementPointer, ":out_val", &value2)
        
        // execute
        let executed = OCI_Execute(cursor.statementPointer);
        if executed != 1 {
            throw DatabaseErrors.SQLError(DatabaseError(OCI_GetLastError()))
        }
        
        responseString += "out_value: \(value2)\n"  //prints out the 0 from above, doesn't display the corresponding code from the db
        return responseString
    }
    
    app.get("outbindrefcursor") { req -> String in
        // Create a DB stored procedure that returns a cursor as an out variable
/*
         create or replace procedure  outbindrefcursor(in_limit in number, result out sys_refcursor) is
         sqlqry varchar2(1000);
         begin
         sqlqry := 'select object_name, object_id, object_type from user_objects where rownum <= ' || in_limit;
         open result for sqlqry;
         end;
         /
*/
        var responseString = ""
        
        let conn = req.oraConnPool.pool.getConnection(tag: "")
        // making sure to return the connection upon exit
        defer {
            req.oraConnPool.pool.returnConnection(conn: conn)
        }
        req.logger.debug("got connection from the pool; active connections: \(req.oraConnPool.pool.openedCount)")
        
        let mainCursor: SwiftOracle.Cursor
        do {
            mainCursor = try conn.cursor()
        } catch {
            responseString = "get API DB connection failure: \(error)"
            req.logger.error(Logger.Message(stringLiteral: responseString))
            return responseString
        }
        
        let sqlStr = "declare c sys_refcursor; begin outbindrefcursor(:in_limit, c); dbms_sql.return_result(c); end;"
        
        let value1 = 5
        try mainCursor.execute(sqlStr, params: [":in_limit": BindVar(value1)])
        for r in mainCursor {
            responseString += "\(r["OBJECT_NAME"]!.string) \t \(r["OBJECT_ID"]!.int) \t \(r["OBJECT_TYPE"]!.string) \n"
        }
        
        return responseString
    }
}
