CREATE UNIQUE INDEX idx_230a1cf1$033_deterministic_unique_hash_temp ON summary_transaction_recipient_view_temp USING BTREE(duh) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$033_ordered_action_date_temp ON summary_transaction_recipient_view_temp USING BTREE(action_date DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$033_action_date_and_type_temp ON summary_transaction_recipient_view_temp USING BTREE(action_date DESC NULLS LAST, type) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$033_type_temp ON summary_transaction_recipient_view_temp USING BTREE(type) WITH (fillfactor = 97) WHERE type IS NOT NULL;
CREATE INDEX idx_230a1cf1$033_pulled_from_temp ON summary_transaction_recipient_view_temp USING BTREE(pulled_from DESC NULLS LAST) WITH (fillfactor = 97) WHERE pulled_from IS NOT NULL;
CREATE INDEX idx_230a1cf1$033_recipient_unique_id_temp ON summary_transaction_recipient_view_temp USING BTREE(recipient_unique_id) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$033_recipient_hash_temp ON summary_transaction_recipient_view_temp USING BTREE(recipient_hash) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$033_parent_recipient_unique_id_temp ON summary_transaction_recipient_view_temp USING BTREE(parent_recipient_unique_id) WITH (fillfactor = 97);
