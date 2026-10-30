/* history-data.jsx — 「最近传输」模拟数据：一次大传输 + 多次小传输
   数据形状按真实 App 的历史条目（每文件一条）拼装，便于比较列表长度。 */

function hxRng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

function hxMb(rnd, min, max) {
  return Math.round((min + rnd() * (max - min)) * 1024 * 1024);
}

/* 128 个文件：96 张照片 + 8 段视频 + 10 张截图 + 6 份文档 + 8 个杂项 */
function hxBigTransferFiles() {
  const rnd = hxRng(7);
  const files = [];

  for (let i = 0; i < 96; i += 1) {
    files.push({ id: "p" + i, name: "IMG_" + (4821 + i) + ".HEIC", kind: "HEIC", size: hxMb(rnd, 2.2, 5.8) });
  }
  for (let i = 0; i < 8; i += 1) {
    files.push({ id: "v" + i, name: "VID_" + (1204 + i) + ".MOV", kind: "MOV", size: hxMb(rnd, 42, 210) });
  }
  for (let i = 0; i < 10; i += 1) {
    files.push({ id: "s" + i, name: "截图 2026-10-28 21.0" + i + ".png", kind: "PNG", size: hxMb(rnd, 0.8, 2.4) });
  }

  const docs = [
    ["行程-京都.pdf", "PDF", 0.6, 2.2],
    ["报销单-10月.pdf", "PDF", 0.2, 0.5],
    ["提案-v4.docx", "DOCX", 1.2, 4.5],
    ["合同-扫描.pdf", "PDF", 3.0, 9.0],
    ["通讯录.csv", "CSV", 0.05, 0.3],
    ["发票-0921.pdf", "PDF", 0.15, 0.4],
  ];
  docs.forEach((d, i) => {
    files.push({ id: "d" + i, name: d[0], kind: d[1], size: hxMb(rnd, d[2], d[3]) });
  });

  const misc = [
    ["旅行清单.md", "MD", 0.004, 0.02],
    ["录音-会议.m4a", "M4A", 2.5, 8.0],
    ["海报终稿-v3.fig", "FIG", 12, 24],
    ["素材包.zip", "ZIP", 30, 90],
    ["设计规范.pdf", "PDF", 4, 12],
    ["屏幕录制.mov", "MOV", 25, 80],
    ["座位表.xlsx", "XLSX", 0.05, 0.4],
    ["笔记导出.md", "MD", 0.01, 0.06],
  ];
  misc.forEach((m, i) => {
    files.push({ id: "m" + i, name: m[0], kind: m[1], size: hxMb(rnd, m[2], m[3]) });
  });

  return files;
}

const HX_HEAVY_SESSIONS = [
  {
    id: "s1",
    dir: "in",
    peer: "Anya 的 Pixel 8",
    type: "phone",
    time: "今天 21:04",
    date: new Date(2026, 9, 30, 21, 4),
    note: "已存入相册",
    files: hxBigTransferFiles(),
  },
  {
    id: "s2",
    dir: "out",
    peer: "Yuki 的 MacBook Pro",
    type: "desktop",
    time: "今天 09:12",
    date: new Date(2026, 9, 30, 9, 12),
    note: "校验通过",
    files: [
      { id: "a1", name: "海报终稿-v3.fig", kind: "FIG", size: 18_200_000 },
      { id: "a2", name: "提案-客户版.pdf", kind: "PDF", size: 6_400_000 },
      { id: "a3", name: "封面-300dpi.png", kind: "PNG", size: 3_100_000 },
    ],
  },
  {
    id: "s3",
    dir: "in",
    peer: "客厅 iPad",
    type: "tablet",
    time: "昨天 18:40",
    date: new Date(2026, 9, 29, 18, 40),
    note: "已存入相册",
    files: [
      { id: "b1", name: "IMG_1180.HEIC", kind: "HEIC", size: 4_200_000 },
      { id: "b2", name: "IMG_1181.HEIC", kind: "HEIC", size: 4_600_000 },
      { id: "b3", name: "IMG_1182.HEIC", kind: "HEIC", size: 3_900_000 },
      { id: "b4", name: "IMG_1183.HEIC", kind: "HEIC", size: 5_100_000 },
      { id: "b5", name: "IMG_1184.HEIC", kind: "HEIC", size: 4_400_000 },
      { id: "b6", name: "IMG_1185.HEIC", kind: "HEIC", size: 4_000_000 },
    ],
  },
  {
    id: "s4",
    dir: "out",
    peer: "Mac mini · 工作室",
    type: "desktop",
    time: "昨天 11:02",
    date: new Date(2026, 9, 29, 11, 2),
    note: "校验通过",
    files: Array.from({ length: 12 }, (_, i) => ({
      id: "c" + i,
      name: "导出-第" + (i + 1) + "页.png",
      kind: "PNG",
      size: 1_800_000 + i * 240_000,
    })),
  },
  {
    id: "s5",
    dir: "in",
    peer: "Web 链接 · Safari",
    type: "web",
    time: "10 月 28 日 20:15",
    date: new Date(2026, 9, 28, 20, 15),
    note: "已下载",
    files: [{ id: "e1", name: "价目表-2026.pdf", kind: "PDF", size: 820_000 }],
  },
  {
    id: "s6",
    dir: "out",
    peer: "Windows 笔记本",
    type: "desktop",
    time: "10 月 28 日 08:30",
    date: new Date(2026, 9, 28, 8, 30),
    note: "校验通过",
    files: [
      { id: "f1", name: "驱动包.zip", kind: "ZIP", size: 64_000_000 },
      { id: "f2", name: "安装说明.txt", kind: "TXT", size: 4_200 },
      { id: "f3", name: "截图-01.png", kind: "PNG", size: 980_000 },
      { id: "f4", name: "截图-02.png", kind: "PNG", size: 1_120_000 },
    ],
  },
  {
    id: "s7",
    dir: "in",
    peer: "Anya 的 Pixel 8",
    type: "phone",
    time: "10 月 26 日 22:10",
    date: new Date(2026, 9, 26, 22, 10),
    note: "已存入相册",
    files: [
      { id: "g1", name: "录音-会议.m4a", kind: "M4A", size: 3_100_000 },
      { id: "g2", name: "旅行清单.md", kind: "MD", size: 6_400 },
    ],
  },
  {
    id: "s8",
    dir: "out",
    peer: "Yuki 的 iPad Pro",
    type: "tablet",
    time: "10 月 24 日 14:05",
    date: new Date(2026, 9, 24, 14, 5),
    note: "校验通过",
    files: Array.from({ length: 9 }, (_, i) => ({
      id: "h" + i,
      name: "分镜-0" + (i + 1) + ".jpg",
      kind: "JPG",
      size: 2_200_000 + i * 180_000,
    })),
  },
];

const HX_LIGHT_SESSIONS = [
  {
    id: "l1",
    dir: "in",
    peer: "Anya 的 Pixel 8",
    type: "phone",
    time: "今天 21:04",
    date: new Date(2026, 9, 30, 21, 4),
    note: "已存入相册",
    files: [
      { id: "n1", name: "IMG_2481.HEIC", kind: "HEIC", size: 4_300_000 },
      { id: "n2", name: "旅行清单.md", kind: "MD", size: 6_400 },
    ],
  },
  {
    id: "l2",
    dir: "out",
    peer: "Yuki 的 MacBook Pro",
    type: "desktop",
    time: "今天 09:12",
    date: new Date(2026, 9, 30, 9, 12),
    note: "校验通过",
    files: [{ id: "n3", name: "海报终稿-v3.fig", kind: "FIG", size: 18_200_000 }],
  },
  {
    id: "l3",
    dir: "in",
    peer: "Web 链接 · Safari",
    type: "web",
    time: "昨天 20:15",
    date: new Date(2026, 9, 29, 20, 15),
    note: "已下载",
    files: [{ id: "n4", name: "价目表-2026.pdf", kind: "PDF", size: 820_000 }],
  },
  {
    id: "l4",
    dir: "out",
    peer: "客厅 iPad",
    type: "tablet",
    time: "10 月 28 日 11:02",
    date: new Date(2026, 9, 28, 11, 2),
    note: "校验通过",
    files: [
      { id: "n5", name: "分镜-01.jpg", kind: "JPG", size: 2_400_000 },
      { id: "n6", name: "分镜-02.jpg", kind: "JPG", size: 2_600_000 },
      { id: "n7", name: "分镜-03.jpg", kind: "JPG", size: 2_100_000 },
    ],
  },
  {
    id: "l5",
    dir: "in",
    peer: "Windows 笔记本",
    type: "desktop",
    time: "10 月 26 日 22:10",
    date: new Date(2026, 9, 26, 22, 10),
    note: "已下载",
    files: [
      { id: "n8", name: "安装说明.txt", kind: "TXT", size: 4_200 },
      { id: "n9", name: "截图-01.png", kind: "PNG", size: 980_000 },
    ],
  },
];

function hxSum(files) {
  return files.reduce((sum, f) => sum + f.size, 0);
}

function hxCount(sessions) {
  return sessions.reduce((n, s) => n + s.files.length, 0);
}

const HX_DATA = {
  heavy: {
    key: "heavy",
    label: "大量 · 165 项",
    sessions: HX_HEAVY_SESSIONS,
    totalFiles: hxCount(HX_HEAVY_SESSIONS),
    bigSession: HX_HEAVY_SESSIONS[0],
  },
  light: {
    key: "light",
    label: "普通 · 9 项",
    sessions: HX_LIGHT_SESSIONS,
    totalFiles: hxCount(HX_LIGHT_SESSIONS),
    bigSession: null,
  },
};

/* 每个文件补一个「修改时间」：协议里 FileDto.metadata.modified 本来就有，
   这里用文件名散列生成，让「按日期排序」有真实可看的顺序。 */
function hxHash(text) {
  let h = 0;
  for (let i = 0; i < text.length; i += 1) h = (h * 31 + text.charCodeAt(i)) >>> 0;
  return h;
}

function hxModified(name, base) {
  const h = hxHash(name);
  const shot = name.match(/截图 (\d{4})-(\d{2})-(\d{2})/);
  if (shot) {
    return new Date(Number(shot[1]), Number(shot[2]) - 1, Number(shot[3]), h % 24, (h >> 7) % 60, 0, 0);
  }
  const date = new Date(base.getTime());
  date.setDate(date.getDate() - (h % 27));
  date.setHours(h % 24, (h >> 7) % 60, 0, 0);
  return date;
}

[...HX_HEAVY_SESSIONS, ...HX_LIGHT_SESSIONS].forEach((session) => {
  session.files.forEach((file) => {
    if (!file.modified) file.modified = hxModified(file.name, session.date);
  });
});

/* 搜索 + 方向筛选：作用于文件级，空的会话整组隐藏 */
function hxFilter(sessions, query, filter) {
  const q = (query || "").trim().toLowerCase();
  return sessions
    .filter((s) => (filter === "in" ? s.dir === "in" : filter === "out" ? s.dir === "out" : true))
    .map((s) => (q ? { ...s, files: s.files.filter((f) => f.name.toLowerCase().indexOf(q) !== -1) } : s))
    .filter((s) => s.files.length > 0);
}

Object.assign(window, { HX_DATA, hxFilter, hxSum });
