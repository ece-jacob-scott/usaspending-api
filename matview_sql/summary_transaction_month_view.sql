DROP MATERIALIZED VIEW IF EXISTS summary_transaction_month_view_temp CASCADE;
DROP MATERIALIZED VIEW IF EXISTS summary_transaction_month_view_old CASCADE;

CREATE MATERIALIZED VIEW summary_transaction_month_view_temp AS
SELECT
  -- Deterministic Unique Hash (DUH) created for view concurrent refresh
  MD5(array_to_string(sort(array_agg(transaction_normalized.id::int)), ' '))::uuid AS duh,
  cast(date_trunc('month', transaction_normalized.action_date) as date) as action_date,
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_fpds.pulled_from,

  CASE WHEN COALESCE(transaction_fpds.legal_entity_country_code, transaction_fabs.legal_entity_country_code) = 'UNITED STATES' THEN 'USA' ELSE COALESCE(transaction_fpds.legal_entity_country_code, transaction_fabs.legal_entity_country_code) END AS recipient_location_country_code,
  COALESCE(transaction_fpds.legal_entity_country_name, transaction_fabs.legal_entity_country_name) AS recipient_location_country_name,
  COALESCE(transaction_fpds.legal_entity_state_code, transaction_fabs.legal_entity_state_code) AS recipient_location_state_code,
  COALESCE(transaction_fpds.legal_entity_county_code, transaction_fabs.legal_entity_county_code) AS recipient_location_county_code,
  COALESCE(transaction_fpds.legal_entity_county_name, transaction_fabs.legal_entity_county_name) AS recipient_location_county_name,
  COALESCE(transaction_fpds.legal_entity_congressional, transaction_fabs.legal_entity_congressional) AS recipient_location_congressional_code,
  COALESCE(transaction_fpds.legal_entity_zip5, transaction_fabs.legal_entity_zip5) AS recipient_location_zip5,

  place_of_performance.location_country_code AS pop_country_code,
  place_of_performance.country_name AS pop_country_name,
  place_of_performance.state_code AS pop_state_code,
  place_of_performance.county_code AS pop_county_code,
  place_of_performance.county_name AS pop_county_name,
  place_of_performance.congressional_code AS pop_congressional_code,
  place_of_performance.zip5 AS pop_zip5,

  transaction_normalized.awarding_agency_id,
  transaction_normalized.funding_agency_id,
  TAA.name AS awarding_toptier_agency_name,
  TFA.name AS funding_toptier_agency_name,
  SAA.name AS awarding_subtier_agency_name,
  SFA.name AS funding_subtier_agency_name,
  TAA.abbreviation AS awarding_toptier_agency_abbreviation,
  TFA.abbreviation AS funding_toptier_agency_abbreviation,
  SAA.abbreviation AS awarding_subtier_agency_abbreviation,
  SFA.abbreviation AS funding_subtier_agency_abbreviation,

  COALESCE(recipient_lookup.recipient_hash, MD5(
    UPPER(COALESCE(transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)))::uuid
  )::uuid AS recipient_hash,
  UPPER(COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)) AS recipient_name,
  COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu) AS recipient_unique_id,
  COALESCE(transaction_fpds.ultimate_parent_unique_ide, transaction_fabs.ultimate_parent_unique_ide) AS parent_recipient_unique_id,

  legal_entity.business_categories,
  transaction_fabs.cfda_number,
  references_cfda.program_title AS cfda_title,
  transaction_fpds.product_or_service_code,
  psc.description AS product_or_service_description,
  transaction_fpds.naics AS naics_code,
  naics.description AS naics_description,

  obligation_to_enum(awards.total_obligation) AS total_obl_bin,
  transaction_fpds.type_of_contract_pricing,
  transaction_fpds.type_set_aside,
  transaction_fpds.extent_competed,

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
  references_cfda ON (transaction_fabs.cfda_number = references_cfda.program_number)
LEFT OUTER JOIN
  legal_entity ON (transaction_normalized.recipient_id = legal_entity.legal_entity_id)
LEFT OUTER JOIN
  (SELECT
    recipient_hash,
    legal_business_name AS recipient_name,
    duns
  FROM recipient_lookup AS rlv
  ) recipient_lookup ON recipient_lookup.duns = COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu) AND COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu) IS NOT NULL
LEFT OUTER JOIN
  awards ON (transaction_normalized.award_id = awards.id)
LEFT OUTER JOIN
  references_location AS place_of_performance ON (transaction_normalized.place_of_performance_id = place_of_performance.location_id)
LEFT OUTER JOIN
  agency AS AA ON (transaction_normalized.awarding_agency_id = AA.id)
LEFT OUTER JOIN
  toptier_agency AS TAA ON (AA.toptier_agency_id = TAA.toptier_agency_id)
LEFT OUTER JOIN
  subtier_agency AS SAA ON (AA.subtier_agency_id = SAA.subtier_agency_id)
LEFT OUTER JOIN
  agency AS FA ON (transaction_normalized.funding_agency_id = FA.id)
LEFT OUTER JOIN
  toptier_agency AS TFA ON (FA.toptier_agency_id = TFA.toptier_agency_id)
LEFT OUTER JOIN
  subtier_agency AS SFA ON (FA.subtier_agency_id = SFA.subtier_agency_id)
LEFT OUTER JOIN
  naics ON (transaction_fpds.naics = naics.code)
LEFT OUTER JOIN
  psc ON (transaction_fpds.product_or_service_code = psc.code)
WHERE
  transaction_normalized.action_date >= '2007-10-01'
GROUP BY
  cast(date_trunc('month', transaction_normalized.action_date) as date),
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_fpds.pulled_from,
  legal_entity.business_categories,

  COALESCE(transaction_fpds.legal_entity_country_code, transaction_fabs.legal_entity_country_code),
  COALESCE(transaction_fpds.legal_entity_country_name, transaction_fabs.legal_entity_country_name),
  COALESCE(transaction_fpds.legal_entity_state_code, transaction_fabs.legal_entity_state_code),
  COALESCE(transaction_fpds.legal_entity_county_code, transaction_fabs.legal_entity_county_code),
  COALESCE(transaction_fpds.legal_entity_county_name, transaction_fabs.legal_entity_county_name),
  COALESCE(transaction_fpds.legal_entity_congressional, transaction_fabs.legal_entity_congressional),
  COALESCE(transaction_fpds.legal_entity_zip5, transaction_fabs.legal_entity_zip5),

  place_of_performance.location_country_code,
  place_of_performance.country_name,
  place_of_performance.state_code,
  place_of_performance.county_code,
  place_of_performance.county_name,
  place_of_performance.congressional_code,
  place_of_performance.zip5,

  transaction_normalized.awarding_agency_id,
  transaction_normalized.funding_agency_id,
  TAA.name,
  TFA.name,
  SAA.name,
  SFA.name,
  TAA.abbreviation,
  TFA.abbreviation,
  SAA.abbreviation,
  SFA.abbreviation,

  transaction_fabs.cfda_number,
  references_cfda.program_title,
  transaction_fpds.product_or_service_code,
  psc.description,
  transaction_fpds.naics,
  naics.description,

  obligation_to_enum(awards.total_obligation),
  transaction_fpds.type_of_contract_pricing,
  transaction_fpds.type_set_aside,
  transaction_fpds.extent_competed,
  COALESCE(recipient_lookup.recipient_hash, MD5(
    UPPER(COALESCE(transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)))::uuid),
  COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal),
  COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu),
  COALESCE(transaction_fpds.ultimate_parent_unique_ide, transaction_fabs.ultimate_parent_unique_ide)
ORDER BY
  cast(date_trunc('month', transaction_normalized.action_date) as date) DESC WITH DATA;

CREATE UNIQUE INDEX idx_230a1cf1$fab_deterministic_unique_hash_temp ON summary_transaction_month_view_temp USING BTREE(duh) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$fab_date_temp ON summary_transaction_month_view_temp USING BTREE(action_date DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$fab_action_date_and_type_temp ON summary_transaction_month_view_temp USING BTREE(action_date DESC NULLS LAST, type) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$fab_type_temp ON summary_transaction_month_view_temp USING BTREE(type) WITH (fillfactor = 97) WHERE type IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_pulled_from_temp ON summary_transaction_month_view_temp USING BTREE(pulled_from DESC NULLS LAST) WITH (fillfactor = 97) WHERE pulled_from IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_recipient_unique_id_temp ON summary_transaction_month_view_temp USING BTREE(recipient_unique_id) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$fab_parent_recipient_unique_id_temp ON summary_transaction_month_view_temp USING BTREE(parent_recipient_unique_id) WITH (fillfactor = 97) WHERE parent_recipient_unique_id IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_recipient_country_code_temp ON summary_transaction_month_view_temp USING BTREE(recipient_location_country_code) WITH (fillfactor = 97) WHERE recipient_location_country_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_recipient_state_code_temp ON summary_transaction_month_view_temp USING BTREE(recipient_location_state_code) WITH (fillfactor = 97) WHERE recipient_location_state_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_recipient_county_code_temp ON summary_transaction_month_view_temp USING BTREE(recipient_location_county_code) WITH (fillfactor = 97) WHERE recipient_location_county_code IS NOT NULL;
DO $$ BEGIN RAISE NOTICE '10 indexes created, 31 remaining'; END $$;
CREATE INDEX idx_230a1cf1$fab_recipient_zip_temp ON summary_transaction_month_view_temp USING BTREE(recipient_location_zip5) WITH (fillfactor = 97) WHERE recipient_location_zip5 IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_pop_country_code_temp ON summary_transaction_month_view_temp USING BTREE(pop_country_code) WITH (fillfactor = 97) WHERE pop_country_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_pop_state_code_temp ON summary_transaction_month_view_temp USING BTREE(pop_state_code) WITH (fillfactor = 97) WHERE pop_state_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_pop_county_code_temp ON summary_transaction_month_view_temp USING BTREE(pop_county_code) WITH (fillfactor = 97) WHERE pop_county_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_pop_zip_temp ON summary_transaction_month_view_temp USING BTREE(pop_zip5) WITH (fillfactor = 97) WHERE pop_zip5 IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_awarding_agency_id_temp ON summary_transaction_month_view_temp USING BTREE(awarding_agency_id ASC NULLS LAST) WITH (fillfactor = 97) WHERE awarding_agency_id IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_funding_agency_id_temp ON summary_transaction_month_view_temp USING BTREE(funding_agency_id ASC NULLS LAST) WITH (fillfactor = 97) WHERE funding_agency_id IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_awarding_toptier_agency_name_temp ON summary_transaction_month_view_temp USING BTREE(awarding_toptier_agency_name) WITH (fillfactor = 97) WHERE awarding_toptier_agency_name IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_awarding_subtier_agency_name_temp ON summary_transaction_month_view_temp USING BTREE(awarding_subtier_agency_name) WITH (fillfactor = 97) WHERE awarding_subtier_agency_name IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_funding_toptier_agency_name_temp ON summary_transaction_month_view_temp USING BTREE(funding_toptier_agency_name) WITH (fillfactor = 97) WHERE funding_toptier_agency_name IS NOT NULL;
DO $$ BEGIN RAISE NOTICE '20 indexes created, 21 remaining'; END $$;
CREATE INDEX idx_230a1cf1$fab_funding_subtier_agency_name_temp ON summary_transaction_month_view_temp USING BTREE(funding_subtier_agency_name) WITH (fillfactor = 97) WHERE funding_subtier_agency_name IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_cfda_number_temp ON summary_transaction_month_view_temp USING BTREE(cfda_number) WITH (fillfactor = 97) WHERE cfda_number IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_cfda_title_temp ON summary_transaction_month_view_temp USING BTREE(cfda_title) WITH (fillfactor = 97) WHERE cfda_title IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_psc_temp ON summary_transaction_month_view_temp USING BTREE(product_or_service_code) WITH (fillfactor = 97) WHERE product_or_service_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_naics_temp ON summary_transaction_month_view_temp USING BTREE(naics_code) WITH (fillfactor = 97) WHERE naics_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_total_obl_bin_temp ON summary_transaction_month_view_temp USING BTREE(total_obl_bin) WITH (fillfactor = 97) WHERE total_obl_bin IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_type_of_contract_temp ON summary_transaction_month_view_temp USING BTREE(type_of_contract_pricing) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$fab_type_set_aside_temp ON summary_transaction_month_view_temp USING BTREE(type_set_aside, action_date) WITH (fillfactor = 97) WHERE type_set_aside IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_extent_competed_temp ON summary_transaction_month_view_temp USING BTREE(extent_competed) WITH (fillfactor = 97);
CREATE INDEX idx_230a1cf1$fab_business_categories_temp ON summary_transaction_month_view_temp USING GIN(business_categories);
DO $$ BEGIN RAISE NOTICE '30 indexes created, 11 remaining'; END $$;
CREATE INDEX idx_230a1cf1$fab_simple_pop_geolocation_temp ON summary_transaction_month_view_temp USING BTREE(pop_state_code, action_date) WITH (fillfactor = 97) WHERE pop_country_code = 'USA' AND pop_state_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_pop_covering_geolocation_temp ON summary_transaction_month_view_temp USING BTREE(pop_state_code, fiscal_year, generated_pragmatic_obligation, action_date) WITH (fillfactor = 97) WHERE pop_country_code = 'USA';
CREATE INDEX idx_230a1cf1$fab_compound_geo_pop_1_temp ON summary_transaction_month_view_temp USING BTREE(pop_state_code, pop_county_code, action_date) WITH (fillfactor = 97) WHERE pop_country_code = 'USA' AND pop_state_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_compound_geo_pop_2_temp ON summary_transaction_month_view_temp USING BTREE(pop_state_code, pop_congressional_code, action_date) WITH (fillfactor = 97) WHERE pop_country_code = 'USA' AND pop_state_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_compound_geo_pop_3_temp ON summary_transaction_month_view_temp USING BTREE(pop_zip5, action_date) WITH (fillfactor = 97) WHERE pop_country_code = 'USA' AND pop_zip5 IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_simple_recipient_location_geolocation_temp ON summary_transaction_month_view_temp USING BTREE(recipient_location_state_code, action_date) WITH (fillfactor = 97) WHERE recipient_location_country_code = 'USA' AND recipient_location_state_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_recipient_covering_geolocation_temp ON summary_transaction_month_view_temp USING BTREE(recipient_location_state_code, fiscal_year, generated_pragmatic_obligation, action_date) WITH (fillfactor = 97) WHERE recipient_location_country_code = 'USA';
CREATE INDEX idx_230a1cf1$fab_compound_geo_rl_1_temp ON summary_transaction_month_view_temp USING BTREE(recipient_location_state_code, recipient_location_county_code, action_date) WITH (fillfactor = 97) WHERE recipient_location_country_code = 'USA' AND recipient_location_state_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_compound_geo_rl_2_temp ON summary_transaction_month_view_temp USING BTREE(recipient_location_state_code, recipient_location_congressional_code, action_date) WITH (fillfactor = 97) WHERE recipient_location_country_code = 'USA' AND recipient_location_state_code IS NOT NULL;
CREATE INDEX idx_230a1cf1$fab_compound_geo_rl_3_temp ON summary_transaction_month_view_temp USING BTREE(recipient_location_zip5, action_date) WITH (fillfactor = 97) WHERE recipient_location_country_code = 'USA' AND recipient_location_zip5 IS NOT NULL;
DO $$ BEGIN RAISE NOTICE '40 indexes created, 1 remaining'; END $$;
CREATE INDEX idx_230a1cf1$fab_recipient_hash_temp ON summary_transaction_month_view_temp USING BTREE(recipient_hash) WITH (fillfactor = 97);

ALTER MATERIALIZED VIEW IF EXISTS summary_transaction_month_view RENAME TO summary_transaction_month_view_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_deterministic_unique_hash RENAME TO idx_230a1cf1$fab_deterministic_unique_hash_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_date RENAME TO idx_230a1cf1$fab_date_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_action_date_and_type RENAME TO idx_230a1cf1$fab_action_date_and_type_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_type RENAME TO idx_230a1cf1$fab_type_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_pulled_from RENAME TO idx_230a1cf1$fab_pulled_from_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_recipient_unique_id RENAME TO idx_230a1cf1$fab_recipient_unique_id_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_parent_recipient_unique_id RENAME TO idx_230a1cf1$fab_parent_recipient_unique_id_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_recipient_country_code RENAME TO idx_230a1cf1$fab_recipient_country_code_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_recipient_state_code RENAME TO idx_230a1cf1$fab_recipient_state_code_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_recipient_county_code RENAME TO idx_230a1cf1$fab_recipient_county_code_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_recipient_zip RENAME TO idx_230a1cf1$fab_recipient_zip_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_pop_country_code RENAME TO idx_230a1cf1$fab_pop_country_code_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_pop_state_code RENAME TO idx_230a1cf1$fab_pop_state_code_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_pop_county_code RENAME TO idx_230a1cf1$fab_pop_county_code_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_pop_zip RENAME TO idx_230a1cf1$fab_pop_zip_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_awarding_agency_id RENAME TO idx_230a1cf1$fab_awarding_agency_id_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_funding_agency_id RENAME TO idx_230a1cf1$fab_funding_agency_id_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_awarding_toptier_agency_name RENAME TO idx_230a1cf1$fab_awarding_toptier_agency_name_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_awarding_subtier_agency_name RENAME TO idx_230a1cf1$fab_awarding_subtier_agency_name_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_funding_toptier_agency_name RENAME TO idx_230a1cf1$fab_funding_toptier_agency_name_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_funding_subtier_agency_name RENAME TO idx_230a1cf1$fab_funding_subtier_agency_name_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_cfda_number RENAME TO idx_230a1cf1$fab_cfda_number_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_cfda_title RENAME TO idx_230a1cf1$fab_cfda_title_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_psc RENAME TO idx_230a1cf1$fab_psc_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_naics RENAME TO idx_230a1cf1$fab_naics_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_total_obl_bin RENAME TO idx_230a1cf1$fab_total_obl_bin_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_type_of_contract RENAME TO idx_230a1cf1$fab_type_of_contract_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_type_set_aside RENAME TO idx_230a1cf1$fab_type_set_aside_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_extent_competed RENAME TO idx_230a1cf1$fab_extent_competed_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_business_categories RENAME TO idx_230a1cf1$fab_business_categories_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_simple_pop_geolocation RENAME TO idx_230a1cf1$fab_simple_pop_geolocation_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_pop_covering_geolocation RENAME TO idx_230a1cf1$fab_pop_covering_geolocation_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_compound_geo_pop_1 RENAME TO idx_230a1cf1$fab_compound_geo_pop_1_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_compound_geo_pop_2 RENAME TO idx_230a1cf1$fab_compound_geo_pop_2_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_compound_geo_pop_3 RENAME TO idx_230a1cf1$fab_compound_geo_pop_3_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_simple_recipient_location_geolocation RENAME TO idx_230a1cf1$fab_simple_recipient_location_geolocation_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_recipient_covering_geolocation RENAME TO idx_230a1cf1$fab_recipient_covering_geolocation_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_compound_geo_rl_1 RENAME TO idx_230a1cf1$fab_compound_geo_rl_1_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_compound_geo_rl_2 RENAME TO idx_230a1cf1$fab_compound_geo_rl_2_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_compound_geo_rl_3 RENAME TO idx_230a1cf1$fab_compound_geo_rl_3_old;
ALTER INDEX IF EXISTS idx_230a1cf1$fab_recipient_hash RENAME TO idx_230a1cf1$fab_recipient_hash_old;

ALTER MATERIALIZED VIEW summary_transaction_month_view_temp RENAME TO summary_transaction_month_view;
ALTER INDEX idx_230a1cf1$fab_deterministic_unique_hash_temp RENAME TO idx_230a1cf1$fab_deterministic_unique_hash;
ALTER INDEX idx_230a1cf1$fab_date_temp RENAME TO idx_230a1cf1$fab_date;
ALTER INDEX idx_230a1cf1$fab_action_date_and_type_temp RENAME TO idx_230a1cf1$fab_action_date_and_type;
ALTER INDEX idx_230a1cf1$fab_type_temp RENAME TO idx_230a1cf1$fab_type;
ALTER INDEX idx_230a1cf1$fab_pulled_from_temp RENAME TO idx_230a1cf1$fab_pulled_from;
ALTER INDEX idx_230a1cf1$fab_recipient_unique_id_temp RENAME TO idx_230a1cf1$fab_recipient_unique_id;
ALTER INDEX idx_230a1cf1$fab_parent_recipient_unique_id_temp RENAME TO idx_230a1cf1$fab_parent_recipient_unique_id;
ALTER INDEX idx_230a1cf1$fab_recipient_country_code_temp RENAME TO idx_230a1cf1$fab_recipient_country_code;
ALTER INDEX idx_230a1cf1$fab_recipient_state_code_temp RENAME TO idx_230a1cf1$fab_recipient_state_code;
ALTER INDEX idx_230a1cf1$fab_recipient_county_code_temp RENAME TO idx_230a1cf1$fab_recipient_county_code;
ALTER INDEX idx_230a1cf1$fab_recipient_zip_temp RENAME TO idx_230a1cf1$fab_recipient_zip;
ALTER INDEX idx_230a1cf1$fab_pop_country_code_temp RENAME TO idx_230a1cf1$fab_pop_country_code;
ALTER INDEX idx_230a1cf1$fab_pop_state_code_temp RENAME TO idx_230a1cf1$fab_pop_state_code;
ALTER INDEX idx_230a1cf1$fab_pop_county_code_temp RENAME TO idx_230a1cf1$fab_pop_county_code;
ALTER INDEX idx_230a1cf1$fab_pop_zip_temp RENAME TO idx_230a1cf1$fab_pop_zip;
ALTER INDEX idx_230a1cf1$fab_awarding_agency_id_temp RENAME TO idx_230a1cf1$fab_awarding_agency_id;
ALTER INDEX idx_230a1cf1$fab_funding_agency_id_temp RENAME TO idx_230a1cf1$fab_funding_agency_id;
ALTER INDEX idx_230a1cf1$fab_awarding_toptier_agency_name_temp RENAME TO idx_230a1cf1$fab_awarding_toptier_agency_name;
ALTER INDEX idx_230a1cf1$fab_awarding_subtier_agency_name_temp RENAME TO idx_230a1cf1$fab_awarding_subtier_agency_name;
ALTER INDEX idx_230a1cf1$fab_funding_toptier_agency_name_temp RENAME TO idx_230a1cf1$fab_funding_toptier_agency_name;
ALTER INDEX idx_230a1cf1$fab_funding_subtier_agency_name_temp RENAME TO idx_230a1cf1$fab_funding_subtier_agency_name;
ALTER INDEX idx_230a1cf1$fab_cfda_number_temp RENAME TO idx_230a1cf1$fab_cfda_number;
ALTER INDEX idx_230a1cf1$fab_cfda_title_temp RENAME TO idx_230a1cf1$fab_cfda_title;
ALTER INDEX idx_230a1cf1$fab_psc_temp RENAME TO idx_230a1cf1$fab_psc;
ALTER INDEX idx_230a1cf1$fab_naics_temp RENAME TO idx_230a1cf1$fab_naics;
ALTER INDEX idx_230a1cf1$fab_total_obl_bin_temp RENAME TO idx_230a1cf1$fab_total_obl_bin;
ALTER INDEX idx_230a1cf1$fab_type_of_contract_temp RENAME TO idx_230a1cf1$fab_type_of_contract;
ALTER INDEX idx_230a1cf1$fab_type_set_aside_temp RENAME TO idx_230a1cf1$fab_type_set_aside;
ALTER INDEX idx_230a1cf1$fab_extent_competed_temp RENAME TO idx_230a1cf1$fab_extent_competed;
ALTER INDEX idx_230a1cf1$fab_business_categories_temp RENAME TO idx_230a1cf1$fab_business_categories;
ALTER INDEX idx_230a1cf1$fab_simple_pop_geolocation_temp RENAME TO idx_230a1cf1$fab_simple_pop_geolocation;
ALTER INDEX idx_230a1cf1$fab_pop_covering_geolocation_temp RENAME TO idx_230a1cf1$fab_pop_covering_geolocation;
ALTER INDEX idx_230a1cf1$fab_compound_geo_pop_1_temp RENAME TO idx_230a1cf1$fab_compound_geo_pop_1;
ALTER INDEX idx_230a1cf1$fab_compound_geo_pop_2_temp RENAME TO idx_230a1cf1$fab_compound_geo_pop_2;
ALTER INDEX idx_230a1cf1$fab_compound_geo_pop_3_temp RENAME TO idx_230a1cf1$fab_compound_geo_pop_3;
ALTER INDEX idx_230a1cf1$fab_simple_recipient_location_geolocation_temp RENAME TO idx_230a1cf1$fab_simple_recipient_location_geolocation;
ALTER INDEX idx_230a1cf1$fab_recipient_covering_geolocation_temp RENAME TO idx_230a1cf1$fab_recipient_covering_geolocation;
ALTER INDEX idx_230a1cf1$fab_compound_geo_rl_1_temp RENAME TO idx_230a1cf1$fab_compound_geo_rl_1;
ALTER INDEX idx_230a1cf1$fab_compound_geo_rl_2_temp RENAME TO idx_230a1cf1$fab_compound_geo_rl_2;
ALTER INDEX idx_230a1cf1$fab_compound_geo_rl_3_temp RENAME TO idx_230a1cf1$fab_compound_geo_rl_3;
ALTER INDEX idx_230a1cf1$fab_recipient_hash_temp RENAME TO idx_230a1cf1$fab_recipient_hash;

ANALYZE VERBOSE summary_transaction_month_view;
GRANT SELECT ON summary_transaction_month_view TO readonly;
