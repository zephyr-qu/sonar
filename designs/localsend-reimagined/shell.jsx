/* shell.jsx — 共用原子组件（无状态，props 进 / 回调出） */

const Switch = ({ on, onChange, label }) => (
  <button
    type="button"
    className={"sw" + (on ? " is-on" : "")}
    role="switch"
    aria-checked={on}
    aria-label={label}
    onClick={() => onChange(!on)}
  ></button>
);

const Segmented = ({ options, index, onChange }) => (
  <div className="seg" role="tablist">
    {options.map((o, i) => (
      <button
        key={o}
        type="button"
        role="tab"
        aria-selected={i === index}
        className={i === index ? "is-on" : ""}
        onClick={() => onChange(i)}
      >
        {o}
      </button>
    ))}
  </div>
);

const IconBtn = ({ label, active, onClick, children }) => (
  <button
    type="button"
    className={"icon-btn" + (active ? " is-active" : "")}
    aria-label={label}
    title={label}
    onClick={onClick}
  >
    {children}
  </button>
);

const Chip = ({ children, accent }) => (
  <span className={"chip" + (accent ? " is-accent" : "")}>{children}</span>
);

const Bar = ({ value }) => (
  <div className="bar" role="progressbar" aria-valuenow={Math.round(value * 100)} aria-valuemin="0" aria-valuemax="100">
    <i style={{ width: Math.max(0, Math.min(1, value)) * 100 + "%" }}></i>
  </div>
);

const DeviceGlyph = ({ type, size = 18 }) => {
  const Glyph = DEVICE_GLYPH[type] || IconLaptop;
  return <Glyph size={size} />;
};

const FileRow = ({ file, onRemove, trailing, progress }) => (
  <div className="filerow">
    <div className="filerow-glyph">{file.kind}</div>
    <div className="grow">
      <div className="filerow-name">{file.name}</div>
      <div className="filerow-meta">
        {fmtBytes(file.size)}
        {progress != null ? " · " + Math.round(progress * 100) + "%" : ""}
      </div>
    </div>
    {onRemove ? (
      <button type="button" className="icon-btn" aria-label={"移除 " + file.name} onClick={() => onRemove(file.id)}>
        <IconX size={15} />
      </button>
    ) : null}
    {trailing}
  </div>
);

const SectionLabel = ({ children, count }) => (
  <div className="section-label">
    <span>{children}</span>
    {count != null ? <span className="count">{count}</span> : null}
  </div>
);

const SubHeader = ({ title, sub, onBack, right }) => (
  <div className="hdr">
    <button type="button" className="icon-btn" aria-label="返回" onClick={onBack}>
      <span style={{ display: "inline-block", transform: "rotate(180deg)" }}>
        <IconChevronRight size={18} />
      </span>
    </button>
    <div className="hdr-id">
      <div className="hdr-alias">{title}</div>
      {sub ? <div className="hdr-sub">{sub}</div> : null}
    </div>
    <div className="hdr-actions">{right}</div>
  </div>
);

const Toast = ({ text }) => (text ? <div className="toast">{text}</div> : null);

const Stat = ({ label, value }) => (
  <div className="stack gap-4">
    <span className="eyebrow">{label}</span>
    <span className="num" style={{ fontSize: 15 }}>{value}</span>
  </div>
);

Object.assign(window, {
  Switch,
  Segmented,
  IconBtn,
  Chip,
  Bar,
  DeviceGlyph,
  FileRow,
  SectionLabel,
  SubHeader,
  Toast,
  Stat,
});
