;(() => {
  const stateKey = "__codexThemeStudioFortuneSafeLayer";
  globalThis[stateKey]?.dispose?.();

  const requestFrame = globalThis.requestAnimationFrame
    ?? ((callback) => setTimeout(callback, 16));
  const cancelFrame = globalThis.cancelAnimationFrame
    ?? clearTimeout;
  let animationFrame = 0;
  const projectBagImages = {
    collapsed: "__FORTUNE_PROJECT_BAG_COLLAPSED_DATA_URL__",
    expanded: "__FORTUNE_PROJECT_BAG_EXPANDED_DATA_URL__"
  };
  const observedResizeTargets = new Set();
  const resizeObserver = typeof globalThis.requestAnimationFrame === "function"
    && typeof globalThis.ResizeObserver === "function"
    ? new ResizeObserver(() => schedule())
    : null;

  function syncResizeTargets(targets) {
    if (!resizeObserver) return;
    const nextTargets = new Set(targets);
    for (const element of observedResizeTargets) {
      if (nextTargets.has(element)) continue;
      resizeObserver.unobserve(element);
      observedResizeTargets.delete(element);
    }
    for (const element of nextTargets) {
      if (observedResizeTargets.has(element)) continue;
      resizeObserver.observe(element);
      observedResizeTargets.add(element);
    }
  }

  function visiblePanelHosts(shellRect) {
    const sidebarToggle = [...document.querySelectorAll("button")]
      .find((element) => element.getAttribute("aria-label") === "显示/隐藏侧边栏");
    if (sidebarToggle) {
      return sidebarToggle.getAttribute("aria-pressed") === "true"
        ? [{ element: sidebarToggle, rect: sidebarToggle.getBoundingClientRect() }]
        : [];
    }
    return [...document.querySelectorAll(
      "file-tree-container, diffs-container, [class*='--thread-floating-content-top-inset']"
    )]
      .map((element) => ({ element, rect: element.getBoundingClientRect() }))
      .filter(({ rect }) => (
        rect.width > 80
        && rect.height > 120
        && rect.left > shellRect.left + shellRect.width * .45
        && rect.right >= shellRect.right - 12
        && rect.left < shellRect.right
      ));
  }

  function syncProjectBagIcons(enabled) {
    const rows = enabled
      ? document.querySelectorAll(
        "aside.app-shell-left-panel [data-app-action-sidebar-project-row]"
      )
      : [];
    const activeMarkers = new Set();
    for (const row of rows) {
      const marker = row.querySelector("svg")?.parentElement;
      if (!marker) continue;
      const state = row.getAttribute("aria-expanded") === "true"
        ? "expanded"
        : "collapsed";
      activeMarkers.add(marker);
      const previousState = marker.dataset.dreamFortuneProjectBag;
      marker.dataset.dreamFortuneProjectBag = state;
      let image = marker.querySelector(":scope > .dream-fortune-project-bag-icon");
      if (!image) {
        image = document.createElement("img");
        image.className = "dream-fortune-project-bag-icon";
        image.alt = "";
        image.setAttribute("aria-hidden", "true");
        image.draggable = false;
        marker.prepend(image);
      }
      if (image.src !== projectBagImages[state]) image.src = projectBagImages[state];
      if (previousState && previousState !== state && state === "expanded") {
        image.classList.remove("is-bursting");
        void image.offsetWidth;
        image.classList.add("is-bursting");
      }
    }
    for (const marker of document.querySelectorAll("[data-dream-fortune-project-bag]")) {
      if (activeMarkers.has(marker)) continue;
      marker.querySelector(":scope > .dream-fortune-project-bag-icon")?.remove();
      delete marker.dataset.dreamFortuneProjectBag;
    }
  }

  function sidebarIcon(label) {
    if (label === "__project__") {
      const projectIcon = document.querySelector(
        "aside.app-shell-left-panel [data-app-action-sidebar-project-row] svg"
      );
      if (projectIcon) return projectIcon.cloneNode(true);
    }
    const control = [...document.querySelectorAll("aside.app-shell-left-panel button")]
      .find((element) => element.innerText?.trim().includes(label));
    return control?.querySelector("svg")?.cloneNode(true) ?? null;
  }

  function hydrateDashboardIcons(dashboard) {
    for (const slot of dashboard.querySelectorAll("[data-icon-source]")) {
      if (slot.querySelector("svg")) continue;
      const icon = sidebarIcon(slot.dataset.iconSource);
      if (icon) slot.appendChild(icon);
    }
  }

  function fillHomeComposer(home, prompt) {
    const editor = home.querySelector('[contenteditable="true"]');
    if (!editor) return;
    editor.focus();
    const selection = window.getSelection?.();
    const range = document.createRange?.();
    if (selection && range) {
      range.selectNodeContents(editor);
      selection.removeAllRanges();
      selection.addRange(range);
    }
    if (typeof document.execCommand === "function") {
      document.execCommand("insertText", false, prompt);
    } else {
      editor.textContent = prompt;
      editor.dispatchEvent(new InputEvent("input", {
        bubbles: true,
        inputType: "insertText",
        data: prompt
      }));
    }
  }

  function syncHomeDashboard(enabled) {
    const home = enabled
      ? document.querySelector('[role="main"].dream-skin-home')
      : null;
    for (const dashboard of document.querySelectorAll(".dream-fortune-home-dashboard")) {
      if (!home || dashboard.parentElement !== home) dashboard.remove();
    }
    if (!home) return;
    const existingDashboard = home.querySelector(":scope > .dream-fortune-home-dashboard");
    if (existingDashboard) {
      hydrateDashboardIcons(existingDashboard);
      return;
    }

    const dashboard = document.createElement("section");
    dashboard.className = "dream-fortune-home-dashboard";
    dashboard.setAttribute("aria-label", "财神工作台");
    dashboard.innerHTML = `
      <header class="dream-fortune-home-header">
        <div class="dream-fortune-home-title">
          <span class="dream-fortune-home-seal" aria-hidden="true"><img src="__FORTUNE_PROJECT_BAG_COLLAPSED_DATA_URL__" alt="" draggable="false"></span>
          <span><b>财神打工版</b><small>Codex 专属皮肤 · 让代码为你打工，效率为你生财</small></span>
        </div>
        <div class="dream-fortune-home-badges">
          <span class="dream-fortune-home-online"><i></i>今日财运在线</span>
          <span class="dream-fortune-home-merit"><i data-icon-source="已安排" aria-hidden="true"></i>功德 +1</span>
        </div>
      </header>
      <div class="dream-fortune-home-hero">
        <img class="dream-fortune-home-figure" src="__FORTUNE_HERO_CUTOUT_DATA_URL__" alt="财神程序员正在使用电脑" draggable="false">
        <div class="dream-fortune-home-copy">
          <span class="dream-fortune-home-kicker">财神驻场 · 开工大吉</span>
          <h1>今天先把项目搞赚钱</h1>
          <p>帮你优化成本、清理技术债、总结进展，顺手把冲突安全合并。</p>
          <div class="dream-fortune-home-tokens" aria-label="今日开工状态">
            <span><i data-icon-source="已安排" aria-hidden="true"></i><b>功德簿</b><em>+1</em></span>
            <span><i data-icon-source="插件" aria-hidden="true"></i><b>金币</b><em>+88</em></span>
            <span><i data-icon-source="站点" aria-hidden="true"></i><b>连签</b><em>7 天</em></span>
          </div>
        </div>
        <aside class="dream-fortune-home-stat" aria-label="本月效率统计">
          <span class="dream-fortune-stat-icon" data-icon-source="拉取请求" aria-hidden="true"></span>
          <small>本月已为团队节省</small>
          <strong>¥ 68,888.00</strong>
          <span>效率提升 <b>+88.8%</b></span>
        </aside>
        <span class="dream-fortune-home-lucky-coin" aria-hidden="true"><i data-icon-source="插件"></i></span>
      </div>
      <div class="dream-fortune-home-actions">
        <button type="button" data-dream-fortune-prompt="分析当前项目的高成本代码路径，给出可执行的性能与资源降本方案，并按优先级排序。">
          <span class="dream-fortune-action-icon" data-icon-source="已安排"></span>
          <span><b>成本优化</b><small>定位高成本路径，给出降本方案</small></span>
        </button>
        <button type="button" data-dream-fortune-prompt="扫描当前项目的技术债、复杂度、过期依赖和待办项，整理成可分批执行的清账计划。">
          <span class="dream-fortune-action-icon" data-icon-source="插件"></span>
          <span><b>技术债清账</b><small>扫描债务，一键整理改造计划</small></span>
        </button>
        <button type="button" data-dream-fortune-prompt="总结当前项目最近的代码变更、已完成事项、风险和下一步，生成一份简洁的项目进展报告。">
          <span class="dream-fortune-action-icon" data-icon-source="站点"></span>
          <span><b>自动报表总结</b><small>汇总变更、风险与下一步</small></span>
        </button>
        <button type="button" data-dream-fortune-prompt="检查当前分支的潜在合并冲突，解释冲突原因，并给出安全的解决与验证步骤。">
          <span class="dream-fortune-action-icon" data-icon-source="拉取请求"></span>
          <span><b>冲突合并开运</b><small>识别冲突，给出安全合并方案</small></span>
        </button>
      </div>`;

    hydrateDashboardIcons(dashboard);
    dashboard.addEventListener("click", (event) => {
      const button = event.target.closest("[data-dream-fortune-prompt]");
      if (!button) return;
      fillHomeComposer(home, button.dataset.dreamFortunePrompt);
    });
    home.appendChild(dashboard);
  }

  function update() {
    animationFrame = 0;
    const chrome = document.getElementById("codex-dream-skin-chrome");
    const shell = document.querySelector("main.main-surface");
    if (!chrome || !shell) return;

    if (document.documentElement.getAttribute("data-dream-theme-id") !== "preset-fortune-coder") {
      chrome.style.removeProperty("--dream-fortune-safe-right");
      delete chrome.dataset.dreamFortuneContentOpen;
      syncProjectBagIcons(false);
      syncHomeDashboard(false);
      return;
    }

    const shellRect = shell.getBoundingClientRect();
    const panels = visiblePanelHosts(shellRect);
    const contentOpen = panels.length > 0;
    const safeRightValue = "92px";
    if (chrome.style.getPropertyValue("--dream-fortune-safe-right") !== safeRightValue) {
      chrome.style.setProperty("--dream-fortune-safe-right", safeRightValue);
    }
    if (contentOpen) {
      chrome.dataset.dreamFortuneContentOpen = "true";
    } else {
      delete chrome.dataset.dreamFortuneContentOpen;
    }
    syncProjectBagIcons(true);
    syncHomeDashboard(true);
    syncResizeTargets([shell, ...panels.map(({ element }) => element)]);
  }

  function schedule() {
    if (animationFrame) return;
    animationFrame = requestFrame(update);
  }

  const mutationObserver = new MutationObserver(schedule);
  mutationObserver.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ["class", "data-dream-theme-id", "style"],
    childList: true,
    subtree: true
  });
  window.addEventListener("resize", schedule, { passive: true });
  update();

  globalThis[stateKey] = {
    dispose() {
      if (animationFrame) cancelFrame(animationFrame);
      mutationObserver.disconnect();
      resizeObserver?.disconnect();
      observedResizeTargets.clear();
      window.removeEventListener("resize", schedule);
      const chrome = document.getElementById("codex-dream-skin-chrome");
      chrome?.style.removeProperty("--dream-fortune-safe-right");
      if (chrome?.dataset) delete chrome.dataset.dreamFortuneContentOpen;
      syncProjectBagIcons(false);
      syncHomeDashboard(false);
    }
  };

  const providerState = globalThis.window?.__CODEX_DREAM_SKIN_STATE__
    ?? globalThis.__CODEX_DREAM_SKIN_STATE__;
  return {
    installed: Boolean(providerState),
    version: providerState?.version,
    themeId: providerState?.themeId ?? "custom",
    shell: document.documentElement.getAttribute("data-dream-shell")
      ?? providerState?.detectShellMode?.(),
    analysis: providerState?.analysis ?? null
  };
})();
