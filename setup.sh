#!/usr/bin/env bash
# setup.sh — fast-food-database (QuickBite)
# MongoDB 7 document database for the QuickBite fast-food chain: menu items,
# locations, customers, orders (with embedded items) and reviews, seeded with
# sample data. Part of the Business Builds series.
#
# Usage:
#   ./setup.sh          # same as: ./setup.sh docker
#   ./setup.sh docker   # bootstrap Docker, run MongoDB with Compose, seed + smoke test
#   ./setup.sh k8s      # bootstrap kubectl, run MongoDB on Kubernetes (StatefulSet), seed + smoke test
#   ./setup.sh down     # tear down (Docker Compose and/or Kubernetes; data kept)
#
# One-liner (fresh Ubuntu/Debian VM):
#   curl -fsSL https://raw.githubusercontent.com/UncleD0886475978/fast-food-database/main/setup.sh | bash
set -e

REPO_NAME="fast-food-database"
REPO="fast-food-database"
OWNER="UncleD0886475978"
REPO_URL="https://github.com/UncleD0886475978/${REPO_NAME}.git"
RUN_ONELINE="curl -fsSL https://raw.githubusercontent.com/${OWNER}/${REPO}/main/setup.sh | bash"

# ---------- pretty output ----------
if [ -t 1 ]; then
  BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
  BOLD=''; GREEN=''; CYAN=''; YELLOW=''; RED=''; NC=''
fi
step() { printf "\n${BOLD}${CYAN}==>${NC} ${BOLD}%s${NC}\n" "$*"; }
info() { printf "    %s\n" "$*"; }
ok()   { printf "${GREEN}  ✓ %s${NC}\n" "$*"; }
warn() { printf "${YELLOW}  ! %s${NC}\n" "$*"; }
die()  { printf "${RED}  ✗ %s${NC}\n" "$*" >&2; exit 1; }

# ---------- defaults (must match .env.example / k8s secret example) ----------
DB_NAME="${DB_NAME:-quickbite}"
DB_USER="${DB_USER:-quickbite}"
DB_PASSWORD="${DB_PASSWORD:-quickbite_change_me}"
DB_PORT="${DB_PORT:-27017}"
APP="fast-food-mongodb"
NS="quickbite"
MODE="${1:-docker}"

load_env() { if [ -f .env ]; then set -a; . ./.env; set +a; fi; }

# ---------- platform check + base bootstrap ----------
step "Platform check + base bootstrap (git, curl, ca-certificates, gnupg)"
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "ERROR: this script needs root or sudo to install packages." >&2
    exit 1
  fi
fi
APT=0
if [ "$(uname -s)" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then APT=1; fi
INSTALLED=""
APT_UPDATED=""
note_installed() { INSTALLED="${INSTALLED} $1"; }
apt_update_once() {
  if [ -z "${APT_UPDATED}" ]; then $SUDO apt-get update -y; APT_UPDATED=1; fi
}
apt_install() {
  apt_update_once
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "$@"
}
if [ "${APT}" -eq 1 ]; then
  BASE_PKGS=""
  command -v git >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} git"
  command -v curl >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} curl"
  [ -f /etc/ssl/certs/ca-certificates.crt ] || BASE_PKGS="${BASE_PKGS} ca-certificates"
  command -v gpg >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} gnupg"
  if [ -n "${BASE_PKGS}" ]; then
    info "Installing base tools:${BASE_PKGS}"
    # shellcheck disable=SC2086
    apt_install ${BASE_PKGS}
    note_installed "${BASE_PKGS}"
  else
    ok "Base tools already present (git, curl, ca-certificates, gnupg)"
  fi
else
  warn "Non-apt platform detected — this script can only auto-install on Ubuntu/Debian."
  info "Install git, curl, Docker and/or kubectl manually for your platform, then re-run."
  [ "$MODE" = "down" ] || exit 1
fi

# ---------- locate the repo (works for ./setup.sh and for curl | bash) ----------
step "Locating the repo checkout"
if [ -f "$0" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
  SCRIPT_DIR="$PWD"
fi
if [ -f "docker-compose.yml" ] && [ -f "seed.js" ]; then
  REPO_DIR="$PWD"
  info "Already inside the repo checkout: $REPO_DIR"
elif [ -f "${SCRIPT_DIR}/docker-compose.yml" ] && [ -f "${SCRIPT_DIR}/seed.js" ]; then
  REPO_DIR="$SCRIPT_DIR"
  info "Using script location: $REPO_DIR"
else
  REPO_DIR="$HOME/repos/$REPO_NAME"
  if [ -d "$REPO_DIR/.git" ]; then
    info "Existing checkout found — pulling latest..."
    git -C "$REPO_DIR" pull --ff-only || true
  else
    if ! command -v git >/dev/null 2>&1; then
      die "git not found. Install git first: https://git-scm.com/downloads"
    fi
    info "Cloning $REPO_URL into $REPO_DIR ..."
    mkdir -p "$HOME/repos"
    git clone "$REPO_URL" "$REPO_DIR"
  fi
fi
cd "$REPO_DIR"

# ---------- prerequisite installers ----------
DOCKER="docker"
install_docker() {
  if command -v docker >/dev/null 2>&1; then
    info "docker: already present ($(docker --version))"
  elif [ "${APT}" -eq 1 ]; then
    info "Installing Docker Engine via the official get.docker.com script..."
    curl -fsSL https://get.docker.com | $SUDO sh
    note_installed "docker"
  else
    return 1
  fi
  if ! docker info >/dev/null 2>&1 && ! $SUDO docker info >/dev/null 2>&1; then
    info "Starting the Docker daemon..."
    $SUDO systemctl enable --now docker 2>/dev/null || $SUDO service docker start 2>/dev/null || true
    for _i in $(seq 1 15); do
      if docker info >/dev/null 2>&1 || $SUDO docker info >/dev/null 2>&1; then break; fi
      sleep 2
    done
  fi
  if docker info >/dev/null 2>&1; then
    DOCKER="docker"
  elif $SUDO docker info >/dev/null 2>&1; then
    DOCKER="sudo docker"
    if [ "$(id -u)" -ne 0 ]; then
      $SUDO usermod -aG docker "$USER" 2>/dev/null || true
      info "NOTE: you were added to the 'docker' group (applies at next login); this run uses 'sudo docker'."
    fi
  else
    echo "ERROR: Docker is installed but the daemon could not be started." >&2
    echo "       On a VM:  sudo systemctl start docker   |   In a container/WSL without systemd, Docker cannot run here." >&2
    exit 1
  fi
  ok "Docker daemon OK (using: ${DOCKER})"
}

install_kubectl() {
  if command -v kubectl >/dev/null 2>&1; then info "kubectl: already present"; return 0; fi
  if [ "${APT}" -ne 1 ]; then return 1; fi
  if ! command -v sudo >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then return 1; fi
  info "Installing kubectl (official binary)..."
  KARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
  case "${KARCH}" in x86_64) KARCH="amd64" ;; aarch64) KARCH="arm64" ;; esac
  KVER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSLO "https://dl.k8s.io/release/${KVER}/bin/linux/${KARCH}/kubectl"
  $SUDO install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
  note_installed "kubectl"
}

need_docker() {
  step "Bootstrapping Docker"
  MISSING_LIST=""
  install_docker || MISSING_LIST="${MISSING_LIST} docker(https://docs.docker.com/get-docker/)"
  if [ -n "${MISSING_LIST}" ]; then
    die "could not auto-install on this platform. Missing:${MISSING_LIST} — install manually, then re-run."
  fi
  # shellcheck disable=SC2086
  if ! ${DOCKER} compose version >/dev/null 2>&1; then
    die "'docker compose' (v2 plugin) is not available. The get.docker.com installer normally includes it; on Debian/Ubuntu you can also run: sudo apt-get install -y docker-compose-plugin"
  fi
  ok "Docker + Compose ready"
}

need_kubectl() {
  step "Bootstrapping kubectl"
  MISSING_LIST=""
  install_kubectl || MISSING_LIST="${MISSING_LIST} kubectl(https://kubernetes.io/docs/tasks/tools/)"
  if [ -n "${MISSING_LIST}" ]; then
    die "could not auto-install kubectl on this platform. Missing:${MISSING_LIST} — install manually, then re-run."
  fi
  ok "kubectl: $(kubectl version --client 2>/dev/null | head -1 || echo present)"
  step "Checking Kubernetes access"
  if ! kubectl cluster-info >/dev/null 2>&1; then
    die "kubectl cannot reach a cluster. Start minikube / kind / Docker Desktop Kubernetes, or set your kubeconfig, then re-run. Easy local cluster: https://minikube.sigs.k8s.io/docs/start/"
  fi
  ok "kubectl connected to a cluster"
}

print_summary() {
  cat <<EOF

=================== BOOTSTRAP SUMMARY ===================
Installed during this run:${INSTALLED:- (nothing — all tools were already present)}
Working copy: ${REPO_DIR}
Next time, set up from scratch on any fresh Ubuntu VM with one line:
  ${RUN_ONELINE}
=========================================================
EOF
}

SMOKE_AGG='db.orders.aggregate([{$unwind:"$items"},{$group:{_id:"$items.name", qty:{$sum:"$items.qty"}, revenue:{$sum:{$multiply:["$items.qty","$items.unit_price"]}}}},{$sort:{qty:-1}},{$limit:5}]).forEach(printjson)'

# ---------- modes ----------
do_down() {
  step "Tearing down QuickBite MongoDB"
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1 && [ -f docker-compose.yml ]; then
    load_env
    docker compose down || true
    ok "Docker Compose stack stopped (data volume 'quickbite_mongodb_data' kept — add -v yourself if you really want it gone)"
  fi
  if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
    kubectl delete -f k8s/service.yaml -f k8s/statefulset.yaml -f k8s/pvc.yaml --ignore-not-found=true || true
    kubectl delete -f k8s/secret.yaml --ignore-not-found=true || true
    ok "Kubernetes resources deleted (namespace '$NS' and its data kept)"
  fi
  echo
  info "Done."
}

run_docker() {
  need_docker
  step "Preparing configuration"
  if [ ! -f .env ]; then cp .env.example .env; ok "Created .env from .env.example (edit it to change the password)"; else ok ".env already exists — using it"; fi
  load_env
  step "Starting MongoDB with Docker Compose"
  # shellcheck disable=SC2086
  ${DOCKER} compose up -d
  step "Waiting for MongoDB to accept connections"
  for i in $(seq 1 60); do
    # shellcheck disable=SC2086
    if ${DOCKER} compose exec -T db mongosh --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then ok "Database is ready"; break; fi
    if [ "$i" = "60" ]; then die "Database did not become ready in time. Check logs: docker compose logs db"; fi
    sleep 2
  done
  step "Loading sample data (seed.js)"
  # shellcheck disable=SC2086
  ${DOCKER} compose exec -T db mongosh -u "$DB_USER" -p "$DB_PASSWORD" --authenticationDatabase admin "$DB_NAME" < seed.js
  ok "Seed data loaded into database '$DB_NAME'"
  step "Smoke test — top-selling items (aggregation over embedded order items)"
  # shellcheck disable=SC2086
  ${DOCKER} compose exec -T db mongosh -u "$DB_USER" -p "$DB_PASSWORD" --authenticationDatabase admin "$DB_NAME" --quiet --eval "$SMOKE_AGG"
  ok "Smoke test passed"
  print_summary
  print_docker_info
}

print_docker_info() {
  step "QuickBite MongoDB is UP — connection info"
  info "Host:     localhost"
  info "Port:     $DB_PORT"
  info "Database: $DB_NAME"
  info "User:     $DB_USER   (admin/root user, auth database: admin)"
  info "Password: $DB_PASSWORD   (from .env — change it for anything real)"
  info "Connect:  mongosh \"mongodb://$DB_USER:$DB_PASSWORD@localhost:$DB_PORT/$DB_NAME?authSource=admin\""
  info "Shell:    docker compose exec db mongosh -u $DB_USER -p $DB_PASSWORD --authenticationDatabase admin $DB_NAME"
  echo
  info "Logs:  docker compose logs -f db"
  info "Stop:  ./setup.sh down        (or: docker compose down)"
}

run_k8s() {
  need_kubectl
  load_env
  step "Preparing Kubernetes manifests"
  if [ ! -f k8s/secret.yaml ]; then cp k8s/secret.example.yaml k8s/secret.yaml; ok "Created k8s/secret.yaml from the example (edit it to change the password)"; fi
  step "Applying manifests (namespace, secret, storage, StatefulSet, services)"
  kubectl apply -f k8s/namespace.yaml
  kubectl apply -f k8s/secret.yaml
  kubectl apply -f k8s/pvc.yaml
  kubectl apply -f k8s/statefulset.yaml
  kubectl apply -f k8s/service.yaml
  step "Waiting for the pod to be ready"
  kubectl -n "$NS" rollout status statefulset/"$APP" --timeout=300s
  ok "Pod is ready"
  POD="$(kubectl -n "$NS" get pod -l app="$APP" -o jsonpath='{.items[0].metadata.name}')"
  [ -n "$POD" ] || POD="${APP}-0"
  info "Seeding from pod: $POD"
  step "Loading sample data (seed.js copied into the pod)"
  kubectl -n "$NS" cp seed.js "$POD":/tmp/seed.js
  kubectl -n "$NS" exec "$POD" -- mongosh -u "$DB_USER" -p "$DB_PASSWORD" --authenticationDatabase admin "$DB_NAME" /tmp/seed.js
  ok "Seed data loaded into database '$DB_NAME'"
  step "Smoke test — top-selling items (aggregation over embedded order items)"
  kubectl -n "$NS" exec "$POD" -- mongosh -u "$DB_USER" -p "$DB_PASSWORD" --authenticationDatabase admin "$DB_NAME" --quiet --eval "$SMOKE_AGG"
  ok "Smoke test passed"
  print_summary
  step "QuickBite MongoDB is UP on Kubernetes — how to connect"
  info "Port-forward (run this, leave it open):"
  info "  kubectl -n $NS port-forward svc/$APP 27017:27017"
  info "Then connect from another terminal:"
  info "  mongosh \"mongodb://$DB_USER:$DB_PASSWORD@localhost:27017/$DB_NAME?authSource=admin\""
  echo
  info "Logs:  kubectl -n $NS logs statefulset/$APP -f"
  info "Stop:  ./setup.sh down"
}

case "$MODE" in
  docker) run_docker ;;
  k8s)    run_k8s ;;
  down)   do_down ;;
  *) echo "Usage: ./setup.sh [docker|k8s|down]" >&2; exit 1 ;;
esac
