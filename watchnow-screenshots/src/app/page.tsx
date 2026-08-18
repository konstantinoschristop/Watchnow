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
// iPhone mockup measurements (pre-measured from mockup.png)
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
// Theme — dark cinematic (derived from Watchnow accent #5083F5)
// =========================================================
const THEME = {
  bgGradient: "linear-gradient(180deg, #0A1429 0%, #050816 60%, #04060F 100%)",
  fg: "#F8FAFC",
  muted: "#94A3B8",
  accent: "#5083F5",
  accentDeep: "#2D5BD9",
};

// =========================================================
// Image preload (data-URI cache for html-to-image reliability)
// =========================================================
const IMAGE_PATHS = [
  "/mockup.png",
  "/app-icon.png",
  "/screenshots/movies.png",
  "/screenshots/watchlist.png",
  "/screenshots/details.png",
  "/screenshots/coach.png",
  "/screenshots/personalization.png",
  "/screenshots/movie-night.png",
  "/screenshots/superman-details.png",
  "/screenshots/reminder-banner.png",
  "/screenshots/streaming.png",
  "/screenshots/reminders.png",
  "/screenshots/notification-banner-cropped.jpg",
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

// =========================================================
// Width formula for iPhone in this canvas
// =========================================================
function phoneW(cW: number, cH: number, clamp = 0.84) {
  return Math.min(clamp, 0.72 * (cH / cW) * MK_RATIO);
}

// =========================================================
// Phone frame component
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
            color: THEME.accent,
            textTransform: "uppercase",
            marginBottom: cW * 0.02,
          }}
        >
          {label}
        </div>
      )}
      <div
        style={{
          fontSize: cW * 0.095,
          fontWeight: 700,
          lineHeight: 1.02,
          letterSpacing: cW * -0.0015,
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
// Decorative glow
// =========================================================
function BgGlow({
  x,
  y,
  size,
  color = THEME.accent,
  opacity = 0.4,
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
        filter: `blur(${size * 0.1}px)`,
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
    background: "rgba(255,255,255,0.06)",
    border: "1px solid rgba(255,255,255,0.14)",
    backdropFilter: "blur(20px)",
    color: THEME.fg,
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

const SLIDE_1: SlideDef = {
  id: "discover",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: THEME.bgGradient,
        }}
      >
        <BgGlow x="-15%" y="35%" size={cW * 1.2} opacity={0.35} />
        <BgGlow x="60%" y="55%" size={cW * 0.9} color={THEME.accentDeep} opacity={0.55} />
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
            label="DISCOVER"
            headline={
              <>
                Everything you
                <br />
                want to watch.
              </>
            }
            sub="Find movies, series, actors, trailers, reviews, and more in one place."
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
          <Phone src={img("/screenshots/movies.png")} alt="Movies home" />
        </div>
      </div>
    );
  },
};

const SLIDE_3: SlideDef = {
  id: "streaming-filter-retired",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH, 0.78) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: THEME.bgGradient,
        }}
      >
        <BgGlow x="55%" y="20%" size={cW * 1.0} opacity={0.4} />
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
            label="STREAMING FILTER"
            headline={
              <>
                Filter by streamer.
                <br />
                Watch instantly.
              </>
            }
            sub="See only what's on Netflix, Apple TV, Prime — anywhere you subscribe."
          />
        </div>
        <div
          style={{
            position: "absolute",
            top: cH * 0.34,
            left: cW * 0.05,
            display: "flex",
            flexDirection: "column",
            gap: cW * 0.024,
            zIndex: 5,
          }}
        >
          <div style={pillStyle(cW)}>Netflix</div>
          <div style={{ ...pillStyle(cW), marginLeft: cW * 0.06 }}>Apple TV+</div>
          <div style={pillStyle(cW)}>Prime Video</div>
          <div style={{ ...pillStyle(cW), marginLeft: cW * 0.04 }}>Disney+</div>
          <div style={pillStyle(cW)}>HBO Max</div>
        </div>
        <div
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            width: `${fw}%`,
            transform: "translateX(-25%) translateY(14%)",
          }}
        >
          <Phone src={img("/screenshots/streaming.png")} alt="Browse by streaming" />
        </div>
      </div>
    );
  },
};

const SLIDE_4: SlideDef = {
  id: "streaming",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: "linear-gradient(180deg, #051026 0%, #03050E 100%)",
        }}
      >
        <BgGlow x="20%" y="55%" size={cW * 1.0} color={THEME.accent} opacity={0.45} />
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
            label="STREAMING"
            headline={
              <>
                Know where
                <br />
                to watch.
              </>
            }
            sub="Find it on Netflix, Prime Video, Disney+, Apple TV and more."
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
          <Phone src={img("/screenshots/details.png")} alt="Where to watch" />
        </div>
      </div>
    );
  },
};

const SLIDE_5: SlideDef = {
  id: "watchlist",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH, 0.78) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: "linear-gradient(165deg, #0A1429 0%, #050818 100%)",
        }}
      >
        <BgGlow x="-20%" y="20%" size={cW * 1.0} color={THEME.accentDeep} opacity={0.5} />
        <BgGlow x="60%" y="70%" size={cW * 0.8} color={THEME.accent} opacity={0.3} />
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
            label="YOUR LIBRARY"
            headline={
              <>
                Save now.
                <br />
                Watch later.
              </>
            }
            sub="Your personal movie and TV library — organized, synced, and never lost."
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
          <Phone src={img("/screenshots/watchlist.png")} alt="Watchlist" />
        </div>
      </div>
    );
  },
};

const SLIDE_REMINDERS: SlideDef = {
  id: "reminders",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: "linear-gradient(180deg, #0A1429 0%, #050816 60%, #04060F 100%)",
        }}
      >
        <BgGlow x="-15%" y="40%" size={cW * 1.1} color={THEME.accent} opacity={0.4} />
        <BgGlow x="55%" y="65%" size={cW * 0.9} color={THEME.accentDeep} opacity={0.45} />
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
            label="REMINDERS"
            headline={
              <>
                Never miss
                <br />
                what&apos;s next.
              </>
            }
            sub="Get notified when the movies and series you care about are released."
          />
        </div>
        {/* Both pieces are real simulator captures of the production
            reminder flow — the details screen and, floating over its top
            edge, the actual iOS banner it fires. Scaled up from its native
            size so the copy survives an App Store thumbnail; nothing here is
            drawn or recreated. */}
        <div
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            width: `${fw}%`,
            transform: "translateX(-50%) translateY(13%)",
          }}
        >
          <Phone
            src={img("/screenshots/superman-details.png")}
            alt="Superman details screen in WatchNow"
          />
        </div>
        <div
          style={{
            position: "absolute",
            top: cH * 0.345,
            left: "50%",
            width: "92%",
            transform: "translateX(-50%)",
            zIndex: 20,
            borderRadius: cW * 0.055,
            overflow: "hidden",
            boxShadow: `0 ${cW * 0.022}px ${cW * 0.055}px rgba(0,0,0,0.55), 0 0 ${cW * 0.07}px rgba(80,131,245,0.28)`,
          }}
        >
          <img
            src={img("/screenshots/reminder-banner.png")}
            alt="Out now — Superman is out today, time to watch"
            style={{ width: "100%", display: "block" }}
            draggable={false}
          />
        </div>
      </div>
    );
  },
};

const SLIDE_6: SlideDef = {
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
            "radial-gradient(ellipse at 50% 30%, #0F2347 0%, #060A1A 60%, #03050E 100%)",
        }}
      >
        <BgGlow x="50%" y="20%" size={cW * 1.4} color={THEME.accent} opacity={0.5} />
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
            alt="Watchnow"
            style={{
              width: iconSize,
              height: iconSize,
              borderRadius: iconSize * 0.225,
              boxShadow: `0 ${cW * 0.02}px ${cW * 0.04}px rgba(0,0,0,0.5), 0 0 ${cW * 0.08}px rgba(80,131,245,0.5)`,
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
              color: THEME.accent,
              textTransform: "uppercase",
              marginBottom: cW * 0.024,
            }}
          >
            Watchnow
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
            Your next binge
            <br />
            starts here.
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
            Your personal movie &amp; TV companion.
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
            "Movie Coach",
            "Movie Night",
            "Streaming guide",
            "Watchlist",
            "Reminders",
            "Episode tracking",
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

const SLIDE_COACH: SlideDef = {
  id: "coach",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: "linear-gradient(180deg, #0A1429 0%, #050816 60%, #04060F 100%)",
        }}
      >
        <BgGlow x="78%" y="40%" size={cW * 1.05} color={THEME.accent} opacity={0.42} />
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
            label="MOVIE COACH"
            headline={
              <>
                Should you
                <br />
                watch it?
              </>
            }
            sub={
              <>
                A personal second opinion for every movie and series, shaped by
                what you like.
                <span
                  style={{
                    display: "block",
                    marginTop: cW * 0.018,
                    color: THEME.accent,
                    fontWeight: 600,
                  }}
                >
                  Powered entirely on-device.
                </span>
              </>
            }
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
          <Phone src={img("/screenshots/coach.png")} alt="Movie Coach verdict on a series" />
        </div>
      </div>
    );
  },
};

const SLIDE_PERSONALIZATION: SlideDef = {
  id: "personalization",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: "linear-gradient(180deg, #0A1429 0%, #050816 60%, #04060F 100%)",
        }}
      >
        <BgGlow x="24%" y="38%" size={cW * 1.05} color={THEME.accent} opacity={0.42} />
        <div style={{ position: "absolute", top: cH * 0.07, left: cW * 0.07, right: cW * 0.07 }}>
          <Caption
            cW={cW}
            label="PERSONALIZATION"
            headline={
              <>
                It knows what
                <br />
                you like.
              </>
            }
            sub="Get smarter advice based on your watchlist, likes, and the titles you care about."
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
          <Phone src={img("/screenshots/personalization.png")} alt="Movie Coach referencing the genres you save" />
        </div>
      </div>
    );
  },
};

const SLIDE_MOVIENIGHT: SlideDef = {
  id: "movie-night",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: "linear-gradient(180deg, #0A1429 0%, #050816 60%, #04060F 100%)",
        }}
      >
        <BgGlow x="72%" y="52%" size={cW * 1.0} color={THEME.accent} opacity={0.44} />
        <div style={{ position: "absolute", top: cH * 0.07, left: cW * 0.07, right: cW * 0.07 }}>
          <Caption
            cW={cW}
            label="MOVIE NIGHT"
            headline={<>Can&apos;t decide?</>}
            sub="Swipe to match. Find something that fits tonight."
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
          <Phone src={img("/screenshots/movie-night.png")} alt="Movie Night swipe matching" />
        </div>
      </div>
    );
  },
};

const SLIDES: SlideDef[] = [SLIDE_COACH, SLIDE_MOVIENIGHT, SLIDE_4, SLIDE_REMINDERS, SLIDE_5];

// =========================================================
// Preview card (scaled via ResizeObserver)
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
        background: "#1f2937",
        cursor: "pointer",
        boxShadow: hover
          ? "0 10px 32px rgba(0,0,0,0.28)"
          : "0 4px 14px rgba(0,0,0,0.15)",
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
            background: "rgba(0,0,0,0.42)",
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

  // Writes a rendered slide straight into ./exports via the save route,
  // instead of going through a browser download. Handy for scripted/agent
  // runs and for regenerating a single slide without touching the others.
  async function saveSlideToDisk(i: number) {
    const el = exportRefs.current[i];
    if (!el) return { error: "no slide element" };
    const dataUrl = await captureSlide(el, currentSize.w, currentSize.h);
    const filename = `${String(i + 1).padStart(2, "0")}-${SLIDES[i].id}-${currentSize.w}x${currentSize.h}.png`;
    const res = await fetch("/api/save", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ filename, dataUrl }),
    });
    return res.json();
  }

  useEffect(() => {
    (window as unknown as Record<string, unknown>).saveSlideToDisk = saveSlideToDisk;
  });

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
            Watchnow · iPhone Screenshots
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
              background: exporting ? "#93c5fd" : "#2563eb",
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
