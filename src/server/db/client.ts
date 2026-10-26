import "server-only";

import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";

import * as schema from "./schema";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  throw new Error("Thiếu biến môi trường DATABASE_URL");
}

// Giữ một kết nối duy nhất khi Next.js hot-reload ở môi trường dev.
const globalForDb = globalThis as unknown as { pgClient?: ReturnType<typeof postgres> };

// prepare: false để tương thích connection pooler ở chế độ transaction (DESIGN §4.3).
const client = globalForDb.pgClient ?? postgres(databaseUrl, { prepare: false });
if (process.env.NODE_ENV !== "production") globalForDb.pgClient = client;

export const db = drizzle({ client, schema, casing: "snake_case" });

export type Db = typeof db;
export type Tx = Parameters<Parameters<Db["transaction"]>[0]>[0];
