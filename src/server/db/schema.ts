// Drizzle schema — tham chiếu: docs/DESIGN.md §2.
// View, trigger, RLS và dữ liệu khởi tạo nằm trong migration SQL viết tay (drizzle/*_db_logic.sql).

import { sql } from "drizzle-orm";
import {
  bigint,
  boolean,
  check,
  date,
  index,
  jsonb,
  pgEnum,
  pgSequence,
  pgTable,
  pgView,
  primaryKey,
  smallint,
  text,
  timestamp,
  unique,
  uniqueIndex,
  uuid,
} from "drizzle-orm/pg-core";
import { authUsers } from "drizzle-orm/supabase";

const timestamptz = (name?: string) =>
  name ? timestamp(name, { withTimezone: true }) : timestamp({ withTimezone: true });

// Số tiền VND. Tối đa 100.000.000đ mỗi bản ghi (BR-09) nên an toàn với kiểu number của JS.
const money = () => bigint({ mode: "number" });

const MAX_AMOUNT = 100_000_000;

// ===== Enum =====

export const memberType = pgEnum("member_type", ["regular", "student"]);
export const memberStatus = pgEnum("member_status", ["active", "inactive"]);
export const memberRole = pgEnum("member_role", ["captain", "vice", "member"]);
export const playerPosition = pgEnum("player_position", ["GK", "DF", "MF", "FW"]);
export const pricingMode = pgEnum("pricing_mode", ["by_type", "flat", "manual"]);
export const collectionStatus = pgEnum("collection_status", ["open", "closed"]);
export const paymentStatus = pgEnum("payment_status", [
  "pending",
  "confirmed",
  "rejected",
  "cancelled",
]);
export const paymentSource = pgEnum("payment_source", ["member_report", "admin_record"]);

// ===== Thành viên =====

export const memberCodeSeq = pgSequence("member_code_seq");

export const members = pgTable(
  "members",
  {
    id: uuid().primaryKey().defaultRandom(),
    code: text()
      .notNull()
      .unique()
      .default(sql`('M' || lpad(nextval('member_code_seq')::text, 3, '0'))`),
    userId: uuid()
      .unique("members_user_id_unique")
      .references(() => authUsers.id, { onDelete: "set null" }),
    name: text().notNull(),
    email: text().unique(),
    phone: text(),
    jerseyNumber: smallint(),
    position: playerPosition(),
    memberType: memberType().notNull().default("regular"),
    status: memberStatus().notNull().default("active"),
    role: memberRole().notNull().default("member"),
    createdAt: timestamptz().notNull().defaultNow(),
    updatedAt: timestamptz().notNull().defaultNow(),
  },
  (t) => [
    check("members_name_not_blank", sql`length(trim(${t.name})) > 0`),
    check("members_email_lowercase", sql`${t.email} = lower(${t.email})`),
    check("members_jersey_range", sql`${t.jerseyNumber} between 0 and 99`),
    // BR-05: số áo không trùng giữa thành viên đang Hoạt động
    uniqueIndex("members_jersey_active_uq")
      .on(t.jerseyNumber)
      .where(sql`${t.status} = 'active' and ${t.jerseyNumber} is not null`),
  ],
);

// ===== Cài đặt (một dòng duy nhất) =====

export const settings = pgTable(
  "settings",
  {
    id: smallint().primaryKey().default(1),
    teamName: text().notNull().default("N88"),
    transferPrefix: text().notNull().default("N88"),
    bankBin: text(),
    bankName: text(),
    accountNo: text(),
    accountName: text(),
    qrMode: text().notNull().default("dynamic"),
    staticQrPath: text(),
    defaultFeeRegular: money().notNull().default(200_000),
    defaultFeeStudent: money().notNull().default(100_000),
    sheetId: text(),
    updatedAt: timestamptz().notNull().defaultNow(),
  },
  (t) => [
    check("settings_singleton", sql`${t.id} = 1`),
    check("settings_transfer_prefix_format", sql`${t.transferPrefix} ~ '^[A-Z0-9]{2,6}$'`),
    check("settings_qr_mode", sql`${t.qrMode} in ('dynamic', 'static')`),
    check("settings_fee_regular_positive", sql`${t.defaultFeeRegular} > 0`),
    check("settings_fee_student_positive", sql`${t.defaultFeeStudent} > 0`),
  ],
);

// ===== Đợt thu =====

export const collections = pgTable(
  "collections",
  {
    id: uuid().primaryKey().defaultRandom(),
    code: text().notNull().unique(),
    title: text().notNull(),
    dueDate: date(),
    note: text(),
    pricingMode: pricingMode().notNull(),
    // Lưu lại để tham khảo; số tiền thật nằm ở charges.amount (BR-02)
    feeRegular: money(),
    feeStudent: money(),
    flatAmount: money(),
    status: collectionStatus().notNull().default("open"),
    createdBy: uuid()
      .notNull()
      .references(() => members.id),
    createdAt: timestamptz().notNull().defaultNow(),
    closedAt: timestamptz(),
  },
  // BR-10
  (t) => [check("collections_code_format", sql`${t.code} ~ '^[A-Z0-9]{3,8}$'`)],
);

// ===== Khoản phải đóng =====

export const charges = pgTable(
  "charges",
  {
    id: uuid().primaryKey().defaultRandom(),
    collectionId: uuid()
      .notNull()
      .references(() => collections.id, { onDelete: "cascade" }),
    memberId: uuid()
      .notNull()
      .references(() => members.id, { onDelete: "restrict" }),
    amount: money().notNull(),
    note: text(),
    waivedAt: timestamptz(),
    waivedBy: uuid().references(() => members.id),
    createdAt: timestamptz().notNull().defaultNow(),
  },
  (t) => [
    check("charges_amount_range", sql`${t.amount} > 0 and ${t.amount} <= ${sql.raw(String(MAX_AMOUNT))}`),
    // BR-04
    unique("charges_collection_member_uq").on(t.collectionId, t.memberId),
    index("charges_member_idx").on(t.memberId),
  ],
);

// ===== Thanh toán =====

export const payments = pgTable(
  "payments",
  {
    id: uuid().primaryKey().defaultRandom(),
    memberId: uuid()
      .notNull()
      .references(() => members.id, { onDelete: "restrict" }),
    totalAmount: money().notNull(),
    transferCode: text().notNull(),
    isBundle: boolean().notNull().default(false),
    status: paymentStatus().notNull(),
    source: paymentSource().notNull(),
    proofPath: text(),
    note: text(),
    rejectReason: text(),
    cancelReason: text(),
    createdBy: uuid()
      .notNull()
      .references(() => members.id),
    createdAt: timestamptz().notNull().defaultNow(),
    reviewedBy: uuid().references(() => members.id),
    reviewedAt: timestamptz(),
    cancelledBy: uuid().references(() => members.id),
    cancelledAt: timestamptz(),
  },
  (t) => [
    check(
      "payments_total_range",
      sql`${t.totalAmount} > 0 and ${t.totalAmount} <= ${sql.raw(String(MAX_AMOUNT))}`,
    ),
    // BR-12
    check("payments_transfer_code_length", sql`length(${t.transferCode}) <= 25`),
    check("payments_reject_reason", sql`${t.status} <> 'rejected' or ${t.rejectReason} is not null`),
    check("payments_cancel_reason", sql`${t.status} <> 'cancelled' or ${t.cancelReason} is not null`),
    index("payments_status_idx").on(t.status, t.createdAt),
    index("payments_member_idx").on(t.memberId, t.createdAt.desc()),
  ],
);

export const paymentItems = pgTable(
  "payment_items",
  {
    paymentId: uuid()
      .notNull()
      .references(() => payments.id, { onDelete: "cascade" }),
    chargeId: uuid()
      .notNull()
      .references(() => charges.id, { onDelete: "restrict" }),
    amount: money().notNull(),
    // Bản sao của payments.status = 'pending', do trigger duy trì. Không ghi trực tiếp.
    pending: boolean().notNull().default(false),
  },
  (t) => [
    primaryKey({ columns: [t.paymentId, t.chargeId] }),
    check("payment_items_amount_positive", sql`${t.amount} > 0`),
    // BR-13: mỗi khoản tối đa một thanh toán đang chờ
    uniqueIndex("payment_items_one_pending_uq").on(t.chargeId).where(sql`${t.pending}`),
    index("payment_items_charge_idx").on(t.chargeId),
  ],
);

// ===== Khoản chi =====

export const expenseCategories = pgTable("expense_categories", {
  id: uuid().primaryKey().defaultRandom(),
  name: text().notNull().unique(),
  isHidden: boolean().notNull().default(false),
  sortOrder: smallint().notNull().default(0),
});

export const expenses = pgTable(
  "expenses",
  {
    id: uuid().primaryKey().defaultRandom(),
    title: text().notNull(),
    amount: money().notNull(),
    spentOn: date().notNull(),
    categoryId: uuid()
      .notNull()
      .references(() => expenseCategories.id, { onDelete: "restrict" }),
    spentBy: uuid().references(() => members.id),
    receiptPath: text(),
    note: text(),
    createdBy: uuid()
      .notNull()
      .references(() => members.id),
    createdAt: timestamptz().notNull().defaultNow(),
    updatedAt: timestamptz().notNull().defaultNow(),
    deletedAt: timestamptz(),
    deletedBy: uuid().references(() => members.id),
    deleteReason: text(),
  },
  (t) => [
    check("expenses_amount_range", sql`${t.amount} > 0 and ${t.amount} <= ${sql.raw(String(MAX_AMOUNT))}`),
    check("expenses_delete_reason", sql`${t.deletedAt} is null or ${t.deleteReason} is not null`),
    index("expenses_spent_on_idx").on(t.spentOn.desc()).where(sql`${t.deletedAt} is null`),
  ],
);

// ===== Nhật ký =====

export const auditLogs = pgTable(
  "audit_logs",
  {
    id: bigint({ mode: "number" }).primaryKey().generatedAlwaysAsIdentity(),
    // Cố ý không đặt FK: nhật ký phải tồn tại kể cả khi thành viên bị xóa.
    actorId: uuid(),
    action: text().notNull(),
    entity: text().notNull(),
    entityId: text().notNull(),
    before: jsonb(),
    after: jsonb(),
    reason: text(),
    createdAt: timestamptz().notNull().defaultNow(),
  },
  (t) => [
    index("audit_logs_entity_idx").on(t.entity, t.entityId, t.createdAt.desc()),
    index("audit_logs_created_idx").on(t.createdAt.desc()),
  ],
);

// ===== Trạng thái đồng bộ Google Sheet (một dòng duy nhất) =====

export const syncState = pgTable(
  "sync_state",
  {
    id: smallint().primaryKey().default(1),
    dirty: boolean().notNull().default(true),
    dirtySince: timestamptz(),
    lastSuccessAt: timestamptz(),
    lastError: text(),
    lastErrorAt: timestamptz(),
  },
  (t) => [check("sync_state_singleton", sql`${t.id} = 1`)],
);

// ===== View (tạo bằng migration SQL, Drizzle chỉ dùng để đọc có kiểu) =====

export const chargeStatusEnum = ["waived", "paid", "pending", "partial", "unpaid"] as const;
export type ChargeStatus = (typeof chargeStatusEnum)[number];

export const vChargeStatus = pgView("v_charge_status", {
  chargeId: uuid().notNull(),
  collectionId: uuid().notNull(),
  memberId: uuid().notNull(),
  amount: money().notNull(),
  paid: money().notNull(),
  remaining: money().notNull(),
  hasPending: boolean().notNull(),
  status: text({ enum: chargeStatusEnum }).notNull(),
}).existing();

export const vCollectionProgress = pgView("v_collection_progress", {
  collectionId: uuid().notNull(),
  code: text().notNull(),
  title: text().notNull(),
  status: collectionStatus().notNull(),
  dueDate: date(),
  memberCount: bigint({ mode: "number" }).notNull(),
  doneCount: bigint({ mode: "number" }).notNull(),
  totalDue: money().notNull(),
  totalPaid: money().notNull(),
}).existing();

export const vMemberDebt = pgView("v_member_debt", {
  memberId: uuid().notNull(),
  name: text().notNull(),
  jerseyNumber: smallint(),
  status: memberStatus().notNull(),
  debt: money().notNull(),
}).existing();

export const vFundBalance = pgView("v_fund_balance", {
  totalIn: money().notNull(),
  totalOut: money().notNull(),
  balance: money().notNull(),
}).existing();
