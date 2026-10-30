/* history-app.jsx — 方案对比页：三台手机 + 实测列表高度 + 说明 */

const { useState: appUseState, useRef: appUseRef, useEffect: appUseEffect } = React;

const HX_VARIANTS = [
  {
    id: "a",
    tag: "A",
    title: "全展开",
    badge: "照字面",
    sub: "每次传输常显，文件全部按完整行列出。只有滚动，没有折叠。",
    screen: () => ScreenA,
    notes: [
      ["留住", "传输分组、先后顺序和每个文件，一眼到底"],
      ["代价", "列表长度 = 文件数，165 项要滚 8 屏"],
      ["适合", "单次文件少（≤ 10）、主要用来「看记录」"],
    ],
  },
  {
    id: "b",
    tag: "B",
    title: "密度自适应",
    badge: "推荐",
    sub: "同样常显不折叠，但行密度跟着文件数走：多就变小，不藏起来。",
    screen: () => ScreenB,
    notes: [
      ["规则", "≤ 6 全行 · 7–30 紧凑行 · > 30 双列宫格"],
      ["效果", "128 项从 128 行压到 64 行，长度减半"],
      ["代价", "文件极多时，名字仍然是主要信息"],
    ],
  },
  {
    id: "c",
    tag: "C",
    title: "封顶 + 全屏查看",
    badge: "页面最短",
    sub: "每次传输的文件区固定高度、区内滚动，不折叠；要看全就进全屏列表。",
    screen: () => ScreenC,
    notes: [
      ["规则", "> 6 项时文件区封顶 118px，可内滚"],
      ["兜底", "「查看全部」进全屏，带独立搜索"],
      ["代价", "手机上是嵌套滚动，手感要多调"],
    ],
  },
];

const HxColumn = ({ variant, data }) => {
  const mainRef = appUseRef(null);
  const [m, setM] = appUseState({ h: 0, view: 1 });

  appUseEffect(() => {
    const measure = () => {
      const el = mainRef.current;
      if (!el) return;
      setM({ h: el.scrollHeight, view: el.clientHeight || 1 });
    };
    const raf = requestAnimationFrame(measure);
    const timer = setTimeout(measure, 260);
    return () => {
      cancelAnimationFrame(raf);
      clearTimeout(timer);
    };
  }, [data.key, variant.id]);

  const Screen = variant.screen();
  const screens = m.h / m.view;
  const tone = screens > 5 ? "var(--danger)" : screens > 2.4 ? "var(--fg)" : "var(--accent)";

  return (
    <div className="hx-col">
      <div className="hx-col-head">
        <span className="hx-tag">{variant.tag}</span>
        <h2 className="hx-col-title">{variant.title}</h2>
        <span className="hx-col-badge">{variant.badge}</span>
      </div>
      <p className="hx-col-sub">{variant.sub}</p>

      <div className="phone">
        <Screen data={data} mainRef={mainRef} />
      </div>

      <div className="hx-metrics">
        <div className="hx-metric">
          <span className="k">列表高度（实测）</span>
          <span className="v">{m.h.toLocaleString("en-US")} px</span>
        </div>
        <div className="hx-metric">
          <span className="k">要滚几屏</span>
          <span className="v" style={{ color: tone }}>{screens.toFixed(1)} 屏</span>
        </div>
      </div>

      <ul className="hx-notes-list">
        {variant.notes.map((n) => (
          <li key={n[0]}><b>{n[0]}</b> · {n[1]}</li>
        ))}
      </ul>
    </div>
  );
};

const HxPage = () => {
  const [scenario, setScenario] = appUseState("heavy");
  const data = HX_DATA[scenario];

  return (
    <div className="studio hx-page">
      <div className="hx-wrap">
        <header className="hx-head">
          <div className="hx-kicker">LocalSend · 传输页 · 最近传输</div>
          <h1 className="hx-title">不折叠，文件很多时怎么办</h1>
          <p className="hx-lede">
            现在每次传输折叠成一行，点开才看得到文件。下面三种做法都<strong>不折叠</strong>，区别只在「文件很多时怎么排」。
            同一份数据：<b>1 次 128 个文件的传输 + 7 次小传输，共 165 项</b>；每台手机里的列表高度是真实渲染后量出来的。
            手机可以直接滚动、搜索、筛选，C 还能点「查看全部」。
          </p>
          <div className="hx-scenario">
            <span className="lbl">数据量</span>
            <div className="hx-seg">
              <button type="button" className={scenario === "heavy" ? "is-on" : ""} onClick={() => setScenario("heavy")}>
                大量 · 165 项
              </button>
              <button type="button" className={scenario === "light" ? "is-on" : ""} onClick={() => setScenario("light")}>
                普通 · 9 项
              </button>
            </div>
            <span className="lbl" style={{ marginLeft: 6 }}>切到「普通」看三者其实一样——差别只在文件多的时候才出现</span>
          </div>
        </header>

        <div className="hx-rack">
          {HX_VARIANTS.map((variant) => (
            <HxColumn key={variant.id} variant={variant} data={data} />
          ))}
        </div>

        <footer className="hx-foot">
          <div>
            <h3>比列表怎么排更关键：两个数据层问题</h3>
            <ol>
              <li>
                历史是<b>按文件</b>存的，每个方向上限 <code>_maxHistoryEntries = 30</code>。
                一次 128 个文件的传输会写 128 条，结果是：<b>更早的历史全被挤掉，这次传输自己也只剩 30 条</b>。
                「文件很多」真正先炸的是这里，不是 UI。
              </li>
              <li>
                分组键是「方向 + 设备 + <b>分钟</b>」，同一批文件跨分钟到达会被拆成好几次传输。
                现在的折叠行因此并不总是「一次传输」。
              </li>
              <li>
                建议改成<b>按会话存</b>：一条历史 = 一次传输（peer、时间、状态、文件列表），上限按<b>会话数</b>算（比如 50 次）。
                文件列表可以只存元数据，点开再取路径。
              </li>
            </ol>
          </div>

          <div>
            <h3>我的建议</h3>
            <div className="hx-pick">
              <p>
                默认用 <span className="accent">B</span>：传输常显、组头吸顶，文件按数量换密度。
                用户永远不用「先点开」，但也不会被一次 500 个文件铺满屏幕。
              </p>
              <p>
                单次超过 ~40 项时，<b>自动退到 C 的封顶 + 全屏查看</b>（C 的全屏列表就是 B 的宫格放大版，同一套渲染）。
                <span className="accent">A</span> 只在文件很少时成立，适合当「没有折叠」的极端参照。
              </p>
            </div>

            <h3 style={{ marginTop: 18 }}>三种方案共用的优化</h3>
            <ul>
              <li><b>组头吸顶</b>：滚到第 87 个文件时，仍然知道这是哪一次传输。</li>
              <li><b>搜索 + 方向筛选</b>：文件多的时候，「找那一个」比「看全部」更常用。</li>
              <li><b>虚拟化</b>：Flutter 的 <code>ListView.builder</code> 天然只建可见行，165 行不卡。</li>
              <li><b>行内操作</b>：点文件打开；长按/更多里放「在文件夹中显示、删除、信息」。</li>
              <li><b>桌面端</b>沿用同一套规则，只是内容区更宽、宫格列数自动增加。</li>
            </ul>
          </div>
        </footer>
      </div>
    </div>
  );
};

ReactDOM.createRoot(document.getElementById("root")).render(<HxPage />);
