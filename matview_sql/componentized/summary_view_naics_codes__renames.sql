ALTER MATERIALIZED VIEW IF EXISTS summary_view_naics_codes RENAME TO summary_view_naics_codes_old;
ALTER INDEX IF EXISTS idx_230a1cf1$2b6_deterministic_unique_hash RENAME TO idx_230a1cf1$2b6_deterministic_unique_hash_old;
ALTER INDEX IF EXISTS idx_230a1cf1$2b6_action_date RENAME TO idx_230a1cf1$2b6_action_date_old;
ALTER INDEX IF EXISTS idx_230a1cf1$2b6_type RENAME TO idx_230a1cf1$2b6_type_old;
ALTER INDEX IF EXISTS idx_230a1cf1$2b6_naics RENAME TO idx_230a1cf1$2b6_naics_old;
ALTER INDEX IF EXISTS idx_230a1cf1$2b6_pulled_from RENAME TO idx_230a1cf1$2b6_pulled_from_old;

ALTER MATERIALIZED VIEW summary_view_naics_codes_temp RENAME TO summary_view_naics_codes;
ALTER INDEX idx_230a1cf1$2b6_deterministic_unique_hash_temp RENAME TO idx_230a1cf1$2b6_deterministic_unique_hash;
ALTER INDEX idx_230a1cf1$2b6_action_date_temp RENAME TO idx_230a1cf1$2b6_action_date;
ALTER INDEX idx_230a1cf1$2b6_type_temp RENAME TO idx_230a1cf1$2b6_type;
ALTER INDEX idx_230a1cf1$2b6_naics_temp RENAME TO idx_230a1cf1$2b6_naics;
ALTER INDEX idx_230a1cf1$2b6_pulled_from_temp RENAME TO idx_230a1cf1$2b6_pulled_from;
