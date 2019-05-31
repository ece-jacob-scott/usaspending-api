CREATE UNIQUE INDEX idx_230a1cf1$4df_deterministic_unique_hash_temp ON summary_view_cfda_number_temp USING BTREE(duh) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$4df_action_date_temp ON summary_view_cfda_number_temp USING BTREE(action_date DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$4df_type_temp ON summary_view_cfda_number_temp USING BTREE(type) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$4df_pulled_from_temp ON summary_view_cfda_number_temp USING BTREE(pulled_from) WITH (fillfactor = 97) WHERE pulled_from IS NOT NULL;
