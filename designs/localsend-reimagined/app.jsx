/* app.jsx — 状态、动作、形态切换与挂载（方向 A · 信号） */

const { useState, useEffect, useRef } = React;

const Tweaks = ({ platform, setPlatform, layout, setLayout, onReceive, onHide }) => (
  <div className="tweaks">
    <span className="tweaks-label">形态</span>
    <div className="tgroup">
      <button type="button" className={"tbtn" + (platform === "phone" ? " is-on" : "")} onClick={() => setPlatform("phone")}>
        手机
      </button>
      <button type="button" className={"tbtn" + (platform === "desktop" ? " is-on" : "")} onClick={() => setPlatform("desktop")}>
        桌面
      </button>
    </div>
    <span className="divider"></span>
    <span className="tweaks-label">附近页</span>
    <div className="tgroup">
      <button type="button" className={"tbtn" + (layout === 0 ? " is-on" : "")} onClick={() => setLayout(0)}>
        多设备
      </button>
      <button type="button" className={"tbtn" + (layout === 1 ? " is-on" : "")} onClick={() => setLayout(1)}>
        雷达内嵌
      </button>
    </div>
    <span className="divider"></span>
    <button type="button" className="tbtn" onClick={onReceive}>模拟接收</button>
    <button type="button" className="tweaks-toggle" onClick={onHide} aria-label="隐藏控制条">×</button>
  </div>
);

const Studio = () => {
  const [platform, setPlatform] = useState("phone");
  const [showTweaks, setShowTweaks] = useState(true);
  const [screen, setScreen] = useState("near");
  const [lastMain, setLastMain] = useState("near");
  const [filter, setFilter] = useState("all");
  const [favorites, setFavorites] = useState(["mbp"]);
  const [picked, setPicked] = useState([]);
  const [files, setFiles] = useState(MOCK.files);
  const [alias, setAlias] = useState(MOCK.self.alias);
  const [flags, setFlags] = useState({
    visible: true,
    encryption: true,
    checksumOut: true,
    checksumIn: true,
    gallery: true,
    pin: false,
    historySave: true,
    animations: true,
  });
  const [segments, setSegments] = useState({ discovery: 0, theme: 0, quickSave: 1, accent: 0, layout: 1 });
  const [multi, setMulti] = useState(false);
  const [linkOpen, setLinkOpen] = useState(false);
  const [filesOpen, setFilesOpen] = useState(false);
  const [deviceQuery, setDeviceQuery] = useState("");
  const [settingsQuery, setSettingsQuery] = useState("");
  const [openGroup, setOpenGroup] = useState("receive");
  const [transfer, setTransfer] = useState({
    active: false,
    done: false,
    progress: 0,
    direction: "out",
    deviceId: null,
    targets: 1,
    files: [],
    speed: "0",
    eta: "--",
  });
  const [history, setHistory] = useState(MOCK.history);
  const [toast, setToast] = useState(null);
  const toastTimer = useRef(null);
  const pressTimer = useRef(null);

  const say = (msg) => {
    setToast(msg);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 2200);
  };

  useEffect(() => {
    if (!transfer.active || transfer.done) return undefined;
    const id = setInterval(() => {
      setTransfer((prev) => {
        if (!prev.active) return prev;
        const next = Math.min(1, prev.progress + 0.07);
        const done = next >= 1;
        return {
          ...prev,
          progress: next,
          done,
          active: !done,
          speed: done ? prev.speed : (16 + Math.random() * 4).toFixed(1),
          eta: done ? "00:00" : "00:" + String(Math.max(1, Math.round(42 * (1 - next)))).padStart(2, "0"),
        };
      });
    }, 380);
    return () => clearInterval(id);
  }, [transfer.active, transfer.done]);

  useEffect(() => {
    if (!transfer.done) return;
    const device = MOCK.devices.find((d) => d.id === transfer.deviceId);
    setHistory((prev) => [
      {
        id: "h" + Date.now(),
        dir: transfer.direction,
        device: device ? device.name : "未知设备",
        items: transfer.files.length,
        size: totalSize(transfer.files),
        time: "刚刚",
        note: transfer.direction === "out" ? "校验通过" : "已存入相册",
      },
      ...prev,
    ]);
  }, [transfer.done]);

  const startSend = (ids) => {
    const list = ids.filter(Boolean);
    if (files.length === 0) {
      say("先选择要发送的文件");
      return;
    }
    if (list.length === 0) {
      say("先选择目标设备");
      return;
    }
    setPicked(list);
    setMulti(false);
    setTransfer({
      active: true,
      done: false,
      progress: 0.03,
      direction: "out",
      deviceId: list[0],
      targets: list.length,
      files: files,
      speed: "18.4",
      eta: "00:41",
    });
    setScreen("transfer");
    say(list.length > 1 ? "开始发送到 " + list.length + " 台设备" : "开始发送 · " + files.length + " 项");
  };

  const act = {
    setScreen: (next) => {
      if (next === "near" || next === "transfer") setLastMain(next);
      setScreen(next);
    },
    setFilter,
    setVisible: (v) => setFlags((p) => ({ ...p, visible: v })),
    toggleFav: (id) => {
      setFavorites((p) => (p.includes(id) ? p.filter((x) => x !== id) : [...p, id]));
      say(favorites.includes(id) ? "已取消收藏" : "已加入收藏 · 快速接收将生效");
    },
    // 手机：有文件就直接发；桌面或多选模式：点一下是选中/取消
    tapDevice: (id) => {
      if (platform === "desktop" || multi) {
        setPicked((p) => (p.includes(id) ? p.filter((x) => x !== id) : [...p, id]));
        return;
      }
      startSend([id]);
    },
    pickDevice: (id) => setPicked((p) => (p.includes(id) ? p.filter((x) => x !== id) : [...p, id])),
    toggleMulti: () => {
      if (!multi) setFilesOpen(false); // 进入多选就收起托盘，把屏幕让给设备列表
      setMulti((m) => {
        if (m) setPicked([]);
        return !m;
      });
    },
    sendMulti: () => startSend(picked),
    openLink: () => setLinkOpen(true),
    closeLink: () => setLinkOpen(false),
    toggleFiles: () => setFilesOpen((v) => !v),
    closeFiles: () => setFilesOpen(false),
    pressStart: (id) => {
      clearTimeout(pressTimer.current);
      pressTimer.current = setTimeout(() => {
        setMulti(true);
        setPicked([id]);
        setFilesOpen(false);
        say("已进入多选 · 再点其他设备可加选");
      }, 500);
    },
    pressEnd: () => clearTimeout(pressTimer.current),
    copyLink: () => {
      try {
        navigator.clipboard.writeText(MOCK.link.url).catch(() => {});
      } catch (err) {
        /* 非安全上下文里没有剪贴板，原型只做提示 */
      }
      say("链接已复制 · PIN " + MOCK.link.pin);
    },
    removeFile: (id) => setFiles((p) => p.filter((f) => f.id !== id)),
    addFile: () => {
      setFiles((p) => [
        ...p,
        { id: "f" + Date.now(), name: "截图 2026-10-27 19.02.png", kind: "PNG", size: 1_240_000 },
      ]);
      say("已加入本次发送");
    },
    send: () => startSend(picked),
    quickSend: () => startSend(picked),
    accept: () => {
      setTransfer({
        active: true,
        done: false,
        progress: 0.03,
        direction: "in",
        deviceId: "pixel",
        targets: 1,
        files: MOCK.incoming.files,
        speed: "12.6",
        eta: "00:18",
      });
      setScreen("transfer");
      say("开始接收");
    },
    reject: () => {
      setScreen("near");
      say("已拒绝该请求");
    },
    cancel: () => {
      setTransfer((t) => ({ ...t, active: false, done: false, progress: 0 }));
      say("已取消传输");
    },
    resetTransfer: () =>
      setTransfer({ active: false, done: false, progress: 0, direction: "out", deviceId: null, targets: 1, files: [], speed: "0", eta: "--" }),
    openFolder: () => say("已在文件管理器中打开 Downloads/LocalSend"),
    flag: (key, value) => {
      setFlags((p) => ({ ...p, [key]: value }));
      if (key === "visible") say(value ? "对本网络可见" : "已隐藏，仅链接可接收");
    },
    segment: (key, index) => setSegments((p) => ({ ...p, [key]: index })),
    alias: setAlias,
    settingsQuery: setSettingsQuery,
    deviceQuery: setDeviceQuery,
    openGroup: setOpenGroup,
    manual: () => say("手动发送需要对方 IP:端口"),
    offlineTap: () => say("该设备当前离线 · 无法发送"),
    link: () => say("链接接收已开启 · PIN 4821"),
    noop: () => say("原型中未实现"),
  };

  const s = {
    platform,
    screen,
    lastMain,
    filter,
    favorites,
    picked,
    files,
    alias,
    flags,
    segments,
    multi,
    linkOpen,
    filesOpen,
    deviceQuery,
    settingsQuery,
    openGroup,
    transfer,
    history,
    visible: flags.visible,
    devices: MOCK.devices,
  };

  return (
    <div className="studio">
      {platform === "phone" ? (
        <div className="phone">
          {screen === "transfer" ? <TransferScreen s={s} act={act} /> : null}
          {screen === "receive" ? <ReceiveScreen s={s} act={act} /> : null}
          {screen === "settings" ? <SettingsScreen s={s} act={act} /> : null}
          {screen === "near" ? <NearScreen s={s} act={act} /> : null}
          {linkOpen ? <LinkSheet s={s} act={act} /> : null}
          <Toast text={toast} />
        </div>
      ) : (
        <DesktopApp s={s} act={act} />
      )}

      {showTweaks ? (
        <Tweaks
          platform={platform}
          setPlatform={setPlatform}
          layout={segments.layout}
          setLayout={(i) => setSegments((p) => ({ ...p, layout: i }))}
          onReceive={() => setScreen("receive")}
          onHide={() => setShowTweaks(false)}
        />
      ) : (
        <button type="button" className="tweaks" onClick={() => setShowTweaks(true)}>
          <span className="tweaks-label">显示控制</span>
        </button>
      )}
    </div>
  );
};

ReactDOM.createRoot(document.getElementById("root")).render(<Studio />);
