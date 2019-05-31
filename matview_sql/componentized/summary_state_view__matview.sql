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
