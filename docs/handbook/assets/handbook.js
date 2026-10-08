/* XP Notepad handbook behaviour: theme, combined filters and search, deep links,
 * screenshot enlargement, copy buttons and print preparation. The page is readable
 * without this script; the toolbar is only shown when the script runs. */
(function () {
  'use strict';

  var doc = document;
  var root = doc.documentElement;
  root.classList.add('js');

  var STORAGE_KEY = 'xp-notepad-handbook-theme';
  var THEME_LABELS = { system: 'System', light: 'Light', dark: 'Dark' };
  var THEME_ORDER = ['system', 'light', 'dark'];

  // ------------------------------------------------------------------ theme

  var themeButton = doc.getElementById('theme-toggle');

  function storedTheme() {
    try {
      var value = window.localStorage.getItem(STORAGE_KEY);
      return THEME_LABELS[value] ? value : 'system';
    } catch (error) {
      return 'system';
    }
  }

  function saveTheme(value) {
    try {
      window.localStorage.setItem(STORAGE_KEY, value);
    } catch (error) {
      /* Storage can be unavailable (private windows); the choice then lasts for this page only. */
    }
  }

  function applyTheme(value) {
    if (value === 'light' || value === 'dark') {
      root.setAttribute('data-theme', value);
    } else {
      root.removeAttribute('data-theme');
    }
    if (themeButton) {
      themeButton.textContent = 'Theme: ' + THEME_LABELS[value];
      themeButton.setAttribute('aria-label', 'Theme: ' + THEME_LABELS[value] + '. Activate to change the theme.');
    }
  }

  var currentTheme = storedTheme();
  applyTheme(currentTheme);

  if (themeButton) {
    themeButton.addEventListener('click', function () {
      var next = THEME_ORDER[(THEME_ORDER.indexOf(currentTheme) + 1) % THEME_ORDER.length];
      currentTheme = next;
      saveTheme(next);
      applyTheme(next);
    });
  }

  // ------------------------------------------------------- filters and search

  var blocks = Array.prototype.slice.call(doc.querySelectorAll('[data-block]'));
  var sections = Array.prototype.slice.call(doc.querySelectorAll('section.doc-section'));
  var controls = {
    audience: doc.getElementById('filter-audience'),
    topic: doc.getElementById('filter-topic'),
    platform: doc.getElementById('filter-platform'),
    status: doc.getElementById('filter-status'),
    severity: doc.getElementById('filter-severity')
  };
  var searchInput = doc.getElementById('search');
  var resetButton = doc.getElementById('reset-filters');
  var statusLine = doc.getElementById('result-status');
  var emptyState = doc.getElementById('no-results');
  var resultsPanel = doc.getElementById('search-results');
  var resultsList = doc.getElementById('search-results-list');
  var revealed = null;

  blocks.forEach(function (el) {
    el._searchText = el.textContent.replace(/\s+/g, ' ').toLowerCase();
  });

  function currentState() {
    var state = { terms: [] };
    Object.keys(controls).forEach(function (key) {
      state[key] = controls[key] ? controls[key].value : 'all';
    });
    var query = searchInput ? searchInput.value.trim().toLowerCase() : '';
    if (query) {
      state.terms = query.split(/\s+/);
    }
    return state;
  }

  // Audience and platform blocks may be tagged "all", which matches every choice.
  function matchesChoice(el, key, value) {
    if (value === 'all') return true;
    var tag = el.getAttribute('data-' + key);
    if (key === 'audience' || key === 'platform') {
      return tag === value || tag === 'all';
    }
    return tag === value;
  }

  function matchesTerms(el, terms) {
    for (var i = 0; i < terms.length; i += 1) {
      if (el._searchText.indexOf(terms[i]) === -1) return false;
    }
    return true;
  }

  function sectionLink(sectionId) {
    return doc.querySelector('.toc a[href="#' + sectionId + '"]');
  }

  function sectionTitle(sec) {
    var heading = sec.querySelector(':scope > h2');
    return heading ? heading.textContent : sec.id;
  }

  function blockTitle(el) {
    var heading = el.querySelector('h3');
    return heading ? heading.textContent.replace(/Copy link/g, '').trim() : el.id;
  }

  function filtersActive(state) {
    return state.audience !== 'all' || state.topic !== 'all' || state.platform !== 'all' ||
      state.status !== 'all' || state.severity !== 'all' || state.terms.length > 0;
  }

  function revealContent(active) {
    var details = Array.prototype.slice.call(doc.querySelectorAll('details.reveal'));
    if (active) {
      if (revealed === null) {
        revealed = details.map(function (d) { return d.open; });
      }
      details.forEach(function (d) {
        if (d.closest('[data-block]') && !d.closest('[hidden]')) d.open = true;
      });
    } else if (revealed !== null) {
      details.forEach(function (d, index) { d.open = revealed[index]; });
      revealed = null;
    }
  }

  function renderResults(state, visibleBlocks) {
    if (!resultsPanel || !resultsList) return;
    if (state.terms.length === 0) {
      resultsPanel.hidden = true;
      resultsList.textContent = '';
      return;
    }
    resultsPanel.hidden = false;
    resultsList.textContent = '';
    if (visibleBlocks.length === 0) {
      var none = doc.createElement('li');
      none.textContent = 'No items match this search with the current filters.';
      resultsList.appendChild(none);
      return;
    }
    visibleBlocks.slice(0, 40).forEach(function (el) {
      var item = doc.createElement('li');
      var link = doc.createElement('a');
      var section = el.closest('section.doc-section');
      link.href = '#' + el.id;
      link.textContent = blockTitle(el);
      item.appendChild(link);
      var where = doc.createElement('span');
      where.className = 'filter-note';
      where.textContent = ' in ' + (section ? sectionTitle(section) : 'the handbook');
      item.appendChild(where);
      resultsList.appendChild(item);
    });
    if (visibleBlocks.length > 40) {
      var more = doc.createElement('li');
      more.textContent = 'Showing the first 40 of ' + visibleBlocks.length + ' results. Refine the search to see the rest.';
      resultsList.appendChild(more);
    }
  }

  function apply() {
    var state = currentState();
    var active = filtersActive(state);
    var visible = [];

    blocks.forEach(function (el) {
      var keep = matchesChoice(el, 'audience', state.audience) &&
        matchesChoice(el, 'topic', state.topic) &&
        matchesChoice(el, 'platform', state.platform) &&
        matchesChoice(el, 'status', state.status) &&
        matchesChoice(el, 'severity', state.severity) &&
        matchesTerms(el, state.terms);
      el.hidden = !keep;
      if (keep) visible.push(el);
    });

    sections.forEach(function (sec) {
      var shown = sec.querySelectorAll(':scope [data-block]:not([hidden])').length;
      sec.hidden = shown === 0;
      var link = sectionLink(sec.id);
      if (link) {
        var counter = link.querySelector('.count');
        if (counter) counter.textContent = String(shown);
      }
    });

    if (statusLine) {
      var total = blocks.length;
      var text = '<strong>' + visible.length + '</strong> of ' + total + ' items shown';
      statusLine.innerHTML = text + (active ? ' (filters or search active)' : '');
    }
    if (emptyState) emptyState.hidden = visible.length !== 0;
    if (resetButton) resetButton.disabled = !active;

    revealContent(state.terms.length > 0);
    renderResults(state, visible);
  }

  function resetFilters(quiet) {
    Object.keys(controls).forEach(function (key) {
      if (controls[key]) controls[key].value = 'all';
    });
    if (searchInput) searchInput.value = '';
    apply();
    if (quiet && statusLine) {
      statusLine.insertAdjacentText('beforeend', ' Filters were reset so the linked item is visible.');
    }
  }

  var pending = null;
  function scheduleApply() {
    window.clearTimeout(pending);
    pending = window.setTimeout(apply, 120);
  }

  Object.keys(controls).forEach(function (key) {
    if (controls[key]) controls[key].addEventListener('change', apply);
  });
  if (searchInput) searchInput.addEventListener('input', scheduleApply);
  if (resetButton) {
    resetButton.addEventListener('click', function () {
      resetFilters(false);
      if (searchInput) searchInput.focus();
    });
  }

  // -------------------------------------------------------------- deep links

  function openAncestors(el) {
    var parent = el.parentElement;
    while (parent) {
      if (parent.tagName === 'DETAILS') parent.open = true;
      parent = parent.parentElement;
    }
  }

  function showTarget(id, moveFocus) {
    var target = doc.getElementById(id);
    if (!target) return false;
    var block = target.closest('[data-block]');
    if (block && block.hidden) {
      resetFilters(true);
    }
    var scope = block || target;
    openAncestors(scope);
    if (block) {
      // Open the item's own evidence and steps, so the linked content is visible at once.
      block.querySelectorAll('details.reveal').forEach(function (d) { d.open = true; });
    }
    var heading = scope.querySelector('h2, h3') || scope;
    if (!heading.hasAttribute('tabindex')) heading.setAttribute('tabindex', '-1');
    heading.scrollIntoView({ block: 'start' });
    if (moveFocus) heading.focus({ preventScroll: true });
    return true;
  }

  function followHash() {
    var id = decodeURIComponent(window.location.hash.slice(1));
    if (id) showTarget(id, true);
  }

  window.addEventListener('hashchange', followHash);

  // ------------------------------------------------------------ copy controls

  function copyText(text, done) {
    function fallback() {
      var area = doc.createElement('textarea');
      area.value = text;
      area.setAttribute('readonly', '');
      area.style.position = 'fixed';
      area.style.top = '-1000px';
      doc.body.appendChild(area);
      area.select();
      var ok = false;
      try {
        ok = doc.execCommand('copy');
      } catch (error) {
        ok = false;
      }
      doc.body.removeChild(area);
      done(ok);
    }
    if (window.navigator.clipboard && window.navigator.clipboard.writeText) {
      window.navigator.clipboard.writeText(text).then(function () { done(true); }, fallback);
    } else {
      fallback();
    }
  }

  function flash(button, message) {
    var original = button.getAttribute('data-label') || button.textContent;
    button.setAttribute('data-label', original);
    button.textContent = message;
    window.setTimeout(function () { button.textContent = original; }, 1800);
  }

  doc.querySelectorAll('pre.code').forEach(function (pre) {
    var button = doc.createElement('button');
    button.type = 'button';
    button.className = 'copy-button';
    button.textContent = 'Copy';
    button.setAttribute('aria-label', 'Copy the code example');
    button.addEventListener('click', function () {
      var code = pre.querySelector('code');
      copyText(code ? code.textContent : pre.textContent, function (ok) {
        flash(button, ok ? 'Copied' : 'Select and copy');
      });
    });
    pre.appendChild(button);
  });

  doc.querySelectorAll('[data-block] > h3').forEach(function (heading) {
    var block = heading.parentElement;
    var button = doc.createElement('button');
    button.type = 'button';
    button.className = 'link-button';
    button.textContent = 'Copy link';
    button.setAttribute('aria-label', 'Copy a link to ' + blockTitle(block));
    button.addEventListener('click', function () {
      var base = window.location.href.split('#')[0];
      copyText(base + '#' + block.id, function (ok) {
        flash(button, ok ? 'Link copied' : 'Copy failed');
      });
    });
    heading.appendChild(button);
  });

  // ---------------------------------------------------- screenshot enlargement

  var lightbox = doc.getElementById('lightbox');
  var lightboxImage = doc.getElementById('lightbox-image');
  var lightboxCaption = doc.getElementById('lightbox-caption');
  var lightboxClose = doc.getElementById('lightbox-close');
  var lastTrigger = null;

  if (lightbox && typeof lightbox.showModal === 'function') {
    doc.addEventListener('click', function (event) {
      var link = event.target.closest ? event.target.closest('a.shot-link') : null;
      if (!link || event.defaultPrevented) return;
      if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      lastTrigger = link;
      lightboxImage.src = link.getAttribute('href');
      lightboxImage.alt = link.getAttribute('data-alt') || '';
      lightboxCaption.textContent = link.getAttribute('data-caption') || '';
      lightbox.showModal();
      lightboxClose.focus();
    });
    lightbox.addEventListener('close', function () {
      lightboxImage.removeAttribute('src');
      if (lastTrigger) lastTrigger.focus();
    });
    lightboxClose.addEventListener('click', function () { lightbox.close(); });
    lightbox.addEventListener('click', function (event) {
      if (event.target === lightbox) lightbox.close();
    });
  }

  // ------------------------------------------------------------------ print

  var openBeforePrint = null;
  window.addEventListener('beforeprint', function () {
    openBeforePrint = Array.prototype.slice.call(doc.querySelectorAll('details')).map(function (d) {
      var was = d.open;
      d.open = true;
      return was;
    });
  });
  window.addEventListener('afterprint', function () {
    if (openBeforePrint === null) return;
    Array.prototype.slice.call(doc.querySelectorAll('details')).forEach(function (d, index) {
      d.open = openBeforePrint[index];
    });
    openBeforePrint = null;
  });

  var printButton = doc.getElementById('print-button');
  if (printButton) {
    printButton.addEventListener('click', function () { window.print(); });
  }

  // ------------------------------------------------------------------- start

  apply();
  if (window.location.hash) followHash();
})();
