import { defineConfig } from "drizzle-kit";

export default defineConfig({
  dialect: "postgresql",
  schema: "./src/server/db/schema.ts",
  out: "./drizzle",
  casing: "snake_case",
  // Chỉ quản lý schema public; schema auth, storage… thuộc về Supabase.
  schemaFilter: ["public"],
  dbCredentials: {
    url: process.env.DATABASE_URL ?? "postgresql://postgres:postgres@127.0.0.1:55322/postgres",
  },
  strict: true,
  verbose: true,
});
