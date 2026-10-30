/* desktop.jsx — 桌面版：左侧 rail + 设备面 + 右侧托盘/传输栏（方向 A · 信号） */

const DesktopRail = ({ s, act }) => (
  <div className="rail">
    <div className="hdr-mark" style={{ marginBottom: 10 }}>
      <IconSignal size={16} />
    </div>
    <button type="button" className={"rail-btn" + (s.screen === "near" ? " is-on" : "")} onClick={() => act.setScreen("near")}>
      <IconSignal size={17} />
      附近
    </button>
    <button type="button" className={"rail-btn" + (s.screen === "transfer" ? " is-on" : "")} onClick={() => act.setScreen("transfer")}>
      <IconClock size={17} />
      传输
    </button>
    <div className="rail-spacer"></div>
    <button type="button" className={"rail-btn" + (s.screen === "settings" ? " is-on" : "")} onClick={() => act.setScreen("settings")}>
      <IconSliders size={17} />
      设置
    </button>
  </div>
);

const DesktopHeader = ({ s, act }) => (
  <div className="win-hdr">
    <div className="hdr-mark"><IconPhone size={15} /></div>
    <div className="stack" style={{ minWidth: 0 }}>
      <span style={{ fontSize: 14, fontWeight: 600 }}>{s.alias}</span>
      <span className="hdr-sub">
        <span className={"dot" + (s.visible ? "" : " is-off")}></span>
        {MOCK.self.network} · {MOCK.self.ip}:{MOCK.self.port}
      </span>
    </div>
    <div className="row gap-8" style={{ marginLeft: "auto" }}>
      <Chip accent={s.flags.encryption}>{s.flags.encryption ? "已加密" : "明文"}</Chip>
      <Chip>协议 {MOCK.self.protocol}</Chip>
      <span className="row gap-8" style={{ marginLeft: 6 }}>
        <span className="setrow-value">{s.visible ? "可见" : "隐藏"}</span>
        <Switch on={s.visible} onChange={(v) => act.setVisible(v)} label="对本网络可见" />
      </span>
    </div>
  </div>
);

/* A · 信号：设备卡 */
const DesktopNearSignal = ({ s, list, act }) => (
  <React.Fragment>
    <h2 className="win-title">附近的设备</h2>
    <p className="screen-lede" style={{ margin: "6px 0 0" }}>{list.filter((d) => d.online).length} 台在线 · 点卡片选择目标，右侧托盘确认后发送</p>
    <div className="devgrid">
      {list.map((d) => (
        <button
          key={d.id}
          type="button"
          className={"devcard" + (s.picked.includes(d.id) ? " is-selected" : "")}
          onClick={() => act.pickDevice(d.id)}
          style={{ opacity: d.online ? 1 : 0.6 }}
        >
          <div className="row" style={{ justifyContent: "space-between" }}>
            <span className="dev-glyph"><DeviceGlyph type={d.type} size={18} /></span>
            <span
              role="button"
              tabIndex={0}
              className={"star" + (s.favorites.includes(d.id) ? " is-on" : "")}
              aria-label="收藏"
              onClick={(e) => { e.stopPropagation(); act.toggleFav(d.id); }}
            >
              <IconStar size={16} filled={s.favorites.includes(d.id)} />
            </span>
          </div>
          <div className="devcard-name">{d.name}</div>
          <div className="devcard-meta">
            {d.online ? "在线 · " + d.rtt + " ms" : "离线"}<br />
            {d.ip} · {d.last}
          </div>
        </button>
      ))}
    </div>
  </React.Fragment>
);

const DesktopTransfer = ({ s, act }) => {
  const t = s.transfer;
  const device = t.deviceId ? s.devices.find((d) => d.id === t.deviceId) : null;
  return (
    <React.Fragment>
      <h2 className="win-title">传输</h2>
      {t.active || t.done ? (
        <div className="card" style={{ marginTop: 16, padding: 18 }}>
          <div className="row" style={{ marginBottom: 14 }}>
            <span className="dev-glyph">{t.done ? <IconCheck size={17} /> : <DeviceGlyph type={device ? device.type : "desktop"} size={17} />}</span>
            <span className="grow">
              <span className="dev-name" style={{ display: "block" }}>
                {(t.done ? (t.direction === "out" ? "已发送到 " : "已接收自 ") : t.direction === "out" ? "发送到 " : "接收自 ") + (t.targets > 1 ? t.targets + " 台设备" : device ? device.name : "")}
              </span>
              <span className="dev-meta">
                <span>{t.files.length} 项 · {fmtBytes(totalSize(t.files))}</span>
                <span className="sep">·</span>
                <span>{t.done ? "完成" : t.speed + " MB/s · 剩余 " + t.eta}</span>
              </span>
            </span>
            {t.done ? <Chip accent><IconShield size={12} /> 校验通过</Chip> : null}
          </div>
          <Bar value={t.progress} />
          <div style={{ marginTop: 14 }}>
            {t.files.map((f) => <FileRow key={f.id} file={f} progress={t.done ? 1 : Math.min(1, t.progress * 1.15)} />)}
          </div>
          <div className="row gap-10" style={{ marginTop: 14 }}>
            {t.done ? (
              <React.Fragment>
                <button type="button" className="btn btn-ghost grow" onClick={act.openFolder}><IconFolder size={15} /> 打开文件夹</button>
                <button type="button" className="btn btn-primary grow" onClick={act.resetTransfer}>完成</button>
              </React.Fragment>
            ) : (
              <button type="button" className="btn btn-ghost btn-block" onClick={act.cancel}>取消传输</button>
            )}
          </div>
        </div>
      ) : (
        <p className="screen-lede" style={{ marginTop: 12 }}>当前没有进行中的传输。</p>
      )}

      <SectionLabel count={s.history.length + " 条"}>最近的传输</SectionLabel>
      <div>
        {s.history.map((h) => (
          <div key={h.id} className="filerow" style={{ padding: "12px 0" }}>
            <span className="filerow-glyph" style={{ color: h.dir === "in" ? "var(--accent)" : "var(--muted)" }}>
              {h.dir === "in" ? <IconArrowDown size={14} /> : <IconArrowUp size={14} />}
            </span>
            <span className="grow">
              <span className="filerow-name" style={{ display: "block" }}>{h.device} · {h.items} 项</span>
              <span className="filerow-meta">{fmtBytes(h.size)} · {h.note}</span>
            </span>
            <span className="num" style={{ fontSize: 10, color: "var(--faint)" }}>{h.time}</span>
          </div>
        ))}
      </div>
    </React.Fragment>
  );
};

const DesktopSettings = ({ s, act }) => (
  <React.Fragment>
    <h2 className="win-title">设置</h2>
    <p className="screen-lede" style={{ margin: "6px 0 14px" }}>
      5 组 · 重排后的信息架构：可见性 / 接收 / 安全与传输 / 外观 / 高级
    </p>
    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))", gap: "0 32px" }}>
      {MOCK.settings.map((g) => (
        <div className="group" key={g.id} style={{ paddingBottom: 10 }}>
          <div style={{ padding: "14px 0 6px" }}>
            <div className="group-title">{g.title}</div>
            <div className="group-sub">{g.summary}</div>
          </div>
          <div className="group-body" style={{ paddingBottom: 6 }}>
            {g.rows.map((row) => <SettingRow key={row.key} row={row} s={s} act={act} />)}
          </div>
        </div>
      ))}
    </div>
  </React.Fragment>
);

const DesktopAside = ({ s, act }) => {
  const t = s.transfer;
  return (
    <div className="win-aside">
      <SectionLabel count={fmtBytes(totalSize(s.files))}>托盘</SectionLabel>
      {s.files.length === 0 ? (
        <button type="button" className="dropzone" onClick={act.addFile}>
          <span className="row gap-8"><IconPlus size={16} /> 拖放文件到这里</span>
          <span className="filerow-meta">或点击选择文件 / 文件夹</span>
        </button>
      ) : (
        <div>
          {s.files.map((f) => <FileRow key={f.id} file={f} onRemove={act.removeFile} />)}
          <button type="button" className="link-row" onClick={act.addFile}>
            <IconPlus size={15} /><span className="grow">添加文件</span>
          </button>
          <div className="row gap-10" style={{ marginTop: 12 }}>
            <button type="button" className="btn btn-primary grow" onClick={act.quickSend}>
              <IconSend size={15} /> 发送
            </button>
          </div>
          <p className="setrow-desc" style={{ marginTop: 10 }}>
            目标：{s.picked.length === 0 ? "未选择（点左侧设备卡）" : s.picked.map((id) => (s.devices.find((d) => d.id === id) || {}).name).join("、")}
          </p>
        </div>
      )}

      <SectionLabel>进行中</SectionLabel>
      {t.active ? (
        <div className="stack gap-8">
          <div className="row" style={{ justifyContent: "space-between" }}>
            <span className="filerow-name">{t.direction === "out" ? "发送" : "接收"} · {(s.devices.find((d) => d.id === t.deviceId) || {}).name}</span>
            <span className="num" style={{ fontSize: 10, color: "var(--muted)" }}>{Math.round(t.progress * 100)}%</span>
          </div>
          <Bar value={t.progress} />
          <span className="filerow-meta">{t.speed} MB/s · 剩余 {t.eta}</span>
          <button type="button" className="btn btn-ghost" style={{ height: 34 }} onClick={act.cancel}>取消</button>
        </div>
      ) : (
        <p className="setrow-desc">空闲</p>
      )}

      <SectionLabel>接收策略</SectionLabel>
      <p className="setrow-desc" style={{ marginTop: 0 }}>
        快速保存：{["关闭", "仅收藏", "全部"][s.segments.quickSave]} · 保存到 Downloads/LocalSend
      </p>
      <button type="button" className="link-row" style={{ marginTop: 8 }} onClick={() => act.setScreen("settings")}>
        <IconShield size={15} /><span className="grow">加密与 PIN 设置</span>
        <IconChevronRight size={14} className="chev" />
      </button>
    </div>
  );
};

const DesktopFooterActions = ({ act }) => (
  <div className="row gap-10" style={{ marginTop: 24 }}>
    <button type="button" className="btn btn-ghost" onClick={act.manual}>
      <IconPin size={15} /> 手动发送
    </button>
    <button type="button" className="btn btn-ghost" onClick={act.link}>
      <IconLink size={15} /> 通过链接接收
    </button>
    <span className="setrow-desc" style={{ marginLeft: "auto" }}>拖放文件到右侧托盘即可开始</span>
  </div>
);

const DesktopApp = ({ s, act }) => {
  const list = visibleDevices(s);
  return (
    <div className="win">
      <DesktopRail s={s} act={act} />
      <div className="win-main">
        <DesktopHeader s={s} act={act} />
        <div className="win-body">
          <div className="win-content">
            {s.screen === "near" ? <DesktopNearSignal s={s} list={list} act={act} /> : null}
            {s.screen === "transfer" ? <DesktopTransfer s={s} act={act} /> : null}
            {s.screen === "near" ? <DesktopFooterActions act={act} /> : null}
            {s.screen === "settings" ? <DesktopSettings s={s} act={act} /> : null}
          </div>
          {s.screen !== "settings" ? <DesktopAside s={s} act={act} /> : null}
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { DesktopApp });
