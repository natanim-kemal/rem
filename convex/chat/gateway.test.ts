import { describe, expect, it } from "vitest";
import { buildChatCompletionsUrl, buildSystemPrompt } from "./gateway";

describe("buildChatCompletionsUrl", () => {
  it("appends v1 chat completions path", () => {
    expect(buildChatCompletionsUrl("http://localhost:20128")).toBe(
      "http://localhost:20128/v1/chat/completions",
    );
  });

  it("strips trailing slashes", () => {
    expect(buildChatCompletionsUrl("https://gw.example.com/")).toBe(
      "https://gw.example.com/v1/chat/completions",
    );
  });
});

describe("buildSystemPrompt", () => {
  it("includes the article text", () => {
    expect(buildSystemPrompt("Some article text", false)).toContain(
      "Some article text",
    );
  });

  it("notes limited context", () => {
    expect(buildSystemPrompt("Title only", true)).toContain("limited");
  });
});
