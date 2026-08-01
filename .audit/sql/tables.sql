select table_schema, table_name, table_type
from information_schema.tables
where table_schema in ('public','auth','storage')
order by table_schema, table_name;
