/* type-to-search.js — generic type-to-search bar, extracted from jobs.vhost/index.html.
 *
 * behavior: debounced query callback, Escape clears, native search-clear (x) fires a
 * query update, and typing ANYWHERE on the page (outside of another input/textarea/select,
 * no modifier key held) auto-focuses the search box — Backspace re-focuses it too, but
 * only while a query is already active, so it doesn't steal focus from normal navigation.
 *
 * usage:
 *   <input type="search" id="search-input" placeholder="suchen…">
 *   <script src="/shared/templates/components/type-to-search.js"></script>
 *   <script>
 *     P7.createTypeToSearch({
 *       inputEl: document.getElementById('search-input'),
 *       onQuery: (query) => render(query),   // called with '' on clear
 *     });
 *   </script>
 *
 * pairs with P7.highlightTerms(text, terms) below and .search-hl / mark.search-hl in
 * spectrum.css for rendering the matched substrings.
 */
(function (global) {
    'use strict';

    function escHtml(s) {
        return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;')
            .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function highlightTerms(text, terms) {
        var html = escHtml(text || '');
        if (!terms || !terms.length) return html;
        terms.forEach(function (t) {
            var re = new RegExp(escHtml(t).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');
            html = html.replace(re, '<mark class="search-hl">$&</mark>');
        });
        return html;
    }

    function createTypeToSearch(opts) {
        opts = opts || {};
        var inputEl = opts.inputEl;
        var onQuery = opts.onQuery || function () {};
        var debounceMs = opts.debounceMs != null ? opts.debounceMs : 150;

        if (!inputEl) {
            throw new Error('createTypeToSearch: opts.inputEl is required');
        }

        var debounceTimer = null;
        var query = '';

        function setQuery(next, immediate) {
            query = next;
            clearTimeout(debounceTimer);
            if (immediate) {
                onQuery(query);
            } else {
                debounceTimer = setTimeout(function () { onQuery(query); }, debounceMs);
            }
        }

        inputEl.addEventListener('input', function (e) {
            setQuery(e.target.value.trim(), false);
        });
        inputEl.addEventListener('keydown', function (e) {
            if (e.key === 'Escape') {
                inputEl.value = '';
                setQuery('', true);
            }
        });
        inputEl.addEventListener('search', function () {
            /* fires when the native × (clear) control is clicked */
            setQuery(inputEl.value.trim(), true);
        });

        if (opts.autoFocusOnType !== false) {
            document.addEventListener('keydown', function (e) {
                if (e.target === inputEl) return;
                if (e.target.closest && e.target.closest('input, textarea, select')) return;
                if (e.ctrlKey || e.metaKey || e.altKey) return;
                if (e.key === 'Backspace' && query) { inputEl.focus(); return; }
                if (e.key.length !== 1) return;
                inputEl.focus();
            });
        }

        return {
            getQuery: function () { return query; },
            clear: function () { inputEl.value = ''; setQuery('', true); },
        };
    }

    global.P7 = global.P7 || {};
    global.P7.createTypeToSearch = createTypeToSearch;
    global.P7.highlightTerms = highlightTerms;
    global.P7.escHtml = escHtml;
})(window);
