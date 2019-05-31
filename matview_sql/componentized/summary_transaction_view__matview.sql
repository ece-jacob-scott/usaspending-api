CREATE MATERIALIZED VIEW summary_transaction_view_temp AS
SELECT
  -- Deterministic Unique Hash (DUH) created for view concurrent refresh
  MD5(array_to_string(sort(array_agg(transaction_normalized.id::int)), ' '))::uuid AS duh,
  transaction_normalized.action_date,
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
  transaction_normalized.action_date,
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_fpds.pulled_from,

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

  COALESCE(recipient_lookup.recipient_hash, MD5(
    UPPER(COALESCE(transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)))::uuid),
  COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal),
  COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu),
  COALESCE(transaction_fpds.ultimate_parent_unique_ide, transaction_fabs.ultimate_parent_unique_ide),
  legal_entity.business_categories,
  transaction_fabs.cfda_number,
  references_cfda.program_title,
  transaction_fpds.product_or_service_code,
  psc.description,
  transaction_fpds.naics,
  naics.description,
  obligation_to_enum(awards.total_obligation),
  transaction_fpds.type_of_contract_pricing,
  transaction_fpds.type_set_aside,
  transaction_fpds.extent_competed WITH DATA;
