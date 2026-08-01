select n.nspname as schema_name,
       c.conname as constraint_name,
       conrelid::regclass::text as source_table,
       confrelid::regclass::text as target_table,
       pg_get_constraintdef(c.oid) as definition
from pg_constraint c
join pg_namespace n on n.oid = c.connamespace
where c.contype = 'f' and n.nspname in ('public','auth','storage')
order by n.nspname, conrelid::regclass::text, c.conname;
