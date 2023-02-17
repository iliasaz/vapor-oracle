create or replace function get_refcursor(i_maxrows in number) return sys_refcursor as
cv sys_refcursor;
begin
open cv for select object_name, object_id from user_objects where rownum <= i_maxrows;
return cv;
end;
/


create or replace procedure squared(in_val in number, out_val out number) is
begin
out_val := in_val * in_val;
end;
/

select object_name, object_id, object_type from user_objects;

create or replace procedure  outbindrefcursor(in_limit in number, result out sys_refcursor) is
  sqlqry varchar2(1000);
begin
--  sqlqry := 'select object_name, object_id, object_type from user_objects where rownum <= ' || in_limit;
--  open result for sqlqry;
open result for select object_name, object_id, object_type from user_objects where rownum <= in_limit;
--dbms_sql.return_result(result);
end;
/


var out_cur refcursor
begin outbindrefcursor(5, :out_cur); end;
/
print out_Cur


-- Basic Auth example

create table app_users (username varchar2(128), passwd varchar2(255), passwd_hash varchar2(1024), paswd_salt varchar2(128));
-- very basic example, password is stored as clear text. DO NOT use in production!!
insert into app_users(username, passwd) values('vapor','secret');
commit;

-- more advanced example. we don't store the password in the database. instead we store SHA512 has of the password with salt, and the salt itself. the salt should be different for each user.
-- make sure to grant execute on dbms_crypto to <schema_owner>
create table app_users2 (username varchar2(128), passwd_hash varchar2(1024), passwd_salt varchar2(128));
insert into app_users2(username, passwd_hash, passwd_salt) values('vapor', dbms_crypto.hash(utl_i18n.string_to_raw('secret' || 'uhadnrgpcuihn1238^$#', 'AL32UTF8'), 6), 'uhadnrgpcuihn1238^$#');
commit;

