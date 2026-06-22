/**
 * RollHouse PRO — Theme System
 * Підключи <script src="/static/_theme.js"></script> на кожній сторінці (перед _sidebar.js).
 * API: window.rhTheme.set('light'|'dark'), window.rhTheme.current
 * Тема зберігається: localStorage (миттєво) + users.theme в DB (при наступному вході синхронізується).
 */
(function () {
  'use strict';

  // ─── Кольорові токени ────────────────────────────────────────────────────
  const T = {
    dark: {
      bg:          '#0a0a14',
      surface:     '#111120',
      surfaceLow:  '#0e0e1e',
      popup:       '#161626',
      bulkBg:      '#0d1030',
      border:      '#1e1e38',
      borderAlt:   '#1a1a30',
      border2:     '#252545',
      border3:     '#2a2a50',
      text:        '#d0d0e0',
      textHi:      '#ccd0ee',
      muted:       '#556688',
      accent:      '#88aaff',
      accentMuted: '#5566aa',
      accentDark:  '#4466cc',
      green:       '#66dd99',
      yellow:      '#ffcc55',
      red:         '#ff6666',
    },
    light: {
      bg:          '#F0F2F5',
      surface:     '#FFFFFF',
      surfaceLow:  '#F8F9FA',
      popup:       '#FFFFFF',
      bulkBg:      '#EEF2FF',
      border:      '#E5E7EB',
      borderAlt:   '#E5E7EB',
      border2:     '#D1D5DB',
      border3:     '#D1D5DB',
      text:        '#1F2937',
      textHi:      '#111827',
      muted:       '#6B7280',
      accent:      '#2563EB',
      accentMuted: '#3B82F6',
      accentDark:  '#1D4ED8',
      green:       '#16A34A',
      yellow:      '#B45309',
      red:         '#DC2626',
    },
  };

  // ─── Кольори рядків таблиці за статусом ──────────────────────────────────
  const ROW = {
    dark: {
      new:       'rgba(100,120,255,.05)',
      confirmed: 'transparent',
      cooking:   'rgba(255,160,30,.06)',
      on_way:    'rgba(80,180,255,.05)',
      delivered: 'rgba(80,200,80,.04)',
      cancelled: 'transparent',
      overdue:   'rgba(200,80,30,.09)',
    },
    light: {
      new:       '#FFF7ED',
      confirmed: '#FFFFFF',
      cooking:   '#FFFDE7',
      on_way:    '#EFF6FF',
      delivered: '#F0FDF4',
      cancelled: '#F9FAFB',
      overdue:   '#FFF1F2',
    },
  };

  // ─── CSS генерація ────────────────────────────────────────────────────────
  function buildCSS(name) {
    const t  = T[name];
    const rc = ROW[name];
    const s  = `[data-theme="${name}"]`;   // selector prefix
    const sh = name === 'light'
      ? '0 4px 16px rgba(0,0,0,.12)'
      : '0 4px 16px rgba(0,0,0,.55)';

    return `
/* ══ ${name.toUpperCase()} THEME ══ */
${s} body { background:${t.bg}!important; color:${t.text}!important; }

/* Topbar */
${s} .topbar { background:${t.surface}!important; border-bottom-color:${t.border}!important; }
${s} .topbar .logo { color:${t.accent}!important; }
${s} .topbar .nav-link { color:${t.accentMuted}!important; }
${s} .topbar .nav-link:hover { background:rgba(37,99,235,.08)!important; color:${t.accent}!important; }
${s} .topbar .refresh-btn { border-color:${t.border2}!important; color:${t.accentMuted}!important; }
${s} .topbar .refresh-btn:hover { border-color:${t.accent}!important; color:${t.accent}!important; }

/* KPI row */
${s} .kpi-row { border-bottom-color:${t.border}!important; background:${t.bg}!important; }
${s} .kpi-card { background:${t.surface}!important; border-color:${t.border}!important; }
${s} .kpi-card .kpi-label { color:${t.muted}!important; }
${s} .kpi-card .kpi-val { color:${t.textHi}!important; }
${s} .kpi-card .kpi-sub { color:${t.muted}!important; }
${s} .kpi-card.accent-blue .kpi-val  { color:${t.accent}!important; }
${s} .kpi-card.accent-green .kpi-val { color:${t.green}!important; }
${s} .kpi-card.accent-yellow .kpi-val{ color:${t.yellow}!important; }

/* Filters */
${s} .filters { border-bottom-color:${t.border}!important; background:${t.bg}!important; }
${s} .filters input,${s} .filters select {
  background:${t.surface}!important; border-color:${t.border2}!important; color:${t.text}!important;
}
${s} .filters input:focus,${s} .filters select:focus { border-color:${t.accent}!important; }
${s} .filter-label { color:${t.muted}!important; }
${s} .btn-reset { border-color:${t.border2}!important; color:${t.muted}!important; }
${s} .btn-reset:hover { border-color:${t.accent}!important; color:${t.accent}!important; }

/* Status chips */
${s} .s-chip { border-color:${t.border2}!important; }

/* Tag buttons */
${s} .tag-btn:not([class*="active"]) { border-color:${t.border}!important; color:${t.muted}!important; }

/* Table */
${s} .table-wrap { background:${t.bg}!important; }
${s} thead th { background:${t.surfaceLow}!important; border-bottom-color:${t.border}!important; color:${t.muted}!important; }
${s} thead th.sort-asc::after,${s} thead th.sort-desc::after { color:${t.accent}!important; }
${s} tbody tr { border-bottom-color:${t.border}!important; background:${t.surface}; }
${s} tbody tr:hover td { background:rgba(37,99,235,.04)!important; }
${s} tbody td { color:${t.text}!important; }
${s} .td-id    { color:${t.muted}!important; }
${s} .td-date  { color:${t.accentMuted}!important; }
${s} .td-phone { color:${t.accent}!important; }
${s} .td-name  { color:${t.textHi}!important; }
${s} .td-amount{ color:${t.green}!important; }
${s} .td-city  { color:${t.muted}!important; }
${s} .td-addr  { color:${t.muted}!important; }

/* Row colors by status */
${s} tr[data-status="new"]       { background:${rc.new}!important; }
${s} tr[data-status="confirmed"] { background:${rc.confirmed}!important; }
${s} tr[data-status="cooking"]   { background:${rc.cooking}!important; }
${s} tr[data-status="on_way"]    { background:${rc.on_way}!important; }
${s} tr[data-status="delivered"] { background:${rc.delivered}!important; }
${s} tr[data-status="cancelled"] { background:${rc.cancelled}!important; }
${s} tr.row-overdue              { background:${rc.overdue}!important; }
${s} tr.row-selected td          { background:rgba(37,99,235,.1)!important; }

/* Status badges */
${s} .st-new       { background:rgba(255,167,38,.15)!important; color:${t.yellow}!important; }
${s} .st-confirmed { background:rgba(37,99,235,.12)!important;  color:${t.accent}!important; }
${s} .st-cooking   { background:rgba(180,83,9,.12)!important;   color:${t.yellow}!important; }
${s} .st-on_way    { background:rgba(22,163,74,.12)!important;  color:${t.green}!important; }
${s} .st-delivered { background:rgba(22,163,74,.18)!important;  color:${t.green}!important; }
${s} .st-cancelled { background:rgba(220,38,38,.1)!important;   color:${t.red}!important; }

/* Bulk bar */
${s} #bulkBar { background:${t.bulkBg}!important; border-bottom-color:${t.accent}!important; }
${s} .bulk-count { color:${t.accent}!important; }
${s} .bulk-sep { color:${t.border}!important; }
${s} .bulk-select { background:${t.surface}!important; border-color:${t.border2}!important; color:${t.text}!important; }

/* Status popup */
${s} .status-popup { background:${t.popup}!important; border-color:${t.border2}!important; box-shadow:${sh}!important; }
${s} .status-popup-item { color:${t.text}!important; }
${s} .status-popup-item:hover { background:rgba(37,99,235,.06)!important; }
${s} .status-popup .popup-title { color:${t.muted}!important; border-bottom-color:${t.border}!important; }

/* Side panel */
${s} .side-panel { background:${t.surface}!important; border-left-color:${t.border}!important; }
${s} .panel-header { border-bottom-color:${t.border}!important; }
${s} .panel-header .panel-title { color:${t.textHi}!important; }
${s} .panel-close { color:${t.muted}!important; }
${s} .panel-close:hover { color:${t.accent}!important; }
${s} .panel-body { background:${t.surface}!important; }
${s} .panel-field label { color:${t.muted}!important; }
${s} .panel-field .pval { color:${t.text}!important; }
${s} .panel-section-title { color:${t.muted}!important; border-bottom-color:${t.border}!important; }
${s} .panel-footer { background:${t.surface}!important; border-top-color:${t.border}!important; }
${s} .panel-footer button { background:${t.bulkBg}!important; border-color:${t.border2}!important; color:${t.accent}!important; }
${s} .panel-footer .btn-accent { background:${t.accent}!important; color:#fff!important; border-color:${t.accent}!important; }

/* Modal/dialog */
${s} .rh-modal-bg { background:rgba(0,0,0,${name==='light'?'.35':'.7'})!important; }
${s} .rh-modal { background:${t.surface}!important; border-color:${t.border}!important; box-shadow:${sh}!important; }
${s} .rh-modal h3 { color:${t.textHi}!important; }
${s} .rh-modal label { color:${t.muted}!important; }
${s} .rh-modal input,${s} .rh-modal select,${s} .rh-modal textarea {
  background:${t.surfaceLow}!important; border-color:${t.border2}!important; color:${t.text}!important;
}
${s} .rh-modal .modal-footer { border-top-color:${t.border}!important; }

/* Toast */
${s} .rh-toast { background:${t.popup}!important; border-color:${t.border}!important; color:${t.text}!important; box-shadow:${sh}!important; }

/* Misc elements */
${s} .panel-note,${s} .note-text { background:${t.surfaceLow}!important; border-color:${t.border}!important; color:${t.text}!important; }
${s} .panel-note textarea { background:${t.surfaceLow}!important; color:${t.text}!important; border-color:${t.border2}!important; }
${s} .courier-badge { background:rgba(22,163,74,.12)!important; color:${t.green}!important; }
`;
  }

  // ─── Inject CSS ───────────────────────────────────────────────────────────
  function injectCSS() {
    if (document.getElementById('rh-theme-css')) return;
    const style = document.createElement('style');
    style.id = 'rh-theme-css';
    style.textContent = buildCSS('dark') + buildCSS('light');
    document.head.insertBefore(style, document.head.firstChild);
  }

  // ─── Apply theme ──────────────────────────────────────────────────────────
  function applyTheme(name) {
    if (name !== 'light' && name !== 'dark') return;
    document.documentElement.setAttribute('data-theme', name);
    localStorage.setItem('rh_theme', name);
    window.rhTheme.current = name;
    document.dispatchEvent(new CustomEvent('rh-theme-change', { detail: { theme: name } }));
  }

  // ─── Apply immediately (prevent FOUC) ────────────────────────────────────
  const _initial = localStorage.getItem('rh_theme') || 'light';
  document.documentElement.setAttribute('data-theme', _initial);
  injectCSS();

  // ─── Public API ───────────────────────────────────────────────────────────
  window.rhTheme = {
    current: _initial,

    /** Встановити тему і зберегти в DB */
    set: function (name) {
      if (name === window.rhTheme.current) return;
      applyTheme(name);
      fetch('/api/auth/preferences', {
        method:  'PATCH',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({ theme: name }),
      }).catch(() => {});
    },

    toggle: function () {
      window.rhTheme.set(window.rhTheme.current === 'dark' ? 'light' : 'dark');
    },
  };

  // ─── Sync з сервером після завантаження ──────────────────────────────────
  document.addEventListener('DOMContentLoaded', function () {
    fetch('/api/auth/me', { credentials: 'same-origin' })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (d) {
        if (d && d.theme && d.theme !== localStorage.getItem('rh_theme')) {
          applyTheme(d.theme);
        }
      })
      .catch(function () {});
  });
})();
