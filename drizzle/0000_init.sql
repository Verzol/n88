CREATE TYPE "public"."collection_status" AS ENUM('open', 'closed');--> statement-breakpoint
CREATE TYPE "public"."member_role" AS ENUM('captain', 'vice', 'member');--> statement-breakpoint
CREATE TYPE "public"."member_status" AS ENUM('active', 'inactive');--> statement-breakpoint
CREATE TYPE "public"."member_type" AS ENUM('regular', 'student');--> statement-breakpoint
CREATE TYPE "public"."payment_source" AS ENUM('member_report', 'admin_record');--> statement-breakpoint
CREATE TYPE "public"."payment_status" AS ENUM('pending', 'confirmed', 'rejected', 'cancelled');--> statement-breakpoint
CREATE TYPE "public"."player_position" AS ENUM('GK', 'DF', 'MF', 'FW');--> statement-breakpoint
CREATE TYPE "public"."pricing_mode" AS ENUM('by_type', 'flat', 'manual');--> statement-breakpoint
CREATE SEQUENCE "public"."member_code_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1;--> statement-breakpoint
CREATE TABLE "audit_logs" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "audit_logs_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"actor_id" uuid,
	"action" text NOT NULL,
	"entity" text NOT NULL,
	"entity_id" text NOT NULL,
	"before" jsonb,
	"after" jsonb,
	"reason" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "charges" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"collection_id" uuid NOT NULL,
	"member_id" uuid NOT NULL,
	"amount" bigint NOT NULL,
	"note" text,
	"waived_at" timestamp with time zone,
	"waived_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "charges_collection_member_uq" UNIQUE("collection_id","member_id"),
	CONSTRAINT "charges_amount_range" CHECK ("charges"."amount" > 0 and "charges"."amount" <= 100000000)
);
--> statement-breakpoint
CREATE TABLE "collections" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"code" text NOT NULL,
	"title" text NOT NULL,
	"due_date" date,
	"note" text,
	"pricing_mode" "pricing_mode" NOT NULL,
	"fee_regular" bigint,
	"fee_student" bigint,
	"flat_amount" bigint,
	"status" "collection_status" DEFAULT 'open' NOT NULL,
	"created_by" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"closed_at" timestamp with time zone,
	CONSTRAINT "collections_code_unique" UNIQUE("code"),
	CONSTRAINT "collections_code_format" CHECK ("collections"."code" ~ '^[A-Z0-9]{3,8}$')
);
--> statement-breakpoint
CREATE TABLE "expense_categories" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"is_hidden" boolean DEFAULT false NOT NULL,
	"sort_order" smallint DEFAULT 0 NOT NULL,
	CONSTRAINT "expense_categories_name_unique" UNIQUE("name")
);
--> statement-breakpoint
CREATE TABLE "expenses" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"title" text NOT NULL,
	"amount" bigint NOT NULL,
	"spent_on" date NOT NULL,
	"category_id" uuid NOT NULL,
	"spent_by" uuid,
	"receipt_path" text,
	"note" text,
	"created_by" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	"deleted_by" uuid,
	"delete_reason" text,
	CONSTRAINT "expenses_amount_range" CHECK ("expenses"."amount" > 0 and "expenses"."amount" <= 100000000),
	CONSTRAINT "expenses_delete_reason" CHECK ("expenses"."deleted_at" is null or "expenses"."delete_reason" is not null)
);
--> statement-breakpoint
CREATE TABLE "members" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"code" text DEFAULT ('M' || lpad(nextval('member_code_seq')::text, 3, '0')) NOT NULL,
	"user_id" uuid,
	"name" text NOT NULL,
	"email" text,
	"phone" text,
	"jersey_number" smallint,
	"position" "player_position",
	"member_type" "member_type" DEFAULT 'regular' NOT NULL,
	"status" "member_status" DEFAULT 'active' NOT NULL,
	"role" "member_role" DEFAULT 'member' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "members_code_unique" UNIQUE("code"),
	CONSTRAINT "members_user_id_unique" UNIQUE("user_id"),
	CONSTRAINT "members_email_unique" UNIQUE("email"),
	CONSTRAINT "members_name_not_blank" CHECK (length(trim("members"."name")) > 0),
	CONSTRAINT "members_email_lowercase" CHECK ("members"."email" = lower("members"."email")),
	CONSTRAINT "members_jersey_range" CHECK ("members"."jersey_number" between 0 and 99)
);
--> statement-breakpoint
CREATE TABLE "payment_items" (
	"payment_id" uuid NOT NULL,
	"charge_id" uuid NOT NULL,
	"amount" bigint NOT NULL,
	"pending" boolean DEFAULT false NOT NULL,
	CONSTRAINT "payment_items_payment_id_charge_id_pk" PRIMARY KEY("payment_id","charge_id"),
	CONSTRAINT "payment_items_amount_positive" CHECK ("payment_items"."amount" > 0)
);
--> statement-breakpoint
CREATE TABLE "payments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"member_id" uuid NOT NULL,
	"total_amount" bigint NOT NULL,
	"transfer_code" text NOT NULL,
	"is_bundle" boolean DEFAULT false NOT NULL,
	"status" "payment_status" NOT NULL,
	"source" "payment_source" NOT NULL,
	"proof_path" text,
	"note" text,
	"reject_reason" text,
	"cancel_reason" text,
	"created_by" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"reviewed_by" uuid,
	"reviewed_at" timestamp with time zone,
	"cancelled_by" uuid,
	"cancelled_at" timestamp with time zone,
	CONSTRAINT "payments_total_range" CHECK ("payments"."total_amount" > 0 and "payments"."total_amount" <= 100000000),
	CONSTRAINT "payments_transfer_code_length" CHECK (length("payments"."transfer_code") <= 25),
	CONSTRAINT "payments_reject_reason" CHECK ("payments"."status" <> 'rejected' or "payments"."reject_reason" is not null),
	CONSTRAINT "payments_cancel_reason" CHECK ("payments"."status" <> 'cancelled' or "payments"."cancel_reason" is not null)
);
--> statement-breakpoint
CREATE TABLE "settings" (
	"id" smallint PRIMARY KEY DEFAULT 1 NOT NULL,
	"team_name" text DEFAULT 'N88' NOT NULL,
	"transfer_prefix" text DEFAULT 'N88' NOT NULL,
	"bank_bin" text,
	"bank_name" text,
	"account_no" text,
	"account_name" text,
	"qr_mode" text DEFAULT 'dynamic' NOT NULL,
	"static_qr_path" text,
	"default_fee_regular" bigint DEFAULT 200000 NOT NULL,
	"default_fee_student" bigint DEFAULT 100000 NOT NULL,
	"sheet_id" text,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "settings_singleton" CHECK ("settings"."id" = 1),
	CONSTRAINT "settings_transfer_prefix_format" CHECK ("settings"."transfer_prefix" ~ '^[A-Z0-9]{2,6}$'),
	CONSTRAINT "settings_qr_mode" CHECK ("settings"."qr_mode" in ('dynamic', 'static')),
	CONSTRAINT "settings_fee_regular_positive" CHECK ("settings"."default_fee_regular" > 0),
	CONSTRAINT "settings_fee_student_positive" CHECK ("settings"."default_fee_student" > 0)
);
--> statement-breakpoint
CREATE TABLE "sync_state" (
	"id" smallint PRIMARY KEY DEFAULT 1 NOT NULL,
	"dirty" boolean DEFAULT true NOT NULL,
	"dirty_since" timestamp with time zone,
	"last_success_at" timestamp with time zone,
	"last_error" text,
	"last_error_at" timestamp with time zone,
	CONSTRAINT "sync_state_singleton" CHECK ("sync_state"."id" = 1)
);
--> statement-breakpoint
ALTER TABLE "charges" ADD CONSTRAINT "charges_collection_id_collections_id_fk" FOREIGN KEY ("collection_id") REFERENCES "public"."collections"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "charges" ADD CONSTRAINT "charges_member_id_members_id_fk" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "charges" ADD CONSTRAINT "charges_waived_by_members_id_fk" FOREIGN KEY ("waived_by") REFERENCES "public"."members"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "collections" ADD CONSTRAINT "collections_created_by_members_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."members"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_category_id_expense_categories_id_fk" FOREIGN KEY ("category_id") REFERENCES "public"."expense_categories"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_spent_by_members_id_fk" FOREIGN KEY ("spent_by") REFERENCES "public"."members"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_created_by_members_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."members"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_deleted_by_members_id_fk" FOREIGN KEY ("deleted_by") REFERENCES "public"."members"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "members" ADD CONSTRAINT "members_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payment_items" ADD CONSTRAINT "payment_items_payment_id_payments_id_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payment_items" ADD CONSTRAINT "payment_items_charge_id_charges_id_fk" FOREIGN KEY ("charge_id") REFERENCES "public"."charges"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payments" ADD CONSTRAINT "payments_member_id_members_id_fk" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payments" ADD CONSTRAINT "payments_created_by_members_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."members"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payments" ADD CONSTRAINT "payments_reviewed_by_members_id_fk" FOREIGN KEY ("reviewed_by") REFERENCES "public"."members"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payments" ADD CONSTRAINT "payments_cancelled_by_members_id_fk" FOREIGN KEY ("cancelled_by") REFERENCES "public"."members"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "audit_logs_entity_idx" ON "audit_logs" USING btree ("entity","entity_id","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "audit_logs_created_idx" ON "audit_logs" USING btree ("created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "charges_member_idx" ON "charges" USING btree ("member_id");--> statement-breakpoint
CREATE INDEX "expenses_spent_on_idx" ON "expenses" USING btree ("spent_on" DESC NULLS LAST) WHERE "expenses"."deleted_at" is null;--> statement-breakpoint
CREATE UNIQUE INDEX "members_jersey_active_uq" ON "members" USING btree ("jersey_number") WHERE "members"."status" = 'active' and "members"."jersey_number" is not null;--> statement-breakpoint
CREATE UNIQUE INDEX "payment_items_one_pending_uq" ON "payment_items" USING btree ("charge_id") WHERE "payment_items"."pending";--> statement-breakpoint
CREATE INDEX "payment_items_charge_idx" ON "payment_items" USING btree ("charge_id");--> statement-breakpoint
CREATE INDEX "payments_status_idx" ON "payments" USING btree ("status","created_at");--> statement-breakpoint
CREATE INDEX "payments_member_idx" ON "payments" USING btree ("member_id","created_at" DESC NULLS LAST);