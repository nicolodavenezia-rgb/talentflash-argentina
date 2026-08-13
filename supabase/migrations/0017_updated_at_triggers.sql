-- Complemento del Bloque A: aplica la convención de DATA_MODEL.md §1
-- (updated_at mantenido por trigger) a toda tabla que tenga la columna.
do $$
declare t record;
begin
  for t in
    select c.table_name
    from information_schema.columns c
    join pg_tables p on p.tablename = c.table_name and p.schemaname = 'public'
    where c.table_schema = 'public' and c.column_name = 'updated_at'
  loop
    execute format('drop trigger if exists set_updated_at on %I', t.table_name);
    execute format(
      'create trigger set_updated_at before update on %I for each row execute function set_updated_at()',
      t.table_name);
  end loop;
end $$;
