CREATE UNIQUE INDEX idx_230a1cf1$2b6_deterministic_unique_hash_temp ON summary_view_naics_codes_temp USING BTREE(duh) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$2b6_action_date_temp ON summary_view_naics_codes_temp USING BTREE(action_date DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$2b6_type_temp ON summary_view_naics_codes_temp USING BTREE(type) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$2b6_naics_temp ON summary_view_naics_codes_temp USING BTREE(naics_code) WITH (fillfactor = 97) WHERE naics_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$2b6_pulled_from_temp ON summary_view_naics_codes_temp USING BTREE(pulled_from) WITH (fillfactor = 97) WHERE pulled_from IS NOT NULL;
