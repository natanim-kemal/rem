import { describe, expect, it } from "vitest";
import { extractTextFromHtml, truncateToChars } from "./extract";

describe("extractTextFromHtml", () => {
  it("strips tags and decodes entities", () => {
    const html =
      "<html><head><style>p{}</style></head><body><h1>Title</h1><p>Hello &amp; goodbye</p><script>bad()</script></body></html>";
    expect(extractTextFromHtml(html)).toBe("Title\n\nHello & goodbye");
  });

  it("removes nav, footer and iframe blocks", () => {
    const html = "<nav>menu</nav><p>Main</p><footer>foot</footer><iframe src=\"x\"></iframe>";
    expect(extractTextFromHtml(html)).toBe("Main");
  });

  it("returns empty string when nothing remains", () => {
    expect(extractTextFromHtml("<script>x</script>")).toBe("");
  });
});

describe("truncateToChars", () => {
  it("caps long text at max", () => {
    expect(truncateToChars("a".repeat(30000), 8000).length).toBe(8000);
  });

  it("keeps short text unchanged", () => {
    expect(truncateToChars("hi", 8000)).toBe("hi");
  });
});
