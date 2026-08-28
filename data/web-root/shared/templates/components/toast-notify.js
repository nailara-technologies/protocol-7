/* toast-notify.js — generic non-blocking toast notification, extracted from jobs.vhost/index.html.
 *
 * usage:
 *   <script src="/shared/templates/components/toast-notify.js"></script>
 *   <script>
 *     P7.notify('saved');
 *     P7.notify('import failed: ' + e.message, { err: true });
 *     P7.notify('font blocked — click for details', { err: true, timeout: 6500, onClick: showFix });
 *   </script>
 */
(function (global) {
    'use strict';

    function notify(msg, opts) {
        opts = opts || {};
        var err = opts.err;
        var n = document.createElement('div');
        n.textContent = msg;
        var bg     = err ? 'rgba(50,10,15,0.88)' : 'rgba(5,8,35,0.9)';
        var border = err ? 'rgba(140,40,40,0.55)' : 'rgba(68,39,172,0.55)';
        var glow   = err ? 'rgba(180,50,50,0.25)' : 'rgba(68,39,172,0.35)';
        var color  = err ? '#e08080' : '#6a8cff';
        n.style.cssText = 'position:fixed;bottom:1rem;right:1rem;padding:8px 14px;border-radius:4px;' +
            'font-size:0.8rem;z-index:9999;background:' + bg + ';border:1px solid ' + border + ';' +
            'color:' + color + ';box-shadow:0 0 14px ' + glow + ';' +
            'font-family:' + (opts.fontFamily || "'Courier New',Courier,monospace") + ';';
        if (opts.onClick) {
            n.style.cursor = 'pointer';
            n.style.textDecoration = 'underline dotted';
            n.title = opts.clickTitle || 'click for details';
            n.addEventListener('click', function () { opts.onClick(); n.remove(); });
        }
        document.body.appendChild(n);
        setTimeout(function () { n.remove(); }, opts.timeout || 4000);
        return n;
    }

    global.P7 = global.P7 || {};
    global.P7.notify = notify;
})(window);
