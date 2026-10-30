/* history-screens.jsx — 三种「不折叠」的最近传输列表（手机端）
   A 全展开 / B 密度自适应 / C 封顶内滚 + 全屏查看 */

const { useState: hxUseState, useMemo: hxUseMemo } = React;

/* ---------------- 共用零件 ---------------- */

const HxTabBar = () => (
  <div className="tabbar">
    <button type="button" className="tab">
      <span className="tab-icon"><IconSignal size={18} /></span>
      附近
    </button>
    <button type="button" className="tab is-on">
      <span className="tab-icon"><IconClock size={18} /></span>
      传输
    </button>
  </div>
);

const HxHeader = ({ data }) => (
  <div className="hdr">
    <div className="hdr-id">
      <div className="hdr-alias">传输</div>
      <div className="hdr-sub">
        <span>历史 {data.totalFiles} 项 · {data.sessions.length} 次</span>
      </div>
    </div>
    <div className="hdr-actions">
      <IconBtn label="清空历史"><IconTray size={17} /></IconBtn>
      <IconBtn label="设置"><IconSliders size={17} /></IconBtn>
    </div>
  </div>
);

const HxTools = ({ q, setQ, filter, setFilter, shown }) => (
  <div className="hx-tools">
    <div className="search">
      <IconSearch size={14} />
      <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="搜索文件名" aria-label="搜索文件名" />
    </div>
    <div className="hx-chips" role="tablist" aria-label="筛选">
      {[
        { id: "all", label: "全部 " + shown },
        { id: "in", label: "收到" },
        { id: "out", label: "发出" },
      ].map((it) => (
        <button
          key={it.id}
          type="button"
          role="tab"
          aria-selected={filter === it.id}
          className={"hx-chip" + (filter === it.id ? " is-on" : "")}
          onClick={() => setFilter(it.id)}
        >
          {it.label}
        </button>
      ))}
    </div>
  </div>
);

const HxDir = ({ dir }) => (
  <span className={"hx-dir" + (dir === "in" ? " is-in" : " is-out")}>
    {dir === "in" ? <IconArrowDown size={12} /> : <IconArrowUp size={12} />}
  </span>
);

const HxKind = ({ kind, size }) => (
  <span className="hx-kind" style={{ width: size, height: size, fontSize: size >= 24 ? 8 : 7.5 }}>{kind}</span>
);

const HxRowFull = ({ file }) => (
  <button type="button" className="hx-frow" title={file.name}>
    <HxKind kind={file.kind} size={24} />
    <span className="grow"><span className="hx-fname">{file.name}</span></span>
    <span className="hx-fsize">{fmtBytes(file.size)}</span>
  </button>
);

const HxRowCompact = ({ file }) => (
  <button type="button" className="hx-crow" title={file.name}>
    <span className="hx-dot"></span>
    <span className="grow"><span className="hx-fname">{file.name}</span></span>
    <span className="hx-fsize">{fmtBytes(file.size)}</span>
  </button>
);

const HxMini = ({ file }) => (
  <button type="button" className="hx-mini" title={file.name}>
    <span className="hx-mini-name">{file.name}</span>
    <span className="hx-mini-size">{fmtBytes(file.size)}</span>
  </button>
);

const HxSessionMeta = ({ session, files }) => (
  <span className="grow" style={{ minWidth: 0 }}>
    <span className="hx-gname">{session.dir === "in" ? "接收自 " : "发送到 "}{session.peer}</span>
    <span className="hx-gmeta">
      {files.length} 项 · {fmtBytes(hxSum(files))} · {session.time}
    </span>
  </span>
);

/* ---------------- A：全展开 ---------------- */
const ScreenA = ({ data, mainRef }) => {
  const [q, setQ] = hxUseState("");
  const [filter, setFilter] = hxUseState("all");
  const sessions = hxUseMemo(() => hxFilter(data.sessions, q, filter), [data, q, filter]);
  const shown = sessions.reduce((n, s) => n + s.files.length, 0);

  return (
    <div className="app">
      <HxHeader data={data} />
      <div className="main" ref={mainRef}>
        <HxTools q={q} setQ={setQ} filter={filter} setFilter={setFilter} shown={shown} />
        {sessions.map((session) => (
          <section key={session.id}>
            <div className="hx-group">
              <HxDir dir={session.dir} />
              <HxSessionMeta session={session} files={session.files} />
            </div>
            <div className="hx-files">
              {session.files.map((file) => <HxRowFull key={file.id} file={file} />)}
            </div>
          </section>
        ))}
        {sessions.length === 0 ? <p className="hx-empty">没有匹配的文件</p> : null}
      </div>
      <HxTabBar />
    </div>
  );
};

/* ---------------- B：密度自适应 ---------------- */
const hxDensity = (count) => (count > 30 ? "grid" : count > 6 ? "compact" : "full");

const ScreenB = ({ data, mainRef }) => {
  const [q, setQ] = hxUseState("");
  const [filter, setFilter] = hxUseState("all");
  const sessions = hxUseMemo(() => hxFilter(data.sessions, q, filter), [data, q, filter]);
  const shown = sessions.reduce((n, s) => n + s.files.length, 0);

  return (
    <div className="app">
      <HxHeader data={data} />
      <div className="main" ref={mainRef}>
        <HxTools q={q} setQ={setQ} filter={filter} setFilter={setFilter} shown={shown} />
        {sessions.map((session) => {
          const mode = hxDensity(session.files.length);
          return (
            <article key={session.id} className="hx-card">
              <div className="hx-card-head">
                <HxDir dir={session.dir} />
                <HxSessionMeta session={session} files={session.files} />
                {mode !== "full" ? <span className="hx-mode">{mode === "grid" ? "宫格 2 列" : "紧凑行"}</span> : null}
              </div>
              <div className="hx-card-body">
                {mode === "full" ? session.files.map((file) => <HxRowFull key={file.id} file={file} />) : null}
                {mode === "compact" ? session.files.map((file) => <HxRowCompact key={file.id} file={file} />) : null}
                {mode === "grid" ? (
                  <div className="hx-mini-grid">
                    {session.files.map((file) => <HxMini key={file.id} file={file} />)}
                  </div>
                ) : null}
              </div>
            </article>
          );
        })}
        {sessions.length === 0 ? <p className="hx-empty">没有匹配的文件</p> : null}
      </div>
      <HxTabBar />
    </div>
  );
};

/* ---------------- C：封顶内滚 + 全屏查看 ---------------- */
const HxSheet = ({ session, onClose }) => {
  const [q, setQ] = hxUseState("");
  const files = q ? session.files.filter((f) => f.name.toLowerCase().indexOf(q.trim().toLowerCase()) !== -1) : session.files;

  return (
    <div className="sheet-wrap" onClick={onClose}>
      <div className="sheet" role="dialog" aria-modal="true" aria-label="全部文件" onClick={(e) => e.stopPropagation()}>
        <div className="grabber"></div>
        <div className="hx-sheet-head">
          <span className="grow" style={{ minWidth: 0 }}>
            <span className="eyebrow">本次传输 · {session.time}</span>
            <div className="sheet-title">{session.peer}</div>
          </span>
          <IconBtn label="关闭" onClick={onClose}><IconX size={16} /></IconBtn>
        </div>
        <div className="search" style={{ marginBottom: 8 }}>
          <IconSearch size={14} />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={"在这 " + session.files.length + " 项中搜索"} aria-label="搜索文件" />
        </div>
        <div className="hx-sheet-list">
          {files.map((file) => <HxRowFull key={file.id} file={file} />)}
          {files.length === 0 ? <p className="hx-empty">没有匹配的文件</p> : null}
        </div>
        <div className="hx-sheet-foot">
          {files.length} / {session.files.length} 项 · {fmtBytes(hxSum(files))}
        </div>
      </div>
    </div>
  );
};

const ScreenC = ({ data, mainRef }) => {
  const [q, setQ] = hxUseState("");
  const [filter, setFilter] = hxUseState("all");
  const [sheet, setSheet] = hxUseState(null);
  const sessions = hxUseMemo(() => hxFilter(data.sessions, q, filter), [data, q, filter]);
  const shown = sessions.reduce((n, s) => n + s.files.length, 0);

  return (
    <div className="app">
      <HxHeader data={data} />
      <div className="main" ref={mainRef}>
        <HxTools q={q} setQ={setQ} filter={filter} setFilter={setFilter} shown={shown} />
        {sessions.map((session) => {
          const capped = session.files.length > 6;
          return (
            <article key={session.id} className="hx-card">
              <div className="hx-card-head">
                <HxDir dir={session.dir} />
                <HxSessionMeta session={session} files={session.files} />
              </div>
              <div className={"hx-card-body" + (capped ? " is-capped" : "")}>
                {session.files.map((file) => <HxRowFull key={file.id} file={file} />)}
              </div>
              {capped ? (
                <div className="hx-card-foot">
                  <button type="button" className="hx-more" onClick={() => setSheet(session)}>
                    <IconTray size={13} /> 查看全部 {session.files.length} 项
                  </button>
                </div>
              ) : null}
            </article>
          );
        })}
        {sessions.length === 0 ? <p className="hx-empty">没有匹配的文件</p> : null}
      </div>
      <HxTabBar />
      {sheet ? <HxSheet session={sheet} onClose={() => setSheet(null)} /> : null}
    </div>
  );
};

Object.assign(window, { ScreenA, ScreenB, ScreenC });
