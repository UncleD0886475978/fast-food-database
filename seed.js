// seed.js — QuickBite sample data (mongosh script)
// ============================================================================
// SAMPLE DATA ONLY — a small, made-up dataset for learning and demos.
// Run it against the "quickbite" database, e.g.:
//   mongosh -u quickbite -p quickbite_change_me --authenticationDatabase admin quickbite seed.js
// (./setup.sh loads it for you in both Docker and Kubernetes modes.)
//
// The script is re-runnable: it clears each collection before inserting, so
// running it twice gives you the same dataset, not duplicates.
// ============================================================================

const qb = db.getSiblingDB("quickbite");

// ---------- clear previous sample data ----------
qb.menu_items.deleteMany({});
qb.locations.deleteMany({});
qb.customers.deleteMany({});
qb.orders.deleteMany({});
qb.reviews.deleteMany({});

// ---------- indexes ----------
qb.menu_items.createIndex({ name: 1 });
qb.orders.createIndex({ customer_id: 1 });
qb.orders.createIndex({ ordered_at: -1 });
qb.reviews.createIndex({ location_id: 1 });

// ---------- menu_items ----------
// Pre-generated ObjectIds so orders below can reference items by id.
const menu = {
  classicBurger:   new ObjectId(),
  doubleSmash:     new ObjectId(),
  chickenSandwich: new ObjectId(),
  tenders:         new ObjectId(),
  fries:           new ObjectId(),
  onionRings:      new ObjectId(),
  gardenSalad:     new ObjectId(),
  cola:            new ObjectId(),
  milkshake:       new ObjectId(),
  brownieSundae:   new ObjectId(),
};

qb.menu_items.insertMany([
  { _id: menu.classicBurger,   name: "Classic Burger",         category: "burgers",  price: 8.99,  calories: 550, available: true,  tags: ["beef", "signature"] },
  { _id: menu.doubleSmash,     name: "Double Smash Burger",    category: "burgers",  price: 11.49, calories: 820, available: true,  tags: ["beef", "double", "spicy"] },
  { _id: menu.chickenSandwich, name: "Crispy Chicken Sandwich", category: "chicken", price: 7.99,  calories: 470, available: true,  tags: ["fried", "signature"] },
  { _id: menu.tenders,         name: "Chicken Tenders (6 pc)", category: "chicken",  price: 8.49,  calories: 520, available: true,  tags: ["kids-favorite"] },
  { _id: menu.fries,           name: "French Fries",           category: "sides",    price: 3.49,  calories: 380, available: true,  tags: ["vegetarian"] },
  { _id: menu.onionRings,      name: "Onion Rings",            category: "sides",    price: 4.29,  calories: 410, available: true,  tags: ["vegetarian", "fried"] },
  { _id: menu.gardenSalad,     name: "Garden Salad",           category: "sides",    price: 5.99,  calories: 210, available: true,  tags: ["vegetarian", "fresh"] },
  { _id: menu.cola,            name: "Cola (Large)",           category: "drinks",   price: 2.49,  calories: 290, available: true,  tags: ["fountain"] },
  { _id: menu.milkshake,       name: "Vanilla Milkshake",      category: "drinks",   price: 4.99,  calories: 530, available: true,  tags: ["dessert-drink"] },
  { _id: menu.brownieSundae,   name: "Brownie Sundae",         category: "desserts", price: 5.49,  calories: 450, available: false, tags: ["chocolate", "seasonal"] },
]);

// ---------- locations ----------
const loc = {
  downtown: new ObjectId(),
  riverside: new ObjectId(),
  airport: new ObjectId(),
};

qb.locations.insertMany([
  { _id: loc.downtown,  name: "QuickBite Downtown",     city: "Springfield", address: "120 Main Street",    phone: "555-0101", hours: "Mon-Sun 07:00-23:00" },
  { _id: loc.riverside, name: "QuickBite Riverside",    city: "Springfield", address: "48 Riverwalk Avenue", phone: "555-0102", hours: "Mon-Sun 08:00-22:00" },
  { _id: loc.airport,   name: "QuickBite Airport Road", city: "Riverton",    address: "900 Airport Road",    phone: "555-0103", hours: "Mon-Sun 06:00-00:00" },
]);

// ---------- customers ----------
const cust = {
  amara:  new ObjectId(),
  jonas:  new ObjectId(),
  priya:  new ObjectId(),
  diego:  new ObjectId(),
  fatima: new ObjectId(),
};

qb.customers.insertMany([
  { _id: cust.amara,  name: "Amara Johnson", email: "amara.j@example.com",  phone: "555-1001", loyalty_points: 1240, joined: new Date("2025-03-14") },
  { _id: cust.jonas,  name: "Jonas Weber",   email: "jonas.w@example.com",  phone: "555-1002", loyalty_points: 310,  joined: new Date("2025-08-02") },
  { _id: cust.priya,  name: "Priya Nair",    email: "priya.n@example.com",  phone: "555-1003", loyalty_points: 2680, joined: new Date("2024-11-20") },
  { _id: cust.diego,  name: "Diego Alvarez", email: "diego.a@example.com", phone: "555-1004", loyalty_points: 95,   joined: new Date("2026-09-18") },
  { _id: cust.fatima, name: "Fatima Diallo", email: "fatima.d@example.com", phone: "555-1005", loyalty_points: 870,  joined: new Date("2026-01-05") },
]);

// ---------- orders ----------
// Items are EMBEDDED in the order (with the name + unit_price as sold), so an
// order reads as one document and stays correct even if the menu changes later.
qb.orders.insertMany([
  {
    customer_id: cust.amara, location_id: loc.downtown, channel: "counter", status: "completed",
    items: [
      { menu_item_id: menu.classicBurger, name: "Classic Burger", qty: 2, unit_price: 8.99 },
      { menu_item_id: menu.fries, name: "French Fries", qty: 2, unit_price: 3.49 },
      { menu_item_id: menu.cola, name: "Cola (Large)", qty: 2, unit_price: 2.49 },
    ],
    total: 29.94, ordered_at: new Date("2026-11-02T12:15:00Z"),
  },
  {
    customer_id: cust.priya, location_id: loc.riverside, channel: "app", status: "delivered",
    items: [
      { menu_item_id: menu.chickenSandwich, name: "Crispy Chicken Sandwich", qty: 1, unit_price: 7.99 },
      { menu_item_id: menu.gardenSalad, name: "Garden Salad", qty: 1, unit_price: 5.99 },
      { menu_item_id: menu.milkshake, name: "Vanilla Milkshake", qty: 1, unit_price: 4.99 },
    ],
    total: 18.97, ordered_at: new Date("2026-11-03T18:42:00Z"),
  },
  {
    customer_id: cust.jonas, location_id: loc.downtown, channel: "drive_thru", status: "completed",
    items: [
      { menu_item_id: menu.doubleSmash, name: "Double Smash Burger", qty: 1, unit_price: 11.49 },
      { menu_item_id: menu.onionRings, name: "Onion Rings", qty: 1, unit_price: 4.29 },
      { menu_item_id: menu.cola, name: "Cola (Large)", qty: 1, unit_price: 2.49 },
    ],
    total: 18.27, ordered_at: new Date("2026-11-04T13:05:00Z"),
  },
  {
    customer_id: cust.fatima, location_id: loc.airport, channel: "counter", status: "completed",
    items: [
      { menu_item_id: menu.tenders, name: "Chicken Tenders (6 pc)", qty: 2, unit_price: 8.49 },
      { menu_item_id: menu.fries, name: "French Fries", qty: 1, unit_price: 3.49 },
    ],
    total: 20.47, ordered_at: new Date("2026-11-05T09:31:00Z"),
  },
  {
    customer_id: cust.diego, location_id: loc.riverside, channel: "app", status: "preparing",
    items: [
      { menu_item_id: menu.classicBurger, name: "Classic Burger", qty: 1, unit_price: 8.99 },
      { menu_item_id: menu.milkshake, name: "Vanilla Milkshake", qty: 2, unit_price: 4.99 },
    ],
    total: 18.97, ordered_at: new Date("2026-11-08T19:20:00Z"),
  },
  {
    customer_id: cust.amara, location_id: loc.airport, channel: "drive_thru", status: "completed",
    items: [
      { menu_item_id: menu.doubleSmash, name: "Double Smash Burger", qty: 2, unit_price: 11.49 },
      { menu_item_id: menu.fries, name: "French Fries", qty: 2, unit_price: 3.49 },
      { menu_item_id: menu.cola, name: "Cola (Large)", qty: 2, unit_price: 2.49 },
    ],
    total: 34.94, ordered_at: new Date("2026-11-06T17:48:00Z"),
  },
  {
    customer_id: cust.priya, location_id: loc.downtown, channel: "counter", status: "cancelled",
    items: [
      { menu_item_id: menu.brownieSundae, name: "Brownie Sundae", qty: 1, unit_price: 5.49 },
    ],
    total: 5.49, ordered_at: new Date("2026-11-07T15:12:00Z"),
  },
  {
    customer_id: cust.jonas, location_id: loc.riverside, channel: "app", status: "delivered",
    items: [
      { menu_item_id: menu.chickenSandwich, name: "Crispy Chicken Sandwich", qty: 2, unit_price: 7.99 },
      { menu_item_id: menu.onionRings, name: "Onion Rings", qty: 1, unit_price: 4.29 },
      { menu_item_id: menu.gardenSalad, name: "Garden Salad", qty: 1, unit_price: 5.99 },
    ],
    total: 26.26, ordered_at: new Date("2026-11-08T12:03:00Z"),
  },
]);

// ---------- reviews ----------
qb.reviews.insertMany([
  { customer_id: cust.amara,  location_id: loc.downtown,  rating: 5, comment: "Classic Burger is consistently great, and the line moves fast at lunch.", created_at: new Date("2026-11-02T13:00:00Z") },
  { customer_id: cust.priya,  location_id: loc.riverside, rating: 4, comment: "Loved the chicken sandwich. Milkshake was a little sweet for me.", created_at: new Date("2026-11-03T19:15:00Z") },
  { customer_id: cust.jonas,  location_id: loc.downtown,  rating: 4, comment: "Drive-thru was quick. Onion rings were crispy, not greasy.", created_at: new Date("2026-11-04T13:40:00Z") },
  { customer_id: cust.fatima, location_id: loc.airport,   rating: 5, comment: "Perfect stop before a flight — tenders were hot and fresh.", created_at: new Date("2026-11-05T10:05:00Z") },
  { customer_id: cust.diego,  location_id: loc.riverside, rating: 3, comment: "Food was good but the app order took longer than promised.", created_at: new Date("2026-11-08T19:50:00Z") },
]);

// ---------- summary ----------
print("QuickBite seed complete:");
print("  menu_items: " + qb.menu_items.countDocuments());
print("  locations:  " + qb.locations.countDocuments());
print("  customers:  " + qb.customers.countDocuments());
print("  orders:     " + qb.orders.countDocuments());
print("  reviews:    " + qb.reviews.countDocuments());
