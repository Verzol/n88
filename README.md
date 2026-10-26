# N88 · Quỹ đội

Web app quản lý thành viên và thu chi quỹ đội bóng.

- Định hướng sản phẩm: [docs/PROPOSAL.md](docs/PROPOSAL.md)
- Đặc tả yêu cầu: [docs/SRS.md](docs/SRS.md)
- Thiết kế hệ thống: [docs/DESIGN.md](docs/DESIGN.md)

## Yêu cầu

- Node.js 24+
- Docker Desktop (chạy Supabase local)
- Supabase CLI (`npm i -g supabase` hoặc dùng `npx supabase`)

## Chạy local

```bash
npm install
cp .env.example .env.local
npm run supabase:start      # lần đầu sẽ tải image Docker, mất vài phút
npx supabase status         # lấy anon key, service role key rồi điền vào .env.local
npm run db:migrate          # tạo bảng, view, trigger, dữ liệu khởi tạo
npm run db:smoke            # kiểm tra nhanh logic trong DB (chạy trong giao dịch rồi rollback)
npm run dev
```

Supabase Studio: http://127.0.0.1:55323

## Script

| Lệnh | Việc làm |
|---|---|
| `npm run dev` | Chạy Next.js ở chế độ dev |
| `npm run build` | Build production |
| `npm run lint` | ESLint |
| `npm run typecheck` | Sinh type route rồi chạy `tsc` |
| `npm run db:generate` | Sinh migration từ `src/server/db/schema.ts` |
| `npm run db:migrate` | Áp dụng migration lên DB trong `DATABASE_URL` |
| `npm run db:studio` | Mở Drizzle Studio |
| `npm run db:smoke` | Chạy `scripts/db-smoke.sql` trên DB local |
| `npm run supabase:start` / `supabase:stop` | Bật / tắt Supabase local |

## Migration

- Bảng, enum, index, ràng buộc: khai báo trong `src/server/db/schema.ts`, sinh bằng `npm run db:generate`.
- View, trigger, RLS, dữ liệu khởi tạo: viết tay trong `drizzle/0001_db_logic.sql`. Thay đổi các phần này bằng một migration custom mới: `npx drizzle-kit generate --custom --name=<tên>`.
- Không dùng `supabase db reset` để dựng lại schema; migration do Drizzle quản lý. Muốn làm sạch DB local: `npx supabase db reset` rồi chạy lại `npm run db:migrate`.
