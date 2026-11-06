/* Nova Tweaks storefront interactions. */
(function () {
  "use strict";

  const CFG = window.NOVA_CONFIG || {};
  const $ = (sel, root) => (root || document).querySelector(sel);
  const $$ = (sel, root) => Array.from((root || document).querySelectorAll(sel));

  const money = (n) => "$" + Number(n).toFixed(2);
  const isUrl = (v) => typeof v === "string" && /^https?:\/\//i.test(v.trim());

  /* ---------- Config hydration ---------- */
  if (CFG.version) {
    $$("#versionBadge").forEach((el) => (el.textContent = CFG.version));
  }

  const winEl = $("#winDownload");
  if (winEl) {
    winEl.href = isUrl(CFG.windowsDownload)
      ? CFG.windowsDownload
      : "https://github.com/r00ster21714/fl3sh-optimizer/releases/latest/download/NovaTweaks.exe";
  }

  const macEl = $("#macDownload");
  if (macEl) {
    macEl.href = CFG.macDownload || "downloads/NovaTweaks-macOS.zip";
  }

  const gh = CFG.github || "https://github.com/r00ster21714/fl3sh-optimizer";
  const githubLink = $("#githubLink");
  if (githubLink) githubLink.href = gh;
  const releaseLink = $("#releaseLink");
  if (releaseLink) releaseLink.href = gh.replace(/\/$/, "") + "/releases";

  const vt = $("#virusTotalLink");
  if (vt) {
    vt.href = isUrl(CFG.virusTotal) ? CFG.virusTotal : "https://www.virustotal.com";
    if (!isUrl(CFG.virusTotal)) {
      vt.textContent = "VirusTotal";
      vt.title = "Scan the release yourself before running it";
    } else {
      vt.textContent = "VirusTotal report";
    }
  }

  const support = $("#supportLink");
  if (support) {
    if (CFG.supportEmail) {
      support.href = "mailto:" + CFG.supportEmail;
      support.textContent = "Email support";
    } else {
      support.href = "#faq";
    }
  }

  const year = $("#year");
  if (year) year.textContent = String(new Date().getFullYear());

  // Prices stay in one place: config.js
  const plans = {
    Pro: CFG.pro || { label: "Pro", price: 5.99 },
    Ultimate: CFG.ultimate || { label: "Ultimate", price: 12.99 }
  };
  $$("[data-price]").forEach((el) => {
    const key = el.getAttribute("data-price");
    const plan = key === "pro" ? plans.Pro : plans.Ultimate;
    if (plan && typeof plan.price === "number") {
      el.innerHTML = money(plan.price) + "<small>/mo</small>";
    }
  });

  /* ---------- Mobile menu ---------- */
  const menuBtn = $("#menuBtn");
  const mobileMenu = $("#mobileMenu");
  if (menuBtn && mobileMenu) {
    menuBtn.addEventListener("click", () => {
      const open = mobileMenu.classList.toggle("open");
      menuBtn.setAttribute("aria-expanded", String(open));
      menuBtn.textContent = open ? "✕" : "☰";
    });
    $$("a", mobileMenu).forEach((a) =>
      a.addEventListener("click", () => {
        mobileMenu.classList.remove("open");
        menuBtn.setAttribute("aria-expanded", "false");
        menuBtn.textContent = "☰";
      })
    );
  }

  /* ---------- Reveal on scroll ---------- */
  const revealEls = $$(".reveal");
  if ("IntersectionObserver" in window && revealEls.length) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("in");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    );
    revealEls.forEach((el) => io.observe(el));
  } else {
    revealEls.forEach((el) => el.classList.add("in"));
  }

  /* ---------- Payment link builders ---------- */
  function stripeLink(plan) {
    return isUrl(plan.stripe) ? plan.stripe.trim() : "";
  }

  function paypalLink(plan) {
    const raw = (plan.paypal || "").trim();
    if (isUrl(raw)) return raw;
    if (!raw) return "";
    // Accept a bare handle or email and build a paypal.me link.
    const handle = raw.replace(/^@/, "").replace(/^\$/, "");
    if (!handle) return "";
    return "https://www.paypal.com/paypalme/" + encodeURIComponent(handle) + "/" + Number(plan.price).toFixed(2);
  }

  function cashAppLink(plan) {
    const raw = (plan.cashapp || "").trim();
    if (isUrl(raw)) return raw;
    if (!raw) return "";
    const tag = raw.replace(/^https?:\/\/cash\.app\//i, "").replace(/^\$/, "").split("/")[0];
    if (!tag) return "";
    return "https://cash.app/$" + encodeURIComponent(tag) + "/" + Number(plan.price).toFixed(2);
  }

  /* ---------- Checkout modal ---------- */
  const modal = $("#buyModal");
  const titleEl = $("#buyTitle");
  const subEl = $("#buySub");
  const noteEl = $("#modalNote");
  const methods = [
    { el: $("#payStripe"), build: stripeLink, name: "card / Stripe" },
    { el: $("#payPayPal"), build: paypalLink, name: "PayPal" },
    { el: $("#payCashApp"), build: cashAppLink, name: "Cash App" }
  ];
  let activePlan = null;
  let lastFocus = null;

  function setNote(html, warn) {
    if (!noteEl) return;
    noteEl.innerHTML = html;
    noteEl.style.color = warn ? "var(--amber)" : "";
  }

  function openModal(planName) {
    const plan = plans[planName];
    if (!modal || !plan) return;
    activePlan = plan;
    lastFocus = document.activeElement;

    if (titleEl) titleEl.textContent = "Get " + plan.label;
    if (subEl) subEl.textContent = money(plan.price) + " / month · cancel anytime";

    methods.forEach((m) => {
      if (!m.el) return;
      const link = m.build(plan);
      m.el.disabled = !link;
      m.el.setAttribute("aria-disabled", String(!link));
      m.el.title = link ? "" : "Checkout launching soon";
      m.el.onclick = link
        ? () => window.open(link, "_blank", "noopener")
        : () =>
            setNote(
              "<b>" +
                m.name +
                " checkout is launching soon.</b> Payment links aren’t configured yet — try another method, or redeem giveaway balance in the app.",
              true
            );
    });

    if (!stripeLink(plan) && !paypalLink(plan) && !cashAppLink(plan)) {
      setNote(
        "<b>Checkout launching soon.</b> Card, PayPal and Cash App links haven’t been configured yet. Download the app and use the Free tier in the meantime — giveaway credit still works in-app.",
        true
      );
    } else {
      setNote(
        "After payment you receive a license key. Paste it in the app under <b>Settings → Account → License key</b> to activate your plan. Giveaway balance from your account can be applied before paying."
      );
    }

    modal.classList.add("open");
    document.body.style.overflow = "hidden";
    const first = modal.querySelector("button:not([disabled])");
    if (first) first.focus();
  }

  function closeModal() {
    if (!modal) return;
    modal.classList.remove("open");
    document.body.style.overflow = "";
    if (lastFocus && typeof lastFocus.focus === "function") lastFocus.focus();
  }

  $$("[data-buy]").forEach((btn) => {
    btn.addEventListener("click", () => openModal(btn.getAttribute("data-buy")));
  });

  if (modal) {
    $$("[data-close]", modal).forEach((el) => el.addEventListener("click", closeModal));
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && modal.classList.contains("open")) closeModal();
    });
  }

  // Expose for debugging / future in-app purchase handoff.
  window.NovaStore = {
    openCheckout: openModal,
    closeCheckout: closeModal,
    plans: plans
  };
})();
