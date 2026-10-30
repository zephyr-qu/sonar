/* ideas.jsx — 传输历史：三种换掉「长列表」的做法
   ① 拼贴相册 ② 双向时间轴 ③ 日历 */

const { useState: idUseState, useMemo: idUseMemo } = React;

const ID_TINT = {
  HEIC: "rgba(122, 162, 255, 0.18)",
  JPG: "rgba(122, 162, 255, 0.18)",
  PNG: "rgba(122, 162, 255, 0.18)",
  MOV: "rgba(255, 176, 32, 0.18)",
  M4A: "rgba(255, 176, 32, 0.16)",
  PDF: "rgba(242, 105, 94, 0.18)",
  DOCX: "rgba(242, 105, 94, 0.16)",
  ZIP: "rgba(198, 242, 78, 0.16)",
  FIG: "rgba(198, 242, 78, 0.16)",
  XLSX: "rgba(122, 242, 140, 0.16)",
};
const ID_IMG = ["HEIC", "JPG", "PNG"];

/* 没有真实图片时，用一组低明度渐变模拟照片墙，避免一整屏同样的色块 */
const ID_PHOTO = [
  "linear-gradient(145deg, hsl(214 48% 44% / 0.42), hsl(214 48% 26% / 0.18))",
  "linear-gradient(160deg, hsl(266 38% 46% / 0.36), hsl(266 38% 26% / 0.16))",
  "linear-gradient(135deg, hsl(182 36% 40% / 0.34), hsl(182 36% 24% / 0.15))",
  "linear-gradient(150deg, hsl(32 52% 42% / 0.34), hsl(32 52% 24% / 0.15))",
  "linear-gradient(140deg, hsl(92 34% 38% / 0.30), hsl(92 34% 22% / 0.13))",
  "linear-gradient(155deg, hsl(352 42% 44% / 0.32), hsl(352 42% 24% / 0.15))",
];

const idHash = (text) => {
  let h = 0;
  for (let i = 0; i < text.length; i += 1) h = (h * 31 + text.charCodeAt(i)) >>> 0;
  return h;
};

const ID_NOW = new Date(2026, 9, 30, 15, 41);

const IdDir = ({ dir }) => (
  <span className={"hx-dir" + (dir === "in" ? " is-in" : " is-out")}>
    {dir === "in" ? <IconArrowDown size={12} /> : <IconArrowUp size={12} />}
  </span>
);

const IdTile = ({ file, overlay }) => {
  const isPhoto = ID_IMG.indexOf(file.kind) !== -1;
  return (
    <div
      className={"id-tile" + (isPhoto ? " is-img" : "")}
      style={{ background: isPhoto ? ID_PHOTO[idHash(file.name) % ID_PHOTO.length] : ID_TINT[file.kind] || "var(--bg3)" }}
      title={file.name + " · " + fmtBytes(file.size)}
    >
      <span className="id-tile-kind">{file.kind}</span>
      {overlay ? <span className="id-more">{overlay}</span> : null}
    </div>
  );
};

const IdMosaic = ({ files, max, cols }) => {
  const limit = max || 8;
  const shown = files.slice(0, limit);
  const rest = files.length - shown.length;
  const n = Math.max(1, Math.min(shown.length, cols || 4));
  return (
    <div className="id-mosaic" style={{ gridTemplateColumns: "repeat(" + n + ", minmax(0, 1fr))" }}>
      {shown.map((file, index) => (
        <IdTile key={file.id} file={file} overlay={rest > 0 && index === shown.length - 1 ? "+" + rest : null} />
      ))}
    </div>
  );
};

const IdStack = ({ files }) => (
  <div className="id-stack">
    {files.slice(0, 3).map((file) => <IdTile key={file.id} file={file} />)}
  </div>
);

const IdRow = ({ file }) => (
  <button type="button" className="hx-frow" title={file.name}>
    <span className="hx-kind" style={{ width: 24, height: 24, fontSize: 8 }}>{file.kind}</span>
    <span className="grow"><span className="hx-fname">{file.name}</span></span>
    <span className="hx-fsize">{fmtBytes(file.size)}</span>
  </button>
);

const IdHeader = ({ data }) => (
  <div className="hdr">
    <div className="hdr-id">
      <div className="hdr-alias">传输</div>
      <div className="hdr-sub"><span>历史 {data.totalFiles} 项 · {data.sessions.length} 次</span></div>
    </div>
    <div className="hdr-actions">
      <IconBtn label="清空历史"><IconTray size={17} /></IconBtn>
      <IconBtn label="设置"><IconSliders size={17} /></IconBtn>
    </div>
  </div>
);

const IdTabBar = () => (
  <div className="tabbar">
    <button type="button" className="tab"><span className="tab-icon"><IconSignal size={18} /></span>附近</button>
    <button type="button" className="tab is-on"><span className="tab-icon"><IconClock size={18} /></span>传输</button>
  </div>
);

/* ---------------- 二级页面：一次传输的全部文件（三个方案共用） ---------------- */
const ID_GROUP = {
  HEIC: "图片",
  JPG: "图片",
  PNG: "图片",
  MOV: "视频",
  M4A: "音频",
  PDF: "文档",
  DOCX: "文档",
  MD: "文档",
  TXT: "文档",
  CSV: "文档",
  XLSX: "文档",
  ZIP: "压缩包",
  FIG: "其他",
};

const IdDetail = ({ session, onBack }) => {
  const [q, setQ] = idUseState("");
  const [view, setView] = idUseState("grid");
  const [group, setGroup] = idUseState("all");
  const [toast, setToast] = idUseState(null);
  const timer = React.useRef(null);

  const say = (text) => {
    setToast(text);
    clearTimeout(timer.current);
    timer.current = setTimeout(() => setToast(null), 1600);
  };

  const groups = idUseMemo(() => {
    const map = new Map();
    session.files.forEach((file) => {
      const name = ID_GROUP[file.kind] || "其他";
      map.set(name, (map.get(name) || 0) + 1);
    });
    return Array.from(map.entries());
  }, [session]);

  const needle = q.trim().toLowerCase();
  const files = session.files.filter((file) => {
    const name = ID_GROUP[file.kind] || "其他";
    if (group !== "all" && name !== group) return false;
    return !needle || file.name.toLowerCase().indexOf(needle) !== -1;
  });

  return (
    <div className="app id-detail">
      <div className="hdr">
        <button type="button" className="icon-btn" aria-label="返回" onClick={onBack}>
          <span style={{ display: "inline-block", transform: "rotate(180deg)" }}><IconChevronRight size={18} /></span>
        </button>
        <div className="hdr-id">
          <div className="hdr-alias">{session.dir === "in" ? "接收自 " : "发送到 "}{session.peer}</div>
          <div className="hdr-sub">
            <span>{session.time}</span>
            <span>·</span>
            <span>{session.files.length} 项</span>
            <span>·</span>
            <span>{fmtBytes(hxSum(session.files))}</span>
          </div>
        </div>
      </div>

      <div className="main">
        <div className="id-sum">
          <span className="chip is-accent">{session.note}</span>
          <span className="chip">{session.dir === "in" ? "收到" : "发出"}</span>
          <span className="chip">{session.files.length} 个文件</span>
        </div>

        <div className="hx-tools">
          <div className="search">
            <IconSearch size={14} />
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={"在这 " + session.files.length + " 项里搜索"} aria-label="搜索文件名" />
          </div>
          <div className="hx-chips">
            <button type="button" className={"hx-chip" + (group === "all" ? " is-on" : "")} onClick={() => setGroup("all")}>
              全部 {session.files.length}
            </button>
            {groups.map(([name, count]) => (
              <button key={name} type="button" className={"hx-chip" + (group === name ? " is-on" : "")} onClick={() => setGroup(name)}>
                {name} {count}
              </button>
            ))}
          </div>
        </div>

        {view === "grid" ? (
          <div className="id-detail-grid">
            {files.map((file) => <IdTile key={file.id} file={file} />)}
          </div>
        ) : (
          <div>{files.map((file) => <IdRow key={file.id} file={file} />)}</div>
        )}
        {files.length === 0 ? <p className="hx-empty">没有匹配的文件</p> : null}
      </div>

      <div className="id-detail-foot">
        <button type="button" className="btn btn-ghost" style={{ height: 34, padding: "0 12px", fontSize: 12 }} onClick={() => say("已在文件夹中打开")}>
          <IconFolder size={14} /> 打开文件夹
        </button>
        <span className="grow"></span>
        <span className="id-detail-hint">{files.length} / {session.files.length} 项</span>
        <div className="id-seg">
          <button type="button" className={view === "grid" ? "is-on" : ""} onClick={() => setView("grid")}>网格</button>
          <button type="button" className={view === "list" ? "is-on" : ""} onClick={() => setView("list")}>列表</button>
        </div>
      </div>

      {toast ? <div className="id-toast">{toast}</div> : null}
    </div>
  );
};

/* ---------------- ① 拼贴相册 ---------------- */
const IdScreenMosaic = ({ data, mainRef, open }) => {
  const [q, setQ] = idUseState("");
  const sessions = idUseMemo(() => hxFilter(data.sessions, q, "all"), [data, q]);

  return (
    <div className="app">
      <IdHeader data={data} />
      <div className="main" ref={mainRef}>
        <div className="hx-tools">
          <div className="search">
            <IconSearch size={14} />
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="搜索文件名" aria-label="搜索文件名" />
          </div>
        </div>
        {sessions.map((session) => (
          <div key={session.id} className={"id-card" + (session.files.length <= 2 ? " is-single" : "")} data-batch role="button" tabIndex={0} onClick={() => open(session)}>
            <div className="id-card-head">
              <IdDir dir={session.dir} />
              <span className="grow" style={{ minWidth: 0 }}>
                <span className="id-peer">{session.dir === "in" ? "接收自 " : "发送到 "}{session.peer}</span>
                <span className="id-meta">{session.files.length} 项 · {fmtBytes(hxSum(session.files))} · {session.time}</span>
              </span>
              <IconChevronRight size={14} className="chev" />
            </div>
            {session.files.length <= 2 ? (
              session.files.map((file) => (
                <div className="id-single-row" key={file.id}>
                  <IdTile file={file} />
                  <span className="grow" style={{ minWidth: 0 }}>
                    <span className="id-single-name">{file.name}</span>
                  </span>
                  <span className="id-single-size">{fmtBytes(file.size)}</span>
                </div>
              ))
            ) : (
              <IdMosaic files={session.files} max={8} />
            )}
          </div>
        ))}
        {sessions.length === 0 ? <p className="hx-empty">没有匹配的文件</p> : null}
      </div>
      <IdTabBar />
    </div>
  );
};

/* ---------------- ② 双向时间轴 ---------------- */
const idDayKey = (date) => date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate();

const idDayLabel = (date) => {
  if (idDayKey(date) === idDayKey(ID_NOW)) return "今天";
  const yesterday = new Date(ID_NOW.getFullYear(), ID_NOW.getMonth(), ID_NOW.getDate() - 1);
  if (idDayKey(date) === idDayKey(yesterday)) return "昨天";
  return (date.getMonth() + 1) + " 月 " + date.getDate() + " 日";
};

const idGroupByDay = (sessions) => {
  const map = new Map();
  sessions.forEach((session) => {
    const key = idDayKey(session.date);
    if (!map.has(key)) map.set(key, { key: key, label: idDayLabel(session.date), sessions: [] });
    map.get(key).sessions.push(session);
  });
  return Array.from(map.values());
};

const IdScreenTimeline = ({ data, mainRef, open }) => {
  const days = idUseMemo(() => idGroupByDay(data.sessions), [data]);

  return (
    <div className="app">
      <IdHeader data={data} />
      <div className="main" ref={mainRef}>
        <div className="tl">
          {days.map((day) => (
            <div key={day.key}>
              <div className="tl-label"><span>{day.label}</span></div>
              {day.sessions.map((session) => (
                <div key={session.id} className={"tl-row " + (session.dir === "in" ? "is-in" : "is-out")} data-batch>
                  <div className="tl-card" role="button" tabIndex={0} onClick={() => open(session)}>
                    <IdMosaic files={session.files} max={6} cols={3} />
                    <span className="tl-peer">{session.peer}</span>
                    <span className="tl-meta">{session.files.length} 项 · {fmtBytes(hxSum(session.files))} · {session.time.split(" ").slice(-1)[0]}</span>
                  </div>
                </div>
              ))}
            </div>
          ))}
        </div>
      </div>
      <IdTabBar />
    </div>
  );
};

/* ---------------- ③ 日历 ---------------- */
const ID_MONTHS = [
  { y: 2026, m: 8, label: "2026 年 9 月" },
  { y: 2026, m: 9, label: "2026 年 10 月" },
  { y: 2026, m: 10, label: "2026 年 11 月" },
];

const IdScreenCalendar = ({ data, mainRef, open }) => {
  const [mi, setMi] = idUseState(1);
  const [sel, setSel] = idUseState(30);
  const month = ID_MONTHS[mi];

  const byDay = idUseMemo(() => {
    const map = {};
    data.sessions.forEach((session) => {
      const key = idDayKey(session.date);
      map[key] = map[key] || { count: 0, size: 0, sessions: [] };
      map[key].count += session.files.length;
      map[key].size += hxSum(session.files);
      map[key].sessions.push(session);
    });
    return map;
  }, [data]);

  const first = new Date(month.y, month.m, 1);
  const offset = (first.getDay() + 6) % 7;
  const total = new Date(month.y, month.m + 1, 0).getDate();
  const cells = [];
  for (let i = 0; i < offset; i += 1) cells.push(null);
  for (let d = 1; d <= total; d += 1) cells.push(d);

  let maxCount = 0;
  cells.forEach((d) => {
    if (!d) return;
    const entry = byDay[month.y + "-" + (month.m + 1) + "-" + d];
    if (entry) maxCount = Math.max(maxCount, entry.count);
  });

  const selKey = month.y + "-" + (month.m + 1) + "-" + sel;
  const selEntry = byDay[selKey];

  return (
    <div className="app">
      <IdHeader data={data} />
      <div className="main" ref={mainRef}>
        <div className="cal">
          <div className="cal-head">
            <button type="button" className="icon-btn" aria-label="上个月" style={{ width: 26, height: 26 }} onClick={() => { setMi(Math.max(0, mi - 1)); setSel(null); }}>
              <span style={{ display: "inline-block", transform: "rotate(180deg)" }}><IconChevronRight size={13} /></span>
            </button>
            <span className="mon">{month.label}</span>
            <span className="grow"></span>
            <span className="num" style={{ fontSize: 9, color: "var(--faint)" }}>
              {Object.keys(byDay).filter((k) => k.indexOf(month.y + "-" + (month.m + 1) + "-") === 0).length} 天有传输
            </span>
            <button type="button" className="icon-btn" aria-label="下个月" style={{ width: 26, height: 26 }} onClick={() => { setMi(Math.min(ID_MONTHS.length - 1, mi + 1)); setSel(null); }}>
              <IconChevronRight size={13} />
            </button>
          </div>
          <div className="cal-week">
            {["一", "二", "三", "四", "五", "六", "日"].map((w) => <span key={w}>{w}</span>)}
          </div>
          <div className="cal-grid">
            {cells.map((d, i) => {
              if (!d) return <div key={"e" + i} className="cal-cell is-empty"></div>;
              const key = month.y + "-" + (month.m + 1) + "-" + d;
              const entry = byDay[key];
              const isToday = key === idDayKey(ID_NOW);
              return (
                <button
                  key={key}
                  type="button"
                  className={"cal-cell" + (sel === d ? " is-on" : "") + (isToday ? " is-today" : "")}
                  onClick={() => setSel(d)}
                >
                  <span className="cal-num">{d}</span>
                  <span className={"cal-bar" + (entry && entry.count === maxCount && maxCount > 0 ? " is-hot" : "")}
                    style={{ width: entry ? Math.max(3, Math.round((10 * entry.count) / maxCount)) : 4 }}></span>
                </button>
              );
            })}
          </div>
        </div>

        {selEntry ? (
          <React.Fragment>
            <div className="id-dayhead">
              <b>{month.m + 1} 月 {sel} 日</b>
              <span>{selEntry.sessions.length} 次传输 · {selEntry.count} 项 · {fmtBytes(selEntry.size)}</span>
            </div>
            {selEntry.sessions.map((session) => (
              <div key={session.id} className="id-mini" data-batch role="button" tabIndex={0} onClick={() => open(session)}>
                <IdStack files={session.files} />
                <span className="grow" style={{ minWidth: 0 }}>
                  <span className="id-peer">{session.dir === "in" ? "接收自 " : "发送到 "}{session.peer}</span>
                  <span className="id-meta">{session.files.length} 项 · {fmtBytes(hxSum(session.files))} · {session.time.split(" ").slice(-1)[0]}</span>
                </span>
                <IconChevronRight size={14} className="chev" />
              </div>
            ))}
          </React.Fragment>
        ) : (
          <p className="hx-empty">这一天没有传输</p>
        )}
      </div>
      <IdTabBar />
    </div>
  );
};

Object.assign(window, { IdDetail, IdScreenMosaic, IdScreenTimeline, IdScreenCalendar });
