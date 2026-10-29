# Public CI fixture only. The CI preparation script substitutes this package
# so Kim configuration checks never fetch or publish the private application.
{runCommand, ...}:
runCommand "food-tracker-ci-stub" {} ''
  mkdir -p "$out"
  printf '%s\n' '<!doctype html><title>CI fixture</title>' > "$out/index.html"
''
