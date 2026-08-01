select schemaname as schema_name, tablename as table_name, indexname as index_name, indexdef
from pg_indexes
where schemaname in ('public','auth','storage')
order by schemaname, tablename, indexname;
