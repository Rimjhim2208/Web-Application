// ============================================================
//  TimePiece Store — Shared App Utilities (app.js)
//  Included on every page
// ============================================================

// ── Supabase Client ─────────────────────────────────────────
const { createClient } = supabase;
const _supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ── Auth State ──────────────────────────────────────────────
let currentUser = null;

async function initAuth() {
  const { data: { session } } = await _supabase.auth.getSession();
  currentUser = session?.user ?? null;
  updateNavAuth();
  return currentUser;
}

function updateNavAuth() {
  const authLinks = document.querySelectorAll('[data-auth-show]');
  const guestLinks = document.querySelectorAll('[data-guest-show]');

  authLinks.forEach(el => {
    el.style.display = currentUser ? '' : 'none';
  });
  guestLinks.forEach(el => {
    el.style.display = currentUser ? 'none' : '';
  });

  const userNameEl = document.getElementById('nav-user-name');
  if (userNameEl && currentUser) {
    userNameEl.textContent = currentUser.user_metadata?.full_name?.split(' ')[0] || 'Account';
  }

  updateCartBadge();
}

_supabase.auth.onAuthStateChange((event, session) => {
  currentUser = session?.user ?? null;
  updateNavAuth();
  if (event === 'SIGNED_IN') updateCartBadge();
  if (event === 'SIGNED_OUT') {
    localStorage.removeItem('timepiece_cart');
    updateCartBadge();
  }
});

// ── Sign Out ────────────────────────────────────────────────
async function signOut() {
  await _supabase.auth.signOut();
  showToast('Signed out successfully', 'success');
  setTimeout(() => window.location.href = '/index.html', 600);
}

// ── Cart Badge ──────────────────────────────────────────────
async function updateCartBadge() {
  const badge = document.getElementById('cart-badge');
  if (!badge) return;
  const count = await getCartCount();
  badge.textContent = count;
  badge.style.display = count > 0 ? 'flex' : 'none';
}

async function getCartCount() {
  if (currentUser) {
    const { data, error } = await _supabase
      .from('cart_items')
      .select('quantity')
      .eq('user_id', currentUser.id);
    if (error || !data) return 0;
    return data.reduce((sum, item) => sum + item.quantity, 0);
  } else {
    const cart = getLocalCart();
    return cart.reduce((sum, item) => sum + item.quantity, 0);
  }
}

// ── Local Cart (guest) ─────────────────────────────────────
function getLocalCart() {
  try {
    return JSON.parse(localStorage.getItem('timepiece_cart') || '[]');
  } catch { return []; }
}
function saveLocalCart(cart) {
  localStorage.setItem('timepiece_cart', JSON.stringify(cart));
}

// ── Add to Cart ─────────────────────────────────────────────
async function addToCart(productId, quantity = 1, size = null, color = null) {
  if (currentUser) {
    // Check if already in cart
    const { data: existing } = await _supabase
      .from('cart_items')
      .select('id, quantity')
      .eq('user_id', currentUser.id)
      .eq('product_id', productId)
      .eq('size', size || '')
      .eq('color', color || '')
      .single();

    if (existing) {
      await _supabase
        .from('cart_items')
        .update({ quantity: existing.quantity + quantity })
        .eq('id', existing.id);
    } else {
      await _supabase.from('cart_items').insert({
        user_id: currentUser.id,
        product_id: productId,
        quantity,
        size: size || '',
        color: color || ''
      });
    }
  } else {
    const cart = getLocalCart();
    const idx = cart.findIndex(i => i.product_id === productId && i.size === size && i.color === color);
    if (idx >= 0) {
      cart[idx].quantity += quantity;
    } else {
      cart.push({ product_id: productId, quantity, size, color });
    }
    saveLocalCart(cart);
  }
  updateCartBadge();
  showToast('Added to cart! 🛒', 'success');
}

// ── Toast Notifications ─────────────────────────────────────
function showToast(message, type = 'info', duration = 3500) {
  let container = document.getElementById('toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    document.body.appendChild(container);
  }

  const icons = { success: '✓', error: '✕', info: 'ℹ' };
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `
    <span class="toast-icon">${icons[type] || icons.info}</span>
    <span class="toast-message">${message}</span>
  `;
  toast.addEventListener('click', () => removeToast(toast));
  container.appendChild(toast);

  setTimeout(() => removeToast(toast), duration);
}

function removeToast(toast) {
  toast.style.animation = 'fadeOut 0.3s ease forwards';
  setTimeout(() => toast.remove(), 300);
}

// ── Format Currency ─────────────────────────────────────────
function formatPrice(amount) {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
  }).format(amount);
}

// ── Discount Percentage ─────────────────────────────────────
function discountPct(price, salePrice) {
  if (!salePrice || salePrice >= price) return 0;
  return Math.round(((price - salePrice) / price) * 100);
}

// ── Star Rating HTML ────────────────────────────────────────
function starsHTML(rating) {
  const full  = Math.floor(rating);
  const half  = rating % 1 >= 0.5 ? 1 : 0;
  const empty = 5 - full - half;
  return '★'.repeat(full) + (half ? '½' : '') + '☆'.repeat(empty);
}

// ── Navbar scroll effect ────────────────────────────────────
window.addEventListener('scroll', () => {
  const nav = document.querySelector('.navbar');
  if (nav) nav.classList.toggle('scrolled', window.scrollY > 20);
});

// ── Hamburger menu ──────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  const hamburger = document.getElementById('nav-hamburger');
  const navLinks  = document.getElementById('nav-links');
  if (hamburger && navLinks) {
    hamburger.addEventListener('click', () => {
      navLinks.classList.toggle('open');
    });
  }

  // Loader
  const loader = document.getElementById('page-loader');
  if (loader) {
    window.addEventListener('load', () => {
      setTimeout(() => loader.classList.add('hidden'), 300);
    });
  }
});

// ── Require Auth Guard ──────────────────────────────────────
async function requireAuth() {
  const user = await initAuth();
  if (!user) {
    const redirect = encodeURIComponent(window.location.pathname + window.location.search);
    window.location.href = `/pages/login.html?redirect=${redirect}`;
    return false;
  }
  return true;
}

// ── Generate Order Number ───────────────────────────────────
function generateOrderNumber() {
  const date = new Date();
  const dateStr = date.getFullYear().toString() +
    String(date.getMonth() + 1).padStart(2, '0') +
    String(date.getDate()).padStart(2, '0');
  const rand = Math.floor(Math.random() * 9000) + 1000;
  return `TP-${dateStr}-${rand}`;
}

// ── Shared Navbar HTML ──────────────────────────────────────
function renderNavbar(activePage = '') {
  const nav = document.getElementById('navbar');
  if (!nav) return;

  nav.innerHTML = `
    <a href="/index.html" class="navbar-brand">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="10"/>
        <polyline points="12 6 12 12 16 14"/>
      </svg>
      TimePiece
    </a>
    <nav class="navbar-nav" id="nav-links">
      <a href="/index.html" class="nav-link ${activePage==='home'?'active':''}">Home</a>
      <a href="/pages/products.html" class="nav-link ${activePage==='products'?'active':''}">Shop</a>
      <a href="/pages/orders.html" class="nav-link ${activePage==='orders'?'active':''}" data-auth-show>Orders</a>
      <a href="/pages/login.html" class="nav-link" data-guest-show>Login</a>
      <a href="/pages/signup.html" class="btn btn-outline btn-sm" data-guest-show style="text-transform:none;letter-spacing:0;">Sign Up</a>
      <div class="nav-user" data-auth-show style="display:none;align-items:center;gap:8px;">
        <span id="nav-user-name" style="font-size:0.78rem;color:var(--clr-text-muted);white-space:nowrap;"></span>
        <button class="btn btn-ghost btn-sm" onclick="signOut()" style="text-transform:none;letter-spacing:0;padding:4px 12px;font-size:0.72rem;">Sign Out</button>
      </div>
    </nav>
    <div class="navbar-actions">
      <a href="/pages/cart.html" class="btn-cart" title="Cart">
        <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 01-8 0"/></svg>
        <span class="cart-badge" id="cart-badge" style="display:none;">0</span>
      </a>
      <button class="nav-hamburger" id="nav-hamburger" aria-label="Menu">
        <svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="18" x2="21" y2="18"/></svg>
      </button>
    </div>
  `;

  initAuth();
}
