-- ============================================================
--  TimePiece Store — Supabase Database Setup
--  Run this entire file in your Supabase SQL Editor
-- ============================================================

-- ── 1. PROFILES TABLE ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       text,
  full_name   text,
  phone       text,
  address     text,
  city        text,
  pincode     text,
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id OR auth.uid() IS NULL);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, phone)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', ''),
    COALESCE(new.raw_user_meta_data->>'phone', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_new_user() failed for user %: %', new.id, SQLERRM;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ── 2. CATEGORIES TABLE ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.categories (
  id          serial PRIMARY KEY,
  name        text NOT NULL,
  slug        text UNIQUE NOT NULL,
  image_url   text,
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read categories"
  ON public.categories FOR SELECT USING (true);

-- ── 3. PRODUCTS TABLE ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.products (
  id              serial PRIMARY KEY,
  name            text NOT NULL,
  description     text,
  price           numeric(10,2) NOT NULL,
  sale_price      numeric(10,2),
  category_id     int REFERENCES public.categories(id),
  image_url       text,
  images          text[],
  sizes           text[],
  colors          text[],
  stock           int DEFAULT 100,
  rating          numeric(3,1) DEFAULT 4.0,
  reviews_count   int DEFAULT 0,
  featured        boolean DEFAULT false,
  created_at      timestamptz DEFAULT now()
);

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read products"
  ON public.products FOR SELECT USING (true);

CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_featured ON public.products(featured);
CREATE INDEX IF NOT EXISTS idx_products_price ON public.products(price);

-- ── 4. CART ITEMS TABLE ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cart_items (
  id          serial PRIMARY KEY,
  user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  product_id  int REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
  quantity    int DEFAULT 1,
  size        text DEFAULT '',
  color       text DEFAULT '',
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own cart"
  ON public.cart_items FOR ALL USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_cart_user ON public.cart_items(user_id);

-- ── 5. ORDERS TABLE ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.orders (
  id                serial PRIMARY KEY,
  user_id           uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  order_number      text UNIQUE NOT NULL,
  total_amount      numeric(10,2) NOT NULL,
  status            text DEFAULT 'pending' CHECK (status IN ('pending','paid','shipped','delivered','cancelled')),
  payment_id        text,
  shipping_address  jsonb,
  created_at        timestamptz DEFAULT now()
);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own orders"
  ON public.orders FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own orders"
  ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own orders status"
  ON public.orders FOR UPDATE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_orders_user ON public.orders(user_id);

-- ── 6. ORDER ITEMS TABLE ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.order_items (
  id              serial PRIMARY KEY,
  order_id        int REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
  product_id      int REFERENCES public.products(id) ON DELETE SET NULL,
  product_name    text NOT NULL,
  product_image   text,
  price           numeric(10,2) NOT NULL,
  quantity        int DEFAULT 1,
  size            text DEFAULT '',
  color           text DEFAULT '',
  created_at      timestamptz DEFAULT now()
);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own order items"
  ON public.order_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.orders
      WHERE orders.id = order_items.order_id
        AND orders.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert order items"
  ON public.order_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.orders
      WHERE orders.id = order_items.order_id
        AND orders.user_id = auth.uid()
    )
  );

CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items(order_id);


-- ============================================================
--  DEMO DATA — CATEGORIES & PRODUCTS (WATCHES)
-- ============================================================

-- Delete old data first (safe to re-run)
DELETE FROM public.order_items;
DELETE FROM public.orders;
DELETE FROM public.cart_items;
DELETE FROM public.products;
DELETE FROM public.categories;

-- ── Categories ──────────────────────────────────────────────
INSERT INTO public.categories (name, slug, image_url) VALUES
  ('Luxury Watches',  'luxury',   'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400&q=80'),
  ('Sports Watches',  'sports',   'https://images.unsplash.com/photo-1547996160-81dfa63595aa?w=400&q=80'),
  ('Smart Watches',   'smart',    'https://images.unsplash.com/photo-1579586337278-3befd40fd17a?w=400&q=80'),
  ('Casual Watches',  'casual',   'https://images.unsplash.com/photo-1508685096489-7aacd43bd3b1?w=400&q=80'),
  ('Vintage Watches', 'vintage',  'https://images.unsplash.com/photo-1539874754764-5a96559165b0?w=400&q=80');


-- ── Products — LUXURY ────────────────────────────────────────
INSERT INTO public.products
  (name, description, price, sale_price, category_id, image_url, images, sizes, colors, stock, rating, reviews_count, featured)
VALUES

(
  'Seiko Presage Cocktail Time',
  'A stunning automatic watch inspired by the art of Japanese cocktail making. Features a beautiful mother-of-pearl dial with intricate textures representing the Negroni cocktail. 24-jewel automatic movement with 40 hours power reserve. Stainless steel case, 40.5mm.',
  28999, 24999,
  (SELECT id FROM public.categories WHERE slug='luxury'),
  'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&q=80',
  ARRAY['https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&q=80',
        'https://images.unsplash.com/photo-1594534475808-b18fc33b045e?w=600&q=80'],
  ARRAY['One Size'],
  ARRAY['Silver/Blue', 'Silver/White', 'Rose Gold/White'],
  30, 4.8, 124, true
),

(
  'Orient Bambino Classic Dress Watch',
  'A timeless automatic dress watch from Orient with an elegant domed dial and in-house movement. Features a hand-winding and hacking function. 21 jewels, 40 hours power reserve. 40.5mm stainless steel case with a genuine leather strap.',
  14999, 11999,
  (SELECT id FROM public.categories WHERE slug='luxury'),
  'https://images.unsplash.com/photo-1594534475808-b18fc33b045e?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Black/Silver', 'Champagne/Gold', 'White/Silver'],
  50, 4.7, 89, true
),

(
  'Tissot Gentleman Powermatic 80',
  'Swiss-made automatic movement with 80-hour power reserve. Sapphire crystal glass with anti-reflective coating. 40mm stainless steel case, water resistant to 100m. A perfect everyday luxury watch with clean, minimalist design language.',
  44999, 39999,
  (SELECT id FROM public.categories WHERE slug='luxury'),
  'https://images.unsplash.com/photo-1612817288484-6f916006741a?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Blue Dial', 'Black Dial', 'Silver Dial'],
  20, 4.9, 67, false
),

(
  'Citizen Eco-Drive Corso',
  'Powered by light, never needs a battery. Atomic timekeeping with radio-controlled accuracy. 40mm titanium case, ultra-light and hypoallergenic. Perpetual calendar with day/date display. Water resistant to 100m.',
  22999, NULL,
  (SELECT id FROM public.categories WHERE slug='luxury'),
  'https://images.unsplash.com/photo-1547996160-81dfa63595aa?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Silver/White', 'Gunmetal/Black'],
  40, 4.6, 56, false
),


-- ── Products — SPORTS ────────────────────────────────────────
(
  'Casio G-Shock DW-5600BB',
  'The iconic G-Shock in an all-black colorway. Shock resistant structure, 200M water resistance, and mud resistance. Features a built-in LED backlight, countdown timer, stopwatch, and multiple alarms. A true workhorse for outdoor activities.',
  7999, 6499,
  (SELECT id FROM public.categories WHERE slug='sports'),
  'https://images.unsplash.com/photo-1547996160-81dfa63595aa?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['All Black', 'Black/Red', 'Black/Blue'],
  150, 4.8, 312, true
),

(
  'Seiko 5 Sports Street Style',
  'Automatic movement with no battery needed. 42mm case, day-date display, luminous hands and markers. Water resistant to 100m. Comes with both a stainless steel bracelet and an additional silicon strap. Great entry into mechanical watches.',
  8499, NULL,
  (SELECT id FROM public.categories WHERE slug='sports'),
  'https://images.unsplash.com/photo-1508685096489-7aacd43bd3b1?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Blue', 'Black', 'Green', 'Orange'],
  80, 4.6, 198, true
),

(
  'Casio Edifice Solar Chronograph',
  'Solar-powered chronograph with 1/20-second stopwatch. World time for 31 cities, 100M water resistance. Stainless steel case and bracelet, dual time display, and countdown timer. Perfect for active professionals.',
  11999, 9499,
  (SELECT id FROM public.categories WHERE slug='sports'),
  'https://images.unsplash.com/photo-1612817288484-6f916006741a?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Silver/Black', 'Gold/Black'],
  60, 4.5, 145, false
),

(
  'Timex Expedition Scout',
  'A rugged outdoor watch with INDIGLO night-light technology. Lightweight Resin case, leather strap. Date display, very long battery life (2+ years). Shock and water resistant to 50M. Great for hiking, camping, and everyday adventure.',
  2999, 2399,
  (SELECT id FROM public.categories WHERE slug='sports'),
  'https://images.unsplash.com/photo-1539874754764-5a96559165b0?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Brown/Khaki', 'Black/Black', 'Navy/Blue'],
  200, 4.3, 423, false
),


-- ── Products — SMART WATCHES ─────────────────────────────────
(
  'Noise ColorFit Pro 5',
  'AMOLED display with always-on option. Bluetooth calling, 100+ sports modes, heart rate & SpO2 monitoring. Built-in GPS, 7 days battery life. IP68 water resistant. Comes with 2 interchangeable straps in the box.',
  3499, 2799,
  (SELECT id FROM public.categories WHERE slug='smart'),
  'https://images.unsplash.com/photo-1579586337278-3befd40fd17a?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Jet Black', 'Active Blue', 'Rose Pink'],
  300, 4.2, 876, true
),

(
  'boAt Xtend Pro Smartwatch',
  '1.78" AMOLED display with 368x448 resolution. Built-in Alexa, Bluetooth calling. 150+ sports modes, stress & sleep monitoring. 7-day battery backup, IP68 rated. Metal body with premium finish.',
  4999, 3999,
  (SELECT id FROM public.categories WHERE slug='smart'),
  'https://images.unsplash.com/photo-1579586337278-3befd40fd17a?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Active Black', 'Silver', 'Teal'],
  250, 4.3, 654, true
),

(
  'Fastrack Reflex Beat Plus',
  'Large 1.83" display, Bluetooth calling, 100+ watch faces. Health suite with SpO2, heart rate, stress monitoring. 5-day battery, IP67 water resistant. Available in multiple fun colors for the young and active.',
  2499, 1999,
  (SELECT id FROM public.categories WHERE slug='smart'),
  'https://images.unsplash.com/photo-1579586337278-3befd40fd17a?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Black', 'Blue', 'Pink', 'Green'],
  400, 4.0, 1240, false
),

(
  'Fossil Gen 6 Hybrid Wellness',
  'A hybrid smartwatch that looks like an analog watch but has smart features. E-ink display, 2-week battery, heart rate, sleep tracking. Works with both iOS and Android. Premium metal and leather construction.',
  18999, 15499,
  (SELECT id FROM public.categories WHERE slug='smart'),
  'https://images.unsplash.com/photo-1579586337278-3befd40fd17a?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Smoke/Black', 'Silver/White', 'Brown/Cream'],
  45, 4.4, 167, false
),


-- ── Products — CASUAL ────────────────────────────────────────
(
  'Timex Weekender Classic',
  'A simple, clean-looking watch that goes with anything. Quartz movement, fabric NATO strap, mineral crystal glass. Easy to swap strap design — comes with 2 interchangeable straps. Water resistant 30M. Under-rated everyday carry.',
  2999, NULL,
  (SELECT id FROM public.categories WHERE slug='casual'),
  'https://images.unsplash.com/photo-1508685096489-7aacd43bd3b1?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Silver/White', 'Silver/Blue', 'Gold/Cream'],
  300, 4.5, 567, true
),

(
  'Fossil Grant Chronograph',
  'Chronograph watch with a classic three-sub-dial layout. 44mm stainless steel case with genuine leather strap. Mineral crystal glass, 5ATM water resistance. A great looking dress-casual watch that works for office and weekends.',
  8999, 6999,
  (SELECT id FROM public.categories WHERE slug='casual'),
  'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Silver/Brown', 'Gunmetal/Black', 'Rose Gold/Navy'],
  80, 4.4, 289, true
),

(
  'Daniel Wellington Classic Sheffield',
  'Minimalist Swedish design — clean white dial, slim 36mm case, interchangeable mesh or leather strap. Quartz movement, 3ATM water resistance. The go-to watch for minimalist style lovers.',
  9999, 7999,
  (SELECT id FROM public.categories WHERE slug='casual'),
  'https://images.unsplash.com/photo-1612817288484-6f916006741a?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Silver/White', 'Gold/White', 'Rose Gold/White'],
  120, 4.6, 398, false
),

(
  'Sonata Quartz Analog Watch',
  'Reliable everyday quartz watch from Sonata. Clean round dial with date window, stainless steel case, leather strap. Very affordable at this price point. Ideal first watch or office daily wearer. 1-year warranty.',
  1299, 999,
  (SELECT id FROM public.categories WHERE slug='casual'),
  'https://images.unsplash.com/photo-1508685096489-7aacd43bd3b1?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Silver/White', 'Silver/Black'],
  500, 4.1, 1876, false
),


-- ── Products — VINTAGE ───────────────────────────────────────
(
  'Casio Vintage A168WA',
  'A re-edition of the iconic digital watch from the 80s. Stainless steel case and bracelet, electro-luminescent backlight, calendar, and multi-function alarm. Square face, retro feel. Lightweight and very comfortable to wear.',
  3499, 2799,
  (SELECT id FROM public.categories WHERE slug='vintage'),
  'https://images.unsplash.com/photo-1539874754764-5a96559165b0?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Gold', 'Silver', 'Black'],
  200, 4.7, 543, true
),

(
  'Orient Bambino Hand Wind',
  'A classically styled hand-winding mechanical watch. No battery, no automatic rotor — just pure hand-wound movement. Domed crystal glass gives it a vintage look. 40.5mm, water resistant to 30M. Perfect for watch enthusiasts.',
  9999, 8299,
  (SELECT id FROM public.categories WHERE slug='vintage'),
  'https://images.unsplash.com/photo-1594534475808-b18fc33b045e?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['White/Silver', 'Champagne/Gold', 'Black/Silver'],
  60, 4.8, 178, true
),

(
  'HMT Janata Hand Winding',
  'Made in India, for India. The legendary HMT Janata — a classic Indian hand-wound watch that defined time-keeping for generations. Simple, honest, and reliable. A piece of Indian horological history worth owning.',
  4999, NULL,
  (SELECT id FROM public.categories WHERE slug='vintage'),
  'https://images.unsplash.com/photo-1539874754764-5a96559165b0?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['White/Gold', 'Cream/Silver'],
  80, 4.5, 234, false
),

(
  'Casio MTP-V001 Classic Analog',
  'No-nonsense analog quartz watch. Clean round dial, stainless steel case, leather strap. Water resistant 30M. Mineral glass, date display. One of the most reliable budget watches you can buy — long battery life, built to last.',
  1999, 1599,
  (SELECT id FROM public.categories WHERE slug='vintage'),
  'https://images.unsplash.com/photo-1539874754764-5a96559165b0?w=600&q=80',
  NULL,
  ARRAY['One Size'],
  ARRAY['Silver/White', 'Gold/Black', 'Silver/Black'],
  400, 4.3, 789, false
);


-- ============================================================
--  VERIFICATION QUERIES (run separately to check)
-- ============================================================

-- SELECT 'categories' AS table_name, COUNT(*) AS rows FROM categories
-- UNION ALL
-- SELECT 'products', COUNT(*) FROM products;

-- Expected result:
-- categories | 5
-- products   | 20
