/* ideas-app.jsx — 换模型的三种最近传输：并排对比 + 实测尺寸 */

const { useState: iaUseState, useRef: iaUseRef, useEffect: iaUseEffect } = React;

const ID_VARIANTS = [
  {
    id: "mosaic",
    tag: "①",
    title: "拼贴相册",
    badge: "换掉列表",
    sub: "一次传输 = 一张卡，卡面就是这批文件的缩略图拼贴；点开是全屏网格相册。",
    screen: IdScreenMosaic,
    notes: [
      ["机制", "4 列 × 2 行拼贴，第 8 格写「+120」"],
      ["一眼看到", "这批是照片、视频还是文档，不用读字"],
      ["点开", "二级页面：128 项全铺开，可搜索、筛类型"],
    ],
  },
  {
    id: "timeline",
    tag: "②",
    title: "双向时间轴",
    badge: "方向 + 时间",
    sub: "中间一条轴，收到在左、发出在右，每次传输是轴上的一个节点。",
    screen: IdScreenTimeline,
    notes: [
      ["机制", "按天分段，节点带 6 格预览"],
      ["一眼看到", "哪天、收还是发、跟谁、多少文件"],
      ["点开", "同样是二级页面；卡片窄，预览只做提示"],
    ],
  },
  {
    id: "calendar",
    tag: "③",
    title: "日历",
    badge: "按天收敛",
    sub: "月历 + 当日批次；日期格下的条 = 那天的文件量，点一天看那天的传输。",
    screen: IdScreenCalendar,
    notes: [
      ["机制", "文件多的时候，先用「天」把量收住"],
      ["一眼看到", "哪天传得多；128 项只占一张批次卡"],
      ["点开", "二级页面；找跨天的东西先切天再进批次"],
    ],
  },
];

const IdColumn = ({ variant, data }) => {
  const mainRef = iaUseRef(null);
  const [detail, setDetail] = iaUseState(null);
  const [m, setM] = iaUseState({ h: 0, view: 1, batch: 0 });

  iaUseEffect(() => {
    const measure = () => {
      const el = mainRef.current;
      if (!el) return;
      const batch = el.querySelector("[data-batch]");
      setM({ h: el.scrollHeight, view: el.clientHeight || 1, batch: batch ? batch.offsetHeight : 0 });
    };
    const raf = requestAnimationFrame(measure);
    const timer = setTimeout(measure, 260);
    return () => {
      cancelAnimationFrame(raf);
      clearTimeout(timer);
    };
  }, [data.key, variant.id]);

  const Screen = variant.screen;

  return (
    <div className="hx-col">
      <div className="hx-col-head">
        <span className="hx-tag">{variant.tag}</span>
        <h2 className="hx-col-title">{variant.title}</h2>
        <span className="hx-col-badge">{variant.badge}</span>
      </div>
      <p className="hx-col-sub">{variant.sub}</p>

      <div className="phone">
        <Screen data={data} mainRef={mainRef} open={setDetail} />
        {detail ? (
          <div className="id-page-layer">
            <IdDetail session={detail} onBack={() => setDetail(null)} />
          </div>
        ) : null}
      </div>

      <div className="hx-metrics">
        <div className="hx-metric">
          <span className="k">128 项那张卡</span>
          <span className="v">{m.batch} px</span>
        </div>
        <div className="hx-metric">
          <span className="k">列表高度</span>
          <span className="v">{m.h.toLocaleString("en-US")} px</span>
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

const IdPage = () => {
  const [scenario, setScenario] = iaUseState("heavy");
  const data = HX_DATA[scenario];

  return (
    <div className="studio hx-page">
      <div className="hx-wrap">
        <header className="hx-head">
          <div className="hx-kicker">LocalSend · 传输页 · 最近传输 · 第二版</div>
          <h1 className="hx-title">别排列表了，换三种模型</h1>
          <p className="hx-lede">
            上一版三种做法都是「把同一个长列表排紧一点」，文件一多还是不行。这一版把<b>一次传输</b>换成三种东西：
            一张相册、时间轴上的一个节点、一天里的一组批次。列表只做索引，<b>点进去是二级页面</b>——全屏、全部文件、
            可搜索、按类型筛、网格/列表切换。<b>128 个文件在索引里只占一张卡</b>，在二级页面里完整铺开。
            下面的尺寸是渲染后实测的。
          </p>
          <div className="hx-scenario">
            <span className="lbl">数据量</span>
            <div className="hx-seg">
              <button type="button" className={scenario === "heavy" ? "is-on" : ""} onClick={() => setScenario("heavy")}>大量 · 165 项</button>
              <button type="button" className={scenario === "light" ? "is-on" : ""} onClick={() => setScenario("light")}>普通 · 9 项</button>
            </div>
            <span className="lbl" style={{ marginLeft: 6 }}>点任意一张卡 → 二级页面；左上角返回</span>
          </div>
        </header>

        <div className="hx-rack">
          {ID_VARIANTS.map((variant) => (
            <IdColumn key={variant.id} variant={variant} data={data} />
          ))}
        </div>

        <footer className="hx-foot">
          <div>
            <h3>我的建议：① + ② 合成一个默认视图</h3>
            <div className="hx-pick">
              <p>
                列表按<b>天</b>分段（② 的时间骨架），每段下面就是<b>拼贴卡</b>（① 的卡面）。
                这样时间和「这批是什么」同时成立，128 项也只是其中一张卡。
              </p>
              <p>
                <span className="accent">③ 日历</span>不做主视图，做成顶部的「跳到某天」入口：历史越长它越值钱，平时不占首屏。
                索引页只回答「最近传了什么」，剩下的都交给二级页面。
              </p>
            </div>

            <h3 style={{ marginTop: 18 }}>二级页面里放什么（你提的那一步）</h3>
            <ul>
              <li><b>全屏 4 列网格</b>：128 项一次铺开，真实 App 里就是真缩略图；滚动只建可见行。</li>
              <li><b>搜索 + 类型筛选</b>：全部 128 / 图片 96 / 视频 8 / 文档 6，点一下就收窄。</li>
              <li><b>网格 / 列表切换</b>：网格看全貌，列表看文件名和大小。</li>
              <li><b>底部动作条</b>：打开文件夹 + 当前筛选计数；返回走左上角或左滑手势。</li>
              <li><b>页面推入而不是弹层</b>：二级页面占满屏幕，才有地方把东西铺全。</li>
            </ul>

            <h3 style={{ marginTop: 18 }}>三个方案都保留的东西</h3>
            <ul>
              <li><b>缩略图优先</b>：真实 App 里有图就直接用，没有就退回带类型的色块（这里就是色块）。</li>
              <li><b>数量角标</b>：+120 让人知道「卡外面还有多少」，不制造「这就是全部」的错觉。</li>
              <li><b>虚拟化</b>：拼贴只渲染 8 格，二级页网格按可见行建，几百个文件也不卡。</li>
            </ul>
          </div>

          <div>
            <h3>还是要先修数据</h3>
            <p className="hx-col-sub" style={{ minHeight: 0 }}>
              这些卡片都假设「一条历史 = 一次传输」。现在的实现是按文件存、每方向上限 30 条、分组键还带分钟，
              一次 128 个文件的传输会把历史挤空，也拼不出正确的一张卡。改成按会话存之后，上面的设计才成立。
            </p>
            <h3 style={{ marginTop: 18 }}>上一版</h3>
            <p className="hx-col-sub" style={{ minHeight: 0 }}>
              <a href="transfer-history.html">三种「把列表排紧一点」的做法 →</a>
            </p>
          </div>
        </footer>
      </div>
    </div>
  );
};

ReactDOM.createRoot(document.getElementById("root")).render(<IdPage />);
