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
  windowsDownload: "https://github.com/NovaTweaksOfficial/fl3sh-optimizer/releases/latest/download/NovaTweaks.exe",
  windowsFortniteDownload: "",
  windowsMinecraftDownload: "",
  macMinecraftDownload: "downloads/Nova-Tweaks-Minecraft-macOS.zip",
  github: "https://github.com/NovaTweaksOfficial/fl3sh-optimizer",

  // Optional trust links
  virusTotal: "",
  supportEmail: "",

  pro: {
    label: "Pro",
    price: 5.99,
    stripe: "",
    paypal: "",
    cashapp: ""
  },

  ultimate: {
    label: "Ultimate",
    price: 12.99,
    stripe: "",
    paypal: "",
    cashapp: ""
  }
};
