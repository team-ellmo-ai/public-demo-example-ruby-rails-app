# shellcheck shell=bash
# Shared Ruby toolchain helpers, sourced by scripts/setup.sh and scripts/dev.sh.
#
#   ensure_ruby  — make the Ruby pinned in .ruby-version (and the Bundler pinned
#                  in Gemfile.lock) available, installing them if needed.
#   use_ruby     — put an already-installed pinned Ruby first on PATH; fails if
#                  it isn't installed yet.
#
# Install order of preference: an existing mise/rvm/rbenv/asdf, otherwise mise is
# installed (Homebrew if present, else the official https://mise.run installer
# into ~/.local/bin). Nothing is written to your shell profile.

RUBY_REQUIRED="$(sed -e 's/^ruby-//' -e 's/[[:space:]]//g' .ruby-version)"
BUNDLER_REQUIRED="$(awk '/^BUNDLED WITH/{getline; gsub(/[[:space:]]/, ""); print}' Gemfile.lock)"

_ruby_matches() {
  command -v ruby &>/dev/null &&
    [ "$(ruby -e 'print RUBY_VERSION' 2>/dev/null)" = "$RUBY_REQUIRED" ]
}

# Prints the bin dir of the pinned Ruby if some manager already installed it.
_ruby_bin_dir() {
  local dir=""
  if command -v mise &>/dev/null; then
    dir="$(mise where "ruby@$RUBY_REQUIRED" 2>/dev/null || true)"
  fi
  if [ -z "$dir" ] && [ -d "$HOME/.rvm/rubies/ruby-$RUBY_REQUIRED" ]; then
    dir="$HOME/.rvm/rubies/ruby-$RUBY_REQUIRED"
  fi
  if [ -z "$dir" ] && command -v rbenv &>/dev/null; then
    dir="$(rbenv root)/versions/$RUBY_REQUIRED"
  fi
  if [ -z "$dir" ] && command -v asdf &>/dev/null; then
    dir="$(asdf where ruby "$RUBY_REQUIRED" 2>/dev/null || true)"
  fi
  if [ -n "$dir" ] && [ -x "$dir/bin/ruby" ]; then
    echo "$dir/bin"
  fi
}

use_ruby() {
  # mise's standalone installer drops the binary here; make it findable.
  [ -x "$HOME/.local/bin/mise" ] && export PATH="$HOME/.local/bin:$PATH"
  _ruby_matches && return 0
  local bin
  bin="$(_ruby_bin_dir)"
  if [ -z "$bin" ]; then
    echo "✗ Ruby $RUBY_REQUIRED is not installed. Run ./scripts/setup.sh first." >&2
    return 1
  fi
  export PATH="$bin:$PATH"
  hash -r
}

_install_build_deps() {
  case "$(uname -s)" in
    Darwin)
      if ! xcode-select -p &>/dev/null; then
        echo "✗ Xcode Command Line Tools are required to build Ruby." >&2
        echo "  Run: xcode-select --install   (then re-run this script)" >&2
        return 1
      fi
      if command -v brew &>/dev/null; then
        local pkg missing=()
        for pkg in openssl@3 libyaml gmp; do
          brew list --versions "$pkg" &>/dev/null || missing+=("$pkg")
        done
        if [ ${#missing[@]} -gt 0 ]; then
          echo "→ Installing Ruby build dependencies: ${missing[*]}"
          HOMEBREW_NO_AUTO_UPDATE=1 brew install "${missing[@]}"
        fi
      fi
      ;;
    Linux)
      if command -v apt-get &>/dev/null; then
        local sudo=""
        [ "$(id -u)" -ne 0 ] && sudo="sudo"
        echo "→ Installing Ruby build dependencies (apt)..."
        $sudo apt-get update -qq
        $sudo apt-get install -y -qq build-essential curl git libssl-dev \
          libyaml-dev zlib1g-dev libffi-dev libgmp-dev libreadline-dev
      fi
      ;;
  esac
}

_ensure_manager() {
  if command -v mise &>/dev/null || [ -x "$HOME/.rvm/bin/rvm" ] || command -v rbenv &>/dev/null || command -v asdf &>/dev/null; then
    return 0
  fi
  echo "→ No Ruby version manager found — installing mise..."
  if command -v brew &>/dev/null; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew install mise
  else
    curl -fsSL https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
  command -v mise &>/dev/null
}

ensure_ruby() {
  if ! use_ruby 2>/dev/null; then
    echo "→ Ruby $RUBY_REQUIRED not found (have: $(ruby -v 2>/dev/null || echo none))."
    _ensure_manager
    _install_build_deps
    echo "→ Installing Ruby $RUBY_REQUIRED (compiles from source; a few minutes the first time)..."
    if command -v mise &>/dev/null; then
      mise install "ruby@$RUBY_REQUIRED"
    elif [ -x "$HOME/.rvm/bin/rvm" ]; then
      "$HOME/.rvm/bin/rvm" install "ruby-$RUBY_REQUIRED"
    elif command -v rbenv &>/dev/null; then
      rbenv install --skip-existing "$RUBY_REQUIRED"
    else
      asdf plugin add ruby 2>/dev/null || true
      asdf install ruby "$RUBY_REQUIRED"
    fi
    use_ruby
  fi
  echo "✓ Ruby $(ruby -e 'print RUBY_VERSION') ($(command -v ruby))"

  if ! gem list -i bundler -v "$BUNDLER_REQUIRED" &>/dev/null; then
    echo "→ Installing Bundler $BUNDLER_REQUIRED..."
    gem install bundler -v "$BUNDLER_REQUIRED" --no-document
  fi
  echo "✓ Bundler $BUNDLER_REQUIRED"
}
