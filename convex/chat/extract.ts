const MAX_CONTENT_CHARS = 20000;

export function truncateToChars(text: string, max: number): string {
  return text.length <= max ? text : text.slice(0, max);
}

export function extractTextFromHtml(html: string): string {
  let text = html
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, "")
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, "")
    .replace(/<header[^>]*>[\s\S]*?<\/header>/gi, "")
    .replace(/<footer[^>]*>[\s\S]*?<\/footer>/gi, "")
    .replace(/<nav[^>]*>[\s\S]*?<\/nav>/gi, "")
    .replace(/<aside[^>]*>[\s\S]*?<\/aside>/gi, "")
    .replace(/<iframe[^>]*>[\s\S]*?<\/iframe>/gi, "")
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(/<(p|div|h[1-6])[^>]*>/gi, "\n\n")
    .replace(/<br[^>]*>/gi, "\n")
    .replace(/<\/(p|div|h[1-6]|li|tr)[^>]*>/gi, "\n")
    .replace(/<\/li[^>]*>/gi, "\n")
    .replace(/<li[^>]*>/gi, "• ")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&mdash;/g, "—")
    .replace(/&ndash;/g, "–")
    .replace(/&hellip;/g, "...")
    .replace(/&#(\d+);/g, (_m, c: string) => String.fromCharCode(Number(c)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_m, c: string) =>
      String.fromCharCode(parseInt(c, 16)),
    )
    .replace(/\n\s*\n\s*\n+/g, "\n\n")
    .replace(/[ \t]+/g, " ")
    .replace(/•\s*\n/g, "\n")
    .replace(/\n\s*•\s*\n/g, "\n")
    .replace(/^\s*•\s*\n/gm, "")
    .replace(/^\s*•\s*$/gm, "");
  return text.trim();
}

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("timeout")), ms);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (error) => {
        clearTimeout(timer);
        reject(error);
      },
    );
  });
}

export async function fetchUrlContent(
  url: string,
): Promise<{ text?: string; error?: string }> {
  if (!/^https?:\/\//i.test(url)) {
    return { error: "Unsupported URL scheme" };
  }
  try {
    const response = await withTimeout(
      fetch(url, {
        redirect: "follow",
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          Accept:
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          "Accept-Language": "en-US,en;q=0.9",
        },
      }),
      15000,
    );
    if (!response.ok) {
      return { error: `HTTP ${response.status}` };
    }
    const html = await response.text();
    const text = extractTextFromHtml(html);
    if (!text) {
      return { error: "No readable text found" };
    }
    return { text: truncateToChars(text, MAX_CONTENT_CHARS) };
  } catch {
    return { error: "Fetch failed" };
  }
}
