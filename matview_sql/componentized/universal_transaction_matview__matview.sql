CREATE MATERIALIZED VIEW universal_transaction_matview_temp AS
SELECT
  to_tsvector(CONCAT_WS(' ',
    COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal),
    transaction_fpds.naics,
    naics.description,
    psc.description,
    transaction_normalized.description)
  ) AS keyword_ts_vector,
  to_tsvector(CONCAT_WS(' ', awards.piid, awards.fain, awards.uri)) AS award_ts_vector,
  to_tsvector(COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)
  ) AS recipient_name_ts_vector,

  transaction_normalized.id AS transaction_id,
  transaction_normalized.action_date::date,
  transaction_normalized.last_modified_date::date,
  daterange(awards.date_signed, latest_transaction.action_date, '[]') as date_range
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_normalized.action_type,
  transaction_normalized.award_id,
  awards.category AS award_category,

  COALESCE(CASE
    WHEN awards.category = 'loans' THEN awards.total_subsidy_cost
    ELSE transaction_normalized.federal_action_obligation
  END, 0)::NUMERIC(23, 2) AS generated_pragmatic_obligation,
  awards.total_obligation,
  awards.total_subsidy_cost,
  awards.total_loan_value,
  obligation_to_enum(awards.total_obligation) AS total_obl_bin,
  awards.fain,
  awards.uri,
  awards.piid,
  COALESCE(transaction_normalized.federal_action_obligation, 0)::NUMERIC(23, 2) AS federal_action_obligation,
  COALESCE(transaction_normalized.original_loan_subsidy_cost, 0)::NUMERIC(23, 2) AS original_loan_subsidy_cost,
  COALESCE(transaction_normalized.face_value_loan_guarantee, 0)::NUMERIC(23, 2) AS face_value_loan_guarantee,
  transaction_normalized.description AS transaction_description,
  transaction_normalized.modification_number,

  place_of_performance.location_country_code AS pop_country_code,
  place_of_performance.country_name AS pop_country_name,
  place_of_performance.state_code AS pop_state_code,
  place_of_performance.county_code AS pop_county_code,
  place_of_performance.county_name AS pop_county_name,
  place_of_performance.zip5 AS pop_zip5,
  place_of_performance.congressional_code AS pop_congressional_code,

  CASE WHEN COALESCE(transaction_fpds.legal_entity_country_code, transaction_fabs.legal_entity_country_code) = 'UNITED STATES' THEN 'USA' ELSE COALESCE(transaction_fpds.legal_entity_country_code, transaction_fabs.legal_entity_country_code) END AS recipient_location_country_code,
  COALESCE(transaction_fpds.legal_entity_country_name, transaction_fabs.legal_entity_country_name) AS recipient_location_country_name,
  COALESCE(transaction_fpds.legal_entity_state_code, transaction_fabs.legal_entity_state_code) AS recipient_location_state_code,
  COALESCE(transaction_fpds.legal_entity_county_code, transaction_fabs.legal_entity_county_code) AS recipient_location_county_code,
  COALESCE(transaction_fpds.legal_entity_county_name, transaction_fabs.legal_entity_county_name) AS recipient_location_county_name,
  COALESCE(transaction_fpds.legal_entity_congressional, transaction_fabs.legal_entity_congressional) AS recipient_location_congressional_code,
  COALESCE(transaction_fpds.legal_entity_zip5, transaction_fabs.legal_entity_zip5) AS recipient_location_zip5,

  transaction_fpds.naics AS naics_code,
  naics.description AS naics_description,
  transaction_fpds.product_or_service_code,
  psc.description AS product_or_service_description,
  transaction_fpds.pulled_from,
  transaction_fpds.type_of_contract_pricing,
  transaction_fpds.type_set_aside,
  transaction_fpds.extent_competed,
  transaction_fabs.cfda_number,
  references_cfda.program_title AS cfda_title,

  transaction_normalized.recipient_id,
  COALESCE(recipient_lookup.recipient_hash, MD5(
    UPPER(COALESCE(transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)))::uuid
  )::uuid AS recipient_hash,
  UPPER(COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)) AS recipient_name,
  COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu) AS recipient_unique_id,
  COALESCE(transaction_fpds.ultimate_parent_unique_ide, transaction_fabs.ultimate_parent_unique_ide) AS parent_recipient_unique_id,
  legal_entity.business_categories,

  transaction_normalized.awarding_agency_id,
  transaction_normalized.funding_agency_id,
  TAA.name AS awarding_toptier_agency_name,
  TFA.name AS funding_toptier_agency_name,
  SAA.name AS awarding_subtier_agency_name,
  SFA.name AS funding_subtier_agency_name,
  TAA.abbreviation AS awarding_toptier_agency_abbreviation,
  TFA.abbreviation AS funding_toptier_agency_abbreviation,
  SAA.abbreviation AS awarding_subtier_agency_abbreviation,
  SFA.abbreviation AS funding_subtier_agency_abbreviation
FROM
  transaction_normalized
LEFT OUTER JOIN
  transaction_fabs ON (transaction_normalized.id = transaction_fabs.transaction_id AND transaction_normalized.is_fpds = false)
LEFT OUTER JOIN
  transaction_fpds ON (transaction_normalized.id = transaction_fpds.transaction_id AND transaction_normalized.is_fpds = true)
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
  transaction_normalized.action_date >= '2000-10-01'
ORDER BY
  transaction_normalized.action_date DESC WITH DATA;
