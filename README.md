# Rimjhim — Premium Indian Ethnic Wear E-Commerce

A full-featured, production-ready e-commerce web application built with **HTML, CSS, JavaScript**, **Supabase** (backend & database), and **Razorpay** payment gateway.

---

## 🚀 Quick Setup

### Step 1 — Supabase Setup

1. Go to [supabase.com](https://supabase.com) and create a new project.
2. In the Supabase dashboard, go to **SQL Editor**.
3. Open `supabase-setup.sql` from this project and paste the entire file content into the SQL editor.
4. Click **Run** — this creates all tables, sets up Row Level Security, and inserts demo data.
5. Go to **Project Settings → API** and copy:
   - **Project URL** (e.g., `https://xyz.supabase.co`)
   - **Anon / Public Key** (the long JWT string)

### Step 2 — Razorpay Setup

1. Go to [razorpay.com](https://razorpay.com) and create an account.
2. In the dashboard, go to **Settings → API Keys**.
3. Generate a **Test Key** (for development).
4. Copy the **Key ID** (starts with `rzp_test_...`).

### Step 3 — Configure Credentials

Open `js/config.js` and replace the placeholder values:

```javascript
const SUPABASE_URL = 'https://your-project-id.supabase.co';
const SUPABASE_ANON_KEY = 'your-supabase-anon-key';
const RAZORPAY_KEY_ID = 'rzp_test_your_key_id';
```

### Step 4 — Run Locally

This is a pure HTML/CSS/JS app — no build step needed!

Option A — Use VS Code Live Server:
- Install the **Live Server** extension
- Right-click `index.html` → **Open with Live Server**

Option B — Use Python:
```bash
cd d:\Rimjhim\Web-Application
python -m http.server 8000
```
Then open http://localhost:8000

Option C — Use Node.js:
```bash
npx serve d:\Rimjhim\Web-Application
```

---

## 📋 Pages

| Page | URL | Description |
|------|-----|-------------|
| Landing | `/index.html` | Hero, categories, featured products, testimonials |
| Shop | `/pages/products.html` | Products with filters, search, sorting |
| Product Detail | `/pages/product-detail.html?id=X` | Full product view, gallery, size/color selection |
| Cart | `/pages/cart.html` | Shopping cart with promo codes |
| Checkout | `/pages/checkout.html` | Address form + Razorpay payment |
| Orders | `/pages/orders.html` | Order history with status tracking |
| Login | `/pages/login.html` | Email/password + Google OAuth |
| Signup | `/pages/signup.html` | Registration with validation |

---

## 🎟️ Demo Promo Codes

| Code | Discount |
|------|----------|
| `RIMJHIM10` | 10% off any order |
| `NEWUSER20` | 20% off for new users |

---

## 🗄️ Database Schema

```
profiles      — User profiles (linked to auth.users)
categories    — 5 product categories
products      — 22+ products with full details
cart_items    — User shopping carts (persisted in DB)
orders        — Order records with payment info
order_items   — Individual items within each order
```

---

## 💳 Payment Flow (Razorpay)

1. User adds items to cart and proceeds to checkout
2. Address form is filled (pre-populated from profile)
3. User clicks "Place Order & Pay"
4. Razorpay checkout modal opens
5. User completes payment (use test card: `4111 1111 1111 1111`)
6. On success, order is created in Supabase
7. Cart is cleared, success modal is shown

> **Note:** In production, you should create a backend server to call the Razorpay Orders API and verify payment signatures. This app demonstrates the frontend flow.

---

## 🧪 Test Card Details (Razorpay Test Mode)

- **Card Number:** 4111 1111 1111 1111
- **CVV:** Any 3 digits
- **Expiry:** Any future date
- **UPI:** `success@razorpay`
- **Net Banking:** Select any bank → Success

---

## 📦 Project Structure

```
Web-Application/
├── index.html              # Landing page
├── pages/
│   ├── login.html
│   ├── signup.html
│   ├── products.html
│   ├── product-detail.html
│   ├── cart.html
│   ├── checkout.html
│   └── orders.html
├── css/
│   ├── style.css           # Global design system
│   ├── landing.css
│   └── auth.css
│   └── products.css
├── js/
│   ├── config.js           # ← Add your credentials here
│   └── app.js              # Shared utilities
└── supabase-setup.sql      # Run this in Supabase SQL Editor
```

---

## 🎨 Design

- **Theme:** Luxury dark navy with gold accents
- **Fonts:** Playfair Display (headings) + Inter (body)
- **Features:** Glassmorphism cards, gradient animations, micro-interactions, fully responsive

---

Built with ❤️ for Rimjhim