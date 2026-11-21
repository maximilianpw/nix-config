{
  # The stub `rex skill setup` writes, kept byte for byte so `rex skill status`
  # still reads it as current. It only defers to the installed rex command, so
  # it needs replacing only when Rex changes the stub format.
  agents.defaults.skills.sources.rex = ./agent-skill;
}
