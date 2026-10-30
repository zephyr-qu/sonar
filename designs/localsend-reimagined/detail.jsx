/* detail.jsx — 传输页：历史不折叠，点一行进二级页面 */

const { useState: dtUseState, useMemo: dtUseMemo, useRef: dtUseRef } = React;

const DT_TINT = {
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

const DT_GROUP = {
  HEIC: "图片", JPG: "图片", PNG: "图片",
  MOV: "视频", M4A: "音频",
  PDF: "文档", DOCX: "文档", MD: "文档", TXT: "文档", CSV: "文档", XLSX: "文档",
  ZIP: "压缩包", FIG: "其他",
};

const DT_IMG = ["HEIC", "JPG", "PNG"];

const DT_PHOTO = [
  "linear-gradient(145deg, hsl(214 48% 44% / 0.42), hsl(214 48% 26% / 0.18))",
  "linear-gradient(160deg, hsl(266 38% 46% / 0.36), hsl(266 38% 26% / 0.16))",
  "linear-gradient(135deg, hsl(182 36% 40% / 0.34), hsl(182 36% 24% / 0.15))",
  "linear-gradient(150deg, hsl(32 52% 42% / 0.34), hsl(32 52% 24% / 0.15))",
  "linear-gradient(140deg, hsl(92 34% 38% / 0.30), hsl(92 34% 22% / 0.13))",
  "linear-gradient(155deg, hsl(352 42% 44% / 0.32), hsl(352 42% 24% / 0.15))",
];

const dtHash = (text) => {
  let h = 0;
  for (let i = 0; i < text.length; i += 1) h = (h * 31 + text.charCodeAt(i)) >>> 0;
  return h;
};

const dtShort = (date) => {
  if (!date) return "—";
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  const hh = String(date.getHours()).padStart(2, "0");
  const mm = String(date.getMinutes()).padStart(2, "0");
  return m + "-" + d + " " + hh + ":" + mm;
};

const DT_SORTS = [
  { id: "date", label: "日期 ↓" },
  { id: "name", label: "名称 ↑" },
  { id: "size", label: "大小 ↓" },
];

const DtTile = ({ file }) => {
  const isPhoto = DT_IMG.indexOf(file.kind) !== -1;
  return (
    <div
      className={"id-tile" + (isPhoto ? " is-img" : "")}
      style={{ background: isPhoto ? DT_PHOTO[dtHash(file.name) % DT_PHOTO.length] : DT_TINT[file.kind] || "var(--bg3)" }}
      title={file.name + " · " + fmtBytes(file.size) + " · " + dtShort(file.modified)}
    >
      <span className="id-tile-kind">{file.kind}</span>
    </div>
  );
};

const DtRow = ({ file }) => (
  <button type="button" className="hx-frow" title={file.name}>
    <span className="hx-kind" style={{ width: 24, height: 24, fontSize: 8 }}>{file.kind}</span>
    <span className="grow"><span className="hx-fname">{file.name}</span></span>
    <span className="hx-fsize" style={{ color: "var(--faint)" }}>{dtShort(file.modified)}</span>
    <span className="hx-fsize">{fmtBytes(file.size)}</span>
  </button>
);

const DtHeader = ({ data }) => (
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

const DtTabBar = () => (
  <div className="tabbar">
    <button type="button" className="tab"><span className="tab-icon"><IconSignal size={18} /></span>附近</button>
    <button type="button" className="tab is-on"><span className="tab-icon"><IconClock size={18} /></span>传输</button>
  </div>
);

/* 按天分组：默认排序就是日期倒序，同一天内按时间倒序 */
const DT_TODAY = new Date(2026, 9, 30);

const dtDayKey = (date) => date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate();

const dtDayLabel = (date) => {
  if (dtDayKey(date) === dtDayKey(DT_TODAY)) return "今天";
  const yesterday = new Date(DT_TODAY.getFullYear(), DT_TODAY.getMonth(), DT_TODAY.getDate() - 1);
  if (dtDayKey(date) === dtDayKey(yesterday)) return "昨天";
  return (date.getMonth() + 1) + " 月 " + date.getDate() + " 日";
};

const dtGroupByDay = (sessions) => {
  const sorted = sessions.slice().sort((a, b) => b.date - a.date);
  const groups = [];
  sorted.forEach((session) => {
    const key = dtDayKey(session.date);
    const last = groups[groups.length - 1];
    if (last && last.key === key) {
      last.sessions.push(session);
    } else {
      groups.push({ key: key, label: dtDayLabel(session.date), sessions: [session] });
    }
  });
  return groups;
};

const dtClock = (label) => label.split(" ").slice(-1)[0];

/* ---------------- 列表：一行一次传输，不折叠 ---------------- */
const DtList = ({ data, onOpen, mainRef, bodyRef }) => {
  const days = dtGroupByDay(data.sessions);
  return (
    <div className="app">
      <DtHeader data={data} />
      <div className="main" ref={mainRef}>
        <div ref={bodyRef}>
          <div className="section-label" style={{ margin: "6px 0 2px" }}>
            <span>最近传输</span>
            <span className="count">{data.sessions.length}</span>
          </div>
          {days.map((day) => (
            <div key={day.key}>
              <div className="dt-day">{day.label}</div>
              {day.sessions.map((session) => (
                <button key={session.id} type="button" className="dt-row" data-row onClick={() => onOpen(session)}>
                  <span className={"dt-dir" + (session.dir === "in" ? " is-in" : " is-out")}>
                    {session.dir === "in" ? <IconArrowDown size={14} /> : <IconArrowUp size={14} />}
                  </span>
                  <span className="grow" style={{ minWidth: 0 }}>
                    <span className="dt-title">{session.dir === "in" ? "接收自 " : "发送到 "}{session.peer}</span>
                    <span className="dt-meta">
                      {session.files.length} 项 · {fmtBytes(hxSum(session.files))} · {session.note} · {dtClock(session.time)}
                    </span>
                  </span>
                  <IconChevronRight size={14} className="chev" />
                </button>
              ))}
            </div>
          ))}
          <p className="dt-hint">按日期倒序，最新的在最上面 · 点一行进入这次传输的页面</p>
        </div>
      </div>
      <DtTabBar />
    </div>
  );
};

/* 网格单元格：缩略图 + 文件名 —— 切到网格也不丢名字 */
const DtCell = ({ file }) => (
  <div className="dt-cell">
    <DtTile file={file} />
    <span className="dt-cell-name" title={file.name}>{file.name}</span>
  </div>
);

/* ---------------- 二级页面：一次传输的全部文件 ---------------- */
const DtDetail = ({ session, view, onView, onBack, mainRef }) => {
  const [q, setQ] = dtUseState("");
  const [group, setGroup] = dtUseState("all");
  const [sort, setSort] = dtUseState("date");
  const [toast, setToast] = dtUseState(null);
  const timer = dtUseRef(null);

  const say = (text) => {
    setToast(text);
    clearTimeout(timer.current);
    timer.current = setTimeout(() => setToast(null), 1600);
  };

  const groups = dtUseMemo(() => {
    const map = new Map();
    session.files.forEach((file) => {
      const name = DT_GROUP[file.kind] || "其他";
      map.set(name, (map.get(name) || 0) + 1);
    });
    return Array.from(map.entries());
  }, [session]);

  const needle = q.trim().toLowerCase();
  const files = session.files.filter((file) => {
    const name = DT_GROUP[file.kind] || "其他";
    if (group !== "all" && name !== group) return false;
    return !needle || file.name.toLowerCase().indexOf(needle) !== -1;
  });

  /* 默认按文件修改时间倒序：最近改动的排在最前，和相册的时间顺序一致 */
  const sorted = files.slice();
  if (sort === "date") sorted.sort((a, b) => b.modified - a.modified);
  else if (sort === "name") sorted.sort((a, b) => a.name.localeCompare(b.name, "zh-Hans-CN"));
  else sorted.sort((a, b) => b.size - a.size);

  return (
    <div className="app">
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

      <div className="main" ref={mainRef}>
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
            {sorted.map((file) => <DtCell key={file.id} file={file} />)}
          </div>
        ) : (
          <div>{sorted.map((file) => <DtRow key={file.id} file={file} />)}</div>
        )}
        {sorted.length === 0 ? <p className="hx-empty">没有匹配的文件</p> : null}
      </div>

      <div className="id-detail-foot">
        <button type="button" className="btn btn-ghost" style={{ height: 34, padding: "0 12px", fontSize: 12 }} onClick={() => say("已在文件夹中打开")}>
          <IconFolder size={14} /> 打开文件夹
        </button>
        <span className="grow"></span>
        <span className="id-detail-hint">{sorted.length} / {session.files.length}</span>
        <button
          type="button"
          className="dt-sort"
          title="切换排序"
          onClick={() => setSort(sort === "date" ? "name" : sort === "name" ? "size" : "date")}
        >
          排序 · {sort === "date" ? "日期 ↓" : sort === "name" ? "名称 ↑" : "大小 ↓"}
        </button>
        <div className="id-seg">
          <button type="button" className={view === "grid" ? "is-on" : ""} onClick={() => onView("grid")}>网格</button>
          <button type="button" className={view === "list" ? "is-on" : ""} onClick={() => onView("list")}>列表</button>
        </div>
      </div>

      {toast ? <div className="id-toast">{toast}</div> : null}
    </div>
  );
};

/* ---------------- 一台手机：列表 + 可推入的二级页面 ---------------- */
const DtPhone = ({ data, mode, onMeasure }) => {
  const listRef = dtUseRef(null);
  const bodyRef = dtUseRef(null);
  const detailRef = dtUseRef(null);
  const [detail, setDetail] = dtUseState(mode === "list" ? null : data.sessions[0]);
  /* 默认列表（名字最好找）；手动切换后，返回再进还记得 */
  const [view, setView] = dtUseState(mode === "grid" ? "grid" : "list");

  React.useEffect(() => {
    const timer = setTimeout(() => {
      onMeasure({
        list: bodyRef.current ? bodyRef.current.offsetHeight : 0,
        detail: detailRef.current ? detailRef.current.scrollHeight : 0,
      });
    }, 240);
    return () => clearTimeout(timer);
  }, [data.key, detail]);

  return (
    <div className="phone">
      <DtList data={data} onOpen={setDetail} mainRef={listRef} bodyRef={bodyRef} />
      {detail ? (
        <div className="id-page-layer">
          <DtDetail
            session={detail}
            view={view}
            onView={setView}
            onBack={() => setDetail(null)}
            mainRef={detailRef}
          />
        </div>
      ) : null}
    </div>
  );
};

Object.assign(window, { DtPhone });
