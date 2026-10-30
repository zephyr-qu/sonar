/* screens.jsx — 手机端五块屏：附近 / 发送 / 传输 / 接收 / 设置（方向 A · 信号） */

const { useRef, useState, useEffect } = React;

const NearHeader = ({ s, act }) => (
  <div className="hdr">
    <div className="hdr-mark">
      <IconSignal size={17} />
    </div>
    <div className="hdr-id">
      <div className="hdr-alias">{MOCK.self.alias}</div>
      <div className="hdr-sub">
        <span className={"dot" + (s.visible ? "" : " is-off")}></span>
        <span>{s.visible ? "可见" : "已隐藏"}</span>
        <span>·</span>
        <span>{MOCK.self.ip}</span>
      </div>
    </div>
    <div className="hdr-actions">
      <IconBtn label={s.visible ? "对网络隐藏" : "对网络可见"} active={s.visible} onClick={() => act.setVisible(!s.visible)}>
        <IconEye size={17} />
      </IconBtn>
      <IconBtn label="设置" onClick={() => act.setScreen("settings")}>
        <IconSliders size={17} />
      </IconBtn>
    </div>
  </div>
);

const visibleDevices = (s) =>
  s.devices.filter((d) => (s.filter === "fav" ? s.favorites.includes(d.id) : s.filter === "online" ? d.online : true));

const FilterLinks = ({ filter, setFilter }) => (
  <div className="row gap-10" style={{ marginBottom: 6 }}>
    {[
      { id: "all", label: "全部" },
      { id: "online", label: "在线" },
      { id: "fav", label: "收藏" },
    ].map((it) => (
      <button
        key={it.id}
        type="button"
        className={"chip" + (filter === it.id ? " is-accent" : "")}
        onClick={() => setFilter(it.id)}
      >
        {it.label}
      </button>
    ))}
  </div>
);

const NearScreen = ({ s, act }) => (
  <div className="app">
    <NearHeader s={s} act={act} />
    {s.segments.layout === 1 ? <NearRadar s={s} act={act} /> : <NearMany s={s} act={act} />}
    <MultiBar s={s} act={act} />
    <TabBar s={s} act={act} />
  </div>
);

/* 文件宫格：内联托盘与「雷达内嵌」布局共用 */
const KIND_TINT = {
  HEIC: "rgba(122, 162, 255, 0.18)",
  JPG: "rgba(122, 162, 255, 0.18)",
  PNG: "rgba(122, 162, 255, 0.18)",
  FIG: "rgba(198, 242, 78, 0.16)",
  PDF: "rgba(242, 105, 94, 0.18)",
  M4A: "rgba(255, 176, 32, 0.18)",
};
const IMAGE_KINDS = ["HEIC", "JPG", "PNG"];

const FileTiles = ({ s, act }) => (
  <div className="tray-grid">
    {s.files.map((f) => (
      <div className="tile" key={f.id}>
        <div
          className={"tile-thumb" + (IMAGE_KINDS.includes(f.kind) ? " is-image" : "")}
          style={{ background: KIND_TINT[f.kind] || "var(--bg3)" }}
          title={f.name + " · " + fmtBytes(f.size)}
        >
          {f.kind}
        </div>
        <div className="tile-name" title={f.name}>{f.name}</div>
        <button
          type="button"
          className="tile-x"
          aria-label={"移除 " + f.name}
          onClick={() => act.removeFile(f.id)}
        >
          <IconX size={11} />
        </button>
      </div>
    ))}
    <button type="button" className="tile tile-add" onClick={act.addFile}>
      <span className="tile-thumb"><IconPlus size={18} /></span>
      <span className="tile-name">添加文件</span>
    </button>
  </div>
);

/* 内联文件托盘：高度封顶 + 内部滚动，不把设备列表顶出屏幕 */
const InlineTray = ({ s, act }) => (
  <div className="tray-inline">
    <div className="tray-head row">
      <span className="eyebrow">待发送 · {s.files.length} 项 · {fmtBytes(totalSize(s.files))}</span>
      <span className="grow"></span>
      <button type="button" className="chip" onClick={act.openLink}>链接</button>
      <button type="button" className="chip" onClick={act.closeFiles}>收起</button>
    </div>
    <FileTiles s={s} act={act} />
  </div>
);

/* 「雷达内嵌」布局：设备全放进雷达，下方整块给文件 */
const NearRadar = ({ s, act }) => {
  const list = visibleDevices(s);
  const allOnline = list.filter((d) => d.online);
  const allOffline = list.filter((d) => !d.online);
  const online = allOnline.slice(0, 5);
  const offline = allOffline.slice(0, 1);
  const hidden = allOnline.length - online.length + (allOffline.length - offline.length);
  return (
    <div className={"main" + (s.multi ? " has-action" : "")}>
      <div className="row" style={{ marginBottom: 6 }}>
        <span className="eyebrow">{MOCK.self.network}</span>
        <span className="grow"></span>
        <span className="num" style={{ fontSize: 10, color: "var(--faint)" }}>
          {allOnline.length} / {s.devices.length} 在线{hidden ? " · 雷达显示 " + (online.length + offline.length) + " 台" : ""}
        </span>
      </div>

      <div className="row" style={{ marginBottom: 6 }}>
        <FilterLinks filter={s.filter} setFilter={act.setFilter} />
        <span className="grow"></span>
        <button type="button" className="chip" onClick={act.manual}>手动 IP</button>
        <button type="button" className="chip" onClick={act.link}>链接接收</button>
        <button
          type="button"
          className={"chip" + (s.multi ? " is-accent" : "")}
          aria-pressed={s.multi}
          onClick={act.toggleMulti}
        >
          {s.multi ? "多选中" : "多选"}
        </button>
      </div>

      <div className="radar radar-xl">
        <div className="radar-ring r1"></div>
        <div className="radar-ring r2"></div>
        <div className="radar-ring r3"></div>
        <div className="radar-sweep"></div>
        <button
          type="button"
          className="radar-self is-xl"
          aria-label={s.files.length ? "待发送 " + s.files.length + " 项" : "添加文件"}
          onClick={act.addFile}
        >
          <IconPhone size={24} />
          {s.files.length ? (
            <span className="radar-self-badge num">{s.files.length}</span>
          ) : (
            <span className="radar-self-plus"><IconPlus size={12} /></span>
          )}
        </button>

        {online.map((d, i) => {
          const rad = ((-90 + (360 / online.length) * i) * Math.PI) / 180;
          const r = 108 + (i % 2) * 22;
          const x = Math.cos(rad) * r;
          const y = Math.sin(rad) * r;
          return (
            <button
              key={d.id}
              type="button"
              className={"radar-peer is-lg" + (s.picked.includes(d.id) ? " is-selected" : "")}
              style={{ left: "calc(50% + " + x + "px)", top: "calc(50% + " + y + "px)" }}
              onClick={() => act.tapDevice(d.id)}
              onPointerDown={() => act.pressStart(d.id)}
              onPointerUp={act.pressEnd}
              onPointerLeave={act.pressEnd}
              title={d.name}
            >
              <DeviceGlyph type={d.type} size={18} />
              <span className={"peer-label" + (i % 2 ? " is-up" : "")}>{d.name}</span>
            </button>
          );
        })}

        {offline.map((d) => {
          const rad = (215 * Math.PI) / 180;
          return (
            <button
              key={d.id}
              type="button"
              className="radar-peer is-lg is-offline"
              style={{ left: "calc(50% + " + Math.cos(rad) * 150 + "px)", top: "calc(50% + " + Math.sin(rad) * 150 + "px)" }}
              onClick={act.offlineTap}
              title={d.name + " · 离线"}
            >
              <DeviceGlyph type={d.type} size={18} />
              <span className="peer-label is-up">{d.name}</span>
            </button>
          );
        })}
      </div>

      <div className="files-section">
        <div className="row" style={{ marginBottom: 8 }}>
          <span className="eyebrow">待发送 · {s.files.length} 项 · {fmtBytes(totalSize(s.files))}</span>
          <span className="grow"></span>
          <button type="button" className="chip" onClick={act.openLink}>链接</button>
        </div>
        <FileTiles s={s} act={act} />
      </div>
    </div>
  );
};

const MultiBar = ({ s, act }) => {
  if (!s.multi) return null;
  const n = s.picked.length;
  return (
    <div className="actionbar">
      <span className="grow" style={{ minWidth: 0 }}>
        <span className="dev-name" style={{ display: "block" }}>
          {n === 0 ? "选择目标设备" : n + " 台已选"}
        </span>
        <span className="filerow-meta">{s.files.length} 项 · {fmtBytes(totalSize(s.files))}</span>
      </span>
      <button
        type="button"
        className="btn btn-primary"
        disabled={n === 0 || s.files.length === 0}
        onClick={act.sendMulti}
      >
        <IconSend size={15} />
        发送
      </button>
    </div>
  );
};

/* ---------------- 链接面板 ---------------- */
const LinkSheet = ({ s, act }) => (
  <div className="sheet-wrap" onClick={act.closeLink}>
    <div className="sheet" role="dialog" aria-modal="true" aria-label="通过链接发送" onClick={(e) => e.stopPropagation()}>
      <div className="grabber"></div>

      <div className="row" style={{ marginBottom: 14 }}>
        <span className="grow">
          <span className="eyebrow">链接发送 · {s.files.length} 项 · {fmtBytes(totalSize(s.files))}</span>
          <div className="sheet-title">通过链接发送</div>
        </span>
        <IconBtn label="关闭" onClick={act.closeLink}><IconX size={16} /></IconBtn>
      </div>

      <div className="linkbox">
        <span className="num grow" style={{ fontSize: 11.5, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {MOCK.link.url}
        </span>
        <button type="button" className="chip is-accent" onClick={act.copyLink}>复制</button>
      </div>

      <div className="setrow" style={{ padding: "12px 0", borderTop: "1px solid var(--line)", marginTop: 12 }}>
        <div className="grow">
          <div className="setrow-label">要求 PIN</div>
          <div className="setrow-desc">接收方打开链接后需输入 4 位 PIN</div>
        </div>
        <span
          className="num"
          style={{ fontSize: 14, marginRight: 10, color: s.flags.pin ? "var(--accent)" : "var(--faint)" }}
        >
          {s.flags.pin ? MOCK.link.pin : "----"}
        </span>
        <Switch on={s.flags.pin} onChange={(v) => act.flag("pin", v)} label="要求 PIN" />
      </div>

      <div className="setrow" style={{ padding: "12px 0", borderTop: "1px solid var(--line)" }}>
        <div className="grow">
          <div className="setrow-label">加密链接</div>
          <div className="setrow-desc">自签证书，浏览器需接受一次</div>
        </div>
        <Chip accent={s.flags.encryption}>{s.flags.encryption ? "HTTPS" : "HTTP"}</Chip>
      </div>

      <p className="shell-hint" style={{ marginTop: 6 }}>
        下载请求 {MOCK.link.requests} 个 · 传输完成后链接失效
      </p>

      <div className="sheet-cta">
        <button
          type="button"
          className="btn btn-primary btn-block"
          disabled={s.files.length === 0}
          onClick={act.copyLink}
        >
          <IconSend size={16} />
          复制链接
        </button>
      </div>
    </div>
  </div>
);

/* ---------------- 传输：进度 + 历史 ---------------- */
const TransferScreen = ({ s, act }) => {
  const t = s.transfer;
  const device = t.deviceId ? s.devices.find((d) => d.id === t.deviceId) : null;

  return (
    <div className="app">
      <div className="hdr">
        <div className="hdr-id">
          <div className="hdr-alias">传输</div>
          <div className="hdr-sub">{t.active ? "1 个进行中" : "历史 " + s.history.length + " 条"}</div>
        </div>
        <div className="hdr-actions">
          <IconBtn label="设置" onClick={() => act.setScreen("settings")}><IconSliders size={17} /></IconBtn>
        </div>
      </div>

      <div className="main">
        {t.active || t.done ? (
          <div className="card" style={{ padding: 16 }}>
            <div className="row" style={{ marginBottom: 12, alignItems: "flex-start" }}>
              <span className="dev-glyph">
                {t.done ? <IconCheck size={17} /> : <DeviceGlyph type={device ? device.type : "desktop"} size={17} />}
              </span>
              <span className="grow" style={{ minWidth: 0 }}>
                <span className="dev-name" style={{ display: "block" }}>
                  {(t.done ? (t.direction === "out" ? "已发送到 " : "已接收自 ") : t.direction === "out" ? "发送到 " : "接收自 ") + (t.targets > 1 ? t.targets + " 台设备" : device ? device.name : "")}
                </span>
                <span className="dev-meta">
                  <span>{t.files.length} 项</span>
                  <span className="sep">·</span>
                  <span>{fmtBytes(totalSize(t.files))}</span>
                  <span className="sep">·</span>
                  <span>{t.done ? "完成" : t.speed + " MB/s"}</span>
                </span>
              </span>
              {t.done ? (
                <Chip accent><IconShield size={12} /> 校验通过</Chip>
              ) : (
                <span className="num" style={{ fontSize: 11, color: "var(--muted)" }}>剩余 {t.eta}</span>
              )}
            </div>

            <Bar value={t.progress} />
            <div className="row" style={{ justifyContent: "space-between", marginTop: 8 }}>
              <span className="num" style={{ fontSize: 10, color: "var(--muted)" }}>{Math.round(t.progress * 100)}%</span>
              <span className="num" style={{ fontSize: 10, color: "var(--muted)" }}>
                {fmtBytes(totalSize(t.files) * t.progress)} / {fmtBytes(totalSize(t.files))}
              </span>
            </div>

            <div style={{ marginTop: 12 }}>
              {t.files.map((f) => (
                <FileRow key={f.id} file={f} progress={t.done ? 1 : Math.min(1, t.progress * 1.15)} />
              ))}
            </div>

            <div className="row gap-10" style={{ marginTop: 14 }}>
              {t.done ? (
                <React.Fragment>
                  <button type="button" className="btn btn-ghost grow" onClick={act.openFolder}>
                    <IconFolder size={15} /> 打开文件夹
                  </button>
                  <button type="button" className="btn btn-primary grow" onClick={act.resetTransfer}>完成</button>
                </React.Fragment>
              ) : (
                <button type="button" className="btn btn-ghost btn-block" onClick={act.cancel}>取消传输</button>
              )}
            </div>
          </div>
        ) : (
          <div className="card" style={{ textAlign: "center", padding: "26px 16px" }}>
            <div className="num" style={{ fontSize: 11, color: "var(--muted)", letterSpacing: "0.08em" }}>NO ACTIVE TRANSFER</div>
            <p className="screen-lede" style={{ margin: "8px 0 0" }}>从「附近」选一台设备开始，或在收到请求时点「接收」。</p>
          </div>
        )}

        <SectionLabel count={s.history.length + " 条"}>最近的传输</SectionLabel>
        <div>
          {s.history.map((h) => (
            <div key={h.id} className="filerow" style={{ padding: "11px 0" }}>
              <span className="filerow-glyph" style={{ color: h.dir === "in" ? "var(--accent)" : "var(--muted)" }}>
                {h.dir === "in" ? <IconArrowDown size={14} /> : <IconArrowUp size={14} />}
              </span>
              <span className="grow" style={{ minWidth: 0 }}>
                <span className="filerow-name" style={{ display: "block" }}>{h.device} · {h.items} 项</span>
                <span className="filerow-meta">{fmtBytes(h.size)} · {h.note}</span>
              </span>
              <span className="num" style={{ fontSize: 10, color: "var(--faint)" }}>{h.time}</span>
            </div>
          ))}
        </div>
      </div>

      <TabBar s={s} act={act} />
    </div>
  );
};

/* ---------------- 接收：请求 ---------------- */
const ReceiveScreen = ({ s, act }) => {
  const inc = MOCK.incoming;
  const policy =
    s.segments.quickSave === 2
      ? "已开启快速保存 · 自动接收"
      : s.segments.quickSave === 1
      ? "收藏设备自动接收"
      : "每个请求都询问";

  return (
    <div className="app">
      <SubHeader
        title="接收请求"
        sub={policy}
        onBack={() => act.setScreen("near")}
        right={<Chip accent><IconShield size={12} /> 已加密</Chip>}
      />
      <div className="main">
        <div className="row gap-12" style={{ margin: "6px 0 18px" }}>
          <span className="dev-glyph" style={{ width: 44, height: 44 }}>
            <DeviceGlyph type="phone" size={20} />
          </span>
          <span className="grow">
            <span style={{ fontSize: 17, fontFamily: "var(--font-display)", fontWeight: "var(--display-weight)", display: "block" }}>
              {inc.name}
            </span>
            <span className="dev-meta" style={{ marginTop: 4 }}><span>{inc.os}</span></span>
          </span>
        </div>

        <div className="row gap-8" style={{ marginBottom: 12 }}>
          <Chip>{inc.files.length} 个文件</Chip>
          <Chip>{fmtBytes(totalSize(inc.files))}</Chip>
          <Chip>协议 {MOCK.self.protocol}</Chip>
        </div>

        <div className="card" style={{ padding: "4px 14px" }}>
          {inc.files.map((f) => (
            <FileRow key={f.id} file={f} />
          ))}
        </div>

        <div className="setrow" style={{ marginTop: 14 }}>
          <div className="grow">
            <div className="setrow-label">保存到</div>
            <div className="setrow-desc">Downloads/LocalSend · 图片同时存入相册</div>
          </div>
          <button type="button" className="setrow-value" onClick={() => act.setScreen("settings")}>更改</button>
        </div>

        <SectionLabel>连接</SectionLabel>
        <div className="card" style={{ padding: "4px 14px" }}>
          <div className="setrow">
            <div className="grow">
              <div className="setrow-label">设备指纹</div>
              <div className="setrow-desc">SHA-256 · 与上次会话一致</div>
            </div>
            <span className="setrow-value">e3:9a:4c:…:d1:4f</span>
          </div>
          <div className="setrow">
            <div className="grow">
              <div className="setrow-label">传输通道</div>
              <div className="setrow-desc">v2 HTTP · 双向 TLS</div>
            </div>
            <span className="setrow-value">同一局域网</span>
          </div>
        </div>

        <p className="shell-hint" style={{ marginTop: 10 }}>快速保存：{policy}</p>
      </div>

      <div className="row gap-10" style={{ padding: "10px var(--pad) calc(14px + env(safe-area-inset-bottom, 0px))", borderTop: "1px solid var(--line)" }}>
        <button type="button" className="btn btn-ghost" style={{ flex: "0 0 36%" }} onClick={act.reject}>拒绝</button>
        <button type="button" className="btn btn-primary grow" onClick={act.accept}>
          <IconDownload size={16} /> 接收 {inc.files.length} 项
        </button>
      </div>
    </div>
  );
};

/* ---------------- 设置：5 组信息架构 ---------------- */
const SettingRow = ({ row, s, act }) => {
  if (row.type === "switch") {
    return (
      <div className="setrow">
        <div className="grow">
          <div className="setrow-label">{row.label}</div>
          {row.desc ? <div className="setrow-desc">{row.desc}</div> : null}
        </div>
        <Switch on={!!s.flags[row.key]} onChange={(v) => act.flag(row.key, v)} label={row.label} />
      </div>
    );
  }
  if (row.type === "segment") {
    return (
      <div className="stack gap-8" style={{ padding: "9px 0" }}>
        <div>
          <div className="setrow-label">{row.label}</div>
          {row.desc ? <div className="setrow-desc">{row.desc}</div> : null}
        </div>
        <Segmented
          options={row.options}
          index={s.segments[row.key] != null ? s.segments[row.key] : row.index || 0}
          onChange={(i) => act.segment(row.key, i)}
        />
      </div>
    );
  }
  if (row.type === "text") {
    return (
      <div className="stack gap-6" style={{ padding: "9px 0" }}>
        <div className="setrow-label">{row.label}</div>
        <input className="input" value={s.alias} onChange={(e) => act.alias(e.target.value)} aria-label={row.label} />
        {row.desc ? <div className="setrow-desc">{row.desc}</div> : null}
      </div>
    );
  }
  if (row.type === "swatch") {
    const colors = ["#c6f24e", "#ffb020", "#7aa2ff", "#f2695e", "#8a8f98"];
    return (
      <div className="setrow">
        <div className="grow"><div className="setrow-label">{row.label}</div></div>
        <div className="swatches">
          {colors.map((c, i) => (
            <button
              key={c}
              type="button"
              aria-label={"强调色 " + (i + 1)}
              className={"swatch" + (i === s.segments.accent ? " is-on" : "")}
              style={{ background: c }}
              onClick={() => act.segment("accent", i)}
            ></button>
          ))}
        </div>
      </div>
    );
  }
  if (row.type === "link") {
    return (
      <button type="button" className="setrow" style={{ width: "100%", textAlign: "left" }} onClick={act.noop}>
        <div className="grow setrow-label">{row.label}</div>
        {row.value ? <span className="setrow-value">{row.value}</span> : null}
        <IconChevronRight size={14} className="chev" />
      </button>
    );
  }
  return (
    <div className="setrow">
      <div className="grow setrow-label">{row.label}</div>
      <span className="setrow-value">{row.value}</span>
    </div>
  );
};

const SettingsScreen = ({ s, act }) => {
  const q = s.settingsQuery.trim();
  const totalRows = MOCK.settings.reduce((n, g) => n + g.rows.length, 0);
  const groups = MOCK.settings
    .map((g) => ({
      ...g,
      rows: q ? g.rows.filter((r) => (r.label + " " + (r.desc || "")).includes(q)) : g.rows,
    }))
    .filter((g) => (q ? g.rows.length > 0 : true));

  return (
    <div className="app">
      <SubHeader
        title="设置"
        sub={s.flags.visible ? "对网络可见" : "已隐藏"}
        onBack={() => act.setScreen(s.lastMain || "near")}
        right={<IconBtn label="搜索设置"><IconSearch size={17} /></IconBtn>}
      />
      <div className="main">
        <div className="search" style={{ marginBottom: 8 }}>
          <IconSearch size={14} />
          <input
            value={s.settingsQuery}
            onChange={(e) => act.settingsQuery(e.target.value)}
            placeholder={"搜索设置项（共 " + totalRows + " 项）"}
            aria-label="搜索设置项"
          />
        </div>

        {groups.map((g) => {
          const open = s.openGroup === g.id || !!q;
          return (
            <div className="group" key={g.id}>
              <button type="button" className="group-head" onClick={() => act.openGroup(open && !q ? null : g.id)}>
                <div className="grow">
                  <div className="group-title">{g.title}</div>
                  <div className="group-sub">{g.summary} · {g.rows.length} 项</div>
                </div>
                <span style={{ display: "inline-block", transform: open ? "rotate(180deg)" : "none", color: "var(--faint)" }}>
                  <IconChevronDown size={16} />
                </span>
              </button>
              {open ? (
                <div className="group-body">
                  {g.rows.map((row) => (
                    <SettingRow key={row.key} row={row} s={s} act={act} />
                  ))}
                </div>
              ) : null}
            </div>
          );
        })}

        {groups.length === 0 ? (
          <p className="shell-hint">没有匹配「{q}」的设置项。</p>
        ) : null}

        <div className="shell-hint" style={{ marginTop: 18 }}>
          LocalSend · 协议 {MOCK.self.protocol} · 端口 {MOCK.self.port}
          {"\n"}关于 · 贡献者 · 开源许可
        </div>
      </div>
    </div>
  );
};

/* ---------------- 底部导航：附近 / 传输 ---------------- */
const TabBar = ({ s, act }) => (
  <div className="tabbar">
    <button type="button" className={"tab" + (s.screen === "near" ? " is-on" : "")} onClick={() => act.setScreen("near")}>
      <span className="tab-icon"><IconSignal size={18} /></span>
      附近
    </button>
    <button type="button" className={"tab" + (s.screen === "transfer" ? " is-on" : "")} onClick={() => act.setScreen("transfer")}>
      <span className="tab-icon"><IconClock size={18} /></span>
      传输
    </button>
  </div>
);

/* 「多设备」布局：搜索 + 分节双列网格 */
const DeviceCard2 = ({ d, s, act }) => (
  <div className={"dev2" + (s.picked.includes(d.id) ? " is-selected" : "") + (d.online ? "" : " is-offline")}>
    <button
      type="button"
      className="dev2-main"
      onClick={() => act.tapDevice(d.id)}
      onPointerDown={() => act.pressStart(d.id)}
      onPointerUp={act.pressEnd}
      onPointerLeave={act.pressEnd}
      title={d.name}
    >
      <span className="dev2-glyph"><DeviceGlyph type={d.type} size={16} /></span>
      <span className="dev2-id">
        <span className="dev2-name">{d.name}</span>
        <span className="dev2-meta">{d.online ? d.rtt + " ms" : "离线"} · {d.last}</span>
      </span>
    </button>
    {s.multi ? (
      <span className="dev2-check">
        {s.picked.includes(d.id) ? <IconCheck size={14} /> : <span className="num">[ ]</span>}
      </span>
    ) : (
      <button
        type="button"
        className={"dev2-star" + (s.favorites.includes(d.id) ? " is-on" : "")}
        aria-label="收藏"
        onClick={() => act.toggleFav(d.id)}
      >
        <IconStar size={13} filled={s.favorites.includes(d.id)} />
      </button>
    )}
  </div>
);

const NearMany = ({ s, act }) => {
  const list = visibleDevices(s);
  const q = (s.deviceQuery || "").trim().toLowerCase();
  const matched = q ? list.filter((d) => (d.name + " " + d.ip).toLowerCase().includes(q)) : list;
  const favs = matched.filter((d) => s.favorites.includes(d.id));
  const online = matched.filter((d) => d.online && !s.favorites.includes(d.id));
  const offline = matched.filter((d) => !d.online && !s.favorites.includes(d.id));
  const onlineCount = s.devices.filter((d) => d.online).length;
  const card = (d) => <DeviceCard2 key={d.id} d={d} s={s} act={act} />;

  return (
    <div className={"main" + (s.multi ? " has-action" : "")}>
      <div className="mini-radar">
        <span className="mini-dot"></span>
        <span className="num mini-count">{onlineCount}</span>
        <span className="mini-label">台在线 · 已发现 {s.devices.length} 台</span>
        <span className="grow"></span>
        <button type="button" className="chip" onClick={act.link}>链接接收</button>
        <button type="button" className="chip" onClick={act.manual}>手动 IP</button>
      </div>

      {s.files.length ? (
        s.filesOpen ? (
          <div style={{ marginTop: 10 }}>
            <InlineTray s={s} act={act} />
          </div>
        ) : (
          <button type="button" className="filebar" onClick={act.toggleFiles}>
            <IconTray size={15} />
            <span className="grow" style={{ textAlign: "left" }}>
              待发送 · {s.files.length} 项 · {fmtBytes(totalSize(s.files))}
            </span>
            <span className="num" style={{ fontSize: 10, color: "var(--faint)" }}>展开</span>
          </button>
        )
      ) : null}

      <div className="search" style={{ marginTop: 12 }}>
        <IconSearch size={14} />
        <input
          value={s.deviceQuery}
          onChange={(e) => act.deviceQuery(e.target.value)}
          placeholder="搜索设备名或 IP"
          aria-label="搜索设备"
        />
      </div>

      <div className="row" style={{ margin: "10px 0 2px" }}>
        <FilterLinks filter={s.filter} setFilter={act.setFilter} />
        <span className="grow"></span>
        <button
          type="button"
          className={"chip" + (s.multi ? " is-accent" : "")}
          aria-pressed={s.multi}
          onClick={act.toggleMulti}
        >
          {s.multi ? "多选中" : "多选"}
        </button>
      </div>

      {favs.length ? (
        <React.Fragment>
          <div className="sec-title">收藏 · {favs.length}</div>
          <div className={"devgrid2" + (favs.length === 1 ? " is-single" : "")}>{favs.map(card)}</div>
        </React.Fragment>
      ) : null}

      <div className="sec-title">在线 · {online.length}</div>
      {online.length ? (
        <div className="devgrid2">{online.map(card)}</div>
      ) : (
        <p className="setrow-desc" style={{ margin: "4px 0 0" }}>没有匹配的在线设备</p>
      )}

      {offline.length ? (
        <React.Fragment>
          <div className="sec-title">离线 · {offline.length}</div>
          <div className="devgrid2">{offline.map(card)}</div>
        </React.Fragment>
      ) : null}
    </div>
  );
};

Object.assign(window, {
  NearHeader,
  NearScreen,
  InlineTray,
  MultiBar,
  LinkSheet,
  TransferScreen,
  ReceiveScreen,
  SettingsScreen,
  SettingRow,
  TabBar,
  visibleDevices,
});
