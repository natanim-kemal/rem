import { query } from "../_generated/server";

export type ProviderModel = {
  id: string;
  label: string;
  model: string;
  provider: string;
  providerLabel: string;
  baseUrl: string;
  tools: boolean;
};

export const MODEL_CATALOG: ProviderModel[] = [
  {
    id: "groq:llama-3.3-70b-versatile",
    label: "Llama 3.3 70B Versatile",
    model: "llama-3.3-70b-versatile",
    provider: "groq",
    providerLabel: "Groq",
    baseUrl: "https://api.groq.com/openai/v1",
    tools: true,
  },
  {
    id: "groq:llama-3.1-8b-instant",
    label: "Llama 3.1 8B Instant",
    model: "llama-3.1-8b-instant",
    provider: "groq",
    providerLabel: "Groq",
    baseUrl: "https://api.groq.com/openai/v1",
    tools: true,
  },
  {
    id: "openrouter:openai/gpt-oss-20b:free",
    label: "OpenAI GPT OSS 20B (free)",
    model: "openai/gpt-oss-20b:free",
    provider: "openrouter",
    providerLabel: "OpenRouter",
    baseUrl: "https://openrouter.ai/api/v1",
    tools: true,
  },
  {
    id: "openrouter:nvidia/nemotron-3-ultra-550b-a55b:free",
    label: "NVIDIA Nemotron 3 Ultra (free)",
    model: "nvidia/nemotron-3-ultra-550b-a55b:free",
    provider: "openrouter",
    providerLabel: "OpenRouter",
    baseUrl: "https://openrouter.ai/api/v1",
    tools: true,
  },
  {
    id: "mistral:mistral-small-latest",
    label: "Mistral Small Latest",
    model: "mistral-small-latest",
    provider: "mistral",
    providerLabel: "Mistral",
    baseUrl: "https://api.mistral.ai/v1",
    tools: true,
  },
  {
    id: "mistral:mistral-large-latest",
    label: "Mistral Large Latest",
    model: "mistral-large-latest",
    provider: "mistral",
    providerLabel: "Mistral",
    baseUrl: "https://api.mistral.ai/v1",
    tools: true,
  },
  {
    id: "sambanova:Meta-Llama-3.3-70B-Instruct",
    label: "Meta Llama 3.3 70B Instruct",
    model: "Meta-Llama-3.3-70B-Instruct",
    provider: "sambanova",
    providerLabel: "SambaNova",
    baseUrl: "https://api.sambanova.ai/v1",
    tools: false,
  },
  {
    id: "sambanova:DeepSeek-V3.2",
    label: "DeepSeek V3.2",
    model: "DeepSeek-V3.2",
    provider: "sambanova",
    providerLabel: "SambaNova",
    baseUrl: "https://api.sambanova.ai/v1",
    tools: false,
  },
];

const MODEL_LOOKUP = new Map(MODEL_CATALOG.map((m) => [m.id, m]));

export const DEFAULT_MODEL_ID = "groq:llama-3.3-70b-versatile";

export type ResolvedModel = {
  model: string;
  baseUrl: string;
  tools: boolean;
  provider: string;
};

export function resolveModel(modelId?: string): ResolvedModel | null {
  if (!modelId) {
    const baseUrl = process.env.CHAT_GATEWAY_URL;
    const model = process.env.CHAT_MODEL || "auto";
    if (!baseUrl) return null;
    return { model, baseUrl, tools: false, provider: "default" };
  }
  const entry = MODEL_LOOKUP.get(modelId);
  if (!entry) return null;
  return {
    model: entry.model,
    baseUrl: entry.baseUrl,
    tools: entry.tools,
    provider: entry.provider,
  };
}

export function providerApiKey(provider: string): string | undefined {
  switch (provider) {
    case "groq":
      return process.env.CHAT_GATEWAY_KEY;
    case "openrouter":
      return process.env.OPENROUTER_API_KEY;
    case "mistral":
      return process.env.MISTRAL_API_KEY;
    case "sambanova":
      return process.env.SAMBANOVA_API_KEY;
    default:
      return process.env.CHAT_GATEWAY_KEY;
  }
}

export const listModels = query({
  args: {},
  handler: () => {
    const providers = new Map<string, string>();
    for (const model of MODEL_CATALOG) {
      providers.set(model.provider, model.providerLabel);
    }
    const providerList = Array.from(providers.entries()).map(
      ([id, label]) => ({ id, label }),
    );
    const models = MODEL_CATALOG.map((m) => ({
      id: m.id,
      label: m.label,
      provider: m.provider,
      tools: m.tools,
    }));
    return { providers: providerList, models };
  },
});
