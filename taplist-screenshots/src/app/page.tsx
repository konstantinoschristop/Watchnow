"use client";

import { useEffect, useRef, useState } from "react";
import type { ReactElement, ReactNode, CSSProperties } from "react";
import { toPng } from "html-to-image";

// =========================================================
// Canvas + Apple export sizes
// =========================================================
const W = 1320;
const H = 2868;

const IPHONE_SIZES = [
  { label: '6.5"', w: 1242, h: 2688 },
  { label: '6.7"', w: 1284, h: 2778 },
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;

// =========================================================
// iPhone mockup measurements
// =========================================================
const MK_W = 1022;
const MK_H = 2082;
const MK_RATIO = MK_W / MK_H;
const SC_L = (52 / MK_W) * 100;
const SC_T = (46 / MK_H) * 100;
const SC_W = (918 / MK_W) * 100;
const SC_H = (1990 / MK_H) * 100;
const SC_RX = (126 / 918) * 100;
const SC_RY = (126 / 1990) * 100;

// =========================================================
// Theme — light / sage / organic (derived from accent #7C8967)
// =========================================================
const THEME = {
  bgCream: "linear-gradient(180deg, #FBF7EE 0%, #F3ECDA 100%)",
  bgMint:  "linear-gradient(160deg, #F1F5E8 0%, #E2EBD0 100%)",
  bgWarm:  "linear-gradient(180deg, #FFFAEE 0%, #F0E6CE 100%)",
  bgSoft:  "linear-gradient(165deg, #F8F4E8 0%, #E8E1CB 100%)",
  fg: "#1F1F1B",
  muted: "#7A7261",
  sage: "#7C8967",
  sageDeep: "#5E6B4D",
  sageLight: "#D6DEC2",
  emerald: "#3F8A55",
};

// =========================================================
// Image preload
// =========================================================
const IMAGE_PATHS = [
  "/mockup.png",
  "/app-icon.png",
  "/screenshots/home.png",
  "/screenshots/browse.png",
  "/screenshots/basket.png",
  "/screenshots/history.png",
];

const imageCache: Record<string, string> = {};

async function preloadAllImages() {
  await Promise.all(
    IMAGE_PATHS.map(async (path) => {
      const resp = await fetch(path);
      const blob = await resp.blob();
      const dataUrl = await new Promise<string>((resolve) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result as string);
        reader.readAsDataURL(blob);
      });
      imageCache[path] = dataUrl;
    })
  );
}

function img(path: string): string {
  return imageCache[path] || path;
}

function phoneW(cW: number, cH: number, clamp = 0.84) {
  return Math.min(clamp, 0.72 * (cH / cW) * MK_RATIO);
}

// =========================================================
// Phone frame
// =========================================================
function Phone({
  src,
  alt,
  style,
}: {
  src: string;
  alt: string;
  style?: CSSProperties;
}) {
  return (
    <div style={{ position: "relative", aspectRatio: `${MK_W}/${MK_H}`, ...style }}>
      <img
        src={img("/mockup.png")}
        alt=""
        style={{ display: "block", width: "100%", height: "100%" }}
        draggable={false}
      />
      <div
        style={{
          position: "absolute",
          zIndex: 10,
          overflow: "hidden",
          left: `${SC_L}%`,
          top: `${SC_T}%`,
          width: `${SC_W}%`,
          height: `${SC_H}%`,
          borderRadius: `${SC_RX}% / ${SC_RY}%`,
        }}
      >
        <img
          src={src}
          alt={alt}
          style={{
            display: "block",
            width: "100%",
            height: "100%",
            objectFit: "cover",
            objectPosition: "top",
          }}
          draggable={false}
        />
      </div>
    </div>
  );
}

// =========================================================
// Caption
// =========================================================
function Caption({
  cW,
  label,
  headline,
  sub,
  align = "left",
}: {
  cW: number;
  label?: string;
  headline: ReactNode;
  sub?: ReactNode;
  align?: "left" | "center";
}) {
  return (
    <div style={{ textAlign: align, color: THEME.fg }}>
      {label && (
        <div
          style={{
            fontSize: cW * 0.026,
            fontWeight: 600,
            letterSpacing: cW * 0.003,
            color: THEME.sageDeep,
            textTransform: "uppercase",
            marginBottom: cW * 0.02,
          }}
        >
          {label}
        </div>
      )}
      <div
        style={{
          fontSize: cW * 0.098,
          fontWeight: 700,
          lineHeight: 1.0,
          letterSpacing: cW * -0.002,
          color: THEME.fg,
        }}
      >
        {headline}
      </div>
      {sub && (
        <div
          style={{
            fontSize: cW * 0.032,
            fontWeight: 400,
            lineHeight: 1.35,
            color: THEME.muted,
            marginTop: cW * 0.028,
            maxWidth: "92%",
            ...(align === "center" ? { margin: `${cW * 0.028}px auto 0` } : {}),
          }}
        >
          {sub}
        </div>
      )}
    </div>
  );
}

// =========================================================
// Decorative glow blob (soft, warm)
// =========================================================
function SoftBlob({
  x,
  y,
  size,
  color = THEME.sage,
  opacity = 0.18,
}: {
  x: string;
  y: string;
  size: number;
  color?: string;
  opacity?: number;
}) {
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width: size,
        height: size,
        borderRadius: "50%",
        background: `radial-gradient(circle, ${color} 0%, transparent 65%)`,
        opacity,
        filter: `blur(${size * 0.08}px)`,
        pointerEvents: "none",
      }}
    />
  );
}

function pillStyle(cW: number): CSSProperties {
  return {
    display: "inline-block",
    padding: `${cW * 0.018}px ${cW * 0.036}px`,
    borderRadius: 999,
    background: "rgba(124, 137, 103, 0.10)",
    border: "1px solid rgba(124, 137, 103, 0.30)",
    color: THEME.sageDeep,
    fontWeight: 600,
    fontSize: cW * 0.028,
    whiteSpace: "nowrap",
    width: "fit-content",
  };
}

// =========================================================
// Slides
// =========================================================
type SlideProps = { cW: number; cH: number };
type SlideDef = { id: string; component: (p: SlideProps) => ReactElement };

// 1. Hero — Home / Your Regulars
const SLIDE_1: SlideDef = {
  id: "hero",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: THEME.bgCream,
        }}
      >
        <SoftBlob x="-15%" y="40%" size={cW * 1.2} opacity={0.25} />
        <SoftBlob x="60%" y="60%" size={cW * 0.9} color={THEME.emerald} opacity={0.12} />
        <div
          style={{
            position: "absolute",
            top: cH * 0.07,
            left: cW * 0.07,
            right: cW * 0.07,
          }}
        >
          <Caption
            cW={cW}
            label="TAPLIST"
            headline={
              <>
                Skip the typing.
                <br />
                Just tap.
              </>
            }
            sub="Your regulars, one tap away — no searching, no fuss."
          />
        </div>
        <div
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            width: `${fw}%`,
            transform: "translateX(-50%) translateY(13%)",
          }}
        >
          <Phone src={img("/screenshots/home.png")} alt="Your Regulars" />
        </div>
      </div>
    );
  },
};

// 2. Browse — Categorized
const SLIDE_2: SlideDef = {
  id: "browse",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH, 0.78) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: THEME.bgMint,
        }}
      >
        <SoftBlob x="-25%" y="-10%" size={cW * 1.1} color={THEME.sage} opacity={0.22} />
        <SoftBlob x="65%" y="50%" size={cW * 0.7} color={THEME.emerald} opacity={0.10} />
        <div
          style={{
            position: "absolute",
            top: cH * 0.07,
            left: cW * 0.07,
            right: cW * 0.07,
          }}
        >
          <Caption
            cW={cW}
            label="BROWSE"
            headline={
              <>
                Everything, sorted
                <br />
                how you shop.
              </>
            }
            sub="Frozen, household, bakery — categorized the way you'd actually walk the aisles."
          />
        </div>
        <div
          style={{
            position: "absolute",
            bottom: 0,
            right: "-8%",
            width: `${fw}%`,
            transform: "translateY(14%) rotate(-3deg)",
          }}
        >
          <Phone src={img("/screenshots/browse.png")} alt="Browse categories" />
        </div>
      </div>
    );
  },
};

// 3. Basket — Check off
const SLIDE_3: SlideDef = {
  id: "basket",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: THEME.bgWarm,
        }}
      >
        <SoftBlob x="55%" y="20%" size={cW * 1.0} color={THEME.emerald} opacity={0.16} />
        <SoftBlob x="-10%" y="65%" size={cW * 0.9} color={THEME.sage} opacity={0.18} />
        <div
          style={{
            position: "absolute",
            top: cH * 0.07,
            left: cW * 0.07,
            right: cW * 0.07,
          }}
        >
          <Caption
            cW={cW}
            label="IN THE SHOP"
            headline={
              <>
                Check off.
                <br />
                Crush it.
              </>
            }
            sub="Track progress as you go. Quantities, notes, and a satisfying tick."
          />
        </div>
        <div
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            width: `${fw}%`,
            transform: "translateX(-50%) translateY(13%)",
          }}
        >
          <Phone src={img("/screenshots/basket.png")} alt="Basket in progress" />
        </div>
      </div>
    );
  },
};

// 4. History — Reuse
const SLIDE_4: SlideDef = {
  id: "history",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH, 0.78) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: THEME.bgSoft,
        }}
      >
        <SoftBlob x="-20%" y="20%" size={cW * 1.0} color={THEME.sage} opacity={0.22} />
        <SoftBlob x="60%" y="70%" size={cW * 0.8} color={THEME.emerald} opacity={0.12} />
        <div
          style={{
            position: "absolute",
            top: cH * 0.07,
            left: cW * 0.07,
            right: cW * 0.07,
          }}
        >
          <Caption
            cW={cW}
            label="BASKET HISTORY"
            headline={
              <>
                Reuse last
                <br />
                week's shop.
              </>
            }
            sub="Tap once. The same items, ready to go again."
          />
        </div>
        <div
          style={{
            position: "absolute",
            bottom: 0,
            left: "8%",
            width: `${fw}%`,
            transform: "translateY(13%) rotate(2deg)",
          }}
        >
          <Phone src={img("/screenshots/history.png")} alt="Basket history" />
        </div>
      </div>
    );
  },
};

// 5. Closing — Identity
const SLIDE_5: SlideDef = {
  id: "closing",
  component: ({ cW, cH }) => {
    const iconSize = cW * 0.24;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background:
            "radial-gradient(ellipse at 50% 30%, #F1EBD8 0%, #E5DBBE 60%, #D8CDA8 100%)",
        }}
      >
        <SoftBlob x="50%" y="20%" size={cW * 1.4} color={THEME.sage} opacity={0.28} />
        <div
          style={{
            position: "absolute",
            top: cH * 0.13,
            left: "50%",
            transform: "translateX(-50%)",
          }}
        >
          <img
            src={img("/app-icon.png")}
            alt="Taplist"
            style={{
              width: iconSize,
              height: iconSize,
              borderRadius: iconSize * 0.225,
              boxShadow: `0 ${cW * 0.02}px ${cW * 0.04}px rgba(0,0,0,0.18), 0 0 ${cW * 0.06}px rgba(124,137,103,0.35)`,
            }}
            draggable={false}
          />
        </div>
        <div
          style={{
            position: "absolute",
            top: cH * 0.38,
            left: cW * 0.07,
            right: cW * 0.07,
            textAlign: "center",
          }}
        >
          <div
            style={{
              fontSize: cW * 0.04,
              fontWeight: 600,
              letterSpacing: cW * 0.004,
              color: THEME.sageDeep,
              textTransform: "uppercase",
              marginBottom: cW * 0.024,
            }}
          >
            Taplist
          </div>
          <div
            style={{
              fontSize: cW * 0.105,
              fontWeight: 700,
              lineHeight: 1.0,
              letterSpacing: cW * -0.002,
              color: THEME.fg,
            }}
          >
            The fastest way
            <br />
            to shop.
          </div>
          <div
            style={{
              fontSize: cW * 0.034,
              fontWeight: 400,
              lineHeight: 1.4,
              color: THEME.muted,
              marginTop: cW * 0.04,
              maxWidth: "82%",
              marginInline: "auto",
            }}
          >
            Free to download. No subscription. Just tap.
          </div>
        </div>
        <div
          style={{
            position: "absolute",
            bottom: cH * 0.1,
            left: cW * 0.07,
            right: cW * 0.07,
            display: "flex",
            flexWrap: "wrap",
            justifyContent: "center",
            gap: cW * 0.022,
          }}
        >
          {[
            "Your regulars",
            "Categories",
            "Basket history",
            "Recipes",
            "Smart suggestions",
            "Share lists",
          ].map((t) => (
            <div key={t} style={pillStyle(cW)}>
              {t}
            </div>
          ))}
        </div>
      </div>
    );
  },
};

const SLIDES: SlideDef[] = [SLIDE_1, SLIDE_2, SLIDE_3, SLIDE_4, SLIDE_5];

// =========================================================
// Preview card
// =========================================================
function ScreenshotPreview({
  slide,
  idx,
  cW,
  cH,
  onExport,
  exportRef,
}: {
  slide: SlideDef;
  idx: number;
  cW: number;
  cH: number;
  onExport: (idx: number) => void;
  exportRef: (el: HTMLDivElement | null) => void;
}) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.2);
  const [hover, setHover] = useState(false);

  useEffect(() => {
    if (!wrapRef.current) return;
    const ro = new ResizeObserver((entries) => {
      const w = entries[0].contentRect.width;
      setScale(w / cW);
    });
    ro.observe(wrapRef.current);
    return () => ro.disconnect();
  }, [cW]);

  return (
    <div
      ref={wrapRef}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      onClick={() => onExport(idx)}
      style={{
        width: "100%",
        aspectRatio: `${cW}/${cH}`,
        position: "relative",
        overflow: "hidden",
        borderRadius: 14,
        background: "#e9e4d4",
        cursor: "pointer",
        boxShadow: hover
          ? "0 10px 32px rgba(0,0,0,0.18)"
          : "0 4px 14px rgba(0,0,0,0.08)",
        transition: "box-shadow 0.2s ease, transform 0.2s ease",
        transform: hover ? "translateY(-2px)" : "translateY(0)",
      }}
    >
      <div
        style={{
          width: cW,
          height: cH,
          transformOrigin: "top left",
          transform: `scale(${scale})`,
          position: "absolute",
          top: 0,
          left: 0,
        }}
      >
        <slide.component cW={cW} cH={cH} />
      </div>

      <div
        style={{
          position: "absolute",
          top: 8,
          left: 8,
          zIndex: 30,
          background: "rgba(0,0,0,0.55)",
          color: "white",
          fontSize: 11,
          fontWeight: 600,
          padding: "3px 8px",
          borderRadius: 6,
          backdropFilter: "blur(8px)",
        }}
      >
        {idx + 1}. {slide.id}
      </div>

      {hover && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            zIndex: 25,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            background: "rgba(31, 31, 27, 0.45)",
            color: "white",
            fontWeight: 600,
            fontSize: 13,
          }}
        >
          Click to export this slide
        </div>
      )}

      <div
        ref={exportRef}
        style={{
          position: "absolute",
          left: -9999,
          top: 0,
          width: cW,
          height: cH,
          opacity: 0,
          pointerEvents: "none",
        }}
      >
        <slide.component cW={cW} cH={cH} />
      </div>
    </div>
  );
}

// =========================================================
// Main page
// =========================================================
export default function ScreenshotsPage() {
  const [ready, setReady] = useState(false);
  const [sizeIdx, setSizeIdx] = useState(0);
  const [exporting, setExporting] = useState<string | null>(null);
  const exportRefs = useRef<(HTMLDivElement | null)[]>([]);

  useEffect(() => {
    preloadAllImages().then(() => setReady(true));
  }, []);

  const cW = W;
  const cH = H;
  const currentSize = IPHONE_SIZES[sizeIdx];

  async function captureSlide(el: HTMLElement, w: number, h: number): Promise<string> {
    el.style.left = "0px";
    el.style.opacity = "1";
    el.style.zIndex = "-1";

    const opts = { width: w, height: h, pixelRatio: 1, cacheBust: true };
    await toPng(el, opts);
    const dataUrl = await toPng(el, opts);

    el.style.left = "-9999px";
    el.style.opacity = "0";
    el.style.zIndex = "";
    return dataUrl;
  }

  async function exportOne(i: number) {
    const el = exportRefs.current[i];
    if (!el) return;
    setExporting(`${i + 1}/${SLIDES.length}`);
    const dataUrl = await captureSlide(el, currentSize.w, currentSize.h);
    const a = document.createElement("a");
    a.href = dataUrl;
    a.download = `${String(i + 1).padStart(2, "0")}-${SLIDES[i].id}-${currentSize.w}x${currentSize.h}.png`;
    a.click();
    setExporting(null);
  }

  async function exportAll() {
    for (let i = 0; i < SLIDES.length; i++) {
      setExporting(`${i + 1}/${SLIDES.length}`);
      const el = exportRefs.current[i];
      if (!el) continue;
      const dataUrl = await captureSlide(el, currentSize.w, currentSize.h);
      const a = document.createElement("a");
      a.href = dataUrl;
      a.download = `${String(i + 1).padStart(2, "0")}-${SLIDES[i].id}-${currentSize.w}x${currentSize.h}.png`;
      a.click();
      await new Promise((r) => setTimeout(r, 300));
    }
    setExporting(null);
  }

  if (!ready) {
    return (
      <div
        style={{
          minHeight: "100vh",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: "#f3f4f6",
          color: "#6b7280",
        }}
      >
        Loading assets…
      </div>
    );
  }

  return (
    <div
      style={{
        minHeight: "100vh",
        background: "#f3f4f6",
        position: "relative",
        overflowX: "hidden",
      }}
    >
      <div
        style={{
          position: "sticky",
          top: 0,
          zIndex: 50,
          background: "white",
          borderBottom: "1px solid #e5e7eb",
          display: "flex",
          alignItems: "center",
        }}
      >
        <div
          style={{
            flex: 1,
            display: "flex",
            alignItems: "center",
            gap: 12,
            padding: "10px 20px",
            overflowX: "auto",
            minWidth: 0,
          }}
        >
          <span style={{ fontWeight: 700, fontSize: 14, whiteSpace: "nowrap" }}>
            Taplist · iPhone Screenshots
          </span>
          <select
            value={sizeIdx}
            onChange={(e) => setSizeIdx(Number(e.target.value))}
            style={{
              fontSize: 12,
              border: "1px solid #e5e7eb",
              borderRadius: 6,
              padding: "5px 10px",
            }}
          >
            {IPHONE_SIZES.map((s, i) => (
              <option key={i} value={i}>
                {s.label} — {s.w}×{s.h}
              </option>
            ))}
          </select>
          <span style={{ fontSize: 12, color: "#6b7280", whiteSpace: "nowrap" }}>
            {SLIDES.length} slides · click a slide to export individually
          </span>
        </div>
        <div
          style={{
            flexShrink: 0,
            padding: "10px 20px",
            borderLeft: "1px solid #e5e7eb",
          }}
        >
          <button
            onClick={exportAll}
            disabled={!!exporting}
            style={{
              padding: "7px 22px",
              background: exporting ? "#a8b595" : "#5E6B4D",
              color: "white",
              border: "none",
              borderRadius: 8,
              fontSize: 12,
              fontWeight: 600,
              cursor: exporting ? "default" : "pointer",
              whiteSpace: "nowrap",
            }}
          >
            {exporting ? `Exporting… ${exporting}` : "Export All"}
          </button>
        </div>
      </div>

      <div
        style={{
          padding: 24,
          display: "grid",
          gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))",
          gap: 18,
        }}
      >
        {SLIDES.map((s, i) => (
          <ScreenshotPreview
            key={s.id}
            slide={s}
            idx={i}
            cW={cW}
            cH={cH}
            onExport={exportOne}
            exportRef={(el) => {
              exportRefs.current[i] = el;
            }}
          />
        ))}
      </div>
    </div>
  );
}
