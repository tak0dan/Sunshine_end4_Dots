#!/usr/bin/env bash
# Sunshine end-4 dots: end-4's illogical-impulse Hyprland dots + Sunshine's
# changes on top.
#
# One-line install (keep the "bash <(...)" form: the installers ask questions):
#   bash <(curl -fsSL https://raw.githubusercontent.com/tak0dan/Sunshine_end4_Dots/main/install.sh)
#
# Usage: install.sh [OPTIONS] [-- END4_SETUP_OPTIONS]
#   --skip-end4       don't run end-4's installer (only patch + extras)
#   --skip-packages   don't install the extra packages (packages.txt)
#   --skip-dates      don't ask for the important dates shown by fastfetch
#   --skip-services   don't run services.sh at the end
#   -y, --yes         don't ask about optional packages (installs required ones only)
#   -h, --help        show this help
# Anything after "--" goes to end-4's "./setup install" (see ./setup install -h).

set -euo pipefail

REPO_URL=https://github.com/tak0dan/Sunshine_end4_Dots.git
UPSTREAM_URL=https://github.com/end-4/dots-hyprland.git
# end-4 commit the patch was made against
BASE_COMMIT=2f2a376fdb2ad738bf55f693dd0b474b64bb0ab8

cache=${XDG_CACHE_HOME:-$HOME/.cache}
config=${XDG_CONFIG_HOME:-$HOME/.config}
SELF_DIR=$cache/sunshine_end4_dots
UPSTREAM_DIR=$cache/sunshine_end4_dots-upstream

bold=$'\e[1m' cyan=$'\e[36m' red=$'\e[31m' rst=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$bold$cyan" "$1" "$rst"; }
die() { printf '%serror:%s %s\n' "$red" "$rst" "$1" >&2; exit 1; }

skip_end4=false skip_packages=false skip_dates=false skip_services=false yes=false
end4_args=()
args=("$@")
while (( $# )); do
    case $1 in
        --skip-end4) skip_end4=true ;;
        --skip-packages) skip_packages=true ;;
        --skip-dates) skip_dates=true ;;
        --skip-services) skip_services=true ;;
        -y|--yes) yes=true ;;
        -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "${BASH_SOURCE[0]}" 2>/dev/null ||
                   echo "See https://github.com/tak0dan/Sunshine_end4_Dots"; exit 0 ;;
        --) shift; end4_args=("$@"); break ;;
        *) die "unknown option: $1 (see --help)" ;;
    esac
    shift
done

# ---------- preflight ----------
(( EUID != 0 )) || die "run this as your normal user, not as root (it uses sudo when needed)"
command -v pacman &>/dev/null || die "this installer supports Arch-based systems (pacman) only"
[[ -t 0 ]] || die "run it in a terminal: bash <(curl -fsSL ...), not curl ... | bash"
command -v git &>/dev/null || sudo pacman -S --needed --noconfirm git

# ---------- 0. get this repo (when started from the one-liner) ----------
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)
if [[ ! -f $here/patch/dots-hyprland.patch ]]; then
    step "Fetching Sunshine_end4_Dots"
    if [[ -d $SELF_DIR/.git ]]; then
        git -C "$SELF_DIR" pull --ff-only -q
    else
        git clone -q "$REPO_URL" "$SELF_DIR"
    fi
    exec bash "$SELF_DIR/install.sh" "${args[@]}"
fi
PATCH=$here/patch/dots-hyprland.patch

# ---------- 1. end-4's dots at the base commit, with the patch on top ----------
step "Preparing end-4's dots ($UPSTREAM_URL @ ${BASE_COMMIT:0:8})"
if [[ ! -e $UPSTREAM_DIR ]]; then
    git clone -q "$UPSTREAM_URL" "$UPSTREAM_DIR"
fi
git -C "$UPSTREAM_DIR" rev-parse --is-inside-work-tree &>/dev/null ||
    die "$UPSTREAM_DIR exists but is not a git repository; move it away and retry"

# This copy belongs to the installer: always start from the exact base commit
# (drops an older version of the patch), then apply the current patch
git -C "$UPSTREAM_DIR" reset -q --hard
git -C "$UPSTREAM_DIR" clean -qfd
if ! git -C "$UPSTREAM_DIR" cat-file -e "$BASE_COMMIT^{commit}" 2>/dev/null; then
    git -C "$UPSTREAM_DIR" fetch -q origin
fi
git -C "$UPSTREAM_DIR" checkout -q --detach "$BASE_COMMIT"
git -C "$UPSTREAM_DIR" apply --whitespace=nowarn "$PATCH"
echo "Patch applied"
git -C "$UPSTREAM_DIR" submodule update --init --recursive -q

# ---------- 2. end-4's installer (dependencies, services, config files) ----------
dates_dir=$config/fastfetch
keep=$(mktemp -d)
trap 'rm -rf "$keep"' EXIT
# end-4 syncs ~/.config/fastfetch with --delete: keep the user's dates
for f in custom-info.json from_tak_0; do
    [[ -e $dates_dir/$f ]] && cp -a "$dates_dir/$f" "$keep/"
done

if ! $skip_end4; then
    step "Running end-4's installer (./setup install ${end4_args[*]})"
    (cd "$UPSTREAM_DIR" && ./setup install "${end4_args[@]}")
fi

for f in custom-info.json from_tak_0; do
    if [[ -e $keep/$f ]]; then
        rm -rf "${dates_dir:?}/$f"
        cp -a "$keep/$f" "$dates_dir/"
    fi
done

# ---------- 3. files end-4's installer does not copy ----------
step "Installing Sunshine's extra files"
# end-4 only syncs hypr/hyprland and a few named files, not hypr/scripts
mkdir -p "$config/hypr/scripts"
cp -a "$UPSTREAM_DIR/dots/.config/hypr/scripts/." "$config/hypr/scripts/"
echo "hypr/scripts -> $config/hypr/scripts"
install -Dm755 "$here/extras/cpmatrix" "$HOME/.local/bin/cpmatrix"
echo "cpmatrix -> ~/.local/bin/cpmatrix"

# ---------- 4. extra packages ----------
if ! $skip_packages; then
    step "Extra packages (packages.txt)"
    repo_req=() repo_opt=() aur_req=() aur_opt=()
    while read -r name src need _; do
        [[ -z $name || $name == \#* ]] && continue
        pacman -T "$name" &>/dev/null && continue      # installed, or provided by another package
        case $src:$need in
            repo:required) repo_req+=("$name") ;;
            repo:optional) repo_opt+=("$name") ;;
            aur:required) aur_req+=("$name") ;;
            aur:optional) aur_opt+=("$name") ;;
        esac
    done < "$here/packages.txt"

    want_opt=false
    opt=("${repo_opt[@]}" "${aur_opt[@]}")
    if (( ${#opt[@]} )) && ! $yes; then
        echo "Optional packages not installed yet:"
        grep -E "^($(IFS='|'; echo "${opt[*]}"))[[:space:]]" "$here/packages.txt" | sed 's/^/  /'
        read -rp "Install the optional packages too? [y/N] " a
        [[ $a == [yY]* ]] && want_opt=true
    fi
    repo=("${repo_req[@]}") aur=("${aur_req[@]}")
    $want_opt && repo+=("${repo_opt[@]}") aur+=("${aur_opt[@]}")

    (( ${#repo[@]} )) && sudo pacman -S --needed "${repo[@]}"
    if (( ${#aur[@]} )); then
        helper=$(command -v paru || command -v yay || true)
        if [[ -n $helper ]]; then
            "$helper" -S --needed "${aur[@]}"
        else
            echo "No AUR helper (paru/yay) found; install these yourself: ${aur[*]}"
        fi
    fi
    (( ${#repo[@]} + ${#aur[@]} )) || echo "Nothing to install"
fi

# ---------- 5. important dates ----------
if ! $skip_dates; then
    step "Important dates (fastfetch)"
    if [[ -e $keep/custom-info.json || -e $keep/from_tak_0 ]]; then
        read -rp "You already have dates set. Change them now? [y/N] " a
        [[ $a == [yY]* ]] && bash "$here/scripts/set-dates.sh"
    else
        bash "$here/scripts/set-dates.sh"
    fi
fi

# ---------- 6. services ----------
if ! $skip_services; then
    step "Checking services"
    bash "$here/services.sh" || echo "Some checks need attention (see above); re-run $here/services.sh any time."
fi

step "Done"
echo "Log out and back in (or reboot) to start Hyprland with the new setup."
echo "Change the important dates later with: $here/scripts/set-dates.sh"
