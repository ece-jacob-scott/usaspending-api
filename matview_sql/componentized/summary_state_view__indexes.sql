CREATE UNIQUE INDEX idx_230a1cf1$c3a_deterministic_unique_hash_temp ON summary_state_view_temp USING BTREE(duh) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$c3a_ordered_action_date_temp ON summary_state_view_temp USING BTREE(action_date DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$c3a_type_temp ON summary_state_view_temp USING BTREE(type) WITH (fillfactor = 97) WHERE type IS NOT NULL;
CREATE INDEX idx_230a1cf1$c3a_pulled_from_temp ON summary_state_view_temp USING BTREE(pulled_from) WITH (fillfactor = 97) WHERE pulled_from IS NOT NULL;
CREATE INDEX idx_230a1cf1$c3a_pop_country_code_temp ON summary_state_view_temp USING BTREE(pop_country_code) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$c3a_pop_state_code_temp ON summary_state_view_temp USING BTREE(pop_state_code) WITH (fillfactor = 97) WHERE pop_state_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$c3a_compound_geo_pop_temp ON summary_state_view_temp USING BTREE(pop_country_code, pop_state_code, action_date) WITH (fillfactor = 97);
