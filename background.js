const blockedDomains = [
  "twitter.com",
  "x.com",
  "linkedin.com",
  "instagram.com"
];

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === "loading" && tab.url) {
    try {
      const targetUrl = new URL(tab.url);
      const isBlocked = blockedDomains.some(domain =>
        targetUrl.hostname === domain || targetUrl.hostname.endsWith("." + domain)
      );

      if (isBlocked) {
        // Redirect browser tab to your local index.html page
        const redirectUrl = chrome.runtime.getURL(
          `index.html?blocked=${encodeURIComponent(tab.url)}`
        );
        chrome.tabs.update(tabId, { url: redirectUrl });
      }
    } catch (e) {
      // Ignore internal URLs
    }
  }
});
