/* detail-app.jsx — 列表（索引）+ 二级页面（全部文件） */

const { useState: daUseState } = React;

const DT_VARIANTS = [
  {
    id: "list",
    tag: "①",
    title: "列表 · 索引",
    badge: "现在的样子",
    sub: "一行一次传输，128 项也只占一行；默认按日期分组，今天 / 昨天 / 更早。点一行进二级页面。",
    mode: "list",
    notes: [
      ["不变", "行高固定，列表长度只跟「次数」有关"],
      ["排序", "日期倒序 + 按天分组，最新在最上面"],
      ["动作", "点一行 → 二级页面；返回回到原位置"],
    ],
  },
  {
    id: "listview",
    tag: "②",
    title: "二级页面 · 列表",
    badge: "默认",
    sub: "一行一个文件：名字、修改日期、大小。名字最好找，所以默认用它。",
    mode: "listview",
    notes: [
      ["默认", "名字 + 日期 + 大小，扫一眼就能定位"],
      ["排序", "默认日期倒序，可切名称 / 大小"],
      ["筛选", "搜索 + 类型筛选，筛完仍显示「当前 / 总数」"],
    ],
  },
  {
    id: "grid",
    tag: "③",
    title: "二级页面 · 网格",
    badge: "看图",
    sub: "4 列缩略图 + 文件名；照片视频多的批次一眼扫完，名字也还在。",
    mode: "grid",
    notes: [
      ["切换", "底部网格 / 列表，切完返回再进还记得"],
      ["带名字", "缩略图下保留文件名，不至于只剩色块"],
      ["适合", "一次几百张照片、想按画面找"],
    ],
  },
];

const DtPageColumn = ({ variant, data }) => {
  const [m, setM] = daUseState({ list: 0, detail: 0 });
  const isList = variant.mode === "list";

  return (
    <div className="hx-col">
      <div className="hx-col-head">
        <span className="hx-tag">{variant.tag}</span>
        <h2 className="hx-col-title">{variant.title}</h2>
        <span className="hx-col-badge">{variant.badge}</span>
      </div>
      <p className="hx-col-sub">{variant.sub}</p>

      <DtPhone key={data.key + variant.mode} data={data} mode={variant.mode} onMeasure={setM} />

      <div className="hx-metrics">
        <div className="hx-metric">
          <span className="k">{isList ? "列表高度" : "二级页高度"}</span>
          <span className="v">{isList ? m.list.toLocaleString("en-US") : m.detail.toLocaleString("en-US")} px</span>
        </div>
        <div className="hx-metric">
          <span className="k">{isList ? "行数" : "这一页的文件"}</span>
          <span className="v">{isList ? data.sessions.length + " 行" : data.sessions[0].files.length + " 项"}</span>
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

const DtPage = () => {
  const [scenario, setScenario] = daUseState("heavy");
  const data = HX_DATA[scenario];

  return (
    <div className="studio hx-page">
      <div className="hx-wrap">
        <header className="hx-head">
          <div className="hx-kicker">LocalSend · 传输页 · 最近传输 · 第三版</div>
          <h1 className="hx-title">历史不折叠，点进去看全</h1>
          <p className="hx-lede">
            回到现在的样子：<b>历史一行一次传输</b>，128 项也只占一行，不折叠也不展开，默认<b>按日期分组</b>（今天 / 昨天 / 更早）。
            点进去是<b>二级页面</b>——默认<b>列表</b>：文件名 + 修改日期 + 大小，名字最好找；照片视频多的批次可以切<b>网格</b>看图，
            网格里也保留文件名。两种视图都能搜索、按类型筛选、切排序。下面三台手机是同一条流程的三个状态，都能点、都能返回。
          </p>
          <div className="hx-scenario">
            <span className="lbl">数据量</span>
            <div className="hx-seg">
              <button type="button" className={scenario === "heavy" ? "is-on" : ""} onClick={() => setScenario("heavy")}>大量 · 165 项</button>
              <button type="button" className={scenario === "light" ? "is-on" : ""} onClick={() => setScenario("light")}>普通 · 9 项</button>
            </div>
            <span className="lbl" style={{ marginLeft: 6 }}>②③ 已经停在二级页面；① 里点任意一行也能进去</span>
          </div>
        </header>

        <div className="hx-rack">
          {DT_VARIANTS.map((variant) => (
            <DtPageColumn key={variant.id} variant={variant} data={data} />
          ))}
        </div>

        <footer className="hx-foot">
          <div>
            <h3>为什么这比「折叠展开」好</h3>
            <ul>
              <li><b>列表长度可控</b>：n 次传输就是 n 行，跟每次多少文件完全无关。折叠展开时，展开一条就可能多出几百行。</li>
              <li><b>内容不藏在原地</b>：折叠是「同一页里藏起来」，展开后滚动位置会跳、上下文会乱；二级页面是「换一页看全」，返回还能回到原位置。</li>
              <li><b>责任分开</b>：列表负责「最近传了什么」，二级页面负责「这次到底有哪些文件」。</li>
            </ul>

            <h3 style={{ marginTop: 18 }}>二级页面里放什么</h3>
            <ul>
              <li><b>默认列表</b>：一行一个文件，名字 + 修改日期 + 大小。找文件时先想起的是名字，不是画面。</li>
              <li><b>网格（带文件名）</b>：4 列缩略图，格子下面保留文件名；照片视频多的批次切过去扫图。</li>
              <li><b>排序默认日期</b>：用协议里每个文件的 <code>metadata.modified</code> 倒序，可切名称 / 大小。</li>
              <li><b>搜索 + 类型筛选</b>：全部 128 / 图片 106 / 视频 9 / 文档 6，点一下收窄。</li>
              <li><b>底部动作条</b>：打开文件夹、当前 / 总数、排序、视图切换；后续可加「全部保存到相册」「清空这次记录」。</li>
            </ul>
          </div>

          <div>
            <h3>落地时要一起改的</h3>
            <p className="hx-col-sub" style={{ minHeight: 0 }}>
              现在历史是<b>按文件存</b>、每方向上限 30 条，分组键还带「分钟」——一次 128 个文件的传输会把历史挤空，
              也拼不出正确的一行。要改成<b>按会话存</b>（peer、时间、状态、文件列表），上限按会话数算；
              文件列表里顺手把 <code>metadata.modified</code> 一起存下来，二级页面的日期排序才不用再问发送方要。
            </p>
            <h3 style={{ marginTop: 18 }}>交互细节</h3>
            <ul>
              <li>返回：左上角 + 系统返回手势；列表滚动位置保留。</li>
              <li>点文件：打开；长按：多选（保存到相册 / 删除）。</li>
              <li>列表行右侧只留一个箭头，不放操作按钮，避免误触。</li>
            </ul>
            <h3 style={{ marginTop: 18 }}>前两版</h3>
            <p className="hx-col-sub" style={{ minHeight: 0 }}>
              <a href="transfer-history.html">v1：三种「把列表排紧一点」 →</a><br />
              <a href="transfer-history-ideas.html">v2：三种换模型（拼贴 / 时间轴 / 日历） →</a>
            </p>
          </div>
        </footer>
      </div>
    </div>
  );
};

ReactDOM.createRoot(document.getElementById("root")).render(<DtPage />);
