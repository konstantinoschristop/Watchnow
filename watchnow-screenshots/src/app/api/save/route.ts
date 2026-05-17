import { writeFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { NextResponse } from "next/server";

const SAFE_NAME = /^[\w.\- ]+\.png$/;

export async function POST(req: Request) {
  const { filename, dataUrl } = await req.json();
  if (!SAFE_NAME.test(filename)) {
    return NextResponse.json({ error: "bad filename" }, { status: 400 });
  }
  const base64 = String(dataUrl).split(",")[1];
  if (!base64) {
    return NextResponse.json({ error: "bad dataUrl" }, { status: 400 });
  }
  const outDir = join(process.cwd(), "exports");
  await mkdir(outDir, { recursive: true });
  const outPath = join(outDir, filename);
  await writeFile(outPath, Buffer.from(base64, "base64"));
  return NextResponse.json({ path: outPath });
}
