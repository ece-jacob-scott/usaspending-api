ALTER MATERIALIZED VIEW IF EXISTS summary_view_psc_codes RENAME TO summary_view_psc_codes_old;
ALTER INDEX IF EXISTS idx_230a1cf1$508_deterministic_unique_hash RENAME TO idx_230a1cf1$508_deterministic_unique_hash_old;
ALTER INDEX IF EXISTS idx_230a1cf1$508_action_date RENAME TO idx_230a1cf1$508_action_date_old;
ALTER INDEX IF EXISTS idx_230a1cf1$508_type RENAME TO idx_230a1cf1$508_type_old;
ALTER INDEX IF EXISTS idx_230a1cf1$508_pulled_from RENAME TO idx_230a1cf1$508_pulled_from_old;

ALTER MATERIALIZED VIEW summary_view_psc_codes_temp RENAME TO summary_view_psc_codes;
ALTER INDEX idx_230a1cf1$508_deterministic_unique_hash_temp RENAME TO idx_230a1cf1$508_deterministic_unique_hash;
ALTER INDEX idx_230a1cf1$508_action_date_temp RENAME TO idx_230a1cf1$508_action_date;
ALTER INDEX idx_230a1cf1$508_type_temp RENAME TO idx_230a1cf1$508_type;
ALTER INDEX idx_230a1cf1$508_pulled_from_temp RENAME TO idx_230a1cf1$508_pulled_from;
