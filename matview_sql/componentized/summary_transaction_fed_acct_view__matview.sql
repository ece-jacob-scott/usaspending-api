CREATE MATERIALIZED VIEW summary_transaction_fed_acct_view_temp AS
SELECT
  -- Deterministic Unique Hash (DUH) created for view concurrent refresh
  MD5(CONCAT_WS(' ',
    transaction_normalized.action_date,
    transaction_normalized.fiscal_year,
    transaction_normalized.type,
    transaction_fpds.pulled_from,

    TR_ACCT.federal_account_id,
    FABA.treasury_account_id,
    FED_ACT.agency_identifier,
    FED_ACT.main_account_code,
    FED_ACT.account_title,

    COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu),
    COALESCE(transaction_fpds.ultimate_parent_unique_ide, transaction_fabs.ultimate_parent_unique_ide),
    COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)
  ))::uuid AS duh,

  transaction_normalized.action_date,
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_fpds.pulled_from,

  TR_ACCT.federal_account_id,
  FABA.treasury_account_id,
  FED_ACT.agency_identifier,
  FED_ACT.main_account_code,
  FED_ACT.account_title,
  CONCAT_WS('-', FED_ACT.agency_identifier, FED_ACT.main_account_code) AS federal_account_display,

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
  awards ON (transaction_normalized.award_id = awards.id)
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
INNER JOIN
  financial_accounts_by_awards AS FABA ON (awards.id = FABA.award_id)
INNER JOIN
  treasury_appropriation_account AS TR_ACCT ON (FABA.treasury_account_id = TR_ACCT.treasury_account_identifier)
INNER JOIN
 federal_account AS FED_ACT ON TR_ACCT.federal_account_id = FED_ACT.id
WHERE
  transaction_normalized.action_date >= '2007-10-01'
GROUP BY
  transaction_normalized.action_date,
  transaction_normalized.fiscal_year,
  transaction_normalized.type,
  transaction_fpds.pulled_from,

  TR_ACCT.federal_account_id,
  FABA.treasury_account_id,
  FED_ACT.agency_identifier,
  FED_ACT.main_account_code,
  FED_ACT.account_title,

  COALESCE(recipient_lookup.recipient_hash, MD5(
    UPPER(COALESCE(transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal)))::uuid),
  COALESCE(recipient_lookup.recipient_name, transaction_fpds.awardee_or_recipient_legal, transaction_fabs.awardee_or_recipient_legal),
  COALESCE(transaction_fpds.awardee_or_recipient_uniqu, transaction_fabs.awardee_or_recipient_uniqu),
  COALESCE(transaction_fpds.ultimate_parent_unique_ide, transaction_fabs.ultimate_parent_unique_ide) WITH DATA;
