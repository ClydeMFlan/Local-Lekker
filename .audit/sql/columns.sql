select c.table_schema, c.table_name, c.column_name, c.ordinal_position,
       c.data_type, c.udt_name, c.is_nullable, c.column_default
from information_schema.columns c
where c.table_schema in ('public','auth','storage')
order by c.table_schema, c.table_name, c.ordinal_position;
