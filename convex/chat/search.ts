export type SearchResult = {
  title: string;
  url: string;
  snippet: string;
};

const MAX_RESULTS = 5;
const MAX_SNIPPET_CHARS = 2000;
const TIMEOUT_MS = 10000;

function truncate(text: string, max: number): string {
  if (text.length <= max) return text;
  return `${text.slice(0, max).trimEnd()}...`;
}

function dedupeByUrl(results: SearchResult[]): SearchResult[] {
  const seen = new Set<string>();
  const out: SearchResult[] = [];
  for (const result of results) {
    const key = result.url.replace(/^https?:\/\//i, "").replace(/\/+$/, "").toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(result);
    if (out.length >= MAX_RESULTS) break;
  }
  return out;
}

type ProviderAdapter = {
  name: string;
  key: string | undefined;
  search: (query: string, apiKey: string) => Promise<SearchResult[]>;
};

async function tavilySearch(query: string, apiKey: string): Promise<SearchResult[]> {
  const response = await fetch("https://api.tavily.com/search", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      api_key: apiKey,
      query,
      max_results: MAX_RESULTS,
      search_depth: "basic",
      include_answer: false,
    }),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`tavily ${response.status}`);
  const data = (await response.json()) as { results?: Array<{ title?: string; url?: string; content?: string }> };
  return (data.results ?? []).map((r) => ({
    title: r.title ?? "",
    url: r.url ?? "",
    snippet: truncate(r.content ?? "", MAX_SNIPPET_CHARS),
  }));
}

async function serperSearch(query: string, apiKey: string): Promise<SearchResult[]> {
  const response = await fetch("https://google.serper.dev/search", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-API-KEY": apiKey,
    },
    body: JSON.stringify({ q: query, num: MAX_RESULTS }),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`serper ${response.status}`);
  const data = (await response.json()) as { organic?: Array<{ title?: string; link?: string; snippet?: string }> };
  return (data.organic ?? []).map((r) => ({
    title: r.title ?? "",
    url: r.link ?? "",
    snippet: truncate(r.snippet ?? "", MAX_SNIPPET_CHARS),
  }));
}

async function exaSearch(query: string, apiKey: string): Promise<SearchResult[]> {
  const response = await fetch("https://api.exa.ai/search", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
    },
    body: JSON.stringify({
      query,
      numResults: MAX_RESULTS,
      contents: { text: { maxCharacters: MAX_SNIPPET_CHARS } },
    }),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`exa ${response.status}`);
  const data = (await response.json()) as { results?: Array<{ title?: string; url?: string; text?: string }> };
  return (data.results ?? []).map((r) => ({
    title: r.title ?? "",
    url: r.url ?? "",
    snippet: truncate(r.text ?? "", MAX_SNIPPET_CHARS),
  }));
}

const PROVIDERS: ProviderAdapter[] = [
  { name: "tavily", key: process.env.TAVILY_API_KEY, search: tavilySearch },
  { name: "serper", key: process.env.SERPER_API_KEY, search: serperSearch },
  { name: "exa", key: process.env.EXA_API_KEY, search: exaSearch },
];

export async function searchWeb(
  query: string,
): Promise<{ results: SearchResult[]; provider: string } | null> {
  for (const provider of PROVIDERS) {
    if (!provider.key) continue;
    try {
      const raw = await provider.search(query, provider.key);
      const results = dedupeByUrl(raw.filter((r) => r.url));
      if (results.length > 0) {
        return { results, provider: provider.name };
      }
    } catch {
      continue;
    }
  }
  return null;
}

export function formatSearchResults(
  results: SearchResult[],
  provider: string,
): string {
  if (results.length === 0) return "";
  const lines = results.map(
    (r, index) => `[${index + 1}] ${r.title}\n${r.url}\n${r.snippet}`,
  );
  return `\n\nWeb search results (via ${provider}):\n${lines.join("\n\n")}`;
}
