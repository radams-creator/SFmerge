const CONTEXT_MENU_ID = "copy-salesforce-id";

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: CONTEXT_MENU_ID,
    title: "Copy Salesforce ID",
    contexts: ["link", "page"],
    targetUrlPatterns: [
      "https://*.lightning.force.com/lightning/r/Account/*/view"
    ]
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (!tab || !tab.id) {
    return;
  }

  const urlToInspect = info.linkUrl || info.pageUrl;
  if (!urlToInspect) {
    notifyFailure(tab.id, "No URL detected");
    return;
  }

  const recordId = extractSalesforceId(urlToInspect);
  if (!recordId) {
    notifyFailure(tab.id, "No Salesforce ID found in link");
    return;
  }

  try {
    await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: copyTextToClipboard,
      args: [recordId]
    });
    await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: showToast,
      args: [recordId]
    });
  } catch (error) {
    console.error("Failed to copy Salesforce ID", error);
    notifyFailure(tab.id, "Unable to copy ID");
  }
});

function extractSalesforceId(url) {
  const match = url.match(/\/Account\/([A-Za-z0-9]{15,18})(?:\/|$)/);
  return match ? match[1] : null;
}

function notifyFailure(tabId, message) {
  chrome.scripting.executeScript({
    target: { tabId },
    func: showToast,
    args: [message, true]
  });
}

function copyTextToClipboard(text) {
  navigator.clipboard.writeText(text).catch((error) => {
    console.error("Clipboard write failed", error);
    alert(`Unable to copy Salesforce ID: ${error.message}`);
  });
}

function showToast(text, isError = false) {
  const existing = document.getElementById("sf-copy-toast");
  if (existing) {
    existing.remove();
  }

  const toast = document.createElement("div");
  toast.id = "sf-copy-toast";
  toast.textContent = text;
  toast.style.position = "fixed";
  toast.style.bottom = "24px";
  toast.style.right = "24px";
  toast.style.padding = "12px 16px";
  toast.style.borderRadius = "6px";
  toast.style.fontFamily = "Arial, sans-serif";
  toast.style.fontSize = "14px";
  toast.style.boxShadow = "0 4px 12px rgba(0, 0, 0, 0.2)";
  toast.style.backgroundColor = isError ? "#b3261e" : "#1b5e20";
  toast.style.color = "#fff";
  toast.style.zIndex = 2147483647;
  toast.style.opacity = "0";
  toast.style.transition = "opacity 0.2s ease";

  document.body.appendChild(toast);
  requestAnimationFrame(() => {
    toast.style.opacity = "1";
  });

  setTimeout(() => {
    toast.style.opacity = "0";
    toast.addEventListener("transitionend", () => {
      if (toast.parentElement) {
        toast.parentElement.removeChild(toast);
      }
    }, { once: true });
  }, isError ? 2500 : 1500);
}
