-- ==================================================
-- INSERTS
-- ==================================================

-- Add a new customer
INSERT INTO "customers" ("name", "email")
VALUES ('Harvard University', 'admin@harvard.edu');

-- Add a new merchant
INSERT INTO "merchants" ("name", "category")
VALUES ('Harvard Book Store', 'retail');

-- Add a new risk rule
INSERT INTO "risk_rules" (
    "name",
    "description",
    "severity",
    "is_active"
)
VALUES (
    'High Value Transaction',
    'Flags transactions with an unusually high value',
    'high',
    1
);

-- Add a new account
INSERT INTO "accounts" (
    "customer_id",
    "name",
    "opening_balance",
    "currency",
    "status"
)
VALUES (
    1,
    'Harvard Main Account',
    100000,
    'USD',
    'active'
);

-- ==================================================
-- SELECTS
-- ==================================================

-- Find all transactions initiated by a given customer
SELECT *
FROM "transaction_details"
WHERE "from_customer_email" = 'admin@harvard.edu';

-- Find all transactions initiated by a given account
SELECT *
FROM "transaction_details"
WHERE "from_account_name" = 'Harvard Main Account'
AND "from_customer_email" = 'admin@harvard.edu';

-- Find the complete status history of a given transaction
SELECT *
FROM "transaction_status_history"
WHERE "transaction_id" = 1
ORDER BY "date_changed";

-- Find all refund details for a given transaction
SELECT *
FROM "refunds"
WHERE "transaction_id" = 1;

-- Find chargeback details for a given transaction
SELECT *
FROM "chargebacks"
WHERE "transaction_id" = 1;

-- Find all risk flags for a given transaction
SELECT *
FROM "risk_flags"
WHERE "transaction_id" = 1;

-- ==================================================
-- UPDATES
-- ==================================================

-- Complete a refund
UPDATE "refunds"
SET "status" = 'completed'
WHERE "id" = 1;

-- Decline a refund
UPDATE "refunds"
SET "status" = 'declined'
WHERE "id" = 1;

-- Cancel a refund
UPDATE "refunds"
SET "status" = 'cancelled'
WHERE "id" = 1;

-- Move a chargeback under review
UPDATE "chargebacks"
SET "status" = 'under_review'
WHERE "id" = 1;

-- Resolve a chargeback in the merchant's favour
UPDATE "chargebacks"
SET "status" = 'won'
WHERE "id" = 1;

-- Resolve a chargeback in the customer's favour
UPDATE "chargebacks"
SET "status" = 'lost'
WHERE "id" = 1;

-- Cancel a chargeback
UPDATE "chargebacks"
SET "status" = 'cancelled'
WHERE "id" = 1;

-- Activate a risk rule
UPDATE "risk_rules"
SET "is_active" = 1
WHERE "id" = 1;

-- Deactivate a risk rule
UPDATE "risk_rules"
SET "is_active" = 0
WHERE "id" = 1;

-- Move a risk flag under review
UPDATE "risk_flags"
SET "status" = 'under_review'
WHERE "id" = 1;

-- Resolve a risk flag
UPDATE "risk_flags"
SET "status" = 'resolved'
WHERE "id" = 1;

-- Dismiss a risk flag
UPDATE "risk_flags"
SET "status" = 'dismissed'
WHERE "id" = 1;
