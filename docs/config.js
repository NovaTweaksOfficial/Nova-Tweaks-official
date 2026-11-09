/*
  Nova Tweaks storefront configuration.
  Fill in the checkout links below and the Buy buttons go live immediately.

  Stripe Payment Link:  https://buy.stripe.com/...
  PayPal link:          https://www.paypal.com/paypalme/yourname/5.99
  Cash App:             either a full link or just your $cashtag, e.g. "$NovaTweaks"
*/
window.NOVA_CONFIG = {
  version: "v1",

  // Legacy/fallback Windows download (combined build). Prefer per-product URLs when separate builds are published.
  windowsDownload: "https://github.com/NovaTweaksOfficial/Nova-Tweaks-official/releases/latest/download/NovaTweaks.exe",
  windowsFortniteDownload: "https://github.com/NovaTweaksOfficial/Nova-Tweaks-official/releases/latest/download/NovaTweaks-Fortnite-Windows.exe",
  windowsMinecraftDownload: "https://github.com/NovaTweaksOfficial/Nova-Tweaks-official/releases/latest/download/NovaTweaks-Minecraft-Windows.exe",
  macMinecraftDownload: "https://github.com/NovaTweaksOfficial/Nova-Tweaks-official/releases/latest/download/Nova-Tweaks-Minecraft-macOS.zip",
  github: "https://github.com/NovaTweaksOfficial/Nova-Tweaks-official",

  // Optional trust links
  virusTotal: "",
  supportEmail: "",

  pro: {
    label: "Pro",
    price: 5.99,
    // Direct checkout (e.g. SellAuth). When set, Buy opens this URL.
    checkout: "https://nova-tweaks.mysellauth.com/product/nova-tweaks-pro",
    stripe: "",
    paypal: "",
    cashapp: ""
  },

  ultimate: {
    label: "Ultimate",
    price: 12.99,
    // Direct checkout (e.g. SellAuth). When set, Buy opens this URL.
    checkout: "https://nova-tweaks.mysellauth.com/product/nova-tweaks-ultimate",
    stripe: "",
    paypal: "",
    cashapp: ""
  }
};
