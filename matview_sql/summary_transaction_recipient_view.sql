DROP MATERIALIZED VIEW IF EXISTS summary_transaction_recipient_view_temp CASCADE;
DROP MATERIALIZED VIEW IF EXISTS summary_transaction_recipient_view_old CASCADE;

CREATE MATERIALIZED VIEW summary_transaction_recipient_view_temp AS
SELECT
  -- Deterministic Unique Hash (DUH) created for view concurrent refresh
  MD5(array_to_string(sort(array_agg(transaction_normalized.id::int)), ' '))::uuid AS duh,
  transaction_normalized.action_date,
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_fpds.pulled_from,

  COALESCE(recipient_lookup.recipient_hash, MD5(
    UPPER(COALESCE(transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)))::uuid
  )::uuid AS recipient_hash,
  UPPER(COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)) AS recipient_name,
  COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu) AS recipient_unique_id,
  COALESCE(transaction_fpds.ultimate_parent_unique_ide, transaction_fabs.ultimate_parent_unique_ide) AS parent_recipient_unique_id,

  SUM(COALESCE(CASE
      WHEN awards.category = 'loans' THEN awards.total_subsidy_cost
      ELSE transaction_normalized.federal_action_obligation
      END, 0)::NUMERIC(23, 2))::NUMERIC(23, 2) AS generated_pragmatic_obligation,
  SUM(COALESCE(transaction_normalized.federal_action_obligation, 0))::NUMERIC(23, 2) AS federal_action_obligation,
  SUM(COALESCE(transaction_normalized.original_loan_subsidy_cost, 0))::NUMERIC(23, 2) AS original_loan_subsidy_cost,
  SUM(COALESCE(transaction_normalized.face_value_loan_guarantee, 0))::NUMERIC(23, 2) AS face_value_loan_guarantee,
  count(*) AS counts
FROM
  transaction_normalized
LEFT OUTER JOIN
  transaction_fabs ON (transaction_normalized.id = transaction_fabs.transaction_id AND transaction_normalized.is_fpds = false)
LEFT OUTER JOIN
  transaction_fpds ON (transaction_normalized.id = transaction_fpds.transaction_id  AND transaction_normalized.is_fpds = true)
LEFT OUTER JOIN
  (SELECT
    recipient_hash,
    legal_business_name AS recipient_name,
    duns
  FROM recipient_lookup AS rlv
  ) recipient_lookup ON recipient_lookup.duns = COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu) AND COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu) IS NOT NULL
LEFT OUTER JOIN
  awards ON (transaction_normalized.award_id = awards.id)
WHERE
  transaction_normalized.action_date >= '2007-10-01'
GROUP BY
  transaction_normalized.action_date,
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_fpds.pulled_from,

  COALESCE(recipient_lookup.recipient_hash, MD5(
    UPPER(COALESCE(transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)))::uuid),
  UPPER(COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)),
  COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu),
  COALESCE(transaction_fpds.ultimate_parent_unique_ide, transaction_fabs.ultimate_parent_unique_ide) WITH DATA;

CREATE UNIQUE INDEX idx_230a1cf1$033_deterministic_unique_hash_temp ON summary_transaction_recipient_view_temp USING BTREE(duh) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$033_ordered_action_date_temp ON summary_transaction_recipient_view_temp USING BTREE(action_date DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$033_action_date_and_type_temp ON summary_transaction_recipient_view_temp USING BTREE(action_date DESC NULLS LAST, type) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$033_type_temp ON summary_transaction_recipient_view_temp USING BTREE(type) WITH (fillfactor = 97) WHERE type IS NOT NULL;
CREATE INDEX idx_230a1cf1$033_pulled_from_temp ON summary_transaction_recipient_view_temp USING BTREE(pulled_from DESC NULLS LAST) WITH (fillfactor = 97) WHERE pulled_from IS NOT NULL;
CREATE INDEX idx_230a1cf1$033_recipient_unique_id_temp ON summary_transaction_recipient_view_temp USING BTREE(recipient_unique_id) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$033_recipient_hash_temp ON summary_transaction_recipient_view_temp USING BTREE(recipient_hash) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$033_parent_recipient_unique_id_temp ON summary_transaction_recipient_view_temp USING BTREE(parent_recipient_unique_id) WITH (fillfactor = 97);

ALTER MATERIALIZED VIEW IF EXISTS summary_transaction_recipient_view RENAME TO summary_transaction_recipient_view_old;
ALTER INDEX IF EXISTS idx_230a1cf1$033_deterministic_unique_hash RENAME TO idx_230a1cf1$033_deterministic_unique_hash_old;
ALTER INDEX IF EXISTS idx_230a1cf1$033_ordered_action_date RENAME TO idx_230a1cf1$033_ordered_action_date_old;
ALTER INDEX IF EXISTS idx_230a1cf1$033_action_date_and_type RENAME TO idx_230a1cf1$033_action_date_and_type_old;
ALTER INDEX IF EXISTS idx_230a1cf1$033_type RENAME TO idx_230a1cf1$033_type_old;
ALTER INDEX IF EXISTS idx_230a1cf1$033_pulled_from RENAME TO idx_230a1cf1$033_pulled_from_old;
ALTER INDEX IF EXISTS idx_230a1cf1$033_recipient_unique_id RENAME TO idx_230a1cf1$033_recipient_unique_id_old;
ALTER INDEX IF EXISTS idx_230a1cf1$033_recipient_hash RENAME TO idx_230a1cf1$033_recipient_hash_old;
ALTER INDEX IF EXISTS idx_230a1cf1$033_parent_recipient_unique_id RENAME TO idx_230a1cf1$033_parent_recipient_unique_id_old;

ALTER MATERIALIZED VIEW summary_transaction_recipient_view_temp RENAME TO summary_transaction_recipient_view;
ALTER INDEX idx_230a1cf1$033_deterministic_unique_hash_temp RENAME TO idx_230a1cf1$033_deterministic_unique_hash;
ALTER INDEX idx_230a1cf1$033_ordered_action_date_temp RENAME TO idx_230a1cf1$033_ordered_action_date;
ALTER INDEX idx_230a1cf1$033_action_date_and_type_temp RENAME TO idx_230a1cf1$033_action_date_and_type;
ALTER INDEX idx_230a1cf1$033_type_temp RENAME TO idx_230a1cf1$033_type;
ALTER INDEX idx_230a1cf1$033_pulled_from_temp RENAME TO idx_230a1cf1$033_pulled_from;
ALTER INDEX idx_230a1cf1$033_recipient_unique_id_temp RENAME TO idx_230a1cf1$033_recipient_unique_id;
ALTER INDEX idx_230a1cf1$033_recipient_hash_temp RENAME TO idx_230a1cf1$033_recipient_hash;
ALTER INDEX idx_230a1cf1$033_parent_recipient_unique_id_temp RENAME TO idx_230a1cf1$033_parent_recipient_unique_id;

ANALYZE VERBOSE summary_transaction_recipient_view;
GRANT SELECT ON summary_transaction_recipient_view TO readonly;
