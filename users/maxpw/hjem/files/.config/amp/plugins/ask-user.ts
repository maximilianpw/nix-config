import type { PluginAPI } from "@ampcode/plugin";

export const description = "Presents a concise ask_user choice dialog with an optional custom answer.";

type AskUserInput = {
  question: string;
  options: Array<{ label: string; description?: string }>;
};

export default function askUser(amp: PluginAPI) {
  amp.registerTool({
    name: "ask_user",
    title: "Ask user",
    description: "Ask the user one focused multiple-choice question when their answer is required to continue. Provide 2–5 distinct options; the user may enter another answer.",
    inputSchema: {
      type: "object",
      properties: {
        question: { type: "string", description: "The focused question to ask" },
        options: {
          type: "array",
          minItems: 2,
          maxItems: 5,
          items: {
            type: "object",
            properties: {
              label: { type: "string", description: "Short option label" },
              description: { type: "string", description: "Optional explanation" },
            },
            required: ["label"],
          },
        },
      },
      required: ["question", "options"],
    },
    async execute(raw, ctx) {
      const input = raw as AskUserInput;
      if (!Array.isArray(input.options) || input.options.length < 2 || input.options.length > 5) {
        throw new Error(`ask_user requires 2–5 options (received ${input.options?.length ?? 0})`);
      }
      const labels = input.options.map(({ label, description }) => description ? `${label} — ${description}` : label);
      const answer = await ctx.ui.select({
        title: input.question,
        options: labels,
        allowOther: true,
      });
      if (answer === undefined) return "The user cancelled without answering.";
      const index = labels.indexOf(answer);
      return index >= 0
        ? `The user selected: ${input.options[index].label}`
        : `The user answered: ${answer}`;
    },
  });
}
