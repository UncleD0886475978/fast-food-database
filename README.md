<div align="center">

# 🍔 fast-food-database

### MongoDB 7 for the QuickBite fast-food chain — menu, locations, customers, orders & reviews in one command.

Part of the **Business Builds** series — real-world themed database + DevOps projects:
one business per repo, Docker for your laptop, Kubernetes for the cloud.

![MongoDB](https://img.shields.io/badge/MongoDB-7-47A248?logo=mongodb&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-StatefulSet-326CE5?logo=kubernetes&logoColor=white)
![Business Builds](https://img.shields.io/badge/Project-Business%20Builds-success)

</div>

---

## 🚀 Quick start

**One line on a fresh Ubuntu/Debian VM** (installs Docker itself, starts MongoDB, seeds it, and proves it works):

```bash
curl -fsSL https://raw.githubusercontent.com/UncleD0886475978/fast-food-database/main/setup.sh | bash
```

Already have the repo cloned? Same thing, locally:

```bash
./setup.sh          # Docker mode (default)
./setup.sh k8s      # Kubernetes mode (StatefulSet)
./setup.sh down     # stop everything (data is kept)
```

## 🌟 What you get

| Feature | What you get |
|---|---|
| 🚀 **One-command install** | `setup.sh` installs its own prerequisites (Docker / kubectl), starts MongoDB, seeds sample data, and runs a real aggregation smoke test |
| 🍔 **A real business dataset** | `seed.js` loads the QuickBite menu (10 items), 3 locations, 5 customers, 8 orders and 5 reviews — with references that actually line up |
| 🐳 **Docker mode** | Compose stack with a named volume, native `mongosh` healthcheck, and safe change-me defaults in `.env` |
| ☸️ **Kubernetes mode** | `./setup.sh k8s` — StatefulSet + 10Gi PVC + Secret + ClusterIP & headless services in the `quickbite` namespace, seeded right in the pod |
| 💾 **Persistent data** | Your data survives restarts in both modes (Docker volume / Kubernetes PVC) |
| 🔑 **Consistent credentials** | Same db / user / password in Compose, Kubernetes, and this README — no hunting around |
| 🧪 **Proven working** | The installer doesn't just start it — it runs a top-selling-items aggregation over real seeded orders before calling it done |

## 🍔 The QuickBite story

QuickBite is a small fast-food chain: three locations (Downtown, Riverside, Airport Road),
a counter / drive-thru / mobile-app ordering mix, and a loyalty program. Its data is a natural
fit for a **document database**: menus change often, every location sells a slightly different
mix, and an order is a self-contained snapshot of what someone bought.

### Why orders embed their items

In `orders`, the purchased items live **inside** the order document — each with the item's
`menu_item_id`, its name, quantity, and the `unit_price` **as sold**:

```javascript
{
  customer_id: ObjectId("…"),          // reference — customers live in their own collection
  location_id: ObjectId("…"),          // reference
  channel: "drive_thru",
  status: "completed",
  items: [                             // embedded — read and written together with the order
    { menu_item_id: ObjectId("…"), name: "Double Smash Burger", qty: 2, unit_price: 11.49 },
    { menu_item_id: ObjectId("…"), name: "French Fries",        qty: 2, unit_price: 3.49 }
  ],
  total: 34.94,
  ordered_at: ISODate("2026-11-06T17:48:00Z")
}
```

That's the document-model rule of thumb: **data that is read together is stored together.**
An order is always fetched whole (receipt, kitchen ticket, sales report), never item-by-item —
and because the price is copied in at sale time, a later menu price change never rewrites
history. Customers and locations, which are shared and change independently, stay in their
own collections and are referenced by `ObjectId`.

## 🗂️ Collections

| Collection | What it holds | Notable fields / indexes |
|---|---|---|
| `menu_items` | Everything QuickBite sells | `name`, `category` (burgers \| chicken \| sides \| drinks \| desserts), `price`, `calories`, `available`, `tags[]` — index on `name` |
| `locations` | The restaurants | `name`, `city`, `address`, `phone`, `hours` |
| `customers` | Loyalty members | `name`, `email`, `phone`, `loyalty_points`, `joined` |
| `orders` | Orders with **embedded** items | `customer_id`, `location_id`, `items[]`, `total`, `status` (completed \| preparing \| delivered \| cancelled), `channel` (counter \| drive_thru \| app), `ordered_at` — indexes on `customer_id`, `ordered_at` |
| `reviews` | Customer reviews per location | `customer_id`, `location_id`, `rating`, `comment`, `created_at` — index on `location_id` |

Try the smoke-test query yourself — top sellers by quantity and revenue:

```javascript
db.orders.aggregate([
  { $unwind: "$items" },
  { $group: { _id: "$items.name", qty: { $sum: "$items.qty" },
              revenue: { $sum: { $multiply: ["$items.qty", "$items.unit_price"] } } } },
  { $sort: { qty: -1 } },
  { $limit: 5 }
])
```

## 🏗️ How it fits together

```
   Docker mode                          Kubernetes mode
┌──────────────┐                     ┌─────────────────────────────┐
│  your app /  │                     │  namespace: quickbite       │
│  mongosh     │                     │                             │
└──────┬───────┘                     │  Service ──▶ StatefulSet    │
       │ localhost:27017               │               │             │
┌──────▼───────┐                     │               ▼             │
│  MongoDB 7   │                     │        PVC (10Gi storage)   │
│  container   │                     └─────────────────────────────┘
└──────┬───────┘
       ▼
  named volume (data)
```

## ✅ Requirements

- **Docker mode:** a fresh Ubuntu/Debian VM is enough — `setup.sh` installs Docker for you (or bring your own Docker with Compose v2)
- **Kubernetes mode:** `kubectl` (installed for you on apt systems if missing) pointed at any cluster — minikube, kind, Docker Desktop, EKS, AKS, or GKE
- No cloud account, no API keys.

## 🔌 Connect

```bash
# mongosh (from your machine)
mongosh "mongodb://quickbite:quickbite_change_me@localhost:27017/quickbite?authSource=admin"

# or inside the running container
docker compose exec db mongosh -u quickbite -p quickbite_change_me --authenticationDatabase admin quickbite
```

On Kubernetes, port-forward first (leave it running), then use the same command as above:

```bash
kubectl -n quickbite port-forward svc/fast-food-mongodb 27017:27017
```

> ⚠️ The default password is `quickbite_change_me` — fine at home, **change it** in
> `.env` (Docker) or `k8s/secret.yaml` (Kubernetes) for anything real.

## 📁 Project layout

```
fast-food-database/
├── setup.sh              # THE script: docker | k8s | down — bootstraps its own prerequisites
├── docker-compose.yml    # MongoDB 7 + named volume + healthcheck
├── .env.example          # db / user / password / port (change-me defaults)
├── seed.js               # QuickBite sample data (mongosh) — menu, locations, customers, orders, reviews
├── k8s/
│   ├── namespace.yaml        # "quickbite" namespace
│   ├── secret.example.yaml   # same credentials as .env.example
│   ├── pvc.yaml              # 10Gi persistent storage
│   ├── statefulset.yaml      # MongoDB 7, with native readiness/liveness probes
│   └── service.yaml          # ClusterIP + headless service
└── README.md
```

## 👨‍👩‍👧 Sibling repos — Business Builds

- [zadc-liberia-database](https://github.com/UncleD0886475978/zadc-liberia-database) — PostgreSQL for the ZADC Inc. Liberia nonprofit (Zao Development Organization)
- [clothing-store-database](https://github.com/UncleD0886475978/clothing-store-database) — MySQL for the Threads & Co. clothing store
- [nursing-home-eks](https://github.com/UncleD0886475978/nursing-home-eks) — AWS EKS for a nursing home
- [it-services-aks](https://github.com/UncleD0886475978/it-services-aks) — Azure AKS for an IT services company
- [clothing-store-gke](https://github.com/UncleD0886475978/clothing-store-gke) — GCP GKE running the Threads & Co. storefront

## 🗺️ Roadmap

- [x] One-command Docker install with seed data + aggregation smoke test
- [x] One-command Kubernetes install (StatefulSet) with seed data + smoke test
- [x] Persistent storage in both modes
- [ ] Change streams / replica set for local high availability
- [ ] Scheduled backups (mongodump to object storage)
- [ ] Sample ordering API wired to this database

---

<div align="center">

**QuickBite — built to learn MongoDB and DevOps by doing, one business at a time.** 🍔

</div>
