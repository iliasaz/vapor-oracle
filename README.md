# vapor-oracle
A sample application showcasing Vapor 4 connecting to an Oracle database using SwiftOracle package.

In this Vapor application, we create a Connection pool with multithreaded option in OCILIB, and then we inject it into Vapor request using StorageKey protocol and an extension of the Application class.  
Each request thread gets its own connection from the pool (already created at the app startup.)   
The connection pool can be configured with a minimum and a maximum number of connections so that each request doesn't have to establish a new database connection.  

The following environment variables should be configured:
- ORACLE_HOME=path_to_instantclient_XX, for example /Users/myuser/instantclient_19_8
- TNS_ADMIN=path_to_a_directory_with_tnsnames.ora_file, for example, /Users/myuser/instantclient_19_8/network/admin/
- LD_LIBRARY_PATH=path_to_instantclient_XX:path_to_OCILIB_libraries, for example: /Users/myuser/instantclient_19_8:/usr/local/lib
- TNS_NAME=database_tns_alias_from_tnsnames.ora
- DATABASE_USER=db_user
- DATABASE_PASSW=db_password
- LOG_LEVEL=debug, trace, info - see Vapor docs

Added two examples of Basic Authentication using database stored credentials and a connection pool
