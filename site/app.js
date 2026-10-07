(() => {
  "use strict";

  const BASE_URL = "https://thomaslin070217.github.io/FlyGift/";
  const DOWNLOAD_URL = "https://github.com/ThomasLin070217/FlyGift/releases/latest/download/FlyGift-macOS-arm64.zip";
  const copy = {
    zh: {
      makerEyebrow: "制作一份礼物", makerTitle: "给朋友留一个小惊喜。", makerBody: "输入你的名字，我们会生成一条可以直接分享的礼物链接。内容保持神秘，朋友会在下载前看到安全说明。",
      nameLabel: "你的名字", namePlaceholder: "例如：Thomas", previewLabel: "礼物链接", share: "分享礼物", copy: "复制链接", copied: "链接已经复制。", needName: "先写下你的名字。",
      recipientEyebrow: "你收到了一份礼物", recipientTitle: "给你准备了一份礼物。", recipientBody: "这是一个可以在 Mac 上打开的离线互动礼物。里面是什么，拆开才知道。", anonymous: "一位朋友",
      download: "下载朋友送你的礼物", decline: "暂时不要", macOnly: "请在 Apple Silicon Mac 上打开此链接并下载。", ready: "适用于这台 Mac。下载只会在你点击按钮后开始。",
      downloaded: "下载后，按这三步打开", step1: "解压 FlyGift-macOS-arm64.zip，把 FlyGift.app 拖入“应用程序”文件夹。", step2: "双击 FlyGift.app。如果提示开发者无法验证或 Apple 无法检查恶意软件，请在“系统设置 → 隐私与安全性”中找到该 App 的拦截提示；确认来源后点“仍要打开”，再确认“打开”。", step3: "看到礼盒即表示启动成功。菜单栏可随时结束；双击 Esc 也会立即退出。",
      altTitle: "免弹窗安装（推荐）", altCmdLabel: "方法一 · 一行命令", altCmdHint: "打开「终端」粘贴回车。全程没有确认弹窗，装完自动启动。", altCopy: "复制", altCopied: "已复制", altFileLabel: "方法二 · 下载双击安装", altDownload: "下载安装器", altFileHint: "双击后若弹出确认框，点【Open】即可，只会问一次。",
      damagedTitle: "如果提示“已损坏，应移到废纸篓”", damagedBody: "这与普通的开发者验证提示不同。请先删除旧副本，从本页重新下载并核对 SHA-256。若仍然出现，请停止打开，向项目反馈完整报错与 macOS 版本；不要关闭系统安全保护。",
      unsigned: "尚未经 Apple 公证", safetyTitle: "安全与隐私", safetyBody: "FlyGift 完全离线，不申请屏幕录制或辅助功能权限，不设置开机自启，也不会上传任何信息。当前开源测试包使用本地签名校验完整性，但没有 Developer ID 签名和 Apple 公证，首次打开可能被 macOS 拦截。SHA-256 仅校验下载完整性，不代表 Apple 的安全审核。",
      source: "查看源代码", checksum: "校验下载文件", shareTitle: "一份给你的礼物", shareText: "我给你留了一份礼物。"
    },
    en: {
      makerEyebrow: "MAKE A GIFT", makerTitle: "Leave a small surprise for a friend.", makerBody: "Enter your name to create a shareable gift link. The contents stay mysterious, while the recipient sees the safety details before downloading.",
      nameLabel: "Your name", namePlaceholder: "For example: Thomas", previewLabel: "Gift link", share: "Share gift", copy: "Copy link", copied: "Link copied.", needName: "Add your name first.",
      recipientEyebrow: "YOU RECEIVED A GIFT", recipientTitle: " left a gift for you.", recipientBody: "This is an offline interactive gift for Mac. You will only find out what is inside after opening it.", anonymous: "A friend",
      download: "Download your gift", decline: "Not now", macOnly: "Open this link on an Apple Silicon Mac to download the gift.", ready: "This Mac is supported. The download starts only after you click the button.",
      downloaded: "Three steps to open your download", step1: "Unzip FlyGift-macOS-arm64.zip and drag FlyGift.app into Applications.", step2: "Double-click FlyGift.app. If the developer cannot be verified or Apple cannot check it for malicious software, find the app's blocked-launch notice in System Settings → Privacy & Security. After confirming the source, choose Open Anyway, then Open.", step3: "The gift box confirms a successful launch. Quit from the menu bar or double-press Escape at any time.",
      altTitle: "Install without the Gatekeeper popup (recommended)", altCmdLabel: "Option 1 · One-line command", altCmdHint: "Open Terminal, paste, press Return. No confirmation popups, and it launches automatically when done.", altCopy: "Copy", altCopied: "Copied", altFileLabel: "Option 2 · Download and double-click", altDownload: "Download installer", altFileHint: "If macOS asks for confirmation, click Open. It only asks once.",
      damagedTitle: "If macOS says the app is damaged and should be moved to Trash", damagedBody: "This differs from a normal developer-verification warning. Remove the old copy, download again from this page and verify SHA-256. If it persists, stop opening the app and report the exact message and macOS version to the project. Keep system security protections enabled.",
      unsigned: "Not notarized by Apple", safetyTitle: "Safety and privacy", safetyBody: "FlyGift runs fully offline, requests no Screen Recording or Accessibility permission, never starts at login, and uploads nothing. This preview has a local integrity signature but no Developer ID signature or Apple notarization. macOS may block the first launch. SHA-256 verifies download integrity; it is not an Apple security review.",
      source: "View source", checksum: "Verify download", shareTitle: "A gift for you", shareText: "I left a gift for you."
    }
  };

  const params = new URLSearchParams(location.search);
  const sanitizeName = value => Array.from((value || "").normalize("NFKC").replace(/[\u0000-\u001f\u007f<>]/g, "").replace(/\s+/g, " ").trim()).slice(0, 24).join("");
  const sender = sanitizeName(params.get("from"));
  const hasSenderParameter = params.has("from");
  let language = (navigator.language || "en").toLowerCase().startsWith("zh") ? "zh" : "en";
  const creator = document.querySelector("#creator-view");
  const recipient = document.querySelector("#recipient-view");
  const nameInput = document.querySelector("#sender-name");
  const giftLink = document.querySelector("#gift-link");
  const status = document.querySelector("#creator-status");
  const download = document.querySelector("#download-button");
  const deviceNote = document.querySelector("#device-note");
  const isMac = /Macintosh/.test(navigator.userAgent) && !(navigator.maxTouchPoints > 1);

  creator.hidden = hasSenderParameter;
  recipient.hidden = !hasSenderParameter;

  function personalizedURL() {
    const name = sanitizeName(nameInput.value);
    return name ? `${BASE_URL}?from=${encodeURIComponent(name)}` : BASE_URL;
  }

  function render() {
    document.documentElement.lang = language === "zh" ? "zh-CN" : "en";
    document.querySelectorAll("[data-copy]").forEach(el => { el.textContent = copy[language][el.dataset.copy]; });
    document.querySelectorAll("[data-placeholder]").forEach(el => { el.placeholder = copy[language][el.dataset.placeholder]; });
    document.querySelector("#sender-display").textContent = sender || copy[language].anonymous;
    if (!creator.hidden) giftLink.textContent = personalizedURL();
    deviceNote.textContent = isMac ? copy[language].ready : copy[language].macOnly;
    download.setAttribute("aria-disabled", isMac ? "false" : "true");
  }

  nameInput?.addEventListener("input", () => { giftLink.textContent = personalizedURL(); status.textContent = ""; });
  document.querySelector("#language-toggle").addEventListener("click", () => { language = language === "zh" ? "en" : "zh"; render(); });

  async function copyText(text) {
    if (navigator.clipboard?.writeText) return navigator.clipboard.writeText(text);
    const field = document.createElement("textarea");
    field.value = text; field.setAttribute("readonly", ""); field.style.position = "fixed"; field.style.opacity = "0";
    document.body.appendChild(field); field.select();
    const copied = document.execCommand("copy"); field.remove();
    if (!copied) throw new Error("Clipboard is unavailable");
  }

  async function copyLink() {
    const name = sanitizeName(nameInput.value);
    if (!name) { status.textContent = copy[language].needName; nameInput.focus(); return false; }
    await copyText(personalizedURL());
    status.textContent = copy[language].copied;
    return true;
  }

  document.querySelector("#copy-button")?.addEventListener("click", () => { copyLink().catch(() => { status.textContent = giftLink.textContent; }); });
  document.querySelector("#recipient-copy-button")?.addEventListener("click", () => { copyText(location.href).catch(() => {}); });
  document.querySelector("#install-cmd-copy")?.addEventListener("click", async event => {
    const button = event.currentTarget;
    try {
      await copyText(document.querySelector("#install-cmd").textContent.trim());
      button.textContent = copy[language].altCopied;
    } catch {
      button.textContent = document.querySelector("#install-cmd").textContent;
    }
    setTimeout(() => { button.textContent = copy[language].altCopy; }, 1600);
  });
  document.querySelector("#share-button")?.addEventListener("click", async () => {
    if (!sanitizeName(nameInput.value)) { status.textContent = copy[language].needName; nameInput.focus(); return; }
    const data = { title: copy[language].shareTitle, text: copy[language].shareText, url: personalizedURL() };
    if (navigator.share) {
      try { await navigator.share(data); } catch (error) { if (error.name !== "AbortError") await copyLink(); }
    } else { await copyLink(); }
  });

  download.addEventListener("click", event => {
    if (!isMac) { event.preventDefault(); deviceNote.textContent = copy[language].macOnly; return; }
    download.href = DOWNLOAD_URL;
    document.querySelector("#open-help").hidden = false;
  });
  document.querySelector("#decline-button")?.addEventListener("click", () => {
    if (history.length > 1) history.back(); else recipient.innerHTML = `<p class="lede">${language === "zh" ? "没关系，礼物会留在这里。" : "No problem. The gift will stay here."}</p>`;
  });

  render();
})();
