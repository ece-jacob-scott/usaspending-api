DROP MATERIALIZED VIEW IF EXISTS subaward_view_temp CASCADE;
DROP MATERIALIZED VIEW IF EXISTS subaward_view_old CASCADE;

CREATE MATERIALIZED VIEW subaward_view_temp AS
SELECT
  id AS subaward_id,
  to_tsvector(CONCAT_WS(' ',
    sub.recipient_name,
    psc.description,
    sub.description
  )) AS keyword_ts_vector,
  to_tsvector(CONCAT_WS(' ', piid, fain, subaward_number)) AS award_ts_vector,
  to_tsvector(COALESCE(sub.recipient_name, '')) AS recipient_name_ts_vector,

  latest_transaction_id,
  last_modified_date,
  subaward_number,
  amount AS amount,
  obligation_to_enum(amount) AS total_obl_bin,
  sub.description,
  fy(action_date) AS fiscal_year,
  action_date,
  award_report_fy_month,
  award_report_fy_year,

  award_id,
  awarding_agency_id,
  funding_agency_id,
  awarding_toptier_agency_name,
  awarding_subtier_agency_name,
  funding_toptier_agency_name,
  funding_subtier_agency_name,
  awarding_toptier_agency_abbreviation,
  funding_toptier_agency_abbreviation,
  awarding_subtier_agency_abbreviation,
  funding_subtier_agency_abbreviation,

  recipient_unique_id,
  dba_name,
  parent_recipient_unique_id,
  UPPER(COALESCE(recipient_lookup.recipient_name, sub.recipient_name)) AS recipient_name,
  UPPER(COALESCE(parent_recipient_lookup.recipient_name, parent_recipient_name)) AS parent_recipient_name,
  business_type_code,
  business_type_description,

  award_type,
  prime_award_type,

  cfda_id,
  piid,
  fain,

  business_categories,
  prime_recipient_name,

  pulled_from,
  type_of_contract_pricing,
  extent_competed,
  type_set_aside,
  product_or_service_code,
  psc.description AS product_or_service_description,
  cfda_number,
  cfda_title,

  recipient_location_country_name,
  recipient_location_country_code,
  recipient_location_city_name,
  recipient_location_state_code,
  recipient_location_state_name,
  recipient_location_county_code,
  recipient_location_county_name,
  LEFT(COALESCE(recipient_location_zip4, ''), 5) AS recipient_location_zip5,
  recipient_location_street_address,
  recipient_location_congressional_code,

  pop_country_name,
  pop_country_code,
  pop_state_code,
  pop_state_name,
  pop_county_code,
  pop_county_name,
  pop_city_code,
  pop_city_name,
  LEFT(COALESCE(pop_zip4, ''), 5) AS pop_zip5,
  pop_street_address,
  pop_congressional_code
FROM
  subaward AS sub
LEFT OUTER JOIN psc ON product_or_service_code = psc.code
LEFT OUTER JOIN
  (SELECT
    legal_business_name AS recipient_name,
    duns
  FROM recipient_lookup AS rlv
  ) recipient_lookup ON recipient_lookup.duns = recipient_unique_id AND recipient_unique_id IS NOT NULL
LEFT OUTER JOIN
  (SELECT
    legal_business_name AS recipient_name,
    duns
  FROM recipient_lookup AS rlv
  ) parent_recipient_lookup ON parent_recipient_lookup.duns = parent_recipient_unique_id AND parent_recipient_unique_id IS NOT NULL
ORDER BY
  amount DESC NULLS LAST WITH DATA;

CREATE UNIQUE INDEX idx_5dff09d1$c46_subaward_id_temp ON subaward_view_temp USING BTREE(subaward_id) WITH (fillfactor = 97);
CREATE INDEX idx_5dff09d1$c46_award_type_temp ON subaward_view_temp USING BTREE(award_type) WITH (fillfactor = 97) WHERE award_type IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_ordered_subaward_number_temp ON subaward_view_temp USING BTREE(subaward_number DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_5dff09d1$c46_ordered_award_type_temp ON subaward_view_temp USING BTREE(award_type DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_5dff09d1$c46_ordered_fain_temp ON subaward_view_temp USING BTREE(UPPER(fain) DESC NULLS LAST) WITH (fillfactor = 97) WHERE fain IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_ordered_piid_temp ON subaward_view_temp USING BTREE(UPPER(piid) DESC NULLS LAST) WITH (fillfactor = 97) WHERE piid IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_amount_temp ON subaward_view_temp USING BTREE(amount) WITH (fillfactor = 97) WHERE amount IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_ordered_amount_temp ON subaward_view_temp USING BTREE(amount DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_5dff09d1$c46_total_obl_bin_temp ON subaward_view_temp USING BTREE(total_obl_bin) WITH (fillfactor = 97);
CREATE INDEX idx_5dff09d1$c46_gin_recipient_name_temp ON subaward_view_temp USING GIN(recipient_name gin_trgm_ops);
DO $$ BEGIN RAISE NOTICE '10 indexes created, 37 remaining'; END $$;
CREATE INDEX idx_5dff09d1$c46_recipient_name_temp ON subaward_view_temp USING BTREE(recipient_name) WITH (fillfactor = 97) WHERE recipient_name IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_recipient_unique_id_temp ON subaward_view_temp USING BTREE(recipient_unique_id) WITH (fillfactor = 97) WHERE recipient_unique_id IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_parent_recipient_unique_id_temp ON subaward_view_temp USING BTREE(parent_recipient_unique_id) WITH (fillfactor = 97) WHERE parent_recipient_unique_id IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_action_date_temp ON subaward_view_temp USING BTREE(action_date DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_5dff09d1$c46_last_modified_date_temp ON subaward_view_temp USING BTREE(last_modified_date DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_5dff09d1$c46_fiscal_year_temp ON subaward_view_temp USING BTREE(fiscal_year DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_5dff09d1$c46_awarding_agency_id_temp ON subaward_view_temp USING BTREE(awarding_agency_id ASC NULLS LAST) WITH (fillfactor = 97) WHERE awarding_agency_id IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_funding_agency_id_temp ON subaward_view_temp USING BTREE(funding_agency_id ASC NULLS LAST) WITH (fillfactor = 97) WHERE funding_agency_id IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_ordered_awarding_toptier_agency_name_temp ON subaward_view_temp USING BTREE(awarding_toptier_agency_name DESC NULLS LAST) WITH (fillfactor = 97);
CREATE INDEX idx_5dff09d1$c46_ordered_awarding_subtier_agency_name_temp ON subaward_view_temp USING BTREE(awarding_subtier_agency_name DESC NULLS LAST) WITH (fillfactor = 97);
DO $$ BEGIN RAISE NOTICE '20 indexes created, 27 remaining'; END $$;
CREATE INDEX idx_5dff09d1$c46_awarding_toptier_agency_name_temp ON subaward_view_temp USING BTREE(awarding_toptier_agency_name) WITH (fillfactor = 97) WHERE awarding_toptier_agency_name IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_awarding_subtier_agency_name_temp ON subaward_view_temp USING BTREE(awarding_subtier_agency_name) WITH (fillfactor = 97) WHERE awarding_subtier_agency_name IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_funding_toptier_agency_name_temp ON subaward_view_temp USING BTREE(funding_toptier_agency_name) WITH (fillfactor = 97) WHERE funding_toptier_agency_name IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_funding_subtier_agency_name_temp ON subaward_view_temp USING BTREE(funding_subtier_agency_name) WITH (fillfactor = 97) WHERE funding_subtier_agency_name IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_recipient_location_country_code_temp ON subaward_view_temp USING BTREE(recipient_location_country_code) WITH (fillfactor = 97) WHERE recipient_location_country_code IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_recipient_location_state_code_temp ON subaward_view_temp USING BTREE(recipient_location_state_code) WITH (fillfactor = 97) WHERE recipient_location_state_code IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_recipient_location_county_code_temp ON subaward_view_temp USING BTREE(recipient_location_county_code) WITH (fillfactor = 97) WHERE recipient_location_county_code IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_recipient_location_zip5_temp ON subaward_view_temp USING BTREE(recipient_location_zip5) WITH (fillfactor = 97) WHERE recipient_location_zip5 IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_recipient_location_cong_code_temp ON subaward_view_temp USING BTREE(recipient_location_congressional_code) WITH (fillfactor = 97) WHERE recipient_location_congressional_code IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_pop_country_code_temp ON subaward_view_temp USING BTREE(pop_country_code) WITH (fillfactor = 97) WHERE pop_country_code IS NOT NULL;
DO $$ BEGIN RAISE NOTICE '30 indexes created, 17 remaining'; END $$;
CREATE INDEX idx_5dff09d1$c46_pop_state_code_temp ON subaward_view_temp USING BTREE(pop_state_code) WITH (fillfactor = 97) WHERE pop_state_code IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_pop_county_code_temp ON subaward_view_temp USING BTREE(pop_county_code) WITH (fillfactor = 97) WHERE pop_county_code IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_pop_zip5_temp ON subaward_view_temp USING BTREE(pop_zip5) WITH (fillfactor = 97) WHERE pop_zip5 IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_pop_congressional_code_temp ON subaward_view_temp USING BTREE(pop_congressional_code) WITH (fillfactor = 97) WHERE pop_congressional_code IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_cfda_number_temp ON subaward_view_temp USING BTREE(cfda_number) WITH (fillfactor = 97) WHERE cfda_number IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_pulled_from_temp ON subaward_view_temp USING BTREE(pulled_from) WITH (fillfactor = 97) WHERE pulled_from IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_type_of_contract_pricing_temp ON subaward_view_temp USING BTREE(type_of_contract_pricing) WITH (fillfactor = 97) WHERE type_of_contract_pricing IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_extent_competed_temp ON subaward_view_temp USING BTREE(extent_competed) WITH (fillfactor = 97) WHERE extent_competed IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_type_set_aside_temp ON subaward_view_temp USING BTREE(type_set_aside) WITH (fillfactor = 97) WHERE type_set_aside IS NOT NULL;
CREATE INDEX idx_5dff09d1$c46_product_or_service_code_temp ON subaward_view_temp USING BTREE(product_or_service_code) WITH (fillfactor = 97) WHERE product_or_service_code IS NOT NULL;
DO $$ BEGIN RAISE NOTICE '40 indexes created, 7 remaining'; END $$;
CREATE INDEX idx_5dff09d1$c46_gin_product_or_service_description_temp ON subaward_view_temp USING GIN((product_or_service_description) gin_trgm_ops);
CREATE INDEX idx_5dff09d1$c46_gin_business_categories_temp ON subaward_view_temp USING GIN(business_categories);
CREATE INDEX idx_5dff09d1$c46_keyword_ts_vector_temp ON subaward_view_temp USING GIN(keyword_ts_vector);
CREATE INDEX idx_5dff09d1$c46_award_ts_vector_temp ON subaward_view_temp USING GIN(award_ts_vector);
CREATE INDEX idx_5dff09d1$c46_recipient_name_ts_vector_temp ON subaward_view_temp USING GIN(recipient_name_ts_vector);
CREATE INDEX idx_5dff09d1$c46_compound_psc_action_date_temp ON subaward_view_temp USING BTREE(product_or_service_code, action_date) WITH (fillfactor = 97);
CREATE INDEX idx_5dff09d1$c46_compound_cfda_action_date_temp ON subaward_view_temp USING BTREE(cfda_number, action_date) WITH (fillfactor = 97);

ALTER MATERIALIZED VIEW IF EXISTS subaward_view RENAME TO subaward_view_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_subaward_id RENAME TO idx_5dff09d1$c46_subaward_id_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_award_type RENAME TO idx_5dff09d1$c46_award_type_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_ordered_subaward_number RENAME TO idx_5dff09d1$c46_ordered_subaward_number_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_ordered_award_type RENAME TO idx_5dff09d1$c46_ordered_award_type_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_ordered_fain RENAME TO idx_5dff09d1$c46_ordered_fain_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_ordered_piid RENAME TO idx_5dff09d1$c46_ordered_piid_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_amount RENAME TO idx_5dff09d1$c46_amount_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_ordered_amount RENAME TO idx_5dff09d1$c46_ordered_amount_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_total_obl_bin RENAME TO idx_5dff09d1$c46_total_obl_bin_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_gin_recipient_name RENAME TO idx_5dff09d1$c46_gin_recipient_name_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_recipient_name RENAME TO idx_5dff09d1$c46_recipient_name_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_recipient_unique_id RENAME TO idx_5dff09d1$c46_recipient_unique_id_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_parent_recipient_unique_id RENAME TO idx_5dff09d1$c46_parent_recipient_unique_id_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_action_date RENAME TO idx_5dff09d1$c46_action_date_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_last_modified_date RENAME TO idx_5dff09d1$c46_last_modified_date_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_fiscal_year RENAME TO idx_5dff09d1$c46_fiscal_year_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_awarding_agency_id RENAME TO idx_5dff09d1$c46_awarding_agency_id_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_funding_agency_id RENAME TO idx_5dff09d1$c46_funding_agency_id_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_ordered_awarding_toptier_agency_name RENAME TO idx_5dff09d1$c46_ordered_awarding_toptier_agency_name_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_ordered_awarding_subtier_agency_name RENAME TO idx_5dff09d1$c46_ordered_awarding_subtier_agency_name_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_awarding_toptier_agency_name RENAME TO idx_5dff09d1$c46_awarding_toptier_agency_name_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_awarding_subtier_agency_name RENAME TO idx_5dff09d1$c46_awarding_subtier_agency_name_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_funding_toptier_agency_name RENAME TO idx_5dff09d1$c46_funding_toptier_agency_name_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_funding_subtier_agency_name RENAME TO idx_5dff09d1$c46_funding_subtier_agency_name_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_recipient_location_country_code RENAME TO idx_5dff09d1$c46_recipient_location_country_code_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_recipient_location_state_code RENAME TO idx_5dff09d1$c46_recipient_location_state_code_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_recipient_location_county_code RENAME TO idx_5dff09d1$c46_recipient_location_county_code_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_recipient_location_zip5 RENAME TO idx_5dff09d1$c46_recipient_location_zip5_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_recipient_location_cong_code RENAME TO idx_5dff09d1$c46_recipient_location_cong_code_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_pop_country_code RENAME TO idx_5dff09d1$c46_pop_country_code_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_pop_state_code RENAME TO idx_5dff09d1$c46_pop_state_code_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_pop_county_code RENAME TO idx_5dff09d1$c46_pop_county_code_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_pop_zip5 RENAME TO idx_5dff09d1$c46_pop_zip5_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_pop_congressional_code RENAME TO idx_5dff09d1$c46_pop_congressional_code_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_cfda_number RENAME TO idx_5dff09d1$c46_cfda_number_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_pulled_from RENAME TO idx_5dff09d1$c46_pulled_from_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_type_of_contract_pricing RENAME TO idx_5dff09d1$c46_type_of_contract_pricing_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_extent_competed RENAME TO idx_5dff09d1$c46_extent_competed_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_type_set_aside RENAME TO idx_5dff09d1$c46_type_set_aside_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_product_or_service_code RENAME TO idx_5dff09d1$c46_product_or_service_code_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_gin_product_or_service_description RENAME TO idx_5dff09d1$c46_gin_product_or_service_description_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_gin_business_categories RENAME TO idx_5dff09d1$c46_gin_business_categories_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_keyword_ts_vector RENAME TO idx_5dff09d1$c46_keyword_ts_vector_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_award_ts_vector RENAME TO idx_5dff09d1$c46_award_ts_vector_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_recipient_name_ts_vector RENAME TO idx_5dff09d1$c46_recipient_name_ts_vector_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_compound_psc_action_date RENAME TO idx_5dff09d1$c46_compound_psc_action_date_old;
ALTER INDEX IF EXISTS idx_5dff09d1$c46_compound_cfda_action_date RENAME TO idx_5dff09d1$c46_compound_cfda_action_date_old;

ALTER MATERIALIZED VIEW subaward_view_temp RENAME TO subaward_view;
ALTER INDEX idx_5dff09d1$c46_subaward_id_temp RENAME TO idx_5dff09d1$c46_subaward_id;
ALTER INDEX idx_5dff09d1$c46_award_type_temp RENAME TO idx_5dff09d1$c46_award_type;
ALTER INDEX idx_5dff09d1$c46_ordered_subaward_number_temp RENAME TO idx_5dff09d1$c46_ordered_subaward_number;
ALTER INDEX idx_5dff09d1$c46_ordered_award_type_temp RENAME TO idx_5dff09d1$c46_ordered_award_type;
ALTER INDEX idx_5dff09d1$c46_ordered_fain_temp RENAME TO idx_5dff09d1$c46_ordered_fain;
ALTER INDEX idx_5dff09d1$c46_ordered_piid_temp RENAME TO idx_5dff09d1$c46_ordered_piid;
ALTER INDEX idx_5dff09d1$c46_amount_temp RENAME TO idx_5dff09d1$c46_amount;
ALTER INDEX idx_5dff09d1$c46_ordered_amount_temp RENAME TO idx_5dff09d1$c46_ordered_amount;
ALTER INDEX idx_5dff09d1$c46_total_obl_bin_temp RENAME TO idx_5dff09d1$c46_total_obl_bin;
ALTER INDEX idx_5dff09d1$c46_gin_recipient_name_temp RENAME TO idx_5dff09d1$c46_gin_recipient_name;
ALTER INDEX idx_5dff09d1$c46_recipient_name_temp RENAME TO idx_5dff09d1$c46_recipient_name;
ALTER INDEX idx_5dff09d1$c46_recipient_unique_id_temp RENAME TO idx_5dff09d1$c46_recipient_unique_id;
ALTER INDEX idx_5dff09d1$c46_parent_recipient_unique_id_temp RENAME TO idx_5dff09d1$c46_parent_recipient_unique_id;
ALTER INDEX idx_5dff09d1$c46_action_date_temp RENAME TO idx_5dff09d1$c46_action_date;
ALTER INDEX idx_5dff09d1$c46_last_modified_date_temp RENAME TO idx_5dff09d1$c46_last_modified_date;
ALTER INDEX idx_5dff09d1$c46_fiscal_year_temp RENAME TO idx_5dff09d1$c46_fiscal_year;
ALTER INDEX idx_5dff09d1$c46_awarding_agency_id_temp RENAME TO idx_5dff09d1$c46_awarding_agency_id;
ALTER INDEX idx_5dff09d1$c46_funding_agency_id_temp RENAME TO idx_5dff09d1$c46_funding_agency_id;
ALTER INDEX idx_5dff09d1$c46_ordered_awarding_toptier_agency_name_temp RENAME TO idx_5dff09d1$c46_ordered_awarding_toptier_agency_name;
ALTER INDEX idx_5dff09d1$c46_ordered_awarding_subtier_agency_name_temp RENAME TO idx_5dff09d1$c46_ordered_awarding_subtier_agency_name;
ALTER INDEX idx_5dff09d1$c46_awarding_toptier_agency_name_temp RENAME TO idx_5dff09d1$c46_awarding_toptier_agency_name;
ALTER INDEX idx_5dff09d1$c46_awarding_subtier_agency_name_temp RENAME TO idx_5dff09d1$c46_awarding_subtier_agency_name;
ALTER INDEX idx_5dff09d1$c46_funding_toptier_agency_name_temp RENAME TO idx_5dff09d1$c46_funding_toptier_agency_name;
ALTER INDEX idx_5dff09d1$c46_funding_subtier_agency_name_temp RENAME TO idx_5dff09d1$c46_funding_subtier_agency_name;
ALTER INDEX idx_5dff09d1$c46_recipient_location_country_code_temp RENAME TO idx_5dff09d1$c46_recipient_location_country_code;
ALTER INDEX idx_5dff09d1$c46_recipient_location_state_code_temp RENAME TO idx_5dff09d1$c46_recipient_location_state_code;
ALTER INDEX idx_5dff09d1$c46_recipient_location_county_code_temp RENAME TO idx_5dff09d1$c46_recipient_location_county_code;
ALTER INDEX idx_5dff09d1$c46_recipient_location_zip5_temp RENAME TO idx_5dff09d1$c46_recipient_location_zip5;
ALTER INDEX idx_5dff09d1$c46_recipient_location_cong_code_temp RENAME TO idx_5dff09d1$c46_recipient_location_cong_code;
ALTER INDEX idx_5dff09d1$c46_pop_country_code_temp RENAME TO idx_5dff09d1$c46_pop_country_code;
ALTER INDEX idx_5dff09d1$c46_pop_state_code_temp RENAME TO idx_5dff09d1$c46_pop_state_code;
ALTER INDEX idx_5dff09d1$c46_pop_county_code_temp RENAME TO idx_5dff09d1$c46_pop_county_code;
ALTER INDEX idx_5dff09d1$c46_pop_zip5_temp RENAME TO idx_5dff09d1$c46_pop_zip5;
ALTER INDEX idx_5dff09d1$c46_pop_congressional_code_temp RENAME TO idx_5dff09d1$c46_pop_congressional_code;
ALTER INDEX idx_5dff09d1$c46_cfda_number_temp RENAME TO idx_5dff09d1$c46_cfda_number;
ALTER INDEX idx_5dff09d1$c46_pulled_from_temp RENAME TO idx_5dff09d1$c46_pulled_from;
ALTER INDEX idx_5dff09d1$c46_type_of_contract_pricing_temp RENAME TO idx_5dff09d1$c46_type_of_contract_pricing;
ALTER INDEX idx_5dff09d1$c46_extent_competed_temp RENAME TO idx_5dff09d1$c46_extent_competed;
ALTER INDEX idx_5dff09d1$c46_type_set_aside_temp RENAME TO idx_5dff09d1$c46_type_set_aside;
ALTER INDEX idx_5dff09d1$c46_product_or_service_code_temp RENAME TO idx_5dff09d1$c46_product_or_service_code;
ALTER INDEX idx_5dff09d1$c46_gin_product_or_service_description_temp RENAME TO idx_5dff09d1$c46_gin_product_or_service_description;
ALTER INDEX idx_5dff09d1$c46_gin_business_categories_temp RENAME TO idx_5dff09d1$c46_gin_business_categories;
ALTER INDEX idx_5dff09d1$c46_keyword_ts_vector_temp RENAME TO idx_5dff09d1$c46_keyword_ts_vector;
ALTER INDEX idx_5dff09d1$c46_award_ts_vector_temp RENAME TO idx_5dff09d1$c46_award_ts_vector;
ALTER INDEX idx_5dff09d1$c46_recipient_name_ts_vector_temp RENAME TO idx_5dff09d1$c46_recipient_name_ts_vector;
ALTER INDEX idx_5dff09d1$c46_compound_psc_action_date_temp RENAME TO idx_5dff09d1$c46_compound_psc_action_date;
ALTER INDEX idx_5dff09d1$c46_compound_cfda_action_date_temp RENAME TO idx_5dff09d1$c46_compound_cfda_action_date;

ANALYZE VERBOSE subaward_view;
GRANT SELECT ON subaward_view TO readonly;
