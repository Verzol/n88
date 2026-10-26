import "server-only";

import { sql } from "drizzle-orm";

import { db, type Tx } from "./db/client";

export type AuditMeta = {
  /** Tên hành động nghiệp vụ, ví dụ 'payment.confirm'. */
  action: string;
  reason?: string;
};

/**
 * Chạy `fn` trong một giao dịch và gắn thông tin người thực hiện cho trigger nhật ký.
 * set_config(..., true) chỉ có hiệu lực trong giao dịch này nên an toàn khi dùng chung kết nối
 * qua pooler. Tham chiếu: docs/DESIGN.md §9.
 */
export async function withActor<T>(
  actorMemberId: string,
  meta: AuditMeta,
  fn: (tx: Tx) => Promise<T>,
): Promise<T> {
  return db.transaction(async (tx) => {
    await tx.execute(sql`
      select set_config('app.actor_id', ${actorMemberId}, true),
             set_config('app.action',   ${meta.action}, true),
             set_config('app.reason',   ${meta.reason ?? ""}, true)`);
    return fn(tx);
  });
}
