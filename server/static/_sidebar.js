/**
 * RollHouse PRO — Sidebar Navigation Component
 * Самодостатній модуль. Підключи <script src="/static/_sidebar.js"></script>
 * і він сам інжектить CSS + HTML, ініціалізує стан, опитує бейджі.
 */
(function () {
  'use strict';

  // ─── Конфіг ──────────────────────────────────────────────────────────────
  const SB_TAB   = 16;    // fixed tab strip (always visible, never moves)
  const SB_EXP   = 224;   // sidebar panel expanded (total: TAB+EXP = 240px)
  const SB_COL   = 40;    // sidebar panel collapsed (total: TAB+COL = 56px)
  const LS_KEY   = 'rh_nav_mode'; // 'pinned' | 'collapsed'
  const POLL_MS  = 30_000;
  const HOVER_IN = 200;   // ms до розкриття при hover
  const HOVER_OUT= 280;   // ms до згортання після mouseleave

  // ─── SVG іконки (Lucide-style, 24×24, stroke) ────────────────────────────
  function ic(d) {
    return `<svg width="20" height="20" viewBox="0 0 24 24" fill="none"
      stroke="currentColor" stroke-width="1.75"
      stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
  }
  const ICONS = {
    deliveries: ic(`<rect x="1" y="3" width="15" height="13" rx="1"/>
      <path d="M16 8h4l3 3v5h-7z"/>
      <circle cx="5.5" cy="18.5" r="2.5"/>
      <circle cx="18.5" cy="18.5" r="2.5"/>`),

    orders: ic(`<path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>
      <rect x="8" y="2" width="8" height="4" rx="1"/>
      <line x1="9" y1="12" x2="15" y2="12"/>
      <line x1="9" y1="16" x2="13" y2="16"/>`),

    customers: ic(`<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
      <circle cx="9" cy="7" r="4"/>
      <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
      <path d="M16 3.13a4 4 0 0 1 0 7.75"/>`),

    addresses: ic(`<path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 0 1 18 0z"/>
      <circle cx="12" cy="10" r="3"/>`),

    couriers: ic(`<circle cx="12" cy="7" r="4"/>
      <path d="M6 21v-2a6 6 0 0 1 6-6"/>
      <path d="m16 19 2 2 4-4"/>`),

    salary: ic(`<rect x="2" y="6" width="20" height="12" rx="2"/>
      <path d="M22 10H2"/>
      <path d="M12 15h.01"/>`),

    analytics: ic(`<line x1="18" y1="20" x2="18" y2="10"/>
      <line x1="12" y1="20" x2="12" y2="4"/>
      <line x1="6" y1="20" x2="6" y2="14"/>`),

    logs: ic(`<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
      <polyline points="14 2 14 8 20 8"/>
      <line x1="16" y1="13" x2="8" y2="13"/>
      <line x1="16" y1="17" x2="8" y2="17"/>`),

    settings: ic(`<circle cx="12" cy="12" r="3"/>
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83
        2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2
        2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2
        2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0
        0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0
        0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9
        4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1
        1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65
        1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65
        1.65 0 0 0-1.51 1z"/>`),

    logout: ic(`<rect x="3" y="11" width="11" height="11" rx="1"/>
      <path d="M7 11V7a5 5 0 0 1 9.9-1"/>
      <line x1="20" y1="8" x2="20" y2="14"/>
      <polyline points="17 11 20 8 23 11"/>`),

    pin: ic(`<line x1="12" y1="17" x2="12" y2="22"/>
      <path d="M5 17h14v-1.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15
        10.76V6h1a2 2 0 0 0 0-4H8a2 2 0 0 0 0 4h1v4.76a2 2 0 0 1-1.11
        1.79l-1.78.9A2 2 0 0 0 5 15.24z"/>`),
  };

  // ─── Ролі ─────────────────────────────────────────────────────────────────
  // null = будь-який автентифікований користувач
  const R_ALL      = null;
  const R_TEAM     = ['owner', 'admin', 'director', 'senior_operator', 'logistics'];
  const R_SALARY   = ['owner', 'admin', 'director', 'logistics'];
  const R_ANALYT   = ['owner', 'admin', 'director', 'investor'];
  const R_ADMIN    = ['owner', 'admin'];

  // ─── Структура навігації ──────────────────────────────────────────────────
  const NAV_SECTIONS = [
    {
      label: null,
      items: [
        { key: 'deliveries', label: 'Доставки',   href: '/dashboard?view=active', sc: 'D', badge: 'deliveries', roles: R_ALL },
        { key: 'orders',     label: 'Замовлення', href: '/dashboard',             sc: 'O',                      roles: R_ALL },
      ],
    },
    {
      label: 'Клієнти',
      items: [
        { key: 'customers', label: 'Клієнти', href: '/customers', sc: 'C', roles: R_ALL },
        { key: 'addresses', label: 'Адреси',  href: null,         sc: null, soon: true, roles: R_ALL },
      ],
    },
    {
      label: 'Команда',
      items: [
        { key: 'couriers', label: "Кур'єри", href: '/couriers', sc: 'K', dot: true, roles: R_TEAM },
        { key: 'salary',   label: 'Зарплата', href: '/salary',  sc: 'Z',            roles: R_SALARY },
      ],
    },
    {
      label: 'Аналітика',
      items: [
        { key: 'analytics', label: 'Аналітика', href: '/analytics', sc: 'A', roles: R_ANALYT },
        { key: 'logs',      label: 'Логи',       href: '/logs',      sc: 'L', roles: R_ADMIN  },
      ],
    },
  ];

  // ─── Визначення активного пункту ──────────────────────────────────────────
  function getActiveKey() {
    const p = window.location.pathname;
    const q = new URLSearchParams(window.location.search);
    if (p === '/dashboard' && q.get('view') === 'active') return 'deliveries';
    if (p === '/dashboard') return 'orders';
    if (p === '/customers' || p.startsWith('/card'))       return 'customers';
    if (p === '/couriers')   return 'couriers';
    if (p === '/salary')     return 'salary';
    if (p === '/analytics')  return 'analytics';
    if (p === '/logs')       return 'logs';
    if (p === '/admin')      return 'settings';
    return null;
  }

  // ─── CSS ──────────────────────────────────────────────────────────────────
  const CSS = `
:root { --rh-sb: ${SB_TAB + SB_EXP}px; }

/* ── Fixed toggle tab (NEVER moves, always at left:0) ── */
#rh-tab {
  position: fixed; top: 0; left: 0;
  width: ${SB_TAB}px; height: 100vh;
  background: #0D0F14;
  border-right: 1px solid rgba(255,255,255,.1);
  z-index: 201;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  user-select: none;
  transition: background 120ms;
}
#rh-tab:hover { background: #161920; }
#rh-tab-arrow {
  writing-mode: vertical-rl;
  color: #4B5563; font-size: 9px; letter-spacing: 3px;
  transition: color 120ms;
  pointer-events: none;
}
#rh-tab:hover #rh-tab-arrow { color: #9CA3AF; }

#rh-sb {
  position: fixed; top: 0; left: ${SB_TAB}px; height: 100vh;
  width: ${SB_EXP}px;
  background: #0D0F14;
  border-right: 1px solid rgba(255,255,255,.06);
  display: flex; flex-direction: column;
  z-index: 200;
  transition: width 180ms cubic-bezier(.4,0,.2,1);
  overflow: hidden;
  user-select: none;
}
#rh-sb.rh-col { width: ${SB_COL}px; }
#rh-sb.rh-float { box-shadow: 6px 0 40px rgba(0,0,0,.55); z-index: 300; }

/* Header */
.rh-hdr {
  height: 56px; min-height: 56px;
  display: flex; align-items: center;
  padding: 0 12px; gap: 10px;
  border-bottom: 1px solid rgba(255,255,255,.04);
}
.rh-mark {
  width: 32px; height: 32px; min-width: 32px;
  background: linear-gradient(135deg, #FF6B35 0%, #cc4400 100%);
  border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  font-size: 11px; font-weight: 900; color: #fff; letter-spacing: -.5px;
}
.rh-word {
  font-size: 13px; font-weight: 700; color: #F9FAFB;
  white-space: nowrap;
  transition: opacity 160ms;
}
#rh-sb.rh-col .rh-word { opacity: 0; pointer-events: none; }

/* Body */
.rh-body {
  flex: 1; overflow-y: auto; overflow-x: hidden;
  padding: 8px 8px 4px;
  scrollbar-width: none;
}
.rh-body::-webkit-scrollbar { display: none; }

/* Section label */
.rh-slbl {
  font-size: 10px; font-weight: 600; letter-spacing: .08em;
  text-transform: uppercase; color: #4B5563;
  padding: 18px 4px 4px; white-space: nowrap;
  transition: opacity 160ms;
}
#rh-sb.rh-col .rh-slbl { opacity: 0; }

/* Item */
.rh-it {
  display: flex; align-items: center;
  height: 40px; padding: 0 8px; gap: 10px;
  border-radius: 6px; margin-bottom: 1px;
  text-decoration: none; color: #9CA3AF;
  cursor: pointer; white-space: nowrap; overflow: hidden;
  border: none; background: none; width: 100%;
  font-size: 13px; font-family: inherit;
  transition: background 80ms, color 80ms;
  position: relative;
}
.rh-it:hover:not(.rh-soon) { background: rgba(255,255,255,.05); color: #E5E7EB; }
.rh-it.rh-active {
  background: rgba(255,255,255,.08);
  color: #fff; font-weight: 500;
  box-shadow: inset 2px 0 0 #FF6B35;
}
.rh-it.rh-soon { opacity: .35; cursor: default; }

/* Icon */
.rh-ico {
  min-width: 20px; width: 20px; height: 20px;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}

/* Label */
.rh-lbl { flex: 1; transition: opacity 160ms; }
#rh-sb.rh-col .rh-lbl { opacity: 0; }

/* Shortcut hint */
.rh-sc {
  font-size: 10px; font-weight: 600; color: #6B7280;
  opacity: 0; transition: opacity 140ms;
  padding-left: 4px;
}
.rh-it:hover .rh-sc { opacity: .5; }
#rh-sb.rh-col .rh-sc { opacity: 0 !important; }

/* Badge */
.rh-bdg {
  font-size: 10px; font-weight: 700;
  min-width: 18px; height: 18px; padding: 0 4px;
  background: #374151; color: #9CA3AF;
  border-radius: 9px; line-height: 1;
  display: none; align-items: center; justify-content: center;
}
.rh-bdg.show { display: flex; }
.rh-bdg.alert { background: #EF4444; color: #fff; animation: rh-pulse 2s infinite; }
@keyframes rh-pulse {
  0%,100% { box-shadow: 0 0 0 0 rgba(239,68,68,.45); }
  50%      { box-shadow: 0 0 0 5px rgba(239,68,68,0); }
}

/* Online dot (couriers) */
.rh-dot {
  width: 7px; height: 7px; border-radius: 50%;
  background: #22C55E; display: none; flex-shrink: 0;
}
.rh-dot.show { display: block; }

/* Footer */
.rh-foot {
  padding: 8px;
  border-top: 1px solid rgba(255,255,255,.04);
  display: flex; flex-direction: column; gap: 1px;
}
.rh-it.rh-logout:hover { background: rgba(239,68,68,.09); color: #EF4444; }

/* Tooltip */
#rh-tip {
  position: fixed;
  background: #1F2937; color: #F9FAFB;
  font-size: 12px; font-weight: 500;
  padding: 6px 10px; border-radius: 6px;
  pointer-events: none; z-index: 9999;
  opacity: 0; transition: opacity 100ms;
  display: flex; align-items: center; gap: 8px;
  box-shadow: 0 4px 16px rgba(0,0,0,.45);
  white-space: nowrap;
}
#rh-tip .tsc {
  font-size: 10px; color: #6B7280;
  background: #374151; padding: 1px 5px; border-radius: 3px;
}

/* Body offset */
body.rh-sb-on {
  margin-left: var(--rh-sb);
  transition: margin-left 180ms cubic-bezier(.4,0,.2,1);
}
@media (max-width: 767px) {
  #rh-tab { display: none; }
  #rh-sb { left: 0; display: none; }
  body.rh-sb-on { margin-left: 0 !important; }
}
`;

  // ─── Побудова HTML ─────────────────────────────────────────────────────────
  function buildHTML(activeKey) {
    let h = `
      <div class="rh-hdr">
        <div class="rh-mark">РХ</div>
        <span class="rh-word">РоллХаус PRO</span>
      </div>
      <div class="rh-body">`;

    NAV_SECTIONS.forEach(sec => {
      const sectionStart = h.length;
      const labelHtml = sec.label ? `<div class="rh-slbl" data-section-label="${sec.label}">${sec.label}</div>` : '';
      let itemsHtml = '';
      sec.items.forEach(item => {
        const act  = item.key === activeKey ? ' rh-active' : '';
        const soon = item.soon ? ' rh-soon' : '';
        const tag  = item.href && !item.soon ? 'a' : 'div';
        const href = item.href && !item.soon ? ` href="${item.href}"` : '';
        const rolesAttr = item.roles ? ` data-roles="${item.roles.join(',')}"` : '';
        itemsHtml += `<${tag}${href} class="rh-it${act}${soon}"
            data-key="${item.key}" data-lbl="${item.label}" data-sc="${item.sc || ''}"${rolesAttr}>
          <span class="rh-ico">${ICONS[item.key] || ''}</span>
          <span class="rh-lbl">${item.label}${item.soon ? ' <em style="font-size:9px;opacity:.5;font-style:normal">незабаром</em>' : ''}</span>
          ${item.badge ? `<span class="rh-bdg" id="rh-bdg-${item.key}"></span>` : ''}
          ${item.dot   ? `<span class="rh-dot" id="rh-dot-${item.key}"></span>` : ''}
          ${item.sc    ? `<span class="rh-sc">${item.sc}</span>` : ''}
        </${tag}>`;
      });
      h += labelHtml + itemsHtml;
    });

    h += `</div>
      <div class="rh-foot">
        <a href="/admin" class="rh-it${'settings' === activeKey ? ' rh-active' : ''}"
            data-key="settings" data-lbl="Налаштування" data-sc=""
            data-roles="${R_ADMIN.join(',')}">
          <span class="rh-ico">${ICONS.settings}</span>
          <span class="rh-lbl">Налаштування</span>
        </a>
        <div class="rh-it rh-logout" id="rh-logout" data-lbl="Вийти" data-sc="">
          <span class="rh-ico">${ICONS.logout}</span>
          <span class="rh-lbl">Вийти</span>
        </div>
      </div>`;
    return h;
  }

  // ─── Фільтрація по ролі ───────────────────────────────────────────────────
  let _userRole = null;

  function applyRoleFilter(role) {
    _userRole = role;
    if (!role) return; // невідома роль — показуємо все
    const sb = document.getElementById('rh-sb');
    if (!sb) return;

    // Фільтруємо nav items
    sb.querySelectorAll('[data-roles]').forEach(el => {
      const allowed = el.getAttribute('data-roles').split(',');
      el.style.display = allowed.includes(role) ? '' : 'none';
    });

    // Приховуємо section label якщо всі елементи секції сховані
    sb.querySelectorAll('[data-section-label]').forEach(label => {
      let next = label.nextElementSibling;
      let allHidden = true;
      while (next && !next.hasAttribute('data-section-label')) {
        if (next.style.display !== 'none') { allHidden = false; break; }
        next = next.nextElementSibling;
      }
      label.style.display = allHidden ? 'none' : '';
    });
  }

  // ─── Стан ─────────────────────────────────────────────────────────────────
  let _mode = localStorage.getItem(LS_KEY) || 'pinned'; // 'pinned' | 'collapsed'
  let _hTimer = null;
  let _tip = null;

  function applyMode(sb) {
    const collapsed = _mode === 'collapsed';
    sb.classList.toggle('rh-col', collapsed);
    if (!collapsed) sb.classList.remove('rh-float');
    // total = tab + panel
    document.documentElement.style.setProperty(
      '--rh-sb', (SB_TAB + (collapsed ? SB_COL : SB_EXP)) + 'px'
    );
    // update tab arrow direction
    const arrow = document.getElementById('rh-tab-arrow');
    if (arrow) arrow.textContent = collapsed ? '›' : '‹';
  }

  function setMode(mode) {
    _mode = mode;
    localStorage.setItem(LS_KEY, mode);
    applyMode(document.getElementById('rh-sb'));
  }

  // ─── Tooltip ──────────────────────────────────────────────────────────────
  function showTip(el) {
    if (_mode !== 'collapsed') return;
    const lbl = el.dataset.lbl;
    const sc  = el.dataset.sc;
    if (!lbl || !_tip) return;
    _tip.innerHTML = lbl + (sc ? `<span class="tsc">${sc}</span>` : '');
    const r = el.getBoundingClientRect();
    _tip.style.top  = (r.top + r.height / 2 - 15) + 'px';
    _tip.style.left = (SB_TAB + SB_COL + 8) + 'px';
    _tip.style.opacity = '1';
  }
  function hideTip() { if (_tip) _tip.style.opacity = '0'; }

  // ─── Polling бейджів ──────────────────────────────────────────────────────
  async function pollBadges() {
    // Active orders badge
    try {
      const r = await fetch('/api/orders');
      if (r.ok) {
        const d = await r.json();
        const orders = d.orders || [];
        const ACTIVE = new Set(['new', 'confirmed', 'cooking', 'on_way']);
        const now = Date.now();
        const active  = orders.filter(o => !o.deleted && ACTIVE.has(o.status));
        const count   = active.length;
        const overdue = active.some(o => {
          if (o.status !== 'cooking') return false;
          const ts = o.status_changed_at || o.order_date;
          if (!ts) return false;
          const ms = new Date(ts.replace(' ', 'T') + (ts.includes('T') ? '' : 'Z')).getTime();
          return (now - ms) > 45 * 60 * 1000;
        });
        const bdg = document.getElementById('rh-bdg-deliveries');
        if (bdg) {
          if (count > 0) {
            bdg.textContent = count > 99 ? '99+' : count;
            bdg.classList.add('show');
            bdg.classList.toggle('alert', overdue);
          } else {
            bdg.classList.remove('show', 'alert');
          }
        }
      }
    } catch (_) {}

    // Couriers online dot
    try {
      const r = await fetch('/api/couriers');
      if (r.ok) {
        const d = await r.json();
        const online = (d.couriers || []).filter(c => !c.deleted && c.status === 'online').length;
        const dot = document.getElementById('rh-dot-couriers');
        if (dot) dot.classList.toggle('show', online > 0);
      }
    } catch (_) {}
  }

  // ─── Keyboard shortcuts ───────────────────────────────────────────────────
  const SC_MAP = { d: '/dashboard?view=active', o: '/dashboard',
                   c: '/customers', k: '/couriers', z: '/salary', a: '/analytics' };

  function onKey(e) {
    const tag = document.activeElement && document.activeElement.tagName;
    if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;
    if (e.altKey || e.metaKey) return;
    // Ctrl+\ або Ctrl+B → toggle sidebar
    if (e.ctrlKey && (e.key === '\\' || e.key === 'b')) {
      e.preventDefault();
      setMode(_mode === 'pinned' ? 'collapsed' : 'pinned');
      return;
    }
    if (e.ctrlKey) return;
    const dest = SC_MAP[e.key.toLowerCase()];
    if (dest) window.location.href = dest;
  }

  // ─── Init ─────────────────────────────────────────────────────────────────
  function init() {
    // CSS
    const style = document.createElement('style');
    style.textContent = CSS;
    document.head.appendChild(style);

    // Sidebar element
    const sb = document.createElement('nav');
    sb.id = 'rh-sb';
    sb.setAttribute('aria-label', 'Головна навігація');
    sb.innerHTML = buildHTML(getActiveKey());
    document.body.insertBefore(sb, document.body.firstChild);

    // Tooltip element
    _tip = document.createElement('div');
    _tip.id = 'rh-tip';
    document.body.appendChild(_tip);

    // Body offset class
    document.body.classList.add('rh-sb-on');

    // Apply initial mode
    applyMode(sb);

    // ── Fixed toggle tab (always at left:0, never moves) ──
    const tab = document.createElement('div');
    tab.id = 'rh-tab';
    tab.title = 'Розкрити / згорнути навігацію (Ctrl+\\)';
    tab.innerHTML = `<span id="rh-tab-arrow">${_mode === 'pinned' ? '‹' : '›'}</span>`;
    document.body.insertBefore(tab, document.body.firstChild);
    tab.addEventListener('click', () => {
      setMode(_mode === 'pinned' ? 'collapsed' : 'pinned');
    });

    // ── Logout (вбудований в sidebar, працює на всіх сторінках) ──
    document.getElementById('rh-logout').addEventListener('click', async () => {
      if (!confirm('Завершити сесію?')) return;
      // Якщо на сторінці є власний doLogout — делегуємо
      if (typeof doLogout === 'function') { doLogout(); return; }
      // Інакше — власна реалізація
      try { await fetch('/api/auth/logout', { method: 'POST' }); } catch (_) {}
      window.location.href = '/login';
    });

    // ── Завантажити роль і застосувати фільтр ──
    fetch('/api/auth/me', { credentials: 'same-origin' })
      .then(r => r.ok ? r.json() : null)
      .then(d => {
        if (!d) return;
        const role = (d.user && d.user.role) || d.role || null;
        if (role) applyRoleFilter(role);
      })
      .catch(() => {});

    // ── Hover expand (collapsed → floating) ──
    sb.addEventListener('mouseenter', () => {
      if (_mode !== 'collapsed') return;
      clearTimeout(_hTimer);
      _hTimer = setTimeout(() => {
        sb.classList.remove('rh-col');
        sb.classList.add('rh-float');
        // body НЕ зсувається — sidebar плаває поверх
        document.documentElement.style.setProperty('--rh-sb', (SB_TAB + SB_COL) + 'px');
      }, HOVER_IN);
    });
    sb.addEventListener('mouseleave', () => {
      if (_mode !== 'collapsed') return;
      clearTimeout(_hTimer);
      hideTip();
      _hTimer = setTimeout(() => {
        sb.classList.add('rh-col');
        sb.classList.remove('rh-float');
      }, HOVER_OUT);
    });

    // ── Tooltips ──
    sb.querySelectorAll('.rh-it').forEach(el => {
      el.addEventListener('mouseenter', () => showTip(el));
      el.addEventListener('mouseleave', hideTip);
    });

    // ── Auto-collapse after nav click (floating mode) ──
    sb.querySelectorAll('a.rh-it').forEach(el => {
      el.addEventListener('click', () => {
        if (_mode === 'collapsed') {
          clearTimeout(_hTimer);
          sb.classList.add('rh-col');
          sb.classList.remove('rh-float');
        }
      });
    });

    // ── Keyboard ──
    document.addEventListener('keydown', onKey);

    // ── Badge polling ──
    pollBadges();
    setInterval(pollBadges, POLL_MS);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
