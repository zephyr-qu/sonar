/* Sonar 落地页 — 交互（无依赖，约 100 行） */
(function () {
  "use strict";

  var links = window.SONAR_LINKS || {
    repo: "#",
    releases: "#",
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

  /* 复制命令行 */
  var cmd = document.getElementById("cliCommand");
  var copyBtn = document.getElementById("copyCmd");
  if (cmd && copyBtn) {
    copyBtn.addEventListener("click", function () {
      var text = cmd.textContent || "";
      var done = function () {
        copyBtn.classList.add("is-done");
        copyBtn.textContent = "已复制";
        window.setTimeout(function () {
          copyBtn.classList.remove("is-done");
          copyBtn.textContent = "复制";
        }, 1600);
      };

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, done);
      } else {
        var ta = document.createElement("textarea");
        ta.value = text;
        ta.setAttribute("readonly", "");
        ta.style.position = "fixed";
        ta.style.opacity = "0";
        document.body.appendChild(ta);
        ta.select();
        try {
          document.execCommand("copy");
        } catch (e) {
          /* 忽略：复制失败时按钮仍给出反馈 */
        }
        document.body.removeChild(ta);
        done();
      }
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
