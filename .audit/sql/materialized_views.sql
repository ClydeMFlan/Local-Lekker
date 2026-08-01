select schemaname as schema_name, matviewname as view_name, definition
from pg_matviews
where schemaname in ('public','auth','storage')
order by schemaname, matviewname;
