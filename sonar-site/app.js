/* Sonar 落地页 — 交互（无依赖，约 100 行） */
(function () {
  "use strict";

  var links = window.SONAR_LINKS || {
    repo: "#",
    releases: "#",
    windows: "#",
    android: "#",
    upstream: "#",
    version: ""
  };

  /* 导航滚动态 */
  var nav = document.getElementById("nav");
  var onScroll = function () {
    if (!nav) return;
    nav.classList.toggle("is-stuck", window.scrollY > 8);
  };
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  /* 导航高亮：滚到哪一段点亮哪一项（对应 styles.css 的 .nav-links a.is-active） */
  var spyLinks = Array.prototype.slice.call(document.querySelectorAll(".nav-links a[href^='#']"));
  var spySections = spyLinks
    .map(function (a) { return document.querySelector(a.getAttribute("href")); })
    .filter(Boolean);
  var syncSpy = function () {
    if (!spySections.length) return;
    var probe = window.scrollY + 140;
    var current = null;
    spySections.forEach(function (sec) {
      if (sec.offsetTop <= probe) current = sec;
    });
    spyLinks.forEach(function (a) {
      a.classList.toggle("is-active", !!current && a.getAttribute("href") === "#" + current.id);
    });
  };
  syncSpy();
  window.addEventListener("scroll", syncSpy, { passive: true });

  /* 版本号 / 链接 */
  document.querySelectorAll(".js-version").forEach(function (el) {
    el.textContent = links.version ? "v" + links.version : "";
  });
  document.querySelectorAll(".js-repo").forEach(function (el) {
    el.href = links.repo;
    el.target = "_blank";
    el.rel = "noopener";
  });
  document.querySelectorAll(".js-releases").forEach(function (el) {
    el.href = links.releases;
    el.target = "_blank";
    el.rel = "noopener";
  });

  /* 安装包直链：Gitee Release 上的两个文件 */
  [
    [".js-download-windows", links.windows],
    [".js-download-android", links.android]
  ].forEach(function (pair) {
    document.querySelectorAll(pair[0]).forEach(function (el) {
      el.href = pair[1] || links.releases;
      el.target = "_blank";
      el.rel = "noopener";
    });
  });
  document.querySelectorAll(".js-notice").forEach(function (el) {
    el.href = links.notice || links.repo;
    el.target = "_blank";
    el.rel = "noopener";
  });
  document.querySelectorAll(".js-upstream").forEach(function (el) {
    el.href = links.upstream;
    el.target = "_blank";
    el.rel = "noopener";
  });

  /* 重新扫描：重放雷达光点的入场动画 */
  var radar = document.getElementById("radar");
  var rescan = document.getElementById("rescan");
  if (radar && rescan) {
    rescan.addEventListener("click", function () {
      rescan.classList.add("is-spinning");
      window.setTimeout(function () {
        rescan.classList.remove("is-spinning");
      }, 620);

      var blips = radar.querySelectorAll(".blip");
      blips.forEach(function (b) {
        b.style.animation = "none";
      });
      // 强制回流后再交还给样式表，动画从头播放
      void radar.offsetWidth;
      blips.forEach(function (b) {
        b.style.animation = "";
      });
    });
  }


  /* 入场动画 */
  var reveals = document.querySelectorAll(".reveal");
  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  // ?static=1 用于截图/无动画预览
  var forceStatic = /(?:\?|&)static=1/.test(window.location.search);

  if (reduced || forceStatic || !("IntersectionObserver" in window)) {
    reveals.forEach(function (el) {
      el.classList.add("is-in");
    });
    return;
  }

  var io = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-in");
        io.unobserve(entry.target);
      });
    },
    { rootMargin: "0px 0px -12% 0px", threshold: 0.12 }
  );

  reveals.forEach(function (el, i) {
    el.style.transitionDelay = Math.min(i % 3, 2) * 70 + "ms";
    io.observe(el);
  });
})();
