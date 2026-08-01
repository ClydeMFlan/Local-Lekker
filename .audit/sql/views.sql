select table_schema, table_name as view_name, view_definition
from information_schema.views
where table_schema in ('public','auth','storage')
order by table_schema, table_name;
