import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Watchnow · App Store Screenshots",
  description: "Screenshot generator for the Watchnow iOS app",
};

const systemFontStack =
  '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Segoe UI", Roboto, sans-serif';

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col" style={{ fontFamily: systemFontStack }}>
        {children}
      </body>
    </html>
  );
}
