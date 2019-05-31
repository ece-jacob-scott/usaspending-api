DROP MATERIALIZED VIEW IF EXISTS summary_state_view_temp CASCADE;
DROP MATERIALIZED VIEW IF EXISTS summary_state_view_old CASCADE;

CREATE MATERIALIZED VIEW summary_state_view_temp AS
SELECT
  -- Deterministic Unique Hash (DUH) created for view concurrent refresh
  MD5(array_to_string(sort(array_agg(transaction_normalized.id::int)), ' '))::uuid AS duh,
  transaction_normalized.action_date,
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_fpds.pulled_from,
  array_to_string(array_agg(DISTINCT transaction_normalized.award_id), ',') AS distinct_awards,

  place_of_performance.location_country_code AS pop_country_code,
  place_of_performance.state_code AS pop_state_code,

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
  transaction_fpds ON (transaction_normalized.id = transaction_fpds.transaction_id)
LEFT OUTER JOIN
  awards ON (transaction_normalized.award_id = awards.id)
LEFT OUTER JOIN
  references_location AS place_of_performance ON (transaction_normalized.place_of_performance_id = place_of_performance.location_id)
WHERE
  transaction_normalized.action_date >= '2007-10-01' AND
  place_of_performance.location_country_code = 'USA' AND
  place_of_performance.state_code IS NOT NULL
GROUP BY
  transaction_normalized.action_date,
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_fpds.pulled_from,
  place_of_performance.location_country_code,
  place_of_performance.country_name,
  place_of_performance.state_code WITH DATA;

CREATE UNIQUE INDEX idx_230a1cf1$c3a_deterministic_unique_hash_temp ON summary_state_view_temp USING BTREE(duh) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$c3a_ordered_action_date_temp ON summary_state_view_temp USING BTREE(action_date DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$c3a_type_temp ON summary_state_view_temp USING BTREE(type) WITH (fillfactor = 97) WHERE type IS NOT NULL;
CREATE INDEX idx_230a1cf1$c3a_pulled_from_temp ON summary_state_view_temp USING BTREE(pulled_from) WITH (fillfactor = 97) WHERE pulled_from IS NOT NULL;
CREATE INDEX idx_230a1cf1$c3a_pop_country_code_temp ON summary_state_view_temp USING BTREE(pop_country_code) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$c3a_pop_state_code_temp ON summary_state_view_temp USING BTREE(pop_state_code) WITH (fillfactor = 97) WHERE pop_state_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$c3a_compound_geo_pop_temp ON summary_state_view_temp USING BTREE(pop_country_code, pop_state_code, action_date) WITH (fillfactor = 97);

ALTER MATERIALIZED VIEW IF EXISTS summary_state_view RENAME TO summary_state_view_old;
ALTER INDEX IF EXISTS idx_230a1cf1$c3a_deterministic_unique_hash RENAME TO idx_230a1cf1$c3a_deterministic_unique_hash_old;
ALTER INDEX IF EXISTS idx_230a1cf1$c3a_ordered_action_date RENAME TO idx_230a1cf1$c3a_ordered_action_date_old;
ALTER INDEX IF EXISTS idx_230a1cf1$c3a_type RENAME TO idx_230a1cf1$c3a_type_old;
ALTER INDEX IF EXISTS idx_230a1cf1$c3a_pulled_from RENAME TO idx_230a1cf1$c3a_pulled_from_old;
ALTER INDEX IF EXISTS idx_230a1cf1$c3a_pop_country_code RENAME TO idx_230a1cf1$c3a_pop_country_code_old;
ALTER INDEX IF EXISTS idx_230a1cf1$c3a_pop_state_code RENAME TO idx_230a1cf1$c3a_pop_state_code_old;
ALTER INDEX IF EXISTS idx_230a1cf1$c3a_compound_geo_pop RENAME TO idx_230a1cf1$c3a_compound_geo_pop_old;

ALTER MATERIALIZED VIEW summary_state_view_temp RENAME TO summary_state_view;
ALTER INDEX idx_230a1cf1$c3a_deterministic_unique_hash_temp RENAME TO idx_230a1cf1$c3a_deterministic_unique_hash;
ALTER INDEX idx_230a1cf1$c3a_ordered_action_date_temp RENAME TO idx_230a1cf1$c3a_ordered_action_date;
ALTER INDEX idx_230a1cf1$c3a_type_temp RENAME TO idx_230a1cf1$c3a_type;
ALTER INDEX idx_230a1cf1$c3a_pulled_from_temp RENAME TO idx_230a1cf1$c3a_pulled_from;
ALTER INDEX idx_230a1cf1$c3a_pop_country_code_temp RENAME TO idx_230a1cf1$c3a_pop_country_code;
ALTER INDEX idx_230a1cf1$c3a_pop_state_code_temp RENAME TO idx_230a1cf1$c3a_pop_state_code;
ALTER INDEX idx_230a1cf1$c3a_compound_geo_pop_temp RENAME TO idx_230a1cf1$c3a_compound_geo_pop;

ANALYZE VERBOSE summary_state_view;
GRANT SELECT ON summary_state_view TO readonly;
