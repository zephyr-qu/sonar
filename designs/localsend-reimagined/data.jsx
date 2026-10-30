/* data.jsx — 原型用到的真实功能数据（取自 app/lib 的设置与页面结构） */

const MOCK = {
  self: {
    alias: "Kai 的 iPhone",
    deviceType: "phone",
    ip: "192.168.1.17",
    port: 53317,
    protocol: "2.2",
    network: "Kai-Home · 5G",
  },

  devices: [
    {
      id: "mbp",
      name: "Yuki 的 MacBook Pro",
      type: "desktop",
      os: "macOS 15 · 协议 2.2",
      online: true,
      rtt: 12,
      last: "5 分钟前",
      ip: "192.168.1.24",
      angle: -58,
      radius: 74,
    },
    {
      id: "pixel",
      name: "Anya 的 Pixel 8",
      type: "phone",
      os: "Android 16 · 协议 2.2",
      online: true,
      rtt: 38,
      last: "昨天",
      ip: "192.168.1.31",
      angle: 44,
      radius: 96,
    },
    {
      id: "ipad",
      name: "客厅 iPad",
      type: "tablet",
      os: "iPadOS 18 · 协议 2.1",
      online: true,
      rtt: 64,
      last: "3 天前",
      ip: "192.168.1.44",
      angle: 158,
      radius: 66,
    },
    {
      id: "nas",
      name: "NAS-STORAGE",
      type: "server",
      os: "Linux · 协议 2.2",
      online: false,
      rtt: null,
      last: "2 周前",
      ip: "192.168.1.9",
      angle: -140,
      radius: 100,
    },
    {
      id: "macmini",
      name: "Mac mini · 工作室",
      type: "desktop",
      os: "macOS 15 · 协议 2.2",
      online: true,
      rtt: 18,
      last: "今天",
      ip: "192.168.1.21",
      angle: -120,
      radius: 80,
    },
    {
      id: "ipadpro",
      name: "Yuki 的 iPad Pro",
      type: "tablet",
      os: "iPadOS 18 · 协议 2.2",
      online: true,
      rtt: 26,
      last: "昨天",
      ip: "192.168.1.35",
      angle: 100,
      radius: 70,
    },
    {
      id: "winpc",
      name: "Windows 笔记本",
      type: "desktop",
      os: "Windows 11 · 协议 2.1",
      online: true,
      rtt: 54,
      last: "3 天前",
      ip: "192.168.1.61",
      angle: -20,
      radius: 60,
    },
    {
      id: "tv",
      name: "客厅电视",
      type: "tablet",
      os: "Android TV · 协议 2.0",
      online: false,
      rtt: null,
      last: "1 个月前",
      ip: "192.168.1.72",
      angle: 200,
      radius: 90,
    },
    {
      id: "pi",
      name: "raspberrypi",
      type: "server",
      os: "Linux · 协议 2.2",
      online: false,
      rtt: null,
      last: "2 个月前",
      ip: "192.168.1.88",
      angle: 250,
      radius: 90,
    },
  ],

  files: [
    { id: "f1", name: "IMG_2481.HEIC", kind: "HEIC", size: 4_300_000 },
    { id: "f2", name: "海报终稿-v3.fig", kind: "FIG", size: 18_200_000 },
    { id: "f3", name: "报销单-10月.pdf", kind: "PDF", size: 240_000 },
  ],

  history: [
    { id: "h1", dir: "in", device: "Anya 的 Pixel 8", items: 2, size: 6_100_000, time: "昨天 21:04", note: "已存入相册" },
    { id: "h2", dir: "out", device: "Yuki 的 MacBook Pro", items: 1, size: 18_200_000, time: "周一 09:12", note: "校验通过" },
    { id: "h3", dir: "in", device: "Web 链接 · Safari", items: 1, size: 820_000, time: "10 月 18 日", note: "Saved to Downloads" },
  ],

  incoming: {
    deviceId: "pixel",
    name: "Anya 的 Pixel 8",
    os: "Android 16 · 192.168.1.31",
    files: [
      { id: "i1", name: "旅行清单.md", kind: "MD", size: 6_400 },
      { id: "i2", name: "DSC_0912.JPG", kind: "JPG", size: 5_900_000 },
      { id: "i3", name: "录音-会议.m4a", kind: "M4A", size: 3_100_000 },
    ],
  },

  link: {
    url: "http://192.168.1.17:53317/s/7d3f2a",
    pin: "4821",
    requests: 0,
  },

  settings: [
    {
      id: "visibility",
      title: "可见性",
      summary: "别名 · 设备类型 · 发现方式",
      rows: [
        { type: "text", key: "alias", label: "别名", desc: "其他设备在附近看到的名称", value: "Kai 的 iPhone" },
        { type: "value", key: "deviceType", label: "设备类型", value: "手机" },
        { type: "switch", key: "visible", label: "对本网络可见", desc: "关闭后仅能通过链接接收" },
        { type: "segment", key: "discovery", label: "发现方式", options: ["多播", "扫描"], index: 0 },
      ],
    },
    {
      id: "receive",
      title: "接收",
      summary: "保存位置 · 快速保存 · PIN",
      rows: [
        { type: "value", key: "destination", label: "保存到", value: "Downloads/LocalSend" },
        { type: "segment", key: "quickSave", label: "快速保存", desc: "收藏设备发来的文件不再询问", options: ["关闭", "仅收藏", "全部"], index: 1 },
        { type: "switch", key: "gallery", label: "接收后存入相册", desc: "图片与视频" },
        { type: "switch", key: "pin", label: "接收 PIN", desc: "链接接收时要求输入 4 位 PIN" },
        { type: "switch", key: "historySave", label: "保留历史记录" },
      ],
    },
    {
      id: "security",
      title: "安全与传输",
      summary: "加密 · 校验和",
      rows: [
        { type: "switch", key: "encryption", label: "加密传输", desc: "TLS + 双向证书；指纹不符的设备不会出现在附近" },
        { type: "switch", key: "checksumOut", label: "发送时生成校验和" },
        { type: "switch", key: "checksumIn", label: "接收时校验文件" },
      ],
    },
    {
      id: "appearance",
      title: "外观",
      summary: "主题 · 强调色 · 语言",
      rows: [
        { type: "segment", key: "theme", label: "主题", options: ["自动", "浅色", "深色"], index: 0 },
        { type: "segment", key: "layout", label: "附近页布局", desc: "多设备：搜索 + 双列网格；内嵌：设备都在雷达里，下方给文件", options: ["多设备", "内嵌"], index: 0 },
        { type: "swatch", key: "accent", label: "强调色" },
        { type: "value", key: "locale", label: "语言", value: "简体中文" },
        { type: "switch", key: "animations", label: "动效" },
      ],
    },
    {
      id: "advanced",
      title: "高级",
      summary: "端口 · 多播 · 网络 · 调试",
      rows: [
        { type: "value", key: "port", label: "端口", value: "53317" },
        { type: "value", key: "multicast", label: "多播组", value: "224.0.0.167" },
        { type: "value", key: "timeout", label: "发现超时", value: "500 ms" },
        { type: "value", key: "whitelist", label: "网络白名单", value: "未启用" },
        { type: "value", key: "blacklist", label: "网络黑名单", value: "未启用" },
        { type: "link", key: "interfaces", label: "网络接口", value: "3 个" },
        { type: "link", key: "debug", label: "调试与日志" },
      ],
    },
  ],
};

function fmtBytes(n) {
  if (n == null) return "—";
  if (n < 1024) return n + " B";
  const units = ["KB", "MB", "GB"];
  let v = n / 1024;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i += 1;
  }
  return (v >= 10 ? v.toFixed(0) : v.toFixed(1)) + " " + units[i];
}

function totalSize(files) {
  return files.reduce((sum, f) => sum + f.size, 0);
}

Object.assign(window, { MOCK, fmtBytes, totalSize });
