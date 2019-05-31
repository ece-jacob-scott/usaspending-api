DROP MATERIALIZED VIEW IF EXISTS universal_award_matview_temp CASCADE;
DROP MATERIALIZED VIEW IF EXISTS universal_award_matview_old CASCADE;

CREATE MATERIALIZED VIEW universal_award_matview_temp AS
SELECT
  to_tsvector(CONCAT_WS(' ',
    COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal),
    transaction_fpds.naics,
    transaction_fpds.naics_description,
    psc.description,
    (SELECT string_agg(tn.description, ' ') FROM transaction_normalized AS tn WHERE tn.award_id = awards.id GROUP BY tn.award_id)
  )) AS keyword_ts_vector,
  to_tsvector(CONCAT_WS(' ', awards.piid, awards.fain, awards.uri)) AS award_ts_vector,
  to_tsvector(COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)) AS recipient_name_ts_vector,

  awards.id AS award_id,
  awards.category,
  awards.type,
  awards.type_description,
  awards.piid,
  awards.fain,
  awards.uri,
  awards.total_obligation,
  awards.description,
  obligation_to_enum(awards.total_obligation) AS total_obl_bin,
  awards.total_subsidy_cost,
  awards.total_loan_value,

  awards.recipient_id,
  UPPER(COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)) AS recipient_name,
  COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu) AS recipient_unique_id,
  COALESCE(transaction_fpds.ultimate_parent_unique_ide, transaction_fabs.ultimate_parent_unique_ide) AS parent_recipient_unique_id,
  legal_entity.business_categories,

  latest_transaction.action_date,
  latest_transaction.fiscal_year,
  latest_transaction.last_modified_date,
  awards.period_of_performance_start_date,
  awards.period_of_performance_current_end_date,
  awards.date_signed,
  transaction_fpds.ordering_period_end_date::date,
  daterange(awards.date_signed, latest_transaction.action_date, '[]') as date_range,

  transaction_fabs.original_loan_subsidy_cost,
  transaction_fabs.face_value_loan_guarantee,

  latest_transaction.awarding_agency_id,
  latest_transaction.funding_agency_id,
  TAA.name AS awarding_toptier_agency_name,
  TFA.name AS funding_toptier_agency_name,
  SAA.name AS awarding_subtier_agency_name,
  SFA.name AS funding_subtier_agency_name,
  TAA.cgac_code AS awarding_toptier_agency_code,
  TFA.cgac_code AS funding_toptier_agency_code,
  SAA.subtier_code AS awarding_subtier_agency_code,
  SFA.subtier_code AS funding_subtier_agency_code,

  CASE WHEN COALESCE(transaction_fpds.legal_entity_country_code, transaction_fabs.legal_entity_country_code) = 'UNITED STATES' THEN 'USA' ELSE COALESCE(transaction_fpds.legal_entity_country_code, transaction_fabs.legal_entity_country_code) END AS recipient_location_country_code,
  COALESCE(transaction_fpds.legal_entity_country_name, transaction_fabs.legal_entity_country_name) AS recipient_location_country_name,
  COALESCE(transaction_fpds.legal_entity_state_code, transaction_fabs.legal_entity_state_code) AS recipient_location_state_code,
  COALESCE(transaction_fpds.legal_entity_county_code, transaction_fabs.legal_entity_county_code) AS recipient_location_county_code,
  COALESCE(transaction_fpds.legal_entity_county_name, transaction_fabs.legal_entity_county_name) AS recipient_location_county_name,
  COALESCE(transaction_fpds.legal_entity_congressional, transaction_fabs.legal_entity_congressional) AS recipient_location_congressional_code,
  COALESCE(transaction_fpds.legal_entity_zip5, transaction_fabs.legal_entity_zip5) AS recipient_location_zip5,

  place_of_performance.country_name AS pop_country_name,
  place_of_performance.location_country_code AS pop_country_code,
  place_of_performance.state_code AS pop_state_code,
  place_of_performance.county_code AS pop_county_code,
  place_of_performance.county_name AS pop_county_name,
  place_of_performance.city_code AS pop_city_code,
  place_of_performance.zip5 AS pop_zip5,
  place_of_performance.congressional_code AS pop_congressional_code,

  transaction_fabs.cfda_number,
  transaction_fabs.sai_number,
  transaction_fpds.pulled_from,
  transaction_fpds.type_of_contract_pricing,
  transaction_fpds.extent_competed,
  transaction_fpds.type_set_aside,

  transaction_fpds.product_or_service_code,
  psc.description AS product_or_service_description,
  transaction_fpds.naics AS naics_code,
  transaction_fpds.naics_description
FROM
  awards
INNER JOIN
  transaction_normalized AS latest_transaction
    ON (awards.latest_transaction_id = latest_transaction.id)
LEFT OUTER JOIN
  transaction_fabs
    ON (awards.latest_transaction_id = transaction_fabs.transaction_id AND latest_transaction.is_fpds = false)
LEFT OUTER JOIN
  transaction_fpds
    ON (awards.latest_transaction_id = transaction_fpds.transaction_id AND latest_transaction.is_fpds = true)
INNER JOIN
  legal_entity
    ON (awards.recipient_id = legal_entity.legal_entity_id)
LEFT OUTER JOIN
  (SELECT
    recipient_hash,
    legal_business_name AS recipient_name,
    duns
  FROM recipient_lookup AS rlv
  ) recipient_lookup ON recipient_lookup.duns = COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu) AND COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu) IS NOT NULL
LEFT OUTER JOIN
  references_location AS place_of_performance ON (awards.place_of_performance_id = place_of_performance.location_id)
LEFT OUTER JOIN
  psc ON (transaction_fpds.product_or_service_code = psc.code)
LEFT OUTER JOIN
  agency AS AA
    ON (awards.awarding_agency_id = AA.id)
LEFT OUTER JOIN
  toptier_agency AS TAA
    ON (AA.toptier_agency_id = TAA.toptier_agency_id)
LEFT OUTER JOIN
  subtier_agency AS SAA
    ON (AA.subtier_agency_id = SAA.subtier_agency_id)
LEFT OUTER JOIN
  agency AS FA ON (awards.funding_agency_id = FA.id)
LEFT OUTER JOIN
  toptier_agency AS TFA
    ON (FA.toptier_agency_id = TFA.toptier_agency_id)
LEFT OUTER JOIN
  subtier_agency AS SFA
    ON (FA.subtier_agency_id = SFA.subtier_agency_id)
WHERE
  latest_transaction.action_date >= '2000-10-01'
ORDER BY
  awards.total_obligation DESC NULLS LAST WITH DATA;

CREATE UNIQUE INDEX idx_76387eb4$b67_id_temp ON universal_award_matview_temp USING BTREE(award_id) WITH (fillfactor = 97);
CREATE INDEX idx_76387eb4$b67_category_temp ON universal_award_matview_temp USING BTREE(category) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_type_temp ON universal_award_matview_temp USING BTREE(type) WITH (fillfactor = 97) WHERE type IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_ordered_type_temp ON universal_award_matview_temp USING BTREE(type DESC NULLS LAST) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_ordered_type_desc_temp ON universal_award_matview_temp USING BTREE(type_description DESC NULLS LAST) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_ordered_fain_temp ON universal_award_matview_temp USING BTREE(UPPER(fain) DESC NULLS LAST) WITH (fillfactor = 97) WHERE fain IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_ordered_piid_temp ON universal_award_matview_temp USING BTREE(UPPER(piid) DESC NULLS LAST) WITH (fillfactor = 97) WHERE piid IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_total_obligation_temp ON universal_award_matview_temp USING BTREE(total_obligation) WITH (fillfactor = 97) WHERE total_obligation IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_ordered_total_obligation_temp ON universal_award_matview_temp USING BTREE(total_obligation DESC NULLS LAST) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_total_obl_bin_temp ON universal_award_matview_temp USING BTREE(total_obl_bin) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
DO $$ BEGIN RAISE NOTICE '10 indexes created, 62 remaining'; END $$;
CREATE INDEX idx_76387eb4$b67_total_subsidy_cost_temp ON universal_award_matview_temp USING BTREE(total_subsidy_cost) WITH (fillfactor = 97) WHERE total_subsidy_cost IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_total_loan_value_temp ON universal_award_matview_temp USING BTREE(total_loan_value) WITH (fillfactor = 97) WHERE total_loan_value IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_ordered_total_subsidy_cost_temp ON universal_award_matview_temp USING BTREE(total_subsidy_cost DESC NULLS LAST) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_ordered_total_loan_value_temp ON universal_award_matview_temp USING BTREE(total_loan_value DESC NULLS LAST) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_period_of_performance_start_date_temp ON universal_award_matview_temp USING BTREE(period_of_performance_start_date DESC NULLS LAST) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_period_of_performance_current_end_date_temp ON universal_award_matview_temp USING BTREE(period_of_performance_current_end_date DESC NULLS LAST) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_ordered_ordering_period_end_date_temp ON universal_award_matview_temp USING BTREE(ordering_period_end_date DESC NULLS LAST) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_recipient_name_temp ON universal_award_matview_temp USING BTREE(recipient_name) WITH (fillfactor = 97) WHERE recipient_name IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_recipient_unique_id_temp ON universal_award_matview_temp USING BTREE(recipient_unique_id) WITH (fillfactor = 97) WHERE recipient_unique_id IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_parent_recipient_unique_id_temp ON universal_award_matview_temp USING BTREE(parent_recipient_unique_id) WITH (fillfactor = 97) WHERE parent_recipient_unique_id IS NOT NULL AND action_date >= '2007-10-01';
DO $$ BEGIN RAISE NOTICE '20 indexes created, 52 remaining'; END $$;
CREATE INDEX idx_76387eb4$b67_action_date_temp ON universal_award_matview_temp USING BTREE(action_date DESC NULLS LAST) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_last_modified_date_temp ON universal_award_matview_temp USING BTREE(last_modified_date DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_76387eb4$b67_awarding_agency_id_temp ON universal_award_matview_temp USING BTREE(awarding_agency_id ASC NULLS LAST) WITH (fillfactor = 97) WHERE awarding_agency_id IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_funding_agency_id_temp ON universal_award_matview_temp USING BTREE(funding_agency_id ASC NULLS LAST) WITH (fillfactor = 97) WHERE funding_agency_id IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_ordered_awarding_toptier_agency_name_temp ON universal_award_matview_temp USING BTREE(awarding_toptier_agency_name DESC NULLS LAST) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_ordered_awarding_subtier_agency_name_temp ON universal_award_matview_temp USING BTREE(awarding_subtier_agency_name DESC NULLS LAST) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_awarding_toptier_agency_name_temp ON universal_award_matview_temp USING BTREE(awarding_toptier_agency_name) WITH (fillfactor = 97) WHERE awarding_toptier_agency_name IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_awarding_subtier_agency_name_temp ON universal_award_matview_temp USING BTREE(awarding_subtier_agency_name) WITH (fillfactor = 97) WHERE awarding_subtier_agency_name IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_funding_toptier_agency_name_temp ON universal_award_matview_temp USING BTREE(funding_toptier_agency_name) WITH (fillfactor = 97) WHERE funding_toptier_agency_name IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_funding_subtier_agency_name_temp ON universal_award_matview_temp USING BTREE(funding_subtier_agency_name) WITH (fillfactor = 97) WHERE funding_subtier_agency_name IS NOT NULL AND action_date >= '2007-10-01';
DO $$ BEGIN RAISE NOTICE '30 indexes created, 42 remaining'; END $$;
CREATE INDEX idx_76387eb4$b67_recipient_location_country_code_temp ON universal_award_matview_temp USING BTREE(recipient_location_country_code) WITH (fillfactor = 97) WHERE recipient_location_country_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_recipient_location_state_code_temp ON universal_award_matview_temp USING BTREE(recipient_location_state_code) WITH (fillfactor = 97) WHERE recipient_location_state_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_recipient_location_county_code_temp ON universal_award_matview_temp USING BTREE(recipient_location_county_code) WITH (fillfactor = 97) WHERE recipient_location_county_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_recipient_location_zip5_temp ON universal_award_matview_temp USING BTREE(recipient_location_zip5) WITH (fillfactor = 97) WHERE recipient_location_zip5 IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_recipient_location_cong_code_temp ON universal_award_matview_temp USING BTREE(recipient_location_congressional_code) WITH (fillfactor = 97) WHERE recipient_location_congressional_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_pop_country_code_temp ON universal_award_matview_temp USING BTREE(pop_country_code) WITH (fillfactor = 97) WHERE pop_country_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_pop_state_code_temp ON universal_award_matview_temp USING BTREE(pop_state_code) WITH (fillfactor = 97) WHERE pop_state_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_pop_county_code_temp ON universal_award_matview_temp USING BTREE(pop_county_code) WITH (fillfactor = 97) WHERE pop_county_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_pop_zip5_temp ON universal_award_matview_temp USING BTREE(pop_zip5) WITH (fillfactor = 97) WHERE pop_zip5 IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_pop_congressional_code_temp ON universal_award_matview_temp USING BTREE(pop_congressional_code) WITH (fillfactor = 97) WHERE pop_congressional_code IS NOT NULL AND action_date >= '2007-10-01';
DO $$ BEGIN RAISE NOTICE '40 indexes created, 32 remaining'; END $$;
CREATE INDEX idx_76387eb4$b67_simple_pop_geolocation_temp ON universal_award_matview_temp USING BTREE(pop_state_code, action_date) WITH (fillfactor = 97) WHERE pop_country_code = 'USA' AND pop_state_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_compound_geo_pop_1_temp ON universal_award_matview_temp USING BTREE(pop_state_code, pop_county_code, action_date) WITH (fillfactor = 97) WHERE pop_country_code = 'USA' AND pop_state_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_compound_geo_pop_2_temp ON universal_award_matview_temp USING BTREE(pop_state_code, pop_congressional_code, action_date) WITH (fillfactor = 97) WHERE pop_country_code = 'USA' AND pop_state_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_compound_geo_pop_3_temp ON universal_award_matview_temp USING BTREE(pop_zip5, action_date) WITH (fillfactor = 97) WHERE pop_country_code = 'USA' AND pop_zip5 IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_simple_recipient_location_geolocation_temp ON universal_award_matview_temp USING BTREE(recipient_location_state_code, action_date) WITH (fillfactor = 97) WHERE recipient_location_country_code = 'USA' AND recipient_location_state_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_compound_geo_rl_1_temp ON universal_award_matview_temp USING BTREE(recipient_location_state_code, recipient_location_county_code, action_date) WITH (fillfactor = 97) WHERE recipient_location_country_code = 'USA' AND recipient_location_state_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_compound_geo_rl_2_temp ON universal_award_matview_temp USING BTREE(recipient_location_state_code, recipient_location_congressional_code, action_date) WITH (fillfactor = 97) WHERE recipient_location_country_code = 'USA' AND recipient_location_state_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_compound_geo_rl_3_temp ON universal_award_matview_temp USING BTREE(recipient_location_zip5, action_date) WITH (fillfactor = 97) WHERE recipient_location_country_code = 'USA' AND recipient_location_zip5 IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_cfda_number_temp ON universal_award_matview_temp USING BTREE(cfda_number) WITH (fillfactor = 97) WHERE cfda_number IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_pulled_from_temp ON universal_award_matview_temp USING BTREE(pulled_from) WITH (fillfactor = 97) WHERE pulled_from IS NOT NULL AND action_date >= '2007-10-01';
DO $$ BEGIN RAISE NOTICE '50 indexes created, 22 remaining'; END $$;
CREATE INDEX idx_76387eb4$b67_type_of_contract_pricing_temp ON universal_award_matview_temp USING BTREE(type_of_contract_pricing) WITH (fillfactor = 97) WHERE type_of_contract_pricing IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_extent_competed_temp ON universal_award_matview_temp USING BTREE(extent_competed) WITH (fillfactor = 97) WHERE extent_competed IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_type_set_aside_temp ON universal_award_matview_temp USING BTREE(type_set_aside) WITH (fillfactor = 97) WHERE type_set_aside IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_product_or_service_code_temp ON universal_award_matview_temp USING BTREE(product_or_service_code) WITH (fillfactor = 97) WHERE product_or_service_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_gin_product_or_service_description_temp ON universal_award_matview_temp USING GIN((product_or_service_description) gin_trgm_ops);
CREATE INDEX idx_76387eb4$b67_naics_temp ON universal_award_matview_temp USING BTREE(naics_code) WITH (fillfactor = 97) WHERE naics_code IS NOT NULL AND action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_gin_naics_code_temp ON universal_award_matview_temp USING GIN(naics_code gin_trgm_ops);
CREATE INDEX idx_76387eb4$b67_gin_naics_description_temp ON universal_award_matview_temp USING GIN(UPPER(naics_description) gin_trgm_ops);
CREATE INDEX idx_76387eb4$b67_gin_business_categories_temp ON universal_award_matview_temp USING GIN(business_categories);
CREATE INDEX idx_76387eb4$b67_keyword_ts_vector_temp ON universal_award_matview_temp USING GIN(keyword_ts_vector);
DO $$ BEGIN RAISE NOTICE '60 indexes created, 12 remaining'; END $$;
CREATE INDEX idx_76387eb4$b67_award_ts_vector_temp ON universal_award_matview_temp USING GIN(award_ts_vector);
CREATE INDEX idx_76387eb4$b67_recipient_name_ts_vector_temp ON universal_award_matview_temp USING GIN(recipient_name_ts_vector);
CREATE INDEX idx_76387eb4$b67_compound_psc_action_date_temp ON universal_award_matview_temp USING BTREE(product_or_service_code, action_date) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_compound_naics_action_date_temp ON universal_award_matview_temp USING BTREE(naics_code, action_date) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_compound_cfda_action_date_temp ON universal_award_matview_temp USING BTREE(cfda_number, action_date) WITH (fillfactor = 97) WHERE action_date >= '2007-10-01';
CREATE INDEX idx_76387eb4$b67_awarding_toptier_agency_name_pre2008_temp ON universal_award_matview_temp USING BTREE(awarding_toptier_agency_name) WITH (fillfactor = 97) WHERE awarding_toptier_agency_name IS NOT NULL AND action_date < '2007-10-01';
CREATE INDEX idx_76387eb4$b67_awarding_subtier_agency_name_pre2008_temp ON universal_award_matview_temp USING BTREE(awarding_subtier_agency_name) WITH (fillfactor = 97) WHERE awarding_subtier_agency_name IS NOT NULL AND action_date < '2007-10-01';
CREATE INDEX idx_76387eb4$b67_type_pre2008_temp ON universal_award_matview_temp USING BTREE(type) WITH (fillfactor = 97) WHERE type IS NOT NULL AND action_date < '2007-10-01';
CREATE INDEX idx_76387eb4$b67_pulled_from_pre2008_temp ON universal_award_matview_temp USING BTREE(pulled_from) WITH (fillfactor = 97) WHERE pulled_from IS NOT NULL AND action_date < '2007-10-01';
CREATE INDEX idx_76387eb4$b67_recipient_location_country_code_pre2008_temp ON universal_award_matview_temp USING BTREE(recipient_location_country_code) WITH (fillfactor = 97) WHERE recipient_location_country_code IS NOT NULL AND action_date < '2007-10-01';
DO $$ BEGIN RAISE NOTICE '70 indexes created, 2 remaining'; END $$;
CREATE INDEX idx_76387eb4$b67_recipient_location_state_code_pre2008_temp ON universal_award_matview_temp USING BTREE(recipient_location_state_code) WITH (fillfactor = 97) WHERE recipient_location_state_code IS NOT NULL AND action_date < '2007-10-01';
CREATE INDEX idx_76387eb4$b67_action_date_pre2008_temp ON universal_award_matview_temp USING BTREE(action_date) WITH (fillfactor = 97) WHERE action_date < '2007-10-01';

ALTER MATERIALIZED VIEW IF EXISTS universal_award_matview RENAME TO universal_award_matview_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_id RENAME TO idx_76387eb4$b67_id_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_category RENAME TO idx_76387eb4$b67_category_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_type RENAME TO idx_76387eb4$b67_type_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_ordered_type RENAME TO idx_76387eb4$b67_ordered_type_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_ordered_type_desc RENAME TO idx_76387eb4$b67_ordered_type_desc_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_ordered_fain RENAME TO idx_76387eb4$b67_ordered_fain_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_ordered_piid RENAME TO idx_76387eb4$b67_ordered_piid_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_total_obligation RENAME TO idx_76387eb4$b67_total_obligation_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_ordered_total_obligation RENAME TO idx_76387eb4$b67_ordered_total_obligation_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_total_obl_bin RENAME TO idx_76387eb4$b67_total_obl_bin_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_total_subsidy_cost RENAME TO idx_76387eb4$b67_total_subsidy_cost_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_total_loan_value RENAME TO idx_76387eb4$b67_total_loan_value_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_ordered_total_subsidy_cost RENAME TO idx_76387eb4$b67_ordered_total_subsidy_cost_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_ordered_total_loan_value RENAME TO idx_76387eb4$b67_ordered_total_loan_value_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_period_of_performance_start_date RENAME TO idx_76387eb4$b67_period_of_performance_start_date_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_period_of_performance_current_end_date RENAME TO idx_76387eb4$b67_period_of_performance_current_end_date_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_ordered_ordering_period_end_date RENAME TO idx_76387eb4$b67_ordered_ordering_period_end_date_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_recipient_name RENAME TO idx_76387eb4$b67_recipient_name_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_recipient_unique_id RENAME TO idx_76387eb4$b67_recipient_unique_id_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_parent_recipient_unique_id RENAME TO idx_76387eb4$b67_parent_recipient_unique_id_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_action_date RENAME TO idx_76387eb4$b67_action_date_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_last_modified_date RENAME TO idx_76387eb4$b67_last_modified_date_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_awarding_agency_id RENAME TO idx_76387eb4$b67_awarding_agency_id_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_funding_agency_id RENAME TO idx_76387eb4$b67_funding_agency_id_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_ordered_awarding_toptier_agency_name RENAME TO idx_76387eb4$b67_ordered_awarding_toptier_agency_name_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_ordered_awarding_subtier_agency_name RENAME TO idx_76387eb4$b67_ordered_awarding_subtier_agency_name_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_awarding_toptier_agency_name RENAME TO idx_76387eb4$b67_awarding_toptier_agency_name_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_awarding_subtier_agency_name RENAME TO idx_76387eb4$b67_awarding_subtier_agency_name_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_funding_toptier_agency_name RENAME TO idx_76387eb4$b67_funding_toptier_agency_name_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_funding_subtier_agency_name RENAME TO idx_76387eb4$b67_funding_subtier_agency_name_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_recipient_location_country_code RENAME TO idx_76387eb4$b67_recipient_location_country_code_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_recipient_location_state_code RENAME TO idx_76387eb4$b67_recipient_location_state_code_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_recipient_location_county_code RENAME TO idx_76387eb4$b67_recipient_location_county_code_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_recipient_location_zip5 RENAME TO idx_76387eb4$b67_recipient_location_zip5_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_recipient_location_cong_code RENAME TO idx_76387eb4$b67_recipient_location_cong_code_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_pop_country_code RENAME TO idx_76387eb4$b67_pop_country_code_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_pop_state_code RENAME TO idx_76387eb4$b67_pop_state_code_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_pop_county_code RENAME TO idx_76387eb4$b67_pop_county_code_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_pop_zip5 RENAME TO idx_76387eb4$b67_pop_zip5_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_pop_congressional_code RENAME TO idx_76387eb4$b67_pop_congressional_code_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_simple_pop_geolocation RENAME TO idx_76387eb4$b67_simple_pop_geolocation_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_compound_geo_pop_1 RENAME TO idx_76387eb4$b67_compound_geo_pop_1_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_compound_geo_pop_2 RENAME TO idx_76387eb4$b67_compound_geo_pop_2_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_compound_geo_pop_3 RENAME TO idx_76387eb4$b67_compound_geo_pop_3_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_simple_recipient_location_geolocation RENAME TO idx_76387eb4$b67_simple_recipient_location_geolocation_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_compound_geo_rl_1 RENAME TO idx_76387eb4$b67_compound_geo_rl_1_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_compound_geo_rl_2 RENAME TO idx_76387eb4$b67_compound_geo_rl_2_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_compound_geo_rl_3 RENAME TO idx_76387eb4$b67_compound_geo_rl_3_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_cfda_number RENAME TO idx_76387eb4$b67_cfda_number_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_pulled_from RENAME TO idx_76387eb4$b67_pulled_from_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_type_of_contract_pricing RENAME TO idx_76387eb4$b67_type_of_contract_pricing_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_extent_competed RENAME TO idx_76387eb4$b67_extent_competed_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_type_set_aside RENAME TO idx_76387eb4$b67_type_set_aside_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_product_or_service_code RENAME TO idx_76387eb4$b67_product_or_service_code_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_gin_product_or_service_description RENAME TO idx_76387eb4$b67_gin_product_or_service_description_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_naics RENAME TO idx_76387eb4$b67_naics_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_gin_naics_code RENAME TO idx_76387eb4$b67_gin_naics_code_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_gin_naics_description RENAME TO idx_76387eb4$b67_gin_naics_description_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_gin_business_categories RENAME TO idx_76387eb4$b67_gin_business_categories_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_keyword_ts_vector RENAME TO idx_76387eb4$b67_keyword_ts_vector_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_award_ts_vector RENAME TO idx_76387eb4$b67_award_ts_vector_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_recipient_name_ts_vector RENAME TO idx_76387eb4$b67_recipient_name_ts_vector_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_compound_psc_action_date RENAME TO idx_76387eb4$b67_compound_psc_action_date_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_compound_naics_action_date RENAME TO idx_76387eb4$b67_compound_naics_action_date_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_compound_cfda_action_date RENAME TO idx_76387eb4$b67_compound_cfda_action_date_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_awarding_toptier_agency_name_pre2008 RENAME TO idx_76387eb4$b67_awarding_toptier_agency_name_pre2008_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_awarding_subtier_agency_name_pre2008 RENAME TO idx_76387eb4$b67_awarding_subtier_agency_name_pre2008_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_type_pre2008 RENAME TO idx_76387eb4$b67_type_pre2008_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_pulled_from_pre2008 RENAME TO idx_76387eb4$b67_pulled_from_pre2008_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_recipient_location_country_code_pre2008 RENAME TO idx_76387eb4$b67_recipient_location_country_code_pre2008_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_recipient_location_state_code_pre2008 RENAME TO idx_76387eb4$b67_recipient_location_state_code_pre2008_old;
ALTER INDEX IF EXISTS idx_76387eb4$b67_action_date_pre2008 RENAME TO idx_76387eb4$b67_action_date_pre2008_old;

ALTER MATERIALIZED VIEW universal_award_matview_temp RENAME TO universal_award_matview;
ALTER INDEX idx_76387eb4$b67_id_temp RENAME TO idx_76387eb4$b67_id;
ALTER INDEX idx_76387eb4$b67_category_temp RENAME TO idx_76387eb4$b67_category;
ALTER INDEX idx_76387eb4$b67_type_temp RENAME TO idx_76387eb4$b67_type;
ALTER INDEX idx_76387eb4$b67_ordered_type_temp RENAME TO idx_76387eb4$b67_ordered_type;
ALTER INDEX idx_76387eb4$b67_ordered_type_desc_temp RENAME TO idx_76387eb4$b67_ordered_type_desc;
ALTER INDEX idx_76387eb4$b67_ordered_fain_temp RENAME TO idx_76387eb4$b67_ordered_fain;
ALTER INDEX idx_76387eb4$b67_ordered_piid_temp RENAME TO idx_76387eb4$b67_ordered_piid;
ALTER INDEX idx_76387eb4$b67_total_obligation_temp RENAME TO idx_76387eb4$b67_total_obligation;
ALTER INDEX idx_76387eb4$b67_ordered_total_obligation_temp RENAME TO idx_76387eb4$b67_ordered_total_obligation;
ALTER INDEX idx_76387eb4$b67_total_obl_bin_temp RENAME TO idx_76387eb4$b67_total_obl_bin;
ALTER INDEX idx_76387eb4$b67_total_subsidy_cost_temp RENAME TO idx_76387eb4$b67_total_subsidy_cost;
ALTER INDEX idx_76387eb4$b67_total_loan_value_temp RENAME TO idx_76387eb4$b67_total_loan_value;
ALTER INDEX idx_76387eb4$b67_ordered_total_subsidy_cost_temp RENAME TO idx_76387eb4$b67_ordered_total_subsidy_cost;
ALTER INDEX idx_76387eb4$b67_ordered_total_loan_value_temp RENAME TO idx_76387eb4$b67_ordered_total_loan_value;
ALTER INDEX idx_76387eb4$b67_period_of_performance_start_date_temp RENAME TO idx_76387eb4$b67_period_of_performance_start_date;
ALTER INDEX idx_76387eb4$b67_period_of_performance_current_end_date_temp RENAME TO idx_76387eb4$b67_period_of_performance_current_end_date;
ALTER INDEX idx_76387eb4$b67_ordered_ordering_period_end_date_temp RENAME TO idx_76387eb4$b67_ordered_ordering_period_end_date;
ALTER INDEX idx_76387eb4$b67_recipient_name_temp RENAME TO idx_76387eb4$b67_recipient_name;
ALTER INDEX idx_76387eb4$b67_recipient_unique_id_temp RENAME TO idx_76387eb4$b67_recipient_unique_id;
ALTER INDEX idx_76387eb4$b67_parent_recipient_unique_id_temp RENAME TO idx_76387eb4$b67_parent_recipient_unique_id;
ALTER INDEX idx_76387eb4$b67_action_date_temp RENAME TO idx_76387eb4$b67_action_date;
ALTER INDEX idx_76387eb4$b67_last_modified_date_temp RENAME TO idx_76387eb4$b67_last_modified_date;
ALTER INDEX idx_76387eb4$b67_awarding_agency_id_temp RENAME TO idx_76387eb4$b67_awarding_agency_id;
ALTER INDEX idx_76387eb4$b67_funding_agency_id_temp RENAME TO idx_76387eb4$b67_funding_agency_id;
ALTER INDEX idx_76387eb4$b67_ordered_awarding_toptier_agency_name_temp RENAME TO idx_76387eb4$b67_ordered_awarding_toptier_agency_name;
ALTER INDEX idx_76387eb4$b67_ordered_awarding_subtier_agency_name_temp RENAME TO idx_76387eb4$b67_ordered_awarding_subtier_agency_name;
ALTER INDEX idx_76387eb4$b67_awarding_toptier_agency_name_temp RENAME TO idx_76387eb4$b67_awarding_toptier_agency_name;
ALTER INDEX idx_76387eb4$b67_awarding_subtier_agency_name_temp RENAME TO idx_76387eb4$b67_awarding_subtier_agency_name;
ALTER INDEX idx_76387eb4$b67_funding_toptier_agency_name_temp RENAME TO idx_76387eb4$b67_funding_toptier_agency_name;
ALTER INDEX idx_76387eb4$b67_funding_subtier_agency_name_temp RENAME TO idx_76387eb4$b67_funding_subtier_agency_name;
ALTER INDEX idx_76387eb4$b67_recipient_location_country_code_temp RENAME TO idx_76387eb4$b67_recipient_location_country_code;
ALTER INDEX idx_76387eb4$b67_recipient_location_state_code_temp RENAME TO idx_76387eb4$b67_recipient_location_state_code;
ALTER INDEX idx_76387eb4$b67_recipient_location_county_code_temp RENAME TO idx_76387eb4$b67_recipient_location_county_code;
ALTER INDEX idx_76387eb4$b67_recipient_location_zip5_temp RENAME TO idx_76387eb4$b67_recipient_location_zip5;
ALTER INDEX idx_76387eb4$b67_recipient_location_cong_code_temp RENAME TO idx_76387eb4$b67_recipient_location_cong_code;
ALTER INDEX idx_76387eb4$b67_pop_country_code_temp RENAME TO idx_76387eb4$b67_pop_country_code;
ALTER INDEX idx_76387eb4$b67_pop_state_code_temp RENAME TO idx_76387eb4$b67_pop_state_code;
ALTER INDEX idx_76387eb4$b67_pop_county_code_temp RENAME TO idx_76387eb4$b67_pop_county_code;
ALTER INDEX idx_76387eb4$b67_pop_zip5_temp RENAME TO idx_76387eb4$b67_pop_zip5;
ALTER INDEX idx_76387eb4$b67_pop_congressional_code_temp RENAME TO idx_76387eb4$b67_pop_congressional_code;
ALTER INDEX idx_76387eb4$b67_simple_pop_geolocation_temp RENAME TO idx_76387eb4$b67_simple_pop_geolocation;
ALTER INDEX idx_76387eb4$b67_compound_geo_pop_1_temp RENAME TO idx_76387eb4$b67_compound_geo_pop_1;
ALTER INDEX idx_76387eb4$b67_compound_geo_pop_2_temp RENAME TO idx_76387eb4$b67_compound_geo_pop_2;
ALTER INDEX idx_76387eb4$b67_compound_geo_pop_3_temp RENAME TO idx_76387eb4$b67_compound_geo_pop_3;
ALTER INDEX idx_76387eb4$b67_simple_recipient_location_geolocation_temp RENAME TO idx_76387eb4$b67_simple_recipient_location_geolocation;
ALTER INDEX idx_76387eb4$b67_compound_geo_rl_1_temp RENAME TO idx_76387eb4$b67_compound_geo_rl_1;
ALTER INDEX idx_76387eb4$b67_compound_geo_rl_2_temp RENAME TO idx_76387eb4$b67_compound_geo_rl_2;
ALTER INDEX idx_76387eb4$b67_compound_geo_rl_3_temp RENAME TO idx_76387eb4$b67_compound_geo_rl_3;
ALTER INDEX idx_76387eb4$b67_cfda_number_temp RENAME TO idx_76387eb4$b67_cfda_number;
ALTER INDEX idx_76387eb4$b67_pulled_from_temp RENAME TO idx_76387eb4$b67_pulled_from;
ALTER INDEX idx_76387eb4$b67_type_of_contract_pricing_temp RENAME TO idx_76387eb4$b67_type_of_contract_pricing;
ALTER INDEX idx_76387eb4$b67_extent_competed_temp RENAME TO idx_76387eb4$b67_extent_competed;
ALTER INDEX idx_76387eb4$b67_type_set_aside_temp RENAME TO idx_76387eb4$b67_type_set_aside;
ALTER INDEX idx_76387eb4$b67_product_or_service_code_temp RENAME TO idx_76387eb4$b67_product_or_service_code;
ALTER INDEX idx_76387eb4$b67_gin_product_or_service_description_temp RENAME TO idx_76387eb4$b67_gin_product_or_service_description;
ALTER INDEX idx_76387eb4$b67_naics_temp RENAME TO idx_76387eb4$b67_naics;
ALTER INDEX idx_76387eb4$b67_gin_naics_code_temp RENAME TO idx_76387eb4$b67_gin_naics_code;
ALTER INDEX idx_76387eb4$b67_gin_naics_description_temp RENAME TO idx_76387eb4$b67_gin_naics_description;
ALTER INDEX idx_76387eb4$b67_gin_business_categories_temp RENAME TO idx_76387eb4$b67_gin_business_categories;
ALTER INDEX idx_76387eb4$b67_keyword_ts_vector_temp RENAME TO idx_76387eb4$b67_keyword_ts_vector;
ALTER INDEX idx_76387eb4$b67_award_ts_vector_temp RENAME TO idx_76387eb4$b67_award_ts_vector;
ALTER INDEX idx_76387eb4$b67_recipient_name_ts_vector_temp RENAME TO idx_76387eb4$b67_recipient_name_ts_vector;
ALTER INDEX idx_76387eb4$b67_compound_psc_action_date_temp RENAME TO idx_76387eb4$b67_compound_psc_action_date;
ALTER INDEX idx_76387eb4$b67_compound_naics_action_date_temp RENAME TO idx_76387eb4$b67_compound_naics_action_date;
ALTER INDEX idx_76387eb4$b67_compound_cfda_action_date_temp RENAME TO idx_76387eb4$b67_compound_cfda_action_date;
ALTER INDEX idx_76387eb4$b67_awarding_toptier_agency_name_pre2008_temp RENAME TO idx_76387eb4$b67_awarding_toptier_agency_name_pre2008;
ALTER INDEX idx_76387eb4$b67_awarding_subtier_agency_name_pre2008_temp RENAME TO idx_76387eb4$b67_awarding_subtier_agency_name_pre2008;
ALTER INDEX idx_76387eb4$b67_type_pre2008_temp RENAME TO idx_76387eb4$b67_type_pre2008;
ALTER INDEX idx_76387eb4$b67_pulled_from_pre2008_temp RENAME TO idx_76387eb4$b67_pulled_from_pre2008;
ALTER INDEX idx_76387eb4$b67_recipient_location_country_code_pre2008_temp RENAME TO idx_76387eb4$b67_recipient_location_country_code_pre2008;
ALTER INDEX idx_76387eb4$b67_recipient_location_state_code_pre2008_temp RENAME TO idx_76387eb4$b67_recipient_location_state_code_pre2008;
ALTER INDEX idx_76387eb4$b67_action_date_pre2008_temp RENAME TO idx_76387eb4$b67_action_date_pre2008;

ANALYZE VERBOSE universal_award_matview;
GRANT SELECT ON universal_award_matview TO readonly;
