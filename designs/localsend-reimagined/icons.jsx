/* icons.jsx — 单色线条图标，全部 currentColor，stroke 1.7 */

const IconBase = ({ size = 18, children, stroke = 1.7, fill = "none", ...rest }) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill={fill}
    stroke="currentColor"
    strokeWidth={stroke}
    strokeLinecap="round"
    strokeLinejoin="round"
    aria-hidden="true"
    {...rest}
  >
    {children}
  </svg>
);

const IconSignal = (p) => (
  <IconBase {...p}>
    <path d="M12 12v.01" />
    <path d="M8.6 8.6a4.8 4.8 0 0 0 0 6.8" />
    <path d="M15.4 15.4a4.8 4.8 0 0 0 0-6.8" />
    <path d="M5.6 5.6a9 9 0 0 0 0 12.8" />
    <path d="M18.4 18.4a9 9 0 0 0 0-12.8" />
  </IconBase>
);

const IconSliders = (p) => (
  <IconBase {...p}>
    <path d="M4 8h9M17 8h3M4 16h3M11 16h9" />
    <circle cx="15" cy="8" r="2" />
    <circle cx="9" cy="16" r="2" />
  </IconBase>
);

const IconSend = (p) => (
  <IconBase {...p}>
    <path d="M21 3 3 10.5l7.5 3 3 7.5L21 3Z" />
    <path d="M10.5 13.5 21 3" />
  </IconBase>
);

const IconClock = (p) => (
  <IconBase {...p}>
    <circle cx="12" cy="12" r="8.6" />
    <path d="M12 7.6V12l3.1 1.9" />
  </IconBase>
);

const IconLaptop = (p) => (
  <IconBase {...p}>
    <rect x="4" y="5" width="16" height="10.5" rx="1.4" />
    <path d="M2.4 19h19.2" />
  </IconBase>
);

const IconPhone = (p) => (
  <IconBase {...p}>
    <rect x="7" y="2.6" width="10" height="18.8" rx="2.4" />
    <path d="M10.8 18.6h2.4" />
  </IconBase>
);

const IconTablet = (p) => (
  <IconBase {...p}>
    <rect x="4.5" y="2.8" width="15" height="18.4" rx="2" />
    <path d="M11 18.4h2" />
  </IconBase>
);

const IconServer = (p) => (
  <IconBase {...p}>
    <rect x="3.4" y="4" width="17.2" height="6" rx="1.2" />
    <rect x="3.4" y="14" width="17.2" height="6" rx="1.2" />
    <path d="M7 7h.01M7 17h.01" />
  </IconBase>
);

const IconStar = ({ filled = false, ...p }) => (
  <IconBase {...p} fill={filled ? "currentColor" : "none"}>
    <path d="m12 3.6 2.6 5.5 5.9.8-4.3 4.2 1 5.9-5.2-2.9-5.2 2.9 1-5.9L3.5 9.9l5.9-.8L12 3.6Z" />
  </IconBase>
);

const IconSearch = (p) => (
  <IconBase {...p}>
    <circle cx="10.8" cy="10.8" r="6.6" />
    <path d="m16 16 4.2 4.2" />
  </IconBase>
);

const IconPlus = (p) => (
  <IconBase {...p}>
    <path d="M12 5v14M5 12h14" />
  </IconBase>
);

const IconX = (p) => (
  <IconBase {...p}>
    <path d="M6 6l12 12M18 6 6 18" />
  </IconBase>
);

const IconCheck = (p) => (
  <IconBase {...p}>
    <path d="m4.5 12.5 4.8 4.8L19.5 7" />
  </IconBase>
);

const IconChevronRight = (p) => (
  <IconBase {...p}>
    <path d="m9 5.5 6.5 6.5L9 18.5" />
  </IconBase>
);

const IconChevronDown = (p) => (
  <IconBase {...p}>
    <path d="m5.5 9 6.5 6.5L18.5 9" />
  </IconBase>
);

const IconLink = (p) => (
  <IconBase {...p}>
    <path d="M10.4 13.6a3.6 3.6 0 0 0 5.1 0l2.6-2.6a3.6 3.6 0 0 0-5.1-5.1l-1.2 1.2" />
    <path d="M13.6 10.4a3.6 3.6 0 0 0-5.1 0l-2.6 2.6a3.6 3.6 0 0 0 5.1 5.1l1.2-1.2" />
  </IconBase>
);

const IconDownload = (p) => (
  <IconBase {...p}>
    <path d="M12 3.6v11" />
    <path d="m7.3 10 4.7 4.6L16.7 10" />
    <path d="M4.6 19.4h14.8" />
  </IconBase>
);

const IconArrowUp = (p) => (
  <IconBase {...p}>
    <path d="M12 19.4V4.8" />
    <path d="m6.6 10.2 5.4-5.4 5.4 5.4" />
  </IconBase>
);

const IconArrowDown = (p) => (
  <IconBase {...p}>
    <path d="M12 4.6v14.6" />
    <path d="m17.4 13.8-5.4 5.4-5.4-5.4" />
  </IconBase>
);

const IconShield = (p) => (
  <IconBase {...p}>
    <path d="M12 2.8 5 5.6v5.6c0 4.4 2.9 7.6 7 9.9 4.1-2.3 7-5.5 7-9.9V5.6L12 2.8Z" />
    <path d="m8.8 11.8 2.4 2.4 4-4.4" />
  </IconBase>
);

const IconEye = (p) => (
  <IconBase {...p}>
    <path d="M2.6 12S6 5.9 12 5.9 21.4 12 21.4 12 18 18.1 12 18.1 2.6 12 2.6 12Z" />
    <circle cx="12" cy="12" r="2.8" />
  </IconBase>
);

const IconTray = (p) => (
  <IconBase {...p}>
    <path d="M3.4 13.6 5.6 4.8h12.8l2.2 8.8" />
    <path d="M3.4 13.6h5l1.2 2.4h4.8l1.2-2.4h5v5.6H3.4v-5.6Z" />
  </IconBase>
);

const IconFolder = (p) => (
  <IconBase {...p}>
    <path d="M3.2 7.2h6.2l1.8 2.2h9.6v9.4H3.2V7.2Z" />
    <path d="M3.2 7.2V5.4h4.6l1.4 1.8" />
  </IconBase>
);

const IconPin = (p) => (
  <IconBase {...p}>
    <path d="M9 3.4h6l-.8 5.2 3.2 3.2H6.6l3.2-3.2L9 3.4Z" />
    <path d="M12 11.8v8.8" />
  </IconBase>
);

const DEVICE_GLYPH = {
  desktop: IconLaptop,
  phone: IconPhone,
  tablet: IconTablet,
  server: IconServer,
};

Object.assign(window, {
  IconSignal,
  IconSend,
  IconClock,
  IconLaptop,
  IconPhone,
  IconStar,
  IconSearch,
  IconPlus,
  IconX,
  IconCheck,
  IconChevronRight,
  IconChevronDown,
  IconLink,
  IconDownload,
  IconArrowUp,
  IconArrowDown,
  IconShield,
  IconEye,
  IconTray,
  IconFolder,
  IconPin,
  IconSliders,
  DEVICE_GLYPH,
});
