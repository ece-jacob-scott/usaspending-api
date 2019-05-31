DROP MATERIALIZED VIEW IF EXISTS summary_view_psc_codes_temp CASCADE;
DROP MATERIALIZED VIEW IF EXISTS summary_view_psc_codes_old CASCADE;

CREATE MATERIALIZED VIEW summary_view_psc_codes_temp AS
SELECT
  -- Deterministic Unique Hash (DUH) created for view concurrent refresh
  MD5(array_to_string(sort(array_agg(transaction_normalized.id::int)), ' '))::uuid AS duh,
  transaction_normalized.action_date,
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_fpds.pulled_from,
  transaction_fpds.product_or_service_code,

  SUM(COALESCE(CASE
    WHEN awards.category = 'loans' THEN awards.total_subsidy_cost
    ELSE transaction_normalized.federal_action_obligation
  END, 0)::NUMERIC(23, 2))::NUMERIC(23, 2) AS generated_pragmatic_obligation,
  SUM(COALESCE(transaction_normalized.federal_action_obligation, 0))::NUMERIC(23, 2) AS federal_action_obligation,
  0::NUMERIC(23, 2) AS original_loan_subsidy_cost,
  0::NUMERIC(23, 2) AS face_value_loan_guarantee,
  COUNT(*) counts
FROM
  transaction_normalized
LEFT OUTER JOIN
  awards ON (transaction_normalized.award_id = awards.id)
INNER JOIN
  transaction_fpds ON (transaction_normalized.id = transaction_fpds.transaction_id)
WHERE
  transaction_normalized.action_date >= '2007-10-01'
GROUP BY
  transaction_normalized.action_date,
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_fpds.pulled_from,
  transaction_fpds.product_or_service_code WITH DATA;

CREATE UNIQUE INDEX idx_230a1cf1$508_deterministic_unique_hash_temp ON summary_view_psc_codes_temp USING BTREE(duh) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$508_action_date_temp ON summary_view_psc_codes_temp USING BTREE(action_date DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$508_type_temp ON summary_view_psc_codes_temp USING BTREE(type) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$508_pulled_from_temp ON summary_view_psc_codes_temp USING BTREE(pulled_from) WITH (fillfactor = 97) WHERE pulled_from IS NOT NULL;

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

ANALYZE VERBOSE summary_view_psc_codes;
GRANT SELECT ON summary_view_psc_codes TO readonly;
