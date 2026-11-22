# Skills every agent gets. Repositories are pinned in ./npins; `make
# update-skills` moves them.
let
  pins = import ./npins;

  from = pin: directory: include: {
    path = "${pin}/${directory}";
    inherit include;
  };
in {
  mine = {
    path = pins.agent-skills;
    # Maintains that repository; of no use anywhere else.
    exclude = ["update-upstream-skills"];
  };

  bro = from pins.bro "skills" ["bro"];
  clerk = from pins.clerk-skills "skills" ["clerk-webhooks"];
  cua = from pins.cua "libs/cua/skills" ["cua-sandboxes" "cua-spaces" "cua-volume"];
  gui-automation = "${pins.cua}/skills/gui-automation";
  emilkowalski = from pins.emilkowalski-skills "skills" ["emil-design-eng"];
  improve = "${pins.shadcn-improve}/skills/improve";
  jakubkrehel = from pins.jakubkrehel-skills "skills" ["better-ui"];
  mattpocock = from pins.mattpocock-skills "skills" [
    "code-review"
    "codebase-design"
    "diagnosing-bugs"
    "domain-modeling"
    "grill-me"
    "handoff"
    "research"
    "tdd"
    "teach"
    "wait-what"
    "wizard"
    "writing-for-agents"
  ];
  # The repository repeats these under one directory per harness; `core` is
  # the harness-neutral copy.
  plannotator = from pins.plannotator "apps/skills/core" [
    "plannotator"
    "plannotator-annotate"
    "plannotator-inbox"
    "plannotator-last"
    "plannotator-review"
  ];
  plannotator-extra = from pins.plannotator "apps/skills/extra" [
    "plannotator-compound"
    "plannotator-setup-goal"
    "plannotator-visual-explainer"
  ];
  planetscale = pins.planetscale-skills;
  # The stub `rex skill setup` writes, kept byte for byte so `rex skill status`
  # still reads it as current. It only defers to the installed rex command, so
  # it needs replacing only when Rex changes the stub format.
  rex = ../rex/agent-skill;
  show-me = "${pins.humanlayer-skills}/plugins/show-me/skills/show-me";
  typesafe-ai = "${pins.typesafe-ai-skills}/skills/typesafe-ai";
  unslop = "${pins.cursor-plugins}/harness/pstack/claude-code/skills/unslop";
  visual-explainer = "${pins.visual-explainer}/plugins/visual-explainer";
}
