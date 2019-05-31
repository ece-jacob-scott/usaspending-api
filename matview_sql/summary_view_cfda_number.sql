DROP MATERIALIZED VIEW IF EXISTS summary_view_cfda_number_temp CASCADE;
DROP MATERIALIZED VIEW IF EXISTS summary_view_cfda_number_old CASCADE;

CREATE MATERIALIZED VIEW summary_view_cfda_number_temp AS
SELECT
  -- Deterministic Unique Hash (DUH) created for view concurrent refresh
  MD5(array_to_string(sort(array_agg(transaction_normalized.id::int)), ' '))::uuid AS duh,
  transaction_normalized.action_date,
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_fpds.pulled_from,
  transaction_fabs.cfda_number,
  transaction_fabs.cfda_title,

  SUM(COALESCE(CASE
    WHEN awards.category = 'loans' THEN awards.total_subsidy_cost
    ELSE transaction_normalized.federal_action_obligation
  END, 0)::NUMERIC(23, 2))::NUMERIC(23, 2) AS generated_pragmatic_obligation,
  SUM(COALESCE(transaction_normalized.federal_action_obligation, 0))::NUMERIC(23, 2) AS federal_action_obligation,
  SUM(COALESCE(transaction_normalized.original_loan_subsidy_cost, 0))::NUMERIC(23, 2) AS original_loan_subsidy_cost,
  SUM(COALESCE(transaction_normalized.face_value_loan_guarantee, 0))::NUMERIC(23, 2) AS face_value_loan_guarantee,
  COUNT(*) counts
FROM
  transaction_normalized
LEFT OUTER JOIN
  awards ON (transaction_normalized.award_id = awards.id)
LEFT OUTER JOIN
  transaction_fabs ON (transaction_normalized.id = transaction_fabs.transaction_id)
LEFT OUTER JOIN
  transaction_fpds ON (transaction_normalized.id = transaction_fpds.transaction_id)
WHERE
  transaction_normalized.action_date >= '2007-10-01'
GROUP BY
  transaction_normalized.action_date,
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_fpds.pulled_from,
  transaction_fabs.cfda_number,
  transaction_fabs.cfda_title WITH DATA;

CREATE UNIQUE INDEX idx_230a1cf1$4df_deterministic_unique_hash_temp ON summary_view_cfda_number_temp USING BTREE(duh) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$4df_action_date_temp ON summary_view_cfda_number_temp USING BTREE(action_date DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$4df_type_temp ON summary_view_cfda_number_temp USING BTREE(type) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$4df_pulled_from_temp ON summary_view_cfda_number_temp USING BTREE(pulled_from) WITH (fillfactor = 97) WHERE pulled_from IS NOT NULL;

ALTER MATERIALIZED VIEW IF EXISTS summary_view_cfda_number RENAME TO summary_view_cfda_number_old;
ALTER INDEX IF EXISTS idx_230a1cf1$4df_deterministic_unique_hash RENAME TO idx_230a1cf1$4df_deterministic_unique_hash_old;
ALTER INDEX IF EXISTS idx_230a1cf1$4df_action_date RENAME TO idx_230a1cf1$4df_action_date_old;
ALTER INDEX IF EXISTS idx_230a1cf1$4df_type RENAME TO idx_230a1cf1$4df_type_old;
ALTER INDEX IF EXISTS idx_230a1cf1$4df_pulled_from RENAME TO idx_230a1cf1$4df_pulled_from_old;

ALTER MATERIALIZED VIEW summary_view_cfda_number_temp RENAME TO summary_view_cfda_number;
ALTER INDEX idx_230a1cf1$4df_deterministic_unique_hash_temp RENAME TO idx_230a1cf1$4df_deterministic_unique_hash;
ALTER INDEX idx_230a1cf1$4df_action_date_temp RENAME TO idx_230a1cf1$4df_action_date;
ALTER INDEX idx_230a1cf1$4df_type_temp RENAME TO idx_230a1cf1$4df_type;
ALTER INDEX idx_230a1cf1$4df_pulled_from_temp RENAME TO idx_230a1cf1$4df_pulled_from;

ANALYZE VERBOSE summary_view_cfda_number;
GRANT SELECT ON summary_view_cfda_number TO readonly;
