import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

// Cần subset "vietnamese" để hiển thị đủ dấu tiếng Việt.
const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin", "vietnamese"],
});

export const metadata: Metadata = {
  title: "N88 · Quỹ đội",
  description: "Quản lý thành viên và thu chi quỹ đội bóng N88",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="vi" className={`${inter.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
