select event_object_schema as table_schema,
       event_object_table as table_name,
       trigger_name,
       event_manipulation,
       action_timing,
       action_statement
from information_schema.triggers
where trigger_schema in ('public','auth','storage')
order by event_object_schema, event_object_table, trigger_name;
