-- Represent customers who hold accounts
CREATE TABLE "customers" (
    "id" INTEGER,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL UNIQUE CHECK (
        "email" LIKE '%_@_%._%'
        AND "email" NOT LIKE '% %'
        AND LENGTH("email") - LENGTH(REPLACE("email", '@', '')) = 1
    ),
    "address" TEXT,
    "date_created" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY("id")
);

-- Represent financial accounts owned by customers
CREATE TABLE "accounts" (
    "id" INTEGER,
    "customer_id" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "opening_balance" INTEGER NOT NULL,
    "currency" TEXT NOT NULL,
    "status" TEXT NOT NULL
        CHECK ("status" IN ('active', 'suspended', 'closed')),
    "date_created" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY("id"),
    FOREIGN KEY("customer_id") REFERENCES "customers"("id"),
    UNIQUE("customer_id", "name")
);

-- Represent merchants that accept customer payments
CREATE TABLE "merchants" (
    "id" INTEGER,
    "name" TEXT NOT NULL,
    "email" TEXT UNIQUE CHECK (
        "email" LIKE '%_@_%._%'
        AND "email" NOT LIKE '% %'
        AND LENGTH("email") - LENGTH(REPLACE("email", '@', '')) = 1
    ),
    "address" TEXT,
    "iban" TEXT,
    "category" TEXT NOT NULL
        CHECK ("category" IN (
            'retail',
            'groceries',
            'restaurants',
            'transport',
            'travel',
            'entertainment',
            'healthcare',
            'utilities',
            'education',
            'other'
        )),
    "date_created" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY("id")
);

-- Represent payments and transfers between accounts and merchants
CREATE TABLE "transactions" (
    "id" INTEGER,
    "from_account_id" INTEGER NOT NULL,
    "to_account_id" INTEGER,
    "merchant_id" INTEGER,
    "amount" INTEGER NOT NULL
        CHECK ("amount" > 0),
    "transaction_type" TEXT NOT NULL
        CHECK ("transaction_type" IN ('payment', 'transfer')),
    "currency" TEXT NOT NULL,
    "date_created" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "date_processed" DATETIME,

    PRIMARY KEY("id"),
    FOREIGN KEY("from_account_id") REFERENCES "accounts"("id"),
    FOREIGN KEY("to_account_id") REFERENCES "accounts"("id"),
    FOREIGN KEY("merchant_id") REFERENCES "merchants"("id"),

    CHECK(
        (
            "transaction_type" = 'payment'
            AND "merchant_id" IS NOT NULL
            AND "to_account_id" IS NULL
        )
        OR
        (
            "transaction_type" = 'transfer'
            AND "to_account_id" IS NOT NULL
            AND "merchant_id" IS NULL
        )
    ),

    CHECK (
        "to_account_id" IS NULL
        OR "from_account_id" <> "to_account_id"
    )
);

-- Represent the status history of transactions
CREATE TABLE "transaction_status_history" (
    "id" INTEGER,
    "transaction_id" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending'
        CHECK ("status" IN (
            'pending',
            'completed',
            'declined',
            'cancelled'
        )),
    "date_changed" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reason" TEXT,

    PRIMARY KEY("id"),
    FOREIGN KEY("transaction_id") REFERENCES "transactions"("id")
);

-- Represent refund requests for completed transactions
CREATE TABLE "refunds" (
    "id" INTEGER,
    "transaction_id" INTEGER NOT NULL,
    "amount" INTEGER NOT NULL
        CHECK ("amount" > 0),
    "date_requested" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "date_processed" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'pending'
        CHECK ("status" IN (
            'pending',
            'completed',
            'declined',
            'cancelled'
        )),
    "reason" TEXT,

    PRIMARY KEY("id"),
    FOREIGN KEY("transaction_id") REFERENCES "transactions"("id")
);

-- Represent chargeback disputes associated with transactions
CREATE TABLE "chargebacks" (
    "id" INTEGER,
    "transaction_id" INTEGER NOT NULL UNIQUE,
    "amount" INTEGER NOT NULL
        CHECK ("amount" > 0),
    "date_opened" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "date_resolved" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'open'
        CHECK ("status" IN (
            'open',
            'under_review',
            'won',
            'lost',
            'cancelled'
        )),
    "reason" TEXT,
    "resolution" TEXT,

    PRIMARY KEY("id"),
    FOREIGN KEY("transaction_id") REFERENCES "transactions"("id")
);

-- Represent rules used to identify potentially risky transactions
CREATE TABLE "risk_rules" (
    "id" INTEGER,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "severity" TEXT NOT NULL
        CHECK ("severity" IN (
            'low',
            'medium',
            'high'
        )),
    "date_created" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "is_active" BOOLEAN NOT NULL DEFAULT 1
        CHECK ("is_active" IN (0, 1)),

    PRIMARY KEY("id")
);

-- Represent risk flags raised against transactions
CREATE TABLE "risk_flags" (
    "id" INTEGER,
    "transaction_id" INTEGER NOT NULL,
    "risk_rule_id" INTEGER NOT NULL,
    "date_created" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "date_resolved" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'open'
        CHECK ("status" IN (
            'open',
            'under_review',
            'resolved',
            'dismissed'
        )),
    "notes" TEXT,

    PRIMARY KEY("id"),
    FOREIGN KEY("transaction_id") REFERENCES "transactions"("id"),
    FOREIGN KEY("risk_rule_id") REFERENCES "risk_rules"("id")
);


-- Automatically record when a transaction is completed
CREATE TRIGGER "set_transaction_processed_date"
AFTER INSERT ON "transaction_status_history"
FOR EACH ROW
WHEN NEW.status = 'completed'
BEGIN
    UPDATE "transactions"
    SET "date_processed" = NEW.date_changed
    WHERE "id" = NEW.transaction_id
        AND "date_processed" IS NULL;
END;

-- Automatically record when a refund is completed
CREATE TRIGGER "set_refund_processed_date"
AFTER UPDATE OF "status" ON "refunds"
FOR EACH ROW
WHEN NEW.status = 'completed'
    AND OLD.status <> 'completed'
BEGIN
    UPDATE "refunds"
    SET "date_processed" = CURRENT_TIMESTAMP
    WHERE "id" = NEW.id;
END;

-- Automatically record when a chargeback reaches a final status
CREATE TRIGGER "set_chargeback_date_resolved"
AFTER UPDATE OF "status" ON "chargebacks"
FOR EACH ROW
WHEN NEW.status IN ('won', 'lost', 'cancelled')
    AND OLD.status NOT IN ('won', 'lost', 'cancelled')
BEGIN
    UPDATE "chargebacks"
    SET "date_resolved" = CURRENT_TIMESTAMP
    WHERE "id" = NEW.id;
END;

-- Automatically record when a risk flag reaches a final status
CREATE TRIGGER "set_risk_flags_date_resolved"
AFTER UPDATE OF "status" ON "risk_flags"
FOR EACH ROW
WHEN NEW.status IN ('resolved', 'dismissed')
    AND OLD.status NOT IN ('resolved', 'dismissed')
BEGIN
    UPDATE "risk_flags"
    SET "date_resolved" = CURRENT_TIMESTAMP
    WHERE "id" = NEW.id;
END;

-- Combine transactions with customer emails and account names
CREATE VIEW "transaction_details" AS
SELECT
    "transactions".*,
    "accounts"."name" AS "from_account_name",
    "customers"."email" AS "from_customer_email"
FROM "transactions"
JOIN "accounts"
    ON "transactions"."from_account_id" = "accounts"."id"
JOIN "customers"
    ON "accounts"."customer_id" = "customers"."id";


-- Create indexes to speed common searches
CREATE INDEX "accounts_by_customer" ON "accounts"("customer_id");
CREATE INDEX "transactions_by_sender" ON "transactions"("from_account_id");
CREATE INDEX "transactions_by_receiver" ON "transactions"("to_account_id");
CREATE INDEX "transactions_by_merchant" ON "transactions"("merchant_id");
CREATE INDEX "status_history_by_transaction_date" ON "transaction_status_history"("transaction_id", "date_changed");
CREATE INDEX "refunds_by_transaction" ON "refunds"("transaction_id");
CREATE INDEX "risk_flags_by_transaction" ON "risk_flags"("transaction_id");
CREATE INDEX "risk_flags_by_rule" ON "risk_flags"("risk_rule_id");
