import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Платформа arawebsite — адмінка сайтів",
  description: "Керування контентом сайтів клієнтів веб-студії arawebsite",
  robots: { index: false, follow: false },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="uk">
      <body>{children}</body>
    </html>
  );
}
