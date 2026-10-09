/* =========================================================
   CRP_JOBCORE – Bossmenu (system desktopowy)
   - Cały UI generowany stąd (index.html jest pustym szkieletem)
   - Tailwind + ikony SVG z Tablera (inline)
   - Przeglądarka: dane testowe (DEV)
   - FiveM: SendNUIMessage({ action: 'open' | 'update' | 'close', data })
            akcje wychodzą przez POST https://<resource>/<event>
   ========================================================= */

/* ---------- Ikony (Tabler Icons, outline) ---------- */
const ICONS = {
    "box": "<path d=\"M12 3l8 4.5l0 9l-8 4.5l-8 -4.5l0 -9l8 -4.5\" /> <path d=\"M12 12l8 -4.5\" /> <path d=\"M12 12l0 9\" /> <path d=\"M12 12l-8 -4.5\" />",
    "inbox": "<path d=\"M4 4m0 2a2 2 0 0 1 2 -2h12a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-12a2 2 0 0 1 -2 -2z\" /> <path d=\"M4 13h3l3 3h4l3 -3h3\" />",
    "receipt": "<path d=\"M5 21v-16a2 2 0 0 1 2 -2h10a2 2 0 0 1 2 2v16l-3 -2l-2 2l-2 -2l-2 2l-2 -2l-3 2m4 -14h6m-6 4h6m-2 4h2\" />",
    "tag": "<path d=\"M7.5 7.5m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0\" /> <path d=\"M3 6v5.172a2 2 0 0 0 .586 1.414l7.71 7.71a2.41 2.41 0 0 0 3.408 0l5.592 -5.592a2.41 2.41 0 0 0 0 -3.408l-7.71 -7.71a2 2 0 0 0 -1.414 -.586h-5.172a3 3 0 0 0 -3 3z\" />",
    "bold": "<path d=\"M7 5h6a3.5 3.5 0 0 1 0 7h-6z\" /> <path d=\"M13 12h1a3.5 3.5 0 0 1 0 7h-7v-7\" />",
    "italic": "<path d=\"M11 5l6 0\" /> <path d=\"M7 19l6 0\" /> <path d=\"M14 5l-4 14\" />",
    "underline": "<path d=\"M7 5v5a5 5 0 0 0 10 0v-5\" /> <path d=\"M5 19h14\" />",
    "strikethrough": "<path d=\"M5 12l14 0\" /> <path d=\"M16 6.5a4 2 0 0 0 -4 -1.5h-1a3.5 3.5 0 0 0 0 7h2a3.5 3.5 0 0 1 0 7h-1.5a4 2 0 0 1 -4 -1.5\" />",
    "heading": "<path d=\"M7 12h10\" /> <path d=\"M7 5v14\" /> <path d=\"M17 5v14\" /> <path d=\"M15 19h4\" /> <path d=\"M15 5h4\" /> <path d=\"M5 19h4\" /> <path d=\"M5 5h4\" />",
    "list": "<path d=\"M9 6l11 0\" /> <path d=\"M9 12l11 0\" /> <path d=\"M9 18l11 0\" /> <path d=\"M5 6l0 .01\" /> <path d=\"M5 12l0 .01\" /> <path d=\"M5 18l0 .01\" />",
    "list-numbers": "<path d=\"M11 6h9\" /> <path d=\"M11 12h9\" /> <path d=\"M12 18h8\" /> <path d=\"M4 16a2 2 0 1 1 4 0c0 .591 -.5 1 -1 1.5l-3 2.5h4\" /> <path d=\"M6 10v-6l-2 2\" />",
    "quote": "<path d=\"M10 11h-4a1 1 0 0 1 -1 -1v-3a1 1 0 0 1 1 -1h3a1 1 0 0 1 1 1v6c0 2.667 -1.333 4.333 -4 5\" /> <path d=\"M19 11h-4a1 1 0 0 1 -1 -1v-3a1 1 0 0 1 1 -1h3a1 1 0 0 1 1 1v6c0 2.667 -1.333 4.333 -4 5\" />",
    "clear-formatting": "<path d=\"M17 15l4 4m0 -4l-4 4\" /> <path d=\"M7 6v-1h11v1\" /> <path d=\"M7 19l4 0\" /> <path d=\"M13 5l-4 14\" />",
    "arrow-back-up": "<path d=\"M9 14l-4 -4l4 -4\" /> <path d=\"M5 10h11a4 4 0 1 1 0 8h-1\" />",
    "arrow-forward-up": "<path d=\"M15 14l4 -4l-4 -4\" /> <path d=\"M19 10h-11a4 4 0 1 0 0 8h1\" />",
    "notes": "<path d=\"M5 3m0 2a2 2 0 0 1 2 -2h10a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-10a2 2 0 0 1 -2 -2z\" /> <path d=\"M9 7l6 0\" /> <path d=\"M9 11l6 0\" /> <path d=\"M9 15l4 0\" />",
    "alert-triangle": "<path d=\"M12 9v4\" /> <path d=\"M10.363 3.591l-8.106 13.534a1.914 1.914 0 0 0 1.636 2.871h16.214a1.914 1.914 0 0 0 1.636 -2.87l-8.106 -13.536a1.914 1.914 0 0 0 -3.274 0\" /> <path d=\"M12 16h.01\" />",
    "arrow-big-up-lines": "<path d=\"M9 12h-3.586a1 1 0 0 1 -.707 -1.707l6.586 -6.586a1 1 0 0 1 1.414 0l6.586 6.586a1 1 0 0 1 -.707 1.707h-3.586v3h-6v-3\" /> <path d=\"M9 21h6\" /> <path d=\"M9 18h6\" />",
    "arrow-down": "<path d=\"M12 5l0 14\" /> <path d=\"M18 13l-6 6\" /> <path d=\"M6 13l6 6\" />",
    "arrow-up": "<path d=\"M12 5l0 14\" /> <path d=\"M18 11l-6 -6\" /> <path d=\"M6 11l6 -6\" />",
    "arrows-maximize": "<path d=\"M16 4l4 0l0 4\" /> <path d=\"M14 10l6 -6\" /> <path d=\"M8 20l-4 0l0 -4\" /> <path d=\"M4 20l6 -6\" /> <path d=\"M16 20l4 0l0 -4\" /> <path d=\"M14 14l6 6\" /> <path d=\"M8 4l-4 0l0 4\" /> <path d=\"M4 4l6 6\" />",
    "bell": "<path d=\"M10 5a2 2 0 1 1 4 0a7 7 0 0 1 4 6v3a4 4 0 0 0 2 3h-16a4 4 0 0 0 2 -3v-3a7 7 0 0 1 4 -6\" /> <path d=\"M9 17v1a3 3 0 0 0 6 0v-1\" />",
    "briefcase": "<path d=\"M3 9a2 2 0 0 1 2 -2h14a2 2 0 0 1 2 2v9a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2l0 -9\" /> <path d=\"M8 7v-2a2 2 0 0 1 2 -2h4a2 2 0 0 1 2 2v2\" /> <path d=\"M12 12l0 .01\" /> <path d=\"M3 13a20 20 0 0 0 18 0\" />",
    "building-bank": "<path d=\"M3 21l18 0\" /> <path d=\"M3 10l18 0\" /> <path d=\"M5 6l7 -3l7 3\" /> <path d=\"M4 10l0 11\" /> <path d=\"M20 10l0 11\" /> <path d=\"M8 14l0 3\" /> <path d=\"M12 14l0 3\" /> <path d=\"M16 14l0 3\" />",
    "cash": "<path d=\"M7 15h-3a1 1 0 0 1 -1 -1v-8a1 1 0 0 1 1 -1h12a1 1 0 0 1 1 1v3\" /> <path d=\"M7 10a1 1 0 0 1 1 -1h12a1 1 0 0 1 1 1v8a1 1 0 0 1 -1 1h-12a1 1 0 0 1 -1 -1l0 -8\" /> <path d=\"M12 14a2 2 0 1 0 4 0a2 2 0 0 0 -4 0\" />",
    "check": "<path d=\"M5 12l5 5l10 -10\" />",
    "chevron-down": "<path d=\"M6 9l6 6l6 -6\" />",
    "chevron-up": "<path d=\"M6 15l6 -6l6 6\" />",
    "clock-hour-4": "<path d=\"M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0\" /> <path d=\"M12 12l3 2\" /> <path d=\"M12 7v5\" />",
    "clock": "<path d=\"M3 12a9 9 0 1 0 18 0a9 9 0 0 0 -18 0\" /> <path d=\"M12 7v5l3 3\" />",
    "coins": "<path d=\"M9 14c0 1.657 2.686 3 6 3s6 -1.343 6 -3s-2.686 -3 -6 -3s-6 1.343 -6 3\" /> <path d=\"M9 14v4c0 1.656 2.686 3 6 3s6 -1.344 6 -3v-4\" /> <path d=\"M3 6c0 1.072 1.144 2.062 3 2.598s4.144 .536 6 0c1.856 -.536 3 -1.526 3 -2.598c0 -1.072 -1.144 -2.062 -3 -2.598s-4.144 -.536 -6 0c-1.856 .536 -3 1.526 -3 2.598\" /> <path d=\"M3 6v10c0 .888 .772 1.45 2 2\" /> <path d=\"M3 11c0 .888 .772 1.45 2 2\" />",
    "copy": "<path d=\"M7 9.667a2.667 2.667 0 0 1 2.667 -2.667h8.666a2.667 2.667 0 0 1 2.667 2.667v8.666a2.667 2.667 0 0 1 -2.667 2.667h-8.666a2.667 2.667 0 0 1 -2.667 -2.667l0 -8.666\" /> <path d=\"M4.012 16.737a2.005 2.005 0 0 1 -1.012 -1.737v-10c0 -1.1 .9 -2 2 -2h10c.75 0 1.158 .385 1.5 1\" />",
    "dots-vertical": "<path d=\"M11 12a1 1 0 1 0 2 0a1 1 0 1 0 -2 0\" /> <path d=\"M11 19a1 1 0 1 0 2 0a1 1 0 1 0 -2 0\" /> <path d=\"M11 5a1 1 0 1 0 2 0a1 1 0 1 0 -2 0\" />",
    "edit": "<path d=\"M7 7h-1a2 2 0 0 0 -2 2v9a2 2 0 0 0 2 2h9a2 2 0 0 0 2 -2v-1\" /> <path d=\"M20.385 6.585a2.1 2.1 0 0 0 -2.97 -2.97l-8.415 8.385v3h3l8.385 -8.415\" /> <path d=\"M16 5l3 3\" />",
    "device-floppy": "<path d=\"M6 4h10l4 4v10a2 2 0 0 1 -2 2h-12a2 2 0 0 1 -2 -2v-12a2 2 0 0 1 2 -2\" /> <path d=\"M10 14a2 2 0 1 0 4 0a2 2 0 1 0 -4 0\" /> <path d=\"M14 4l0 4l-6 0l0 -4\" />",
    "palette": "<path d=\"M12 21a9 9 0 0 1 0 -18c4.97 0 9 3.582 9 8c0 1.06 -.474 2.078 -1.318 2.828c-.844 .75 -1.989 1.172 -3.182 1.172h-2.5a2 2 0 0 0 -1 3.75a1.3 1.3 0 0 1 -1 2.25\" /> <path d=\"M7.5 10.5a1 1 0 1 0 2 0a1 1 0 1 0 -2 0\" /> <path d=\"M11.5 7.5a1 1 0 1 0 2 0a1 1 0 1 0 -2 0\" /> <path d=\"M15.5 10.5a1 1 0 1 0 2 0a1 1 0 1 0 -2 0\" />",
    "volume": "<path d=\"M15 8a5 5 0 0 1 0 8\" /> <path d=\"M17.7 5a9 9 0 0 1 0 14\" /> <path d=\"M6 15h-2a1 1 0 0 1 -1 -1v-4a1 1 0 0 1 1 -1h2l3.5 -4.5a.8 .8 0 0 1 1.5 .5v14a.8 .8 0 0 1 -1.5 .5l-3.5 -4.5\" />",
    "app-window": "<path d=\"M3 7a2 2 0 0 1 2 -2h14a2 2 0 0 1 2 2v10a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-10\" /> <path d=\"M6 8h.01\" /> <path d=\"M9 8h.01\" />",
    "text-size": "<path d=\"M3 7v-2h13v2\" /> <path d=\"M10 5v14\" /> <path d=\"M12 19h-4\" /> <path d=\"M15 13v-1h6v1\" /> <path d=\"M18 12v7\" /> <path d=\"M17 19h2\" />",
    "hourglass": "<path d=\"M6.5 7h11\" /> <path d=\"M6.5 17h11\" /> <path d=\"M6 20v-2a6 6 0 1 1 12 0v2a1 1 0 0 1 -1 1h-10a1 1 0 0 1 -1 -1\" /> <path d=\"M6 4v2a6 6 0 1 0 12 0v-2a1 1 0 0 0 -1 -1h-10a1 1 0 0 0 -1 1\" />",
    "sparkles": "<path d=\"M16 18a2 2 0 0 1 2 2a2 2 0 0 1 2 -2a2 2 0 0 1 -2 -2a2 2 0 0 1 -2 2m0 -12a2 2 0 0 1 2 2a2 2 0 0 1 2 -2a2 2 0 0 1 -2 -2a2 2 0 0 1 -2 2m-7 12a6 6 0 0 1 6 -6a6 6 0 0 1 -6 -6a6 6 0 0 1 -6 6a6 6 0 0 1 6 6\" />",
    "layout-board": "<path d=\"M4 6a2 2 0 0 1 2 -2h12a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-12a2 2 0 0 1 -2 -2l0 -12\" /> <path d=\"M4 9h8\" /> <path d=\"M12 15h8\" /> <path d=\"M12 4v16\" />",
    "rocket": "<path d=\"M4 13a8 8 0 0 1 7 7a6 6 0 0 0 3 -5a9 9 0 0 0 6 -8a3 3 0 0 0 -3 -3a9 9 0 0 0 -8 6a6 6 0 0 0 -5 3\" /> <path d=\"M7 14a6 6 0 0 0 -3 6a6 6 0 0 0 6 -3\" /> <path d=\"M14 9a1 1 0 1 0 2 0a1 1 0 1 0 -2 0\" />",
    "player-play": "<path d=\"M7 4v16l13 -8l-13 -8\" />",
    "car": "<path d=\"M5 17a2 2 0 1 0 4 0a2 2 0 1 0 -4 0\" /> <path d=\"M15 17a2 2 0 1 0 4 0a2 2 0 1 0 -4 0\" /> <path d=\"M5 17h-2v-6l2 -5h9l4 5h1a2 2 0 0 1 2 2v4h-2m-4 0h-6m-6 -6h15m-6 0v-5\" />",
    "garage": "<path d=\"M4 21v-10l8 -7l8 7v10\" /> <path d=\"M8 21v-8h8v8\" /> <path d=\"M8 17h8\" /> <path d=\"M2 21h20\" />",
    "shopping-cart": "<path d=\"M4 19a2 2 0 1 0 4 0a2 2 0 1 0 -4 0\" /> <path d=\"M15 19a2 2 0 1 0 4 0a2 2 0 1 0 -4 0\" /> <path d=\"M17 17h-11v-14h-2\" /> <path d=\"M6 5l14 1l-1 7h-13\" />",
    "package": "<path d=\"M12 3l8 4.5l0 9l-8 4.5l-8 -4.5l0 -9l8 -4.5\" /> <path d=\"M12 12l8 -4.5\" /> <path d=\"M12 12l0 9\" /> <path d=\"M12 12l-8 -4.5\" /> <path d=\"M16 5.25l-8 4.5\" />",
    "user-minus": "<path d=\"M8 7a4 4 0 1 0 8 0a4 4 0 0 0 -8 0\" /> <path d=\"M6 21v-2a4 4 0 0 1 4 -4h4c.348 0 .686 .045 1.009 .128\" /> <path d=\"M16 19h6\" />",
    "truck-delivery": "<path d=\"M5 17a2 2 0 1 0 4 0a2 2 0 1 0 -4 0\" /> <path d=\"M15 17a2 2 0 1 0 4 0a2 2 0 1 0 -4 0\" /> <path d=\"M5 17h-2v-4m-1 -8h11v12m-4 0h6m4 0h2v-6h-8m0 -5h5l3 5\" /> <path d=\"M3 9l4 0\" />",
    "building-store": "<path d=\"M3 21l18 0\" /> <path d=\"M3 7v1a3 3 0 0 0 6 0v-1m0 1a3 3 0 0 0 6 0v-1m0 1a3 3 0 0 0 6 0v-1h-18l2 -4h14l2 4\" /> <path d=\"M5 21l0 -10.15\" /> <path d=\"M19 21l0 -10.15\" /> <path d=\"M9 21v-4a2 2 0 0 1 2 -2h2a2 2 0 0 1 2 2v4\" />",
    "info-circle": "<path d=\"M3 12a9 9 0 1 0 18 0a9 9 0 0 0 -18 0\" /> <path d=\"M12 9h.01\" /> <path d=\"M11 12h1v4h1\" />",
    "bolt": "<path d=\"M13 3l0 7l6 0l-8 11l0 -7l-6 0l8 -11\" />",
    "shopping-cart-plus": "<path d=\"M4 19a2 2 0 1 0 4 0a2 2 0 0 0 -4 0\" /> <path d=\"M12.5 17h-6.5v-14h-2\" /> <path d=\"M6 5l14 1l-.86 6.017m-2.64 .983h-10.5\" /> <path d=\"M16 19h6\" /> <path d=\"M19 16v6\" />",
    "list-details": "<path d=\"M13 5h8\" /> <path d=\"M13 9h5\" /> <path d=\"M13 15h8\" /> <path d=\"M13 19h5\" /> <path d=\"M3 5a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4\" /> <path d=\"M3 15a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4\" />",
    "eye": "<path d=\"M10 12a2 2 0 1 0 4 0a2 2 0 0 0 -4 0\" /> <path d=\"M21 12c-2.4 4 -5.4 6 -9 6c-3.6 0 -6.6 -2 -9 -6c2.4 -4 5.4 -6 9 -6c3.6 0 6.6 2 9 6\" />",
    "file-text": "<path d=\"M14 3v4a1 1 0 0 0 1 1h4\" /> <path d=\"M17 21h-10a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2h7l5 5v11a2 2 0 0 1 -2 2\" /> <path d=\"M9 9l1 0\" /> <path d=\"M9 13l6 0\" /> <path d=\"M9 17l6 0\" />",
    "history": "<path d=\"M12 8l0 4l2 2\" /> <path d=\"M3.05 11a9 9 0 1 1 .5 4m-.5 5v-5h5\" />",
    "id-badge-2": "<path d=\"M7 12h3v4h-3l0 -4\" /> <path d=\"M10 6h-6a1 1 0 0 0 -1 1v12a1 1 0 0 0 1 1h16a1 1 0 0 0 1 -1v-12a1 1 0 0 0 -1 -1h-6\" /> <path d=\"M10 4a1 1 0 0 1 1 -1h2a1 1 0 0 1 1 1v3a1 1 0 0 1 -1 1h-2a1 1 0 0 1 -1 -1l0 -3\" /> <path d=\"M14 16h2\" /> <path d=\"M14 12h4\" />",
    "ladder": "<path d=\"M8 3v18\" /> <path d=\"M16 3v18\" /> <path d=\"M8 14h8\" /> <path d=\"M8 10h8\" /> <path d=\"M8 6h8\" /> <path d=\"M8 18h8\" />",
    "layout-grid": "<path d=\"M4 5a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4\" /> <path d=\"M14 5a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4\" /> <path d=\"M4 15a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4\" /> <path d=\"M14 15a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4\" />",
    "minus": "<path d=\"M5 12l14 0\" />",
    "plus": "<path d=\"M12 5l0 14\" /> <path d=\"M5 12l14 0\" />",
    "power": "<path d=\"M7 6a7.75 7.75 0 1 0 10 0\" /> <path d=\"M12 4l0 8\" />",
    "receipt-2": "<path d=\"M5 21v-16a2 2 0 0 1 2 -2h10a2 2 0 0 1 2 2v16l-3 -2l-2 2l-2 -2l-2 2l-2 -2l-3 2\" /> <path d=\"M14 8h-2.5a1.5 1.5 0 0 0 0 3h1a1.5 1.5 0 0 1 0 3h-2.5m2 0v1.5m0 -9v1.5\" />",
    "search": "<path d=\"M3 10a7 7 0 1 0 14 0a7 7 0 1 0 -14 0\" /> <path d=\"M21 21l-6 -6\" />",
    "settings": "<path d=\"M10.325 4.317c.426 -1.756 2.924 -1.756 3.35 0a1.724 1.724 0 0 0 2.573 1.066c1.543 -.94 3.31 .826 2.37 2.37a1.724 1.724 0 0 0 1.065 2.572c1.756 .426 1.756 2.924 0 3.35a1.724 1.724 0 0 0 -1.066 2.573c.94 1.543 -.826 3.31 -2.37 2.37a1.724 1.724 0 0 0 -2.572 1.065c-.426 1.756 -2.924 1.756 -3.35 0a1.724 1.724 0 0 0 -2.573 -1.066c-1.543 .94 -3.31 -.826 -2.37 -2.37a1.724 1.724 0 0 0 -1.065 -2.572c-1.756 -.426 -1.756 -2.924 0 -3.35a1.724 1.724 0 0 0 1.066 -2.573c-.94 -1.543 .826 -3.31 2.37 -2.37c1 .608 2.296 .07 2.572 -1.065\" /> <path d=\"M9 12a3 3 0 1 0 6 0a3 3 0 0 0 -6 0\" />",
    "square": "<path d=\"M3 5a2 2 0 0 1 2 -2h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-14\" />",
    "user-check": "<path d=\"M8 7a4 4 0 1 0 8 0a4 4 0 0 0 -8 0\" /> <path d=\"M6 21v-2a4 4 0 0 1 4 -4h4\" /> <path d=\"M15 19l2 2l4 -4\" />",
    "user-circle": "<path d=\"M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0\" /> <path d=\"M9 10a3 3 0 1 0 6 0a3 3 0 1 0 -6 0\" /> <path d=\"M6.168 18.849a4 4 0 0 1 3.832 -2.849h4a4 4 0 0 1 3.834 2.855\" />",
    "user-off": "<path d=\"M8.18 8.189a4.01 4.01 0 0 0 2.616 2.627m3.507 -.545a4 4 0 1 0 -5.59 -5.552\" /> <path d=\"M6 21v-2a4 4 0 0 1 4 -4h4c.412 0 .81 .062 1.183 .178m2.633 2.618c.12 .38 .184 .785 .184 1.204v2\" /> <path d=\"M3 3l18 18\" />",
    "user-plus": "<path d=\"M8 7a4 4 0 1 0 8 0a4 4 0 0 0 -8 0\" /> <path d=\"M16 19h6\" /> <path d=\"M19 16v6\" /> <path d=\"M6 21v-2a4 4 0 0 1 4 -4h4\" />",
    "user-x": "<path d=\"M8 7a4 4 0 1 0 8 0a4 4 0 0 0 -8 0\" /> <path d=\"M6 21v-2a4 4 0 0 1 4 -4h3.5\" /> <path d=\"M22 22l-5 -5\" /> <path d=\"M17 22l5 -5\" />",
    "users": "<path d=\"M5 7a4 4 0 1 0 8 0a4 4 0 1 0 -8 0\" /> <path d=\"M3 21v-2a4 4 0 0 1 4 -4h4a4 4 0 0 1 4 4v2\" /> <path d=\"M16 3.13a4 4 0 0 1 0 7.75\" /> <path d=\"M21 21v-2a4 4 0 0 0 -3 -3.85\" />",
    "wallet": "<path d=\"M17 8v-3a1 1 0 0 0 -1 -1h-10a2 2 0 0 0 0 4h12a1 1 0 0 1 1 1v3m0 4v3a1 1 0 0 1 -1 1h-12a2 2 0 0 1 -2 -2v-12\" /> <path d=\"M20 12v4h-4a2 2 0 0 1 0 -4h4\" />",
    "window-minimize": "<path d=\"M3 17a1 1 0 0 1 1 -1h3a1 1 0 0 1 1 1v3a1 1 0 0 1 -1 1h-3a1 1 0 0 1 -1 -1l0 -3\" /> <path d=\"M4 12v-6a2 2 0 0 1 2 -2h12a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-6\" /> <path d=\"M15 13h-4v-4\" /> <path d=\"M11 13l5 -5\" />",
    "x": "<path d=\"M18 6l-12 12\" /> <path d=\"M6 6l12 12\" />",
    "refresh": "<path d=\"M20 11a8.1 8.1 0 0 0 -15.5 -2m-.5 -4v4h4\" /> <path d=\"M4 13a8.1 8.1 0 0 0 15.5 2m.5 4v-4h-4\" />",
    "badge": "<path d=\"M17 17v-13l-5 3l-5 -3v13l5 3l5 -3\" />",
    "id": "<path d=\"M3 7a3 3 0 0 1 3 -3h12a3 3 0 0 1 3 3v10a3 3 0 0 1 -3 3h-12a3 3 0 0 1 -3 -3l0 -10\" /> <path d=\"M7 10a2 2 0 1 0 4 0a2 2 0 1 0 -4 0\" /> <path d=\"M15 8l2 0\" /> <path d=\"M15 12l2 0\" /> <path d=\"M7 16l10 0\" />",
    "tool": "<path d=\"M7 10h3v-3l-3.5 -3.5a6 6 0 0 1 8 8l6 6a2 2 0 0 1 -3 3l-6 -6a6 6 0 0 1 -8 -8l3.5 3.5\" />",
    "chevron-right": "<path d=\"M9 6l6 6l-6 6\" />",
    "arrow-left": "<path d=\"M5 12l14 0\" /> <path d=\"M5 12l6 6\" /> <path d=\"M5 12l6 -6\" />",
    "calendar": "<path d=\"M4 7a2 2 0 0 1 2 -2h12a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-12a2 2 0 0 1 -2 -2v-12\" /> <path d=\"M16 3v4\" /> <path d=\"M8 3v4\" /> <path d=\"M4 11h16\" /> <path d=\"M11 15h1\" /> <path d=\"M12 15v3\" />",
    "phone": "<path d=\"M5 4h4l2 5l-2.5 1.5a11 11 0 0 0 5 5l1.5 -2.5l5 2v4a2 2 0 0 1 -2 2a16 16 0 0 1 -15 -15a2 2 0 0 1 2 -2\" />",
    "flame": "<path d=\"M12 10.941c2.333 -3.308 .167 -7.823 -1 -8.941c0 3.395 -2.235 5.299 -3.667 6.706c-1.43 1.408 -2.333 3.294 -2.333 5.588c0 3.704 3.134 6.706 7 6.706c3.866 0 7 -3.002 7 -6.706c0 -1.712 -1.232 -4.403 -2.333 -5.588c-2.084 3.353 -3.257 3.353 -4.667 2.235\" />",
    "brush": "<path d=\"M3 21v-4a4 4 0 1 1 4 4h-4\" /> <path d=\"M21 3a16 16 0 0 0 -12.8 10.2\" /> <path d=\"M21 3a16 16 0 0 1 -10.2 12.8\" /> <path d=\"M10.6 9a9 9 0 0 1 4.4 4.4\" />",
    "engine": "<path d=\"M3 10v6\" /> <path d=\"M12 5v3\" /> <path d=\"M10 5h4\" /> <path d=\"M5 13h-2\" /> <path d=\"M6 10h2l2 -2h3.382a1 1 0 0 1 .894 .553l1.448 2.894a1 1 0 0 0 .894 .553h1.382v-2h2a1 1 0 0 1 1 1v6a1 1 0 0 1 -1 1h-2v-2h-3v2a1 1 0 0 1 -1 1h-3.465a1 1 0 0 1 -.832 -.445l-1.703 -2.555h-2v-6\" />",
    "car-crane": "<path d=\"M3 17a2 2 0 1 0 4 0a2 2 0 1 0 -4 0\" /> <path d=\"M15 17a2 2 0 1 0 4 0a2 2 0 1 0 -4 0\" /> <path d=\"M7 18h8m4 0h2v-6a5 5 0 0 0 -5 -5h-1l1.5 5h4.5\" /> <path d=\"M12 18v-11h3\" /> <path d=\"M3 17v-5h9\" /> <path d=\"M4 12v-6l18 -3v2\" /> <path d=\"M8 12v-4l-4 -2\" />",
    "shield-check": "<path d=\"M11.46 20.846a12 12 0 0 1 -7.96 -14.846a12 12 0 0 0 8.5 -3a12 12 0 0 0 8.5 3a12 12 0 0 1 -.09 7.06\" /> <path d=\"M15 19l2 2l4 -4\" />",
    "school": "<path d=\"M22 9l-10 -4l-10 4l10 4l10 -4v6\" /> <path d=\"M6 10.6v5.4a6 3 0 0 0 12 0v-5.4\" />",
    "trophy": "<path d=\"M8 21l8 0\" /> <path d=\"M12 17l0 4\" /> <path d=\"M7 4l10 0\" /> <path d=\"M17 4v8a5 5 0 0 1 -10 0v-8\" /> <path d=\"M3 9a2 2 0 1 0 4 0a2 2 0 1 0 -4 0\" /> <path d=\"M17 9a2 2 0 1 0 4 0a2 2 0 1 0 -4 0\" />",
    "medal": "<path d=\"M12 4v3m-4 -3v6m8 -6v6\" /> <path d=\"M12 18.5l-3 1.5l.5 -3.5l-2 -2l3 -.5l1.5 -3l1.5 3l3 .5l-2 2l.5 3.5l-3 -1.5\" />",
    "award": "<path d=\"M6 9a6 6 0 1 0 12 0a6 6 0 1 0 -12 0\" /> <path d=\"M12 15l3.4 5.89l1.598 -3.233l3.598 .232l-3.4 -5.889\" /> <path d=\"M6.802 12l-3.4 5.89l3.598 -.233l1.598 3.232l3.4 -5.889\" />",
    "certificate": "<path d=\"M12 15a3 3 0 1 0 6 0a3 3 0 1 0 -6 0\" /> <path d=\"M13 17.5v4.5l2 -1.5l2 1.5v-4.5\" /> <path d=\"M10 19h-5a2 2 0 0 1 -2 -2v-10c0 -1.1 .9 -2 2 -2h14a2 2 0 0 1 2 2v10a2 2 0 0 1 -1 1.73\" /> <path d=\"M6 9l12 0\" /> <path d=\"M6 12l3 0\" /> <path d=\"M6 15l2 0\" />",
    "license": "<path d=\"M15 21h-9a3 3 0 0 1 -3 -3v-1h10v2a2 2 0 0 0 4 0v-14a2 2 0 1 1 2 2h-2m2 -4h-11a3 3 0 0 0 -3 3v11\" /> <path d=\"M9 7l4 0\" /> <path d=\"M9 11l4 0\" />",
    "arrows-right": "<path d=\"M21 17l-18 0\" /> <path d=\"M18 4l3 3l-3 3\" /> <path d=\"M18 20l3 -3l-3 -3\" /> <path d=\"M21 7l-18 0\" />",
    "hash": "<path d=\"M5 9l14 0\" /> <path d=\"M5 15l14 0\" /> <path d=\"M11 4l-4 16\" /> <path d=\"M17 4l-4 16\" />",
    "chevron-left": "<path d=\"M15 6l-6 6l6 6\" />",
    "circle-minus": "<path d=\"M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0\" /> <path d=\"M9 12l6 0\" />",
    "circle-plus": "<path d=\"M3 12a9 9 0 1 0 18 0a9 9 0 0 0 -18 0\" /> <path d=\"M9 12h6\" /> <path d=\"M12 9v6\" />",
    "arrow-right": "<path d=\"M5 12l14 0\" /> <path d=\"M13 18l6 -6\" /> <path d=\"M13 6l6 6\" />",
    "ban": "<path d=\"M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0\" /> <path d=\"M5.7 5.7l12.6 12.6\" />",
    "brand-discord": "<path d=\"M8 12a1 1 0 1 0 2 0a1 1 0 0 0 -2 0\" /> <path d=\"M14 12a1 1 0 1 0 2 0a1 1 0 0 0 -2 0\" /> <path d=\"M15.5 17c0 1 1.5 3 2 3c1.5 0 2.833 -1.667 3.5 -3c.667 -1.667 .5 -5.833 -1.5 -11.5c-1.457 -1.015 -3 -1.34 -4.5 -1.5l-.972 1.923a11.913 11.913 0 0 0 -4.053 0l-.975 -1.923c-1.5 .16 -3.043 .485 -4.5 1.5c-2 5.667 -2.167 9.833 -1.5 11.5c.667 1.333 2 3 3.5 3c.5 0 2 -2 2 -3\" /> <path d=\"M7 16.5c3.5 1 6.5 1 10 0\" />",
    "building-community": "<path d=\"M8 9l5 5v7h-5v-4m0 4h-5v-7l5 -5m1 1v-6a1 1 0 0 1 1 -1h10a1 1 0 0 1 1 1v17h-8\" /> <path d=\"M13 7l0 .01\" /> <path d=\"M17 7l0 .01\" /> <path d=\"M17 11l0 .01\" /> <path d=\"M17 15l0 .01\" />",
    "link": "<path d=\"M9 15l6 -6\" /> <path d=\"M11 6l.463 -.536a5 5 0 0 1 7.071 7.072l-.534 .464\" /> <path d=\"M13 18l-.397 .534a5.068 5.068 0 0 1 -7.127 0a4.972 4.972 0 0 1 0 -7.071l.524 -.463\" />",
    "send": "<path d=\"M10 14l11 -11\" /> <path d=\"M21 3l-6.5 18a.55 .55 0 0 1 -1 0l-3.5 -7l-7 -3.5a.55 .55 0 0 1 0 -1l18 -6.5\" />",
    "trash": "<path d=\"M4 7l16 0\" /> <path d=\"M10 11l0 6\" /> <path d=\"M14 11l0 6\" /> <path d=\"M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2 -2l1 -12\" /> <path d=\"M9 7v-3a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v3\" />"
};

const icon = (name, cls = 'size-5') =>
    `<svg xmlns="http://www.w3.org/2000/svg" class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${ICONS[name] || ''}</svg>`;

/* ---------- Helpery ---------- */
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = n => (n < 0 ? '-$' : '$') + Math.abs(Number(n)).toLocaleString('en-US').replace(/,/g, ' ');
// Duże kwoty nie mogą się ucinać: dobieramy wielkość czcionki do długości tekstu (np. saldo 100 000 000).
const moneyFs = (v, base = 26, mid = 20, small = 15) => { const L = String(v).length; return L > 15 ? small - 2 : L > 12 ? small : L > 9 ? mid : base; };
const valFs = v => { const L = String(v).length; return L > 18 ? 10 : L > 14 ? 11 : L > 11 ? 12 : 14; };
const initials = n => n.split(' ').map(p => p[0]).join('').slice(0, 2).toUpperCase();
const fullName = p => p.name || `${p.firstname} ${p.lastname}`;
const pad = n => String(n).padStart(2, '0');
const nowFull = () => { const d = new Date(); return `${today()} ${pad(d.getHours())}:${pad(d.getMinutes())}`; };
const fmtHours = h => { const m = Math.round((h || 0) * 60); return `${Math.floor(m / 60)} h ${pad(m % 60)} min`; };
const fmtClock = d => CFG.timeFmt === '12' ? `${d.getHours() % 12 || 12}:${pad(d.getMinutes())} ${d.getHours() < 12 ? 'AM' : 'PM'}` : `${pad(d.getHours())}:${pad(d.getMinutes())}`;
const joinDate = (dd, mm, y) => CFG.dateFmt === 'ymd' ? [y, mm, dd].filter(Boolean).join('-') : CFG.dateFmt === 'mdy' ? [mm, dd, y].filter(Boolean).join('/') : [dd, mm, y].filter(Boolean).join('.');
const fmtDate = d => joinDate(pad(d.getDate()), pad(d.getMonth() + 1), d.getFullYear());
/* tekst z serwera 'DD.MM[.RRRR][ HH:MM]' -> zgodnie z ustawieniami czasu i daty; short: bez roku, jeśli bieżący (inny rok: 2 cyfry) */
function fmtAt(str, short = false) {
    const m = /^(\d{2})\.(\d{2})(?:\.(\d{4}))?(?:\s+(\d{2}):(\d{2}))?$/.exec(String(str || '').trim());
    if (!m) return str || '—';
    const [, dd, mm, yy, hh, mi] = m;
    const y = !yy ? '' : short ? (+yy === new Date().getFullYear() ? '' : yy.slice(2)) : yy;
    const date = joinDate(dd, mm, y);
    if (hh === undefined) return date;
    const h = +hh, time = CFG.timeFmt === '12' ? `${h % 12 || 12}:${mi} ${h < 12 ? 'AM' : 'PM'}` : `${hh}:${mi}`;
    return `${date} ${time}`;
}
const sameSsn = (a, b) => String(a ?? '') === String(b ?? '');     // SSN z bazy bywa liczbą, a z HTML zawsze tekstem
const getEmp = ssn => S.employees.find(e => sameSsn(e.ssn, ssn));
const today = () => { const d = new Date(); return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()}`; };
const ago = m => m < 1 ? 'teraz' : m < 60 ? `${m} min temu` : m < 1440 ? `${Math.floor(m / 60)} godz. temu` : `${Math.floor(m / 1440)} dni temu`;
const stamp = () => { const d = new Date(); return `${pad(d.getDate())}.${pad(d.getMonth() + 1)} ${pad(d.getHours())}:${pad(d.getMinutes())}`; };

const TONES = {
    brand: 'text-brand bg-brand/10 border-brand/30',
    sky: 'text-sky-400 bg-sky-500/10 border-sky-500/30',
    amber: 'text-amber-400 bg-amber-500/10 border-amber-500/30',
    emerald: 'text-emerald-400 bg-emerald-500/10 border-emerald-500/30',
    violet: 'text-violet-300 bg-violet-500/10 border-violet-500/30',
    slate: 'text-slate-300 bg-slate-500/10 border-slate-500/30'
};

/* ---------- Dźwięki interfejsu (syntezowane WebAudio – bez plików) ---------- */
let AC = null;
function sfx(name) {
    if (!CFG.sound || !CFG.volume) return;
    try { AC = AC || new (window.AudioContext || window.webkitAudioContext)(); if (AC.state === 'suspended') AC.resume(); } catch (e) { return; }
    const t0 = AC.currentTime, vol = CFG.volume / 100;
    const tone = (f, at, dur, type = 'sine', g = 0.14, f2) => {
        const o = AC.createOscillator(), a = AC.createGain();
        o.type = type; o.frequency.setValueAtTime(f, t0 + at);
        if (f2) o.frequency.exponentialRampToValueAtTime(f2, t0 + at + dur);
        a.gain.setValueAtTime(0.0001, t0 + at);
        a.gain.exponentialRampToValueAtTime(Math.max(0.0002, g * vol), t0 + at + 0.01);
        a.gain.exponentialRampToValueAtTime(0.0001, t0 + at + dur);
        o.connect(a); a.connect(AC.destination); o.start(t0 + at); o.stop(t0 + at + dur + 0.03);
    };
    ({
        click: () => tone(1500, 0, 0.045, 'sine', 0.08, 900),
        open: () => { tone(520, 0, 0.1); tone(780, 0.06, 0.14); },
        close: () => { tone(700, 0, 0.09); tone(430, 0.06, 0.12); },
        modal: () => tone(640, 0, 0.09, 'sine', 0.1, 420),
        success: () => { tone(660, 0, 0.11); tone(880, 0.09, 0.18); },
        info: () => tone(900, 0, 0.16, 'sine', 0.12),
        warn: () => { tone(420, 0, 0.12, 'triangle', 0.16); tone(420, 0.15, 0.14, 'triangle', 0.16); },
        error: () => { tone(230, 0, 0.14, 'square', 0.06); tone(170, 0.13, 0.2, 'square', 0.06); }
    }[name] || (() => { }))();
}

/* ---------- Komunikacja z grą (NUI) ---------- */
/* BUILD – znacznik wersji. Szukaj go w konsoli (nui_devtools) po starcie:
   brak tego wpisu = gra nadal ładuje STARY plik (cache / inna kopia / zły ui_page). */
const BUILD = 'nui-fix-3 · 2026-10-01';
/* Wykrywanie, czy strona działa w NUI FiveM:
   1) GetParentResourceName wstrzykuje FiveM,
   2) protokół nui:// (strony NUI w grze),
   3) host zawierający cfx-nui-<resource>.
   Punkty 2-3 chronią na wypadek, gdyby shim nie istniał w chwili startu skryptu –
   w przeciwnym razie strona wpadłaby w tryb DEV i pomalowała ekran w grze. */
const NUI_URL = /^nui:/i.test(location.protocol) || /cfx-nui-/i.test(location.host) || /cfx-nui-/i.test(location.href);
let IN_GAME = typeof GetParentResourceName === 'function' || NUI_URL;
let DEV_ON = false;
const BASE = (document.currentScript?.src || location.href).replace(/[?#].*$/, '').replace(/[^/]*$/, '');   // katalog bossmenu.js – stąd ładujemy vendor/
/* `model: null` / `expressFee: null` w ogóle nie lecą do Lua – w transporcie NUI `null` i brak klucza
   to dla msgpacka to samo, a dzięki temu nie trzeba pamiętać o porównaniach z `json.null` po stronie serwera. */
const stripNulls = data => Object.fromEntries(Object.entries(data || {}).filter(([, v]) => v !== null && v !== undefined));
const nui = (event, data) => fetch(`https://${GetParentResourceName()}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(stripNulls(data))
}).then(r => r.json()).catch(() => null);
let OPEN_ACTION = 'bossmenu';   // nazwa akcji, którą Lua otworzyło UI (ui.openUI(action, data)) – wraca w `close`
let DID_CHANGE = true;         // czy w tej sesji wykonano jakąkolwiek akcję (idzie jako `success` w `close`)
// bez odpowiedzi
const post = (event, data = {}) => {
    if (!IN_GAME) return console.log('[bossmenu] ->', event, data);
    if (event !== 'close') DID_CHANGE = true;
    nui(event, data);
};
// z odpowiedzią serwera: callback NUI zwraca JSON, np. { ok: true, employee: {...} } albo { ok: false, error: '...' }
const request = (event, data = {}) => IN_GAME
    ? nui(event, data).then(r => { if (r?.ok && event !== 'bossmenu:testWebhook') DID_CHANGE = true; return r || { ok: false, error: 'Brak odpowiedzi serwera' }; })
    : new Promise(res => setTimeout(() => res(devReply(event, data)), 350));

/* ---------- Stan danych ---------- */
let S = {
    search: '',
    filter: 'all',          // all | duty | break | off
    job: { name: 'job', label: 'Firma' },
    me: { ssn: '', firstname: '—', lastname: '', grade: 0 },
    features: { licenses: false, badges: false, records: false },   // włączane przez serwer
    licenseDefs: [],
    grades: [], employees: [], funds: 0, maxPrice: 0, related: [], transactions: [], history: [],
    catalog: [], vehicles: [], orders: [], supplier: '',      // garaż
    shop: { suppliers: [], offer: null, out: [], incoming: [] },   // zamówienia B2B (towary)
    salaryMax: null,                                         // limit stawki za godzinę (null = brak limitu w UI)
    webhooks: { plusminus: '', commend: '', promo: '' }
};

/* Zabezpieczenie danych z serwera: brakujace/puste pola nie moga wywalic renderowania.
   Wyjatek w trakcie otwierania okna = gracz zostawal z czarnym, pustym pulpitem. */
function normalizeState(s) {
    if (!s || typeof s !== 'object') s = {};
    if (!s.job || typeof s.job !== 'object') s.job = { name: 'job', label: 'Firma' };
    if (typeof s.job.name !== 'string' || !s.job.name) s.job.name = 'job';
    if (!s.me || typeof s.me !== 'object') s.me = { ssn: '', firstname: '—', lastname: '', grade: 0 };
    if (!s.features || typeof s.features !== 'object') s.features = {};
    ['licenseDefs', 'grades', 'employees', 'transactions', 'history', 'catalog', 'vehicles', 'orders', 'related'].forEach(k => { if (!Array.isArray(s[k])) s[k] = []; });
    s.funds = Number(s.funds) || 0;
    s.maxPrice = Number(s.maxPrice) || 0;
    if (!s.webhooks || typeof s.webhooks !== 'object') s.webhooks = { plusminus: '', commend: '', promo: '' };
    if (!s.shop || typeof s.shop !== 'object') s.shop = { suppliers: [], offer: null, out: [], incoming: [] };
    else {
        s.shop.suppliers = Array.isArray(s.shop.suppliers) ? s.shop.suppliers : [];
        s.shop.out = Array.isArray(s.shop.out) ? s.shop.out : [];
        s.shop.incoming = Array.isArray(s.shop.incoming) ? s.shop.incoming : [];
        if (s.shop.offer && typeof s.shop.offer === 'object' && !Array.isArray(s.shop.offer.products)) s.shop.offer.products = [];
    }
    return s;
}

/* ---------- Stan interfejsu ---------- */
const UI = { z: 10, active: null, sel: null, start: false, startQuery: '' };
const wins = {};            // id aplikacji -> { app, x, y, w, h, z, min, max, prev, el }

/* ---------- Ustawienia użytkownika (zapamiętywane) ---------- */
const CFG_KEY = 'crp_bossmenu_cfg';
const CFG_DEF = {
    size: 85, idle: 30,                 // size: % ekranu gry, idle: % krycia poza UI
    scale: 100,                         // skala zawartości interfejsu (%)
    notif: 'all', notifDur: 3, notifPos: 'br',   // powiadomienia: all | errors | off, czas (s), róg ekranu
    sound: true, volume: 35,            // dźwięki interfejsu
    anim: true,                         // animacje
    remember: true, startApp: 'none',   // zapamiętywanie układu okien, aplikacja otwierana na starcie
    timeFmt: '24', dateFmt: 'dmy',      // 24 | 12, dmy | ymd | mdy
    widgets: ['employees', 'duty', 'funds', 'payout']   // informacje przypięte do widgetu na pulpicie (kolejność = kolejność przypinania)
};
let CFG = { ...CFG_DEF };
try { Object.assign(CFG, JSON.parse(localStorage.getItem(CFG_KEY) || '{}')); } catch (e) { }
const LAYOUT_KEY = 'crp_bossmenu_layout';
let LAYOUT = { geo: {}, open: [] }, LAYOUT_READY = false;
try { const l = JSON.parse(localStorage.getItem(LAYOUT_KEY) || 'null'); if (l && l.geo && Array.isArray(l.open)) LAYOUT = l; } catch (e) { }
const saveCfg = () => { try { localStorage.setItem(CFG_KEY, JSON.stringify(CFG)); } catch (e) { } };

/* ---------- Dane testowe (DEV) ---------- */
let RID = 1;
const R = (kind, by, reason, at, voided) => ({ id: RID++, kind, by, reason, at, voided: voided || null });   // wpis: plus/minus/commend/reprimand; voided = {by, at} gdy unieważniony
const P = (from, to, by, reason, at) => ({ from, to, by, reason, at }); // wpis w historii awansów

const MOCK = {
    job: { name: 'mechanic', label: 'Warsztat Samochodowy' },
    me: { ssn: '731-04-1001', firstname: 'Adam', lastname: 'Nowak', grade: 4 },

    // Funkcje opcjonalne – serwer decyduje, czy są włączone dla danej firmy
    // licenses – licencje · badges – numer odznaki · records – plusy/minusy, pochwały/nagany
    features: { licenses: true, badges: true, records: true },
    // Licencje, które szef może nadawać w tej firmie
    licenseDefs: [
        { id: 'tow', label: 'Holowanie (laweta)', icon: 'car-crane', desc: 'Obsługa lawety i holowanie pojazdów.' },
        { id: 'tuning', label: 'Tuning zaawansowany', icon: 'engine', desc: 'Modyfikacje silnika i zawieszenia.' },
        { id: 'paint', label: 'Lakiernictwo', icon: 'brush', desc: 'Malowanie i personalizacja nadwozia.' },
        { id: 'weld', label: 'Spawanie', icon: 'flame', desc: 'Naprawy blacharskie i spawalnicze.' }
    ],
    grades: [
        { id: 0, name: 'Rekrut', salary: 35 },
        { id: 1, name: 'Mechanik', salary: 50 },
        { id: 2, name: 'Starszy mechanik', salary: 65 },
        { id: 3, name: 'Zastępca szefa', salary: 85 },
        { id: 4, name: 'Szef', salary: 110 }
    ],
    // status = duty | break | off, lastSeen = minuty od końca służby (dla off), hoursWeek = godziny pracy,
    // badge = numer odznaki, records / promotions = historia (najnowsze pierwsze)
    employees: [
        { ssn: '731-04-1001', firstname: 'Adam', lastname: 'Nowak', grade: 4, status: 'duty', lastSeen: 0, badge: 1, hiredAt: '02.09.2026', hoursWeek: 24.5, phonenumber: '555-123-456',
            licenses: [{ id: 'tow', at: '02.09.2026' }, { id: 'tuning', at: '02.09.2026' }, { id: 'paint', at: '02.09.2026' }, { id: 'weld', at: '02.09.2026' }],
            records: [R('commend', 'Zarząd', 'Sprawne otwarcie i prowadzenie warsztatu.', '20.09.2026 12:00')],
            promotions: [] },
        { ssn: '428-93-1012', firstname: 'Kamil', lastname: 'Wiśniewski', grade: 3, status: 'duty', lastSeen: 0, badge: 298, hiredAt: '04.09.2026', hoursWeek: 19, phonenumber: '555-214-387',
            note: { html: '<h2>Uwagi ogólne</h2><p>Bardzo dobry w <strong>holowaniu</strong> i spawaniu. Kontakt z klientami wzorowy.</p><ul><li>Do rozważenia awans na zastępcę szefa</li><li>Szkolenie nowych rekrutów (w tym tygodniu)</li></ul><blockquote>Nie przydzielać nocnych zmian – prośba pracownika.</blockquote>', by: 'Adam Nowak', at: '30.09.2026 20:05' },
            licenses: [{ id: 'tow', at: '06.09.2026' }, { id: 'tuning', at: '12.09.2026' }, { id: 'weld', at: '15.09.2026' }],
            records: [
                R('commend', 'Adam Nowak', 'Szybka i dokładna naprawa floty klienta biznesowego.', '29.09.2026 18:40'),
                R('plus', 'Adam Nowak', 'Brak spóźnień przez cały tydzień.', '27.09.2026 20:05'),
                R('commend', 'Adam Nowak', 'Pomoc w szkoleniu nowych pracowników.', '22.09.2026 16:30'),
                R('minus', 'Adam Nowak', 'Niepełna dokumentacja po zleceniu.', '19.09.2026 21:15'),
                R('plus', 'Adam Nowak', 'Inicjatywa przy organizacji magazynu części.', '16.09.2026 14:10'),
                R('reprimand', 'Adam Nowak', 'Spóźnienie na umówioną zmianę bez informacji.', '11.09.2026 17:55'),
                R('commend', 'Adam Nowak', 'Wzorowa obsługa klienta.', '08.09.2026 19:20'),
                R('plus', 'Adam Nowak', 'Dodatkowa zmiana w weekend.', '07.09.2026 10:00'),
                R('minus', 'Adam Nowak', 'Brak zgłoszenia dojazdu do zlecenia.', '06.09.2026 16:40'),
                R('commend', 'Adam Nowak', 'Świetny start w firmie.', '05.09.2026 18:00'),
                R('plus', 'Adam Nowak', 'Pomoc przy rozładunku dostawy części.', '05.09.2026 11:00'),
                R('minus', 'Adam Nowak', 'Spóźnienie na zmianę (wystawione omyłkowo).', '10.09.2026 09:05', { by: 'Zarząd', at: '10.09.2026 10:30', reason: 'Wpis wystawiony przez pomyłkę – pracownik był wtedy na urlopie.' })],
            promotions: [
                P(2, 3, 'Adam Nowak', 'Bardzo dobre wyniki i odpowiedzialność.', '24.09.2026 19:00'),
                P(1, 2, 'Adam Nowak', 'Powrót na wyższy stopień po szkoleniu.', '18.09.2026 18:10'),
                P(2, 1, 'Adam Nowak', 'Nagana za spóźnienia – tymczasowa degradacja.', '12.09.2026 20:30'),
                P(1, 2, 'Adam Nowak', 'Zaliczona praktyka, awans na starszego mechanika.', '09.09.2026 17:45'),
                P(0, 1, 'Adam Nowak', 'Okres próbny zakończony pozytywnie.', '06.09.2026 15:00')] },
        { ssn: '659-21-1047', firstname: 'Oliwia', lastname: 'Kowalczyk', grade: 2, status: 'break', lastSeen: 0, badge: 312, hiredAt: '09.09.2026', hoursWeek: 14.5, phonenumber: '555-308-142',
            licenses: [{ id: 'paint', at: '14.09.2026' }, { id: 'tow', at: '21.09.2026' }],
            records: [
                R('commend', 'Kamil Wiśniewski', 'Pracownik miesiąca – najwięcej zleceń.', '30.09.2026 20:00'),
                R('plus', 'Adam Nowak', 'Bardzo dobry kontakt z klientami.', '26.09.2026 18:00'),
                R('minus', 'Kamil Wiśniewski', 'Zostawione stanowisko w nieładzie.', '23.09.2026 22:10')],
            promotions: [P(1, 2, 'Adam Nowak', 'Wyróżniające się wyniki w pierwszym tygodniu.', '28.09.2026 21:10'),
                         P(0, 1, 'Kamil Wiśniewski', 'Zakończony okres próbny.', '14.09.2026 18:00')] },
        { ssn: '317-80-1093', firstname: 'Jakub', lastname: 'Zieliński', grade: 2, status: 'off', lastSeen: 145, badge: 347, hiredAt: '10.09.2026', hoursWeek: 11, phonenumber: '555-476-025',
            licenses: [{ id: 'weld', at: '17.09.2026' }],
            records: [R('reprimand', 'Adam Nowak', 'Nieprawidłowa naprawa pojazdu klienta.', '25.09.2026 19:30')],
            promotions: [P(1, 2, 'Adam Nowak', 'Dobra jakość napraw.', '20.09.2026 18:00')] },
        { ssn: '582-47-1110', firstname: 'Patryk', lastname: 'Lewandowski', grade: 1, status: 'off', lastSeen: 1320, badge: null, hiredAt: '16.09.2026', hoursWeek: 6, phonenumber: '555-519-860',
            licenses: [], records: [], promotions: [P(0, 1, 'Kamil Wiśniewski', 'Zakończony okres próbny.', '23.09.2026 17:00')] },
        { ssn: '204-36-1128', firstname: 'Natalia', lastname: 'Mazur', grade: 1, status: 'duty', lastSeen: 0, badge: 361, hiredAt: '29.09.2026', hoursWeek: 4.5, phonenumber: '555-632-914',
            licenses: [{ id: 'tow', at: '30.09.2026' }], records: [R('plus', 'Oliwia Kowalczyk', 'Szybko się uczy.', '30.09.2026 21:00')], promotions: [] },
        { ssn: '846-15-1156', firstname: 'Szymon', lastname: 'Krawczyk', grade: 0, status: 'off', lastSeen: 4300, badge: null, hiredAt: '25.09.2026', hoursWeek: 1.5, phonenumber: '555-747-203',
            licenses: [], records: [], promotions: [] }
    ],
    funds: 184500,
    salaryMax: 150,        // maksymalna stawka za godzinę (opcjonalnie też grades[].maxSalary)
    webhooks: { plusminus: 'https://discord.com/api/webhooks/1156342098871/aBcD-eFgHiJkLmNoPqRsTuVwXyZ_0123456789', commend: '', promo: '' },
    transactions: [
        { type: 'in', amount: 12000, by: 'Kamil Wiśniewski', label: 'Wpłata', at: '30.09 14:22' },
        { type: 'out', amount: 5000, by: 'Adam Nowak', label: 'Wypłata', reason: 'Zakup części do magazynu.', at: '30.09 11:05' },
        { type: 'in', amount: 3400, by: 'System', label: 'Faktury klientów', at: '29.09 22:40' },
        { type: 'out', amount: 28500, by: 'System', label: 'Pensje pracowników', at: '29.09 20:00' },
        { type: 'in', amount: 7800, by: 'Oliwia Kowalczyk', label: 'Wpłata', at: '29.09 16:12' },
        { type: 'in', amount: 2100, by: 'System', label: 'Faktury klientów', at: '29.09 13:05' },
        { type: 'out', amount: 9600, by: 'Adam Nowak', label: 'Wypłata', reason: 'Nowy sprzęt do warsztatu (podnośnik).', at: '28.09 20:10' },
        { type: 'in', amount: 15000, by: 'Adam Nowak', label: 'Wpłata', at: '28.09 18:45' },
        { type: 'in', amount: 4300, by: 'System', label: 'Faktury klientów', at: '27.09 22:30' },
        { type: 'out', amount: 1800, by: 'Kamil Wiśniewski', label: 'Wypłata', reason: 'Zwrot kosztów paliwa.', at: '27.09 15:20' },
        { type: 'in', amount: 6200, by: 'Natalia Mazur', label: 'Wpłata', at: '26.09 19:00' },
        { type: 'out', amount: 24000, by: 'System', label: 'Pensje pracowników', at: '26.09 20:00' },
        { type: 'in', amount: 3900, by: 'System', label: 'Faktury klientów', at: '25.09 21:15' }
    ],
    supplier: 'Premium Deluxe Motorsport',
    vehicleSupplier: true,                  // DEMO: w grze ustawia to Lua – true tylko dla firmy-dostawcy pojazdów
    expressFee: 3000,                       // dopłata za szybki transport (za pojazd); pojazd w katalogu może mieć własne expressFee
    goodsExpressFee: 0,                     // domyślna dopłata za szybki transport towarów (0 = tylko to, co ustawi dostawca na produkcie)
    catalog: [
        { model: 'flatbed', name: 'MTL Flatbed', category: 'Pojazdy serwisowe', price: 42000 },
        { model: 'towtruck', name: 'Vapid Tow Truck', category: 'Pojazdy serwisowe', price: 38000 },
        { model: 'utillitruck3', name: 'Utility Truck', category: 'Pojazdy serwisowe', price: 26000 },
        { model: 'speedo', name: 'Vapid Speedo', category: 'Dostawcze', price: 21000 },
        { model: 'burrito3', name: 'Declasse Burrito', category: 'Dostawcze', price: 19000 },
        { model: 'bison', name: 'Bravado Bison', category: 'Pickupy', price: 31000 },
        { model: 'sadler', name: 'Vapid Sadler', category: 'Pickupy', price: 17000 },
        { model: 'sandking', name: 'Vapid Sandking', category: 'Terenowe', price: 54000 },
        { model: 'caracara2', name: 'Vapid Caracara 4x4', category: 'Terenowe', price: 72000, expressFee: 6500 },
        { model: 'schafter2', name: 'Benefactor Schafter', category: 'Osobowe', price: 28000 },
        { model: 'buffalo', name: 'Bravado Buffalo', category: 'Osobowe', price: 195000 }
    ],
    vehicles: [
        { plate: 'LS 4821', model: 'flatbed', name: 'MTL Flatbed', category: 'Pojazdy serwisowe', assignedTo: '428-93-1012', assignedAt: '28.09.2026 18:20', addedAt: '12.09.2026 16:00' },
        { plate: 'LS 3367', model: 'burrito3', name: 'Declasse Burrito', category: 'Dostawcze', assignedTo: '428-93-1012', assignedAt: '29.09.2026 20:02', addedAt: '12.09.2026 16:00' },
        { plate: 'LS 1093', model: 'towtruck', name: 'Vapid Tow Truck', category: 'Pojazdy serwisowe', assignedTo: '317-80-1093', assignedAt: '24.09.2026 17:45', addedAt: '15.09.2026 19:10' },
        { plate: 'LS 7730', model: 'utillitruck3', name: 'Utility Truck', category: 'Pojazdy serwisowe', assignedTo: '659-21-1047', assignedAt: '25.09.2026 21:30', addedAt: '15.09.2026 19:10' },
        { plate: 'LS 2255', model: 'speedo', name: 'Vapid Speedo', category: 'Dostawcze', assignedTo: null, assignedAt: null, addedAt: '20.09.2026 14:05' },
        { plate: 'LS 9014', model: 'sadler', name: 'Vapid Sadler', category: 'Pickupy', assignedTo: null, assignedAt: null, addedAt: '25.09.2026 15:20' }
    ],
    orders: [
        { id: 'ord-1004', by: 'Kamil Wiśniewski', at: '30.09.2026 21:10', status: 'pending', total: 62000 + 3000,
          items: [{ model: 'bison', name: 'Bravado Bison', price: 31000, express: true, fee: 3000 }, { model: 'bison', name: 'Bravado Bison', price: 31000, express: false, fee: 0 }] },
        { id: 'ord-1003', by: 'Natalia Mazur', at: '29.09.2026 18:44', status: 'accepted', total: 42000,
          items: [{ model: 'flatbed', name: 'MTL Flatbed', price: 42000, express: false, fee: 0 }] },
        { id: 'ord-1002', by: 'Kamil Wiśniewski', at: '25.09.2026 15:20', status: 'delivered', total: 17000,
          items: [{ model: 'sadler', name: 'Vapid Sadler', price: 17000, express: false, fee: 0 }] },
        { id: 'ord-1001', by: 'Natalia Mazur', at: '22.09.2026 20:15', status: 'rejected', note: 'Brak pojazdów na stanie', total: 195000 + 3000,
          items: [{ model: 'buffalo', name: 'Bravado Buffalo', price: 195000, express: true, fee: 3000 }] }
    ],
    shop: {
        suppliers: [
            { job: 'wholesale', label: 'Hurtownia Los Santos', desc: 'Narzędzia, materiały i części dla warsztatów oraz służb. Dostawa w ciągu doby.', products: [
                { id: 'toolbox', name: 'Skrzynka narzędziowa', category: 'Narzędzia', price: 450, desc: 'Komplet kluczy i narzędzi ręcznych.', active: true },
                { id: 'repairkit', name: 'Zestaw naprawczy', category: 'Narzędzia', price: 320, desc: 'Szybka naprawa pojazdu w terenie.', active: true },
                { id: 'tyres', name: 'Opony – komplet', category: 'Części', price: 1200, desc: 'Cztery opony letnie.', active: true },
                { id: 'fuelcan', name: 'Kanister paliwa', category: 'Materiały', price: 90, active: true, expressFee: 40 },
                { id: 'paint', name: 'Puszka farby', category: 'Materiały', price: 60, desc: 'Farba samochodowa, różne kolory.', active: true, access: ['police', 'taxi'] },
                { id: 'parts', name: 'Paczka części zamiennych', category: 'Części', price: 800, active: true }
            ] },
            { job: 'cardealer', label: 'Premium Deluxe Motorsport', desc: 'Akcesoria i dokumenty dla właścicieli pojazdów.', products: [
                { id: 'plates', name: 'Pakiet tablic rejestracyjnych', category: 'Dokumenty', price: 2500, desc: '10 kompletów tablic.', active: true, expressFee: 150 },
                { id: 'keys', name: 'Zestaw kluczyków', category: 'Akcesoria', price: 800, active: true },
                { id: 'wax', name: 'Środek do pielęgnacji lakieru', category: 'Akcesoria', price: 350, active: true }
            ] },
            { job: 'gastro', label: 'Bean Machine Coffee', desc: 'Zaopatrzenie dla firm: kawa, przekąski i napoje.', products: [
                { id: 'coffee', name: 'Kawa – karton', category: 'Napoje', price: 120, active: true, expressFee: 60 },
                { id: 'energy', name: 'Napoje energetyczne – zgrzewka', category: 'Napoje', price: 180, active: true },
                { id: 'sandwich', name: 'Kanapki – zestaw', category: 'Przekąski', price: 240, active: true }
            ] }
        ],
        companies: [
            { job: 'police', label: 'Policja LSPD' }, { job: 'ems', label: 'Pogotowie Los Santos' }, { job: 'taxi', label: 'Taxi Downtown' },
            { job: 'gastro', label: 'Bean Machine Coffee' }, { job: 'wholesale', label: 'Hurtownia Los Santos' }, { job: 'cardealer', label: 'Premium Deluxe Motorsport' }
        ],
        offer: { products: [
            { id: 'o-repair', name: 'Zestaw naprawczy PRO', category: 'Narzędzia', price: 650, desc: 'Szybka naprawa pojazdu w terenie.', active: true, access: ['police', 'ems'] },
            { id: 'o-clean', name: 'Zestaw czyszczący', category: 'Kosmetyka', price: 180, desc: 'Szampon, wosk i mikrofibry.', active: true },
            { id: 'o-tyres', name: 'Opony wyczynowe – komplet', category: 'Części', price: 2400, active: true, access: ['ems'] },
            { id: 'o-oil', name: 'Olej silnikowy 5L', category: 'Płyny', price: 140, active: true },
            { id: 'o-battery', name: 'Akumulator', category: 'Części', price: 520, desc: 'Chwilowo niedostępny.', active: false },
            { id: 'o-car', name: 'Vapid Caracara 4x4', category: 'Pojazdy', price: 72000, desc: 'Terenowy pickup z salonu.', active: true, model: 'caracara2', expressFee: 6500 }
        ] },
        out: [
            { id: 'zam-3004', kind: 'goods', supplier: { job: 'wholesale', label: 'Hurtownia Los Santos' }, buyer: { job: 'mechanic', label: 'Warsztat Samochodowy' }, by: 'Kamil Wiśniewski', at: '01.10.2026 09:12', status: 'pending', note: 'Prosimy o dostawę do 18:00', total: 3850,
              items: [{ id: 'repairkit', name: 'Zestaw naprawczy', price: 320, qty: 10 }, { id: 'fuelcan', name: 'Kanister paliwa', price: 90, qty: 5, express: true, fee: 40 }] },
            { id: 'zam-3003', kind: 'goods', supplier: { job: 'gastro', label: 'Bean Machine Coffee' }, buyer: { job: 'mechanic', label: 'Warsztat Samochodowy' }, by: 'Natalia Mazur', at: '30.09.2026 16:30', status: 'accepted', total: 840,
              items: [{ id: 'coffee', name: 'Kawa – karton', price: 120, qty: 3 }, { id: 'sandwich', name: 'Kanapki – zestaw', price: 240, qty: 2 }] },
            { id: 'zam-3002', kind: 'goods', supplier: { job: 'wholesale', label: 'Hurtownia Los Santos' }, buyer: { job: 'mechanic', label: 'Warsztat Samochodowy' }, by: 'Adam Nowak', at: '27.09.2026 11:05', status: 'delivered', total: 900,
              items: [{ id: 'toolbox', name: 'Skrzynka narzędziowa', price: 450, qty: 2 }] },
            { id: 'zam-3001', kind: 'goods', supplier: { job: 'cardealer', label: 'Premium Deluxe Motorsport' }, buyer: { job: 'mechanic', label: 'Warsztat Samochodowy' }, by: 'Kamil Wiśniewski', at: '24.09.2026 19:48', status: 'rejected', reason: 'Brak tablic na stanie do końca tygodnia', total: 2500,
              items: [{ id: 'plates', name: 'Pakiet tablic rejestracyjnych', price: 2500, qty: 1 }] }
        ],
        incoming: [
            { id: 'zam-4005', kind: 'goods', buyer: { job: 'police', label: 'Policja LSPD' }, by: 'Sierż. Marcin Kot', at: '01.10.2026 10:02', status: 'pending', note: 'Dla floty patrolowej', total: 3440,
              items: [{ id: 'o-repair', name: 'Zestaw naprawczy PRO', price: 650, qty: 4 }, { id: 'o-oil', name: 'Olej silnikowy 5L', price: 140, qty: 6 }] },
            { id: 'zam-4004', kind: 'vehicles', buyer: { job: 'taxi', label: 'Taxi Downtown' }, by: 'Dorota Lis', at: '30.09.2026 22:15', status: 'pending', total: 24000,
              items: [{ model: 'premier', name: 'Declasse Premier', price: 21000, express: true, fee: 3000 }] },
            { id: 'zam-4003', kind: 'goods', buyer: { job: 'ems', label: 'Pogotowie Los Santos' }, by: 'Dr Aleksandra Wrona', at: '30.09.2026 14:40', status: 'accepted', total: 4800,
              items: [{ id: 'o-tyres', name: 'Opony wyczynowe – komplet', price: 2400, qty: 2 }] },
            { id: 'zam-4002', kind: 'goods', buyer: { job: 'taxi', label: 'Taxi Downtown' }, by: 'Dorota Lis', at: '28.09.2026 09:55', status: 'delivered', total: 1800,
              items: [{ id: 'o-clean', name: 'Zestaw czyszczący', price: 180, qty: 10 }] },
            { id: 'zam-4001', kind: 'goods', buyer: { job: 'police', label: 'Policja LSPD' }, by: 'Sierż. Marcin Kot', at: '25.09.2026 18:20', status: 'rejected', reason: 'Produkt wycofany z oferty', total: 2600,
              items: [{ id: 'o-battery', name: 'Akumulator', price: 520, qty: 5 }] }
        ]
    },
    history: [
        { type: 'orderHandled', orderId: 'zam-4003', action: 'accepted', buyer: 'Pogotowie Los Santos', total: 4800, by: 'Kamil Wiśniewski', at: '30.09.2026 15:02' },
        { type: 'goodsOrder', orderId: 'zam-3004', supplier: 'Hurtownia Los Santos', lines: 2, units: 15, total: 3650, items: ['Zestaw naprawczy ×10', 'Kanister paliwa ×5'], by: 'Kamil Wiśniewski', at: '01.10.2026 09:12' },
        { type: 'offerChange', action: 'price', name: 'Opony wyczynowe – komplet', from: 2200, to: 2400, by: 'Natalia Mazur', at: '29.09.2026 12:30' },
        { type: 'order', orderId: 'ord-1004', count: 2, total: 65000, express: 1, items: ['Bravado Bison ⚡', 'Bravado Bison'], by: 'Kamil Wiśniewski', at: '30.09.2026 21:10' },
        { type: 'vehAssign', plate: 'LS 1093', vehicle: 'Vapid Tow Truck', ssn: '317-80-1093', name: 'Jakub Zieliński', from: 'Kamil Wiśniewski', by: 'Natalia Mazur', at: '30.09.2026 22:40' },
        { type: 'vehRevoke', plate: 'LS 2255', vehicle: 'Vapid Speedo', ssn: '428-93-1012', name: 'Kamil Wiśniewski', by: 'Natalia Mazur', at: '30.09.2026 22:31' },
        { type: 'orderCancel', orderId: 'ord-1000', count: 1, total: 19000, by: 'Natalia Mazur', at: '27.09.2026 10:12' },
        { type: 'resetHours', count: 8, total: 96.5, by: 'Natalia Mazur', at: '30.09.2026 23:59' },
        { type: 'webhook', key: 'promo', action: 'changed', by: 'Kamil Wiśniewski', at: '30.09.2026 20:14' },
        { type: 'webhook', key: 'commend', action: 'set', by: 'Kamil Wiśniewski', at: '30.09.2026 20:14' },
        { type: 'salary', grade: 2, gradeName: 'Starszy mechanik', from: 60, to: 65, by: 'Kamil Wiśniewski', at: '29.09.2026 21:02' },
        { type: 'fire', ssn: '118-52-0977', name: 'Filip Sobczak', gradeName: 'Mechanik', by: 'Natalia Mazur', at: '28.09.2026 19:02' },
        { type: 'salary', grade: 0, gradeName: 'Rekrut', from: 40, to: 35, by: 'Natalia Mazur', at: '27.09.2026 12:45' },
        { type: 'webhook', key: 'plusminus', action: 'removed', by: 'Kamil Wiśniewski', at: '26.09.2026 18:30' },
        { type: 'fire', ssn: '640-31-0914', name: 'Sebastian Lis', gradeName: 'Rekrut', by: 'Kamil Wiśniewski', at: '24.09.2026 17:40' },
        { type: 'salary', grade: 3, gradeName: 'Zastępca szefa', from: 80, to: 85, by: 'Kamil Wiśniewski', at: '22.09.2026 20:20' },
        { type: 'webhook', key: 'promo', action: 'set', by: 'Natalia Mazur', at: '20.09.2026 16:05' },
        { type: 'fire', ssn: '377-08-0821', name: 'Marta Zielińska', gradeName: 'Mechanik', by: 'Natalia Mazur', at: '18.09.2026 21:33' }
    ]
};

/* DEV: atrapa odpowiedzi serwera (w grze odpowiada Twój resource) */
const DEV_CITIZENS = {
    '312-77-1401': { firstname: 'Michał', lastname: 'Dąbrowski', phonenumber: '555-881-102' },
    '905-12-1402': { firstname: 'Ewelina', lastname: 'Jankowska', phonenumber: '555-902-455' },
    '276-55-1403': { firstname: 'Dawid', lastname: 'Pawlak', phonenumber: '555-173-690' }
};
function devReply(event, data) {
    console.log('[bossmenu] ->', event, data);
    if (event === 'bossmenu:hire') {
        const c = DEV_CITIZENS[data.ssn];
        return c ? { ok: true, employee: { ...c, ssn: data.ssn, status: 'duty' } } : { ok: false, error: 'Nie znaleziono gracza o tym SSN' };
    }
    if (event === 'bossmenu:orderVehicles') {
        const items = [];
        for (const it of data.items || []) {
            const c = S.catalog.find(x => x.model === it.model);
            if (!c) return { ok: false, error: 'Nie ma takiego pojazdu w katalogu' };
            items.push({ model: c.model, name: c.name, price: c.price, express: !!it.express, fee: it.express ? expressFee(c) : 0 });
        }
        if (!items.length || items.length > CART_MAX) return { ok: false, error: 'Nieprawidłowa liczba pojazdów' };
        const total = items.reduce((n, i) => n + i.price + i.fee, 0);
        if (total > S.funds) return { ok: false, error: 'Brak środków na koncie firmy' };
        return { ok: true, funds: S.funds - total, order: { id: 'ord-' + (1005 + S.orders.length), items, total, by: fullName(S.me), at: nowFull(), status: 'pending' } };
    }
    if (event === 'bossmenu:orderGoods') {
        const sp = shop().suppliers.find(x => x.job === data.supplier); if (!sp) return { ok: false, error: 'Nie znaleziono dostawcy' };
        const items = [];
        for (const it of data.items || []) {
            const pr = (sp.products || []).find(x => sameId(x.id, it.id) && canBuy(x));
            if (!pr) return { ok: false, error: 'Produkt nie jest już dostępny w ofercie' };
            if (!(it.qty >= 1 && it.qty <= QTY_MAX)) return { ok: false, error: 'Nieprawidłowa ilość' };
            const fee = goodsFee(pr), fast = it.express === true && fee > 0;
            items.push({ id: pr.id, name: pr.name, price: pr.price, qty: it.qty, express: fast, fee: fast ? fee : 0 });
        }
        if (!items.length || items.length > SHOP_LINES) return { ok: false, error: 'Nieprawidłowa liczba pozycji' };
        const total = items.reduce((n, i) => n + (i.price + i.fee) * i.qty, 0);
        if (total > S.funds) return { ok: false, error: 'Brak środków na koncie firmy' };
        return { ok: true, funds: S.funds - total, order: { id: 'zam-' + (3005 + shop().out.length), items, total } };
    }
    if (event === 'bossmenu:saveProduct') return { ok: true, product: { id: data.id ?? 'p' + Date.now() } };
    if (event === 'bossmenu:cancelOrder') {
        const o = S.orders.find(x => x.id === data.id) || shop().out.find(x => x.id === data.id);
        return o ? { ok: true, funds: S.funds + ordTotal(o) } : { ok: false, error: 'Nie znaleziono zamówienia' };
    }
    return { ok: true };
}

const gradeName = id => (S.grades.find(g => g.id === id) || { name: '—' }).name;
const gradeSalary = id => S.grades.find(g => g.id === id)?.salary || 0;      // stawka za godzinę
const wageOf = e => Math.round(gradeSalary(e.grade) * (e.hoursWeek || 0));     // proponowane wynagrodzenie = stawka stopnia × godziny
const STATUS = {
    duty: { label: 'Na służbie', text: 'text-emerald-400', dot: 'bg-emerald-400' },
    break: { label: 'Na przerwie', text: 'text-amber-400', dot: 'bg-amber-400' },
    off: { label: 'Poza służbą', text: 'text-slate-400', dot: 'bg-slate-600' }
};
const statusOf = e => e.status && STATUS[e.status] ? e.status : (e.online ? 'duty' : 'off');   // 'online' – zgodność wsteczna
const sinceOff = e => ago(e.lastSeen || 0).replace(' temu', '');
const maxGrade = () => Math.max(...S.grades.map(g => g.id));
const isBossGrade = id => id === maxGrade();
const logVehicle = (kind, v, who, prevSsn) => {
    const prev = prevSsn ? getEmp(prevSsn) : null;
    addHistory(kind === 'assign'
        ? { type: 'vehAssign', plate: v.plate, vehicle: v.name, ssn: who.ssn, name: fullName(who), from: prev && prev.ssn !== who.ssn ? fullName(prev) : '' }
        : { type: 'vehRevoke', plate: v.plate, vehicle: v.name, ssn: who.ssn, name: fullName(who) });
};
const addHistory = entry => { S.history.unshift({ ...entry, by: fullName(S.me), at: nowFull() }); S.history = S.history.slice(0, 300); };

/* =========================================================
   APLIKACJE (widoki okien)
   ========================================================= */

/* ---------- Pracownicy: lista · profil · zatrudnianie ---------- */
const EMP = { view: 'list', ssn: null, hireGrade: 0, tab: null, off: { plus: 0, commend: 0, promo: 0 }, empTab: 'own', relJob: null };
// empTab: 'own' = własna firma, 'rel' = podgląd innych prac (Config.ViewJobs); relJob = wybrana praca
const navEmp = () => { renderWin('employees'); const b = $('.win[data-win=employees] .body'); if (b) b.scrollTop = 0; };
const featOn = k => !!S.features?.[k];
const canManageGrade = e => !isBossGrade(e.grade) && e.ssn !== S.me.ssn;
const hasItem = (list, id) => (list || []).find(x => x.id === id);
const REASON_MIN = 5;      // minimalna długość powodu (awans / wpis)
const REC = {
    plus: { label: 'Plus', icon: 'circle-plus', tone: 'emerald' },
    minus: { label: 'Minus', icon: 'circle-minus', tone: 'brand' },
    commend: { label: 'Pochwała', icon: 'award', tone: 'emerald' },
    reprimand: { label: 'Nagana', icon: 'alert-triangle', tone: 'brand' }
};
const REC_GROUPS = {
    plus: { title: 'Plusy i minusy', icon: 'circle-plus', kinds: ['plus', 'minus'] },
    commend: { title: 'Pochwały i nagany', icon: 'award', kinds: ['commend', 'reprimand'] }
};

function appEmployees() {
    if (EMP.view === 'profile') {
        const e = getEmp(EMP.ssn);
        if (e) return viewProfile(e);
        EMP.view = 'list';
    }
    if (EMP.empTab === 'rel' && S.related.length) return viewRelated();
    return viewList();
}

/* --- zakładka: listy pracowników innych prac (tylko do czytania) --- */
function viewRelated() {
    const groups = S.related || [];
    if (!groups.length) { EMP.empTab = 'own'; return viewList(); }
    if (!groups.some(g => g.job === EMP.relJob)) EMP.relJob = groups[0].job;
    const g = groups.find(x => x.job === EMP.relJob) || groups[0];
    const list = [...(g.employees || [])].sort((a, b) => (b.otherJob ? 0 : 1) - (a.otherJob ? 0 : 1) || b.grade - a.grade || fullName(a).localeCompare(fullName(b)));
    const duty = list.filter(e => statusOf(e) === 'duty' && !e.otherJob).length;

    const rows = list.map(e => `
        <tr class="border-t border-slate-800/70 ${e.otherJob ? 'opacity-60' : ''}">
            <td class="py-2 pl-4 pr-2">
                <div class="flex items-center gap-3">
                    <div class="relative shrink-0">
                        <div class="size-9 rounded-lg ${isBossGrade(e.grade) ? 'bg-brand text-white' : 'bg-slate-800 text-slate-200'} font-extrabold text-xs flex items-center justify-center">${esc(initials(fullName(e)))}</div>
                        <span class="absolute -bottom-0.5 -right-0.5 size-3 rounded-full border-2 border-slate-900 ${STATUS[statusOf(e)].dot}"></span>
                    </div>
                    <div class="min-w-0">
                        <p class="text-sm font-bold text-white truncate">${esc(fullName(e))}</p>
                        <p class="text-[11px] font-mono text-slate-500">SSN ${esc(e.ssn)}${e.phonenumber ? ` · ${esc(e.phonenumber)}` : ''}</p>
                    </div>
                </div>
            </td>
            <td class="px-2"><span class="inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-bold border border-slate-700/60 bg-slate-800/60 text-slate-300 whitespace-nowrap">Stopień ${e.grade}</span></td>
            <td class="px-2 text-xs text-slate-400 whitespace-nowrap">${esc(fmtAt(e.hiredAt))}</td>
            <td class="px-2 text-xs whitespace-nowrap">${e.otherJob
                ? `<span class="font-bold text-amber-400">Inna praca</span><span class="text-slate-500"> · ${esc(e.otherJob)}</span>`
                : `<span class="font-bold ${STATUS[statusOf(e)].text}">${STATUS[statusOf(e)].label}</span>`}</td>
            <td class="px-2 text-xs font-bold whitespace-nowrap ${e.hoursWeek ? 'text-slate-200' : 'text-slate-600'}">${esc(fmtHours(e.hoursWeek))}</td>
        </tr>`).join('');

    const jobBtn = x => `<button data-act="empRel" data-job="${esc(x.job)}" class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition ${x.job === g.job ? 'bg-brand text-white' : 'text-slate-400 hover:text-white hover:bg-slate-800'}">
        ${esc(x.label)}<span class="px-1.5 rounded-md text-[10px] ${x.job === g.job ? 'bg-white/20 text-white' : 'bg-slate-800 text-slate-400'}">${(x.employees || []).length}</span></button>`;

    return `
    ${empTabs()}
    <div class="shrink-0 flex items-center justify-between gap-3">
        <div class="flex gap-1 p-1 rounded-xl bg-slate-900 border border-slate-800">${groups.map(jobBtn).join('')}</div>
        <span class="flex items-center gap-2 text-xs text-slate-400"><span class="text-sky-400">${icon('eye', 'size-4')}</span>Podgląd tylko do czytania – na służbie: <b class="text-white">${duty}</b> / ${list.length}</span>
    </div>
    <div class="rounded-xl border border-slate-800 bg-slate-900/50 overflow-x-auto">
        <table class="w-full text-left">
            <thead><tr class="text-[11px] uppercase tracking-wide text-slate-500">
                <th class="py-3 pl-4 pr-2 font-bold">Pracownik</th><th class="px-2 font-bold">Stopień</th>
                <th class="px-2 font-bold">Zatrudniony</th><th class="px-2 font-bold">Aktywność</th><th class="px-2 font-bold">Godziny</th>
            </tr></thead>
            <tbody>${rows || `<tr><td colspan="5" class="text-center text-xs text-slate-400 py-10">Brak pracowników w tej pracy.</td></tr>`}</tbody>
        </table>
    </div>
    <p class="text-[11px] text-slate-500 mt-3">Lista firmy <b class="text-slate-300">${esc(g.label)}</b> · zatrudnianie, zwalnianie i stopnie nadal ustawia tylko ta firma.
        Zakres podglądu ustawia <span class="font-mono text-slate-400">Config.ViewJobs</span> (albo <span class="font-mono text-slate-400">viewJobs</span> w Config.Jobs).</p>`;
}

/* --- przełącznik zakładek w oknie „Pracownicy” --- */
function empTabs() {
    if (!S.related.length) return '';
    const n = S.related.reduce((a, g) => a + (g.employees || []).length, 0);
    const tab = (id, label, count) => `<button data-act="empTab" data-v="${id}" class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition ${EMP.empTab === id ? 'bg-brand text-white' : 'text-slate-400 hover:text-white hover:bg-slate-800'}">
        ${label}<span class="px-1.5 rounded-md text-[10px] ${EMP.empTab === id ? 'bg-white/20 text-white' : 'bg-slate-800 text-slate-400'}">${count}</span></button>`;
    return `<div class="shrink-0 flex gap-1 p-1 rounded-xl bg-slate-900 border border-slate-800">
        ${tab('own', 'Moja firma', S.employees.length)}${tab('rel', 'Inne prace', n)}</div>`;
}

const crumb = (...parts) => `
    <button data-act="backToList" class="flex items-center gap-1.5 text-xs font-bold text-slate-400 hover:text-white transition mb-0.5">
        ${icon('arrow-left', 'size-4')}
        ${parts.map((p, i) => i === 0 ? p : `<span class="text-slate-600">/</span><span class="text-white">${p}</span>`).join(' ')}
    </button>`;

/* --- lista --- */
function viewList() {
    const q = S.search.trim().toLowerCase(), qd = q.replace(/\D/g, '');
    const tabs = empTabs();
    const bdg = featOn('badges');
    const list = S.employees
        .filter(e => S.filter === 'all' || S.filter === statusOf(e))
        .filter(e => !q || fullName(e).toLowerCase().includes(q) || String(e.ssn).toLowerCase().includes(q)
            || (qd.length >= 3 && String(e.phonenumber || '').replace(/\D/g, '').includes(qd)))
        .sort((a, b) => b.grade - a.grade || fullName(a).localeCompare(fullName(b)));

    const filterBtn = (id, label) => `
        <button data-filter="${id}" class="px-3 py-1.5 rounded-lg text-xs font-bold transition ${S.filter === id
            ? 'bg-brand text-white' : 'text-slate-400 hover:text-white hover:bg-slate-800'}">${label}</button>`;

    const statusCell = e => {
        if (e.otherJob) return `<span class="font-bold text-amber-400">Inna praca</span><span class="text-slate-500"> · ${esc(e.otherJob)}</span>`;
        const k = statusOf(e), st = STATUS[k];
        return `<span class="font-bold ${st.text}">${st.label}</span>${k === 'off' ? `<span class="text-slate-600"> · ${esc(sinceOff(e))}</span>` : ''}`;
    };
    const rows = list.map(e => {
        const boss = isBossGrade(e.grade), self = sameSsn(e.ssn, S.me.ssn);
        return `
        <tr data-act="openProfile" data-ssn="${e.ssn}" class="group border-t border-slate-800/70 hover:bg-slate-800/40 cursor-pointer transition">
            <td class="py-2 pl-4 pr-2">
                <div class="flex items-center gap-3">
                    <div class="relative shrink-0">
                        <div class="size-9 rounded-lg ${boss ? 'bg-brand text-white' : 'bg-slate-800 text-slate-200'} font-extrabold text-xs flex items-center justify-center">${esc(initials(fullName(e)))}</div>
                        <span class="absolute -bottom-0.5 -right-0.5 size-3 rounded-full border-2 border-slate-900 ${STATUS[statusOf(e)].dot}"></span>
                    </div>
                    <div class="min-w-0">
                        <p class="text-sm font-bold text-white truncate">${esc(fullName(e))}${self ? ' <span class="text-[10px] text-brand font-bold ml-1">(Ty)</span>' : ''}</p>
                        <p class="text-[11px] font-mono text-slate-500">SSN ${esc(e.ssn)}</p>
                    </div>
                </div>
            </td>
            <td class="px-2">
                <span class="inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-bold border whitespace-nowrap
                    ${boss ? 'bg-brand/10 text-brand border-brand/30' : 'bg-slate-800/60 text-slate-300 border-slate-700/60'}">${esc(gradeName(e.grade))}</span>
            </td>
            <td class="px-2 text-xs text-slate-400 whitespace-nowrap">${esc(fmtAt(e.hiredAt))}</td>
            <td class="px-2 text-xs whitespace-nowrap">${statusCell(e)}</td>
            <td class="px-2 text-xs font-bold whitespace-nowrap ${e.hoursWeek ? 'text-slate-200' : 'text-slate-600'}" title="Czas pracy">${esc(fmtHours(e.hoursWeek))}</td>
            ${bdg ? `<td class="px-2 text-xs font-bold whitespace-nowrap ${e.badge ? 'text-sky-400' : 'text-slate-600'}">${e.badge ? '#' + esc(e.badge) : '—'}</td>` : ''}
            <td class="py-2 pr-4 pl-2 text-right text-slate-600 group-hover:text-brand transition">${icon('chevron-right', 'size-4')}</td>
        </tr>`;
    }).join('');

    const cols = 6 + (bdg ? 1 : 0);
    return `
    <div class="flex gap-3 mb-4">
        <div class="relative flex-1 min-w-0">
            <span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500">${icon('search', 'size-4')}</span>
            <input id="search" value="${esc(S.search)}" placeholder="Szukaj po imieniu, nazwisku, SSN lub numerze telefonu…" autocomplete="off"
                class="w-full bg-slate-900 border border-slate-800 rounded-xl pl-9 pr-3 py-2.5 text-sm text-white placeholder-slate-500 focus:border-brand/50 outline-none">
        </div>
        <div class="flex gap-1 p-1 rounded-xl bg-slate-900 border border-slate-800 shrink-0">
            ${filterBtn('all', 'Wszyscy')}${filterBtn('duty', 'Na służbie')}${filterBtn('break', 'Przerwa')}${filterBtn('off', 'Poza służbą')}
        </div>
        <button data-act="resetAllHours" title="Zresetuj godziny wszystkim pracownikom" class="shrink-0 flex items-center gap-2 px-3.5 rounded-xl text-sm font-bold text-slate-200 bg-slate-800 hover:bg-slate-700 border border-slate-700/60 transition">
            ${icon('refresh', 'size-4')} Resetuj godziny
        </button>
        <button data-act="openHire" class="shrink-0 flex items-center gap-2 px-4 rounded-xl text-sm font-bold text-white bg-brand hover:opacity-90 transition">
            ${icon('user-plus', 'size-4')} Zatrudnij
        </button>
    </div>
    ${tabs}
    <div class="rounded-xl border border-slate-800 bg-slate-900/50 overflow-x-auto">
        <table class="w-full text-left">
            <thead>
                <tr class="text-[11px] uppercase tracking-wide text-slate-500">
                    <th class="py-3 pl-4 pr-2 font-bold">Pracownik</th>
                    <th class="px-2 font-bold">Stopień</th>
                    <th class="px-2 font-bold">Zatrudniony</th>
                    <th class="px-2 font-bold">Aktywność</th>
                    <th class="px-2 font-bold">Godziny</th>
                    ${bdg ? '<th class="px-2 font-bold">Nr odznaki</th>' : ''}
                    <th class="py-3 pr-4 pl-2"></th>
                </tr>
            </thead>
            <tbody>${rows || `<tr><td colspan="${cols}" class="text-center text-xs text-slate-400 py-10">Brak pracowników spełniających kryteria.</td></tr>`}</tbody>
        </table>
    </div>
    <p class="text-[11px] text-slate-500 mt-3">Wyświetlono ${list.length} z ${S.employees.length} · kliknij pracownika, aby otworzyć jego profil.</p>`;
}

/* --- własny select (zamiast natywnego <select>) --- */
const SEL = {};     // id -> konfiguracja { options, value, placeholder, onChange }
function selectHtml(cfg) {
    const { id, options, value, placeholder = 'Wybierz…', disabled = false } = cfg;
    SEL[id] = cfg;
    const cur = options.find(o => String(o.value) === String(value));
    return `
    <div class="relative" data-select="${id}">
        <button type="button" data-select-toggle="${id}" ${disabled ? 'disabled' : ''}
            class="w-full flex items-center justify-between gap-3 bg-slate-950/60 border border-slate-800 hover:border-slate-700 rounded-xl px-3.5 py-2.5 text-sm font-bold text-left transition outline-none ${disabled ? 'opacity-40 cursor-not-allowed' : ''}">
            <span class="truncate ${cur ? 'text-white' : 'text-slate-500'}">${esc(cur ? cur.label : placeholder)}</span>
            <span data-select-arrow class="text-slate-500 shrink-0 transition-transform">${icon('chevron-down', 'size-4')}</span>
        </button>
        <div data-select-panel class="hidden absolute left-0 right-0 z-40 mt-1.5 max-h-56 overflow-y-auto rounded-xl bg-slate-900 border border-slate-700 shadow-2xl shadow-black/60 p-1">
            ${options.map(o => {
                const sel = String(o.value) === String(value);
                return `<button type="button" data-select-option="${id}" data-value="${esc(o.value)}" ${o.disabled ? 'disabled' : ''}
                    class="w-full flex items-center justify-between gap-2 px-3 py-2 rounded-lg text-sm font-semibold text-left transition
                    ${o.disabled ? 'opacity-40 cursor-not-allowed text-slate-500' : sel ? 'bg-brand/10 text-brand' : 'text-slate-200 hover:bg-slate-800'}">
                    <span class="truncate">${esc(o.label)}${o.hint ? ` <span class="text-[11px] font-medium text-slate-500 ml-1">${esc(o.hint)}</span>` : ''}</span>
                    ${sel ? icon('check', 'size-4') : ''}
                </button>`;
            }).join('')}
            ${options.length ? '' : '<p class="px-3 py-2 text-xs text-slate-500">Brak opcji.</p>'}
        </div>
    </div>`;
}
function closeSelects(except) {
    let was = false;
    $$('[data-select]').forEach(w => {
        if (w.dataset.select === except) return;
        const panel = $('[data-select-panel]', w);
        if (!panel.classList.contains('hidden')) was = true;
        panel.classList.add('hidden');
        $('[data-select-arrow]', w).classList.remove('rotate-180');
    });
    return was;
}
function toggleSelect(id) {
    closeSelects(id);
    const w = $(`[data-select="${id}"]`); if (!w) return;
    const panel = $('[data-select-panel]', w), open = panel.classList.contains('hidden');
    panel.classList.toggle('hidden', !open);
    $('[data-select-arrow]', w).classList.toggle('rotate-180', open);
    panel.classList.remove('bottom-full', 'mb-1.5'); panel.classList.add('mt-1.5');
    panel.style.maxHeight = '';
    if (open) fitSelectPanel(w, panel);
}
/* Lista wyboru musi zmieścić się w tym, co ją przycina (np. w oknie modala) – inaczej
   dolne pozycje są ucięte i nie da się ich kliknąć. Mierzymy najbliższą przewijalną
   ramkę, a gdy na dole brakuje miejsca – otwieramy listę w górę i skracamy jej wysokość. */
function fitSelectPanel(w, panel) {
    let clip = null;
    for (let el = panel.parentElement; el && el !== document.body; el = el.parentElement) {
        const oy = getComputedStyle(el).overflowY;
        if (oy === 'auto' || oy === 'scroll' || oy === 'hidden') { clip = el; break; }
    }
    const lim = (clip || $('#os')).getBoundingClientRect();
    const btn = $('[data-select-toggle]', w).getBoundingClientRect();
    const below = lim.bottom - btn.bottom - 12, above = btn.top - lim.top - 12;
    const natural = Math.min(panel.scrollHeight || 0, 224);          // ile miejsca chce cała lista
    const up = below < natural && (above >= natural || above > below);   // woli górę, gdy tam się zmieści
    panel.classList.toggle('bottom-full', up);
    panel.classList.toggle('mb-1.5', up);
    panel.classList.toggle('mt-1.5', !up);
    panel.style.maxHeight = Math.round(Math.max(96, Math.min(224, up ? above : below))) + 'px';
}
function pickSelect(id, value) {
    const cfg = SEL[id]; if (!cfg) return;
    const opt = cfg.options.find(o => String(o.value) === String(value));
    cfg.value = opt ? opt.value : value;
    const w = $(`[data-select="${id}"]`);
    if (w) w.outerHTML = selectHtml(cfg);
    if (cfg.onChange) cfg.onChange(cfg.value);
}

/* --- drobne komponenty --- */
const fieldLabel = t => `<span class="block text-[10px] font-bold uppercase tracking-wide text-slate-500 mb-1.5">${t}</span>`;
const reasonField = (label = 'Powód', ph = 'Opisz, czego dotyczy zmiana…') => `
    <label class="block">${fieldLabel(label + ' <span class="text-brand">*</span>')}
        <textarea id="modalReason" rows="3" maxlength="200" placeholder="${ph}" data-autofocus
            class="w-full resize-none bg-slate-950/60 border border-slate-800 rounded-xl px-3.5 py-2.5 text-sm text-white placeholder-slate-500 focus:border-brand/50 outline-none"></textarea>
        <span class="block text-[11px] text-slate-500 mt-1.5">Wymagane – minimum ${REASON_MIN} znaków.</span>
    </label>`;
const reasonValue = () => ($('#modalReason')?.value || '').trim();

/* Listy historii dopasowują liczbę wpisów do dostępnej wysokości kolumny (fitLists).
   FIT[key] = wiersze HTML; EMP.off[key] = indeks pierwszego widocznego wpisu. */
const FIT = {};
const pagerHtml = key => `
    <div class="shrink-0 flex items-center justify-between mt-2 pt-2 border-t border-slate-800/70">
        <span data-pinfo="${key}" class="text-[11px] font-semibold text-slate-500"></span>
        <div class="flex gap-1.5">
            ${[[-1, 'chevron-left'], [1, 'chevron-right']].map(([d, ic]) => `
            <button data-act="page" data-key="${key}" data-dir="${d}" class="p-1.5 rounded-lg bg-slate-800 text-slate-300 transition">${icon(ic, 'size-4')}</button>`).join('')}
        </div>
    </div>`;
let fitTimer = 0;
const scheduleFit = () => {         // style Tailwinda mogą dojść chwilę po wstawieniu DOM – przelicz jeszcze raz
    requestAnimationFrame(() => fitLists());
    clearTimeout(fitTimer); fitTimer = setTimeout(() => fitLists(), 200);
};
function fitLists(root) {
    (root || document).querySelectorAll('ul[data-fit]').forEach(ul => {
        const key = ul.dataset.fit, rows = FIT[key] || [], sec = ul.closest('section');
        const info = sec.querySelector(`[data-pinfo="${key}"]`);
        if (!rows.length) {
            ul.innerHTML = '<li class="text-xs text-slate-500 py-8 text-center">Brak wpisów.</li>';
            ul.dataset.starts = '[0]';
            if (info) info.textContent = 'Strona 1 / 1';
            sec.querySelectorAll('[data-act=page]').forEach(btn => setPagerBtn(btn, true));
            return;
        }
        /* 1) zmierz wysokość każdego wiersza, 2) podziel na strony tak, by każda mieściła się w kolumnie */
        ul.innerHTML = rows.join('');
        const H = ul.clientHeight, GAP = 4, hs = [...ul.children].map(li => li.offsetHeight);
        const starts = [0];
        let used = 0, cnt = 0;
        hs.forEach((h, i) => {
            const need = h + (cnt ? GAP : 0);
            if (cnt && used + need > H + 1) { starts.push(i); used = h; cnt = 1; }
            else { used += need; cnt++; }
        });
        const off = EMP.off[key] || 0;
        let page = 0;
        starts.forEach((st, i) => { if (st <= off) page = i; });
        EMP.off[key] = starts[page];
        const end = starts[page + 1] ?? rows.length;
        ul.innerHTML = rows.slice(starts[page], end).join('');
        ul.dataset.starts = JSON.stringify(starts);
        if (info) info.textContent = `Strona ${page + 1} / ${starts.length}`;
        sec.querySelectorAll('[data-act=page]').forEach(btn => setPagerBtn(btn, btn.dataset.dir < 0 ? page <= 0 : page >= starts.length - 1));
    });
}
function setPagerBtn(btn, dis) {
    btn.disabled = dis;
    btn.classList.toggle('opacity-30', dis); btn.classList.toggle('cursor-not-allowed', dis);
    btn.classList.toggle('hover:bg-slate-700', !dis); btn.classList.toggle('hover:text-white', !dis);
}
const shortAt = at => fmtAt(at, true);
const entryRow = ({ ic, tone, title, meta, metaTitle = meta, inline = false, body, act = '', dim = false, note = '' }) => `
    <li class="px-2.5 py-1.5 rounded-xl border min-w-0 ${dim ? 'bg-slate-950/20 border-slate-800/60' : 'bg-slate-950/40 border-slate-800'}">
        <div class="flex items-center gap-1.5 min-w-0 h-[18px]">
            <span class="shrink-0 ${dim ? 'text-slate-500' : TONES[tone].split(' ')[0]}">${icon(ic, 'size-4')}</span>
            <span class="flex items-center gap-1.5 text-xs font-bold ${dim ? 'text-slate-500' : 'text-white'} ${inline ? 'shrink-0' : 'min-w-0'}">${title}</span>
            ${inline ? `<span class="text-slate-600">·</span><span class="truncate text-[10px] font-medium text-slate-500 min-w-0" title="${metaTitle}">${meta}</span>` : ''}
            <span class="ml-auto pl-1 shrink-0">${act}</span>
        </div>
        ${body}
        ${inline ? '' : `<p class="text-[10px] leading-4 text-slate-500 truncate mt-0.5" title="${metaTitle}">${meta}</p>`}
        ${note}
    </li>`;
const reasonLine = (r, dim = false) => `<p class="text-xs leading-4 mt-0.5 line-clamp-2 break-words ${dim ? 'text-slate-500' : 'text-slate-300'}" title="${esc(r)}">${esc(r)}</p>`;

/* panel z listą dopasowującą się do wysokości (fitLists) + stopka z paginacją */
const listPanel = ({ key, title, ic, count, rows, add = '', cls = '' }) => {
    FIT[key] = rows;
    return `
    <section class="flex flex-col min-h-0 min-w-0 rounded-xl bg-slate-900/60 border border-slate-800 p-3 ${cls}">
        <div class="shrink-0 flex items-center justify-between gap-2 mb-2.5">
            <h3 class="flex items-center gap-2 text-[13px] font-extrabold text-white min-w-0"><span class="text-brand shrink-0">${icon(ic, 'size-4')}</span><span class="truncate">${title}</span>
                <span class="px-1.5 rounded-md bg-slate-800 text-[10px] font-bold text-slate-400">${count}</span></h3>
            ${add}
        </div>
        <ul data-fit="${key}" class="relative flex-1 min-h-0 overflow-hidden space-y-1"></ul>
        ${pagerHtml(key)}
    </section>`;
};

/* --- profil pracownika --- */
function viewProfile(e) {
    const boss = isBossGrade(e.grade), self = sameSsn(e.ssn, S.me.ssn), manage = canManageGrade(e);
    const F = { lic: featOn('licenses'), badge: featOn('badges'), rec: featOn('records') };
    const otherJobBar = e.otherJob ? `
    <div class="shrink-0 flex items-start gap-2.5 px-3.5 py-2.5 rounded-xl bg-amber-500/10 border border-amber-500/25 text-[11px] leading-4 text-amber-200">
        <span class="shrink-0 mt-px">${icon('alert-triangle', 'size-4')}</span>
        <p>Ta osoba jest teraz zalogowana na innej pracy: <b>${esc(e.otherJob)}</b>. Dane poniżej pochodzą z listy tej firmy, a aktywność pokazujemy jako „poza służbą”.</p>
    </div>` : '';
    const recs = e.records || [], promos = e.promotions || [];
    const cnt = k => recs.filter(r => r.kind === k && !r.voided).length;      // unieważnione nie wliczają się do statystyk

    const actBtn = (act, ic, label, enabled = true, title = '', extra = '') => `
        <button data-act="${act}" data-ssn="${e.ssn}" ${enabled ? '' : 'disabled'} ${title ? `title="${title}"` : ''}
            class="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-[11px] font-bold border whitespace-nowrap transition ${extra} ${enabled
                ? 'bg-slate-800/70 border-slate-700/60 text-slate-200 hover:bg-slate-700 hover:text-white'
                : 'bg-slate-900 border-slate-800 text-slate-600 cursor-not-allowed'}">${icon(ic, 'size-3.5')}${label}</button>`;
    const row = (ic, label, value) => `
        <div class="flex items-center justify-between gap-4 text-xs">
            <span class="flex items-center gap-1.5 text-slate-500 font-semibold whitespace-nowrap">${icon(ic, 'size-3.5')}${label}</span>
            <span class="font-bold text-slate-200 flex items-center gap-2 whitespace-nowrap">${value}</span>
        </div>`;
    const stat = (n, label, cls) => `
        <div class="text-center px-1"><p class="text-[17px] font-extrabold leading-none ${n ? cls : 'text-slate-600'}">${n}</p>
        <p class="text-[9px] font-semibold uppercase tracking-wide text-slate-500 mt-1">${label}</p></div>`;
    const box = 'rounded-xl bg-slate-950/40 border border-slate-800 px-3 py-2.5 shrink-0';

    /* górny pasek: [awatar | dane] [zatrudnienie] [liczniki] [przyciski] */
    const ssn = e.ssn;
    const phonenumber = e.phonenumber || '—';
    const identity = `
    <div class="flex items-center gap-2.5 flex-1 min-w-0">
        <div class="relative shrink-0">
            <div class="size-[100px] rounded-2xl ${boss ? 'bg-brand text-white' : 'bg-slate-800 text-slate-200'} font-extrabold text-xl flex items-center justify-center">${esc(initials(fullName(e)))}</div>
            <span class="absolute -bottom-1 -right-1 size-4 rounded-full border-[3px] border-slate-900 ${STATUS[statusOf(e)].dot}" title="${STATUS[statusOf(e)].label}"></span>
        </div>
        <div class="min-w-0 space-y-1">
            <h2 class="text-[15px] font-extrabold text-white truncate leading-5">${esc(fullName(e))}${self ? ' <span class="text-xs text-brand font-bold">(Ty)</span>' : ''}</h2>
            <p class="text-xs font-bold truncate ${boss ? 'text-brand' : 'text-slate-300'}">${esc(gradeName(e.grade))}</p>
            ${F.badge ? `<p class="text-[11px] font-semibold truncate ${e.badge ? 'text-sky-400' : 'text-slate-500'}">${e.badge ? 'Odznaka #' + esc(e.badge) : 'Brak odznaki'}</p>` : ''}
            <p class="text-[11px] font-semibold text-slate-500 truncate" title="SSN">SSN <span class="font-mono text-slate-400">${esc(ssn)}</span></p>
            <p class="text-[11px] font-semibold text-slate-500 truncate" title="Numer telefonu">Telefon <span class="font-mono text-slate-400">${esc(phonenumber)}</span></p>
        </div>
    </div>`;

    const boxService = `
    <div class="${box} min-w-[184px] flex flex-col justify-center gap-1.5">
        ${row('calendar', 'Zatrudniony', esc(fmtAt(e.hiredAt)))}
        ${row('clock-hour-4', 'Aktywność', `<span class="${STATUS[statusOf(e)].text}">${STATUS[statusOf(e)].label}</span>${statusOf(e) === 'off' ? `<span class="text-slate-500 font-semibold">· ${esc(sinceOff(e))}</span>` : ''}`)}
        ${row('briefcase', 'Czas pracy', `${esc(fmtHours(e.hoursWeek))}
            <button data-act="resetHours" data-ssn="${e.ssn}" title="Zresetuj godziny"
                class="p-1 rounded-md bg-slate-800 text-slate-300 hover:bg-brand hover:text-white transition">${icon('refresh', 'size-3')}</button>`)}
        ${row('coins', 'Proponowana wypłata', `<span class="text-emerald-400" title="${esc(money(gradeSalary(e.grade)))}/h × ${esc(fmtHours(e.hoursWeek))}">${money(wageOf(e))}</span>`)}
    </div>`;
    const boxStats = F.rec ? `
    <div class="${box} !px-2.5 grid grid-cols-2 gap-x-1 gap-y-2 content-center">
        ${stat(cnt('commend'), 'Pochwały', 'text-emerald-400')}${stat(cnt('reprimand'), 'Nagany', 'text-brand')}
        ${stat(cnt('plus'), 'Plusy', 'text-emerald-400')}${stat(cnt('minus'), 'Minusy', 'text-brand')}
    </div>` : '';
    const myVeh = S.vehicles.filter(v => sameSsn(v.assignedTo, e.ssn));
    const buttons = `
    <div class="grid grid-cols-2 gap-1.5 shrink-0 content-center">
        ${actBtn('openGradeModal', 'ladder', 'Zmień stopień', manage, manage ? '' : (boss ? 'Stopień szefa nie może być zmieniany' : 'Nie możesz zmieniać własnego stopnia'))}
        ${F.lic ? actBtn('openLicenseModal', 'certificate', 'Zarządzaj licencją') : ''}
        ${F.badge ? actBtn('openBadgeModal', 'id', 'Zarządzaj odznaką') : ''}
        <button data-act="fire" data-ssn="${e.ssn}" ${manage ? '' : 'disabled'} title="${manage ? 'Zwolnij pracownika' : 'Nie można zwolnić tej osoby'}"
            class="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-[11px] font-bold border whitespace-nowrap transition ${manage
                ? 'text-brand border-brand/30 bg-brand/5 hover:bg-brand hover:text-white' : 'text-slate-600 border-slate-800 cursor-not-allowed'}">
            ${icon('user-x', 'size-3.5')}Zwolnij
        </button>
        ${actBtn('openVehicleModal', 'car', `Zarządzaj pojazdami<span class="px-1.5 rounded-md bg-slate-950/60 text-[10px] ${myVeh.length ? 'text-slate-200' : 'text-slate-500'}">${myVeh.length}</span>`, true, '', 'justify-center')}
        ${actBtn('openNoteModal', 'notes', `Notatka${hasNote(e) ? '<span class="size-1.5 rounded-full bg-emerald-400" title="Notatka istnieje"></span>' : ''}`, true, esc(hasNote(e) ? `Notatka o pracowniku · ostatnia edycja: ${e.note.by || '—'}, ${fmtAt(e.note.at)}` : 'Notatka o pracowniku (brak)'), 'justify-center')}
    </div>`;
    const header = `
    <section class="shrink-0 flex items-center gap-3 rounded-xl bg-slate-900/70 border border-slate-800 p-3">
        ${identity}
        <div class="flex items-stretch gap-3 shrink-0">${boxService}${boxStats}</div>
        <div class="flex-1 basis-0 min-w-max flex justify-end">${buttons}</div>
    </section>`;

    /* trzy kolumny historii */
    const recRow = r => {
        const v = r.voided;
        return entryRow({
            ic: v ? 'ban' : REC[r.kind].icon, tone: REC[r.kind].tone, dim: !!v,
            title: `<span class="${v ? 'line-through' : ''}">${REC[r.kind].label}</span>${v ? '<span class="px-1.5 py-px rounded bg-slate-800 text-slate-400 text-[9px] font-bold uppercase tracking-wide">Unieważniony</span>' : ''}`,
            body: reasonLine(r.reason, !!v), meta: `${esc(r.by)} · ${esc(v ? fmtAt(r.at) : shortAt(r.at))}`, metaTitle: `${esc(r.by)} · ${esc(fmtAt(r.at))}`, inline: !v,
            note: v ? `<p class="flex items-center gap-1 text-[10px] leading-4 text-slate-400 mt-0.5 truncate">${icon('ban', 'size-3 shrink-0')}<span class="truncate">Unieważnił: <span class="font-semibold text-slate-300">${esc(v.by)}</span> · ${esc(v.at)}</span></p>${v.reason ? `<p class="text-[10px] leading-4 text-slate-400 line-clamp-2 break-words" title="${esc(v.reason)}">Powód: ${esc(v.reason)}</p>` : ''}` : '',
            act: v ? '' : `<button data-act="voidRecord" data-ssn="${e.ssn}" data-id="${esc(r.id)}" title="Unieważnij wpis"
                class="block p-0.5 rounded-md text-slate-500 hover:text-white hover:bg-brand transition">${icon('ban', 'size-4')}</button>`
        });
    };
    const promoRow = h => {
        const up = h.to > h.from;
        return entryRow({
            ic: up ? 'chevron-up' : 'chevron-down', tone: up ? 'emerald' : 'amber',
            title: `<span class="truncate">${esc(gradeName(h.from))}</span><span class="text-slate-500 shrink-0">${icon('arrows-right', 'size-3.5')}</span><span class="truncate ${up ? 'text-emerald-400' : 'text-amber-400'}">${esc(gradeName(h.to))}</span>`,
            body: reasonLine(h.reason), meta: `${up ? 'Awans' : 'Degradacja'} · ${esc(h.by)} · ${esc(fmtAt(h.at))}`
        });
    };
    const column = (key, title, ic, list, rowFn, add = '') => listPanel({ key, title, ic, count: list.length, rows: list.map(rowFn), add });
    const addBtn = g => `<button data-act="addRecord" data-group="${g}" data-ssn="${e.ssn}"
        class="shrink-0 flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[11px] font-bold text-white bg-brand hover:opacity-90 transition">${icon('plus', 'size-3.5')}Dodaj</button>`;
    const cols = [
        ...(F.rec ? ['plus', 'commend'].map(g => column(g, REC_GROUPS[g].title, REC_GROUPS[g].icon, recs.filter(r => REC_GROUPS[g].kinds.includes(r.kind)), recRow, addBtn(g))) : []),
        column('promo', 'Awanse i degradacje', 'history', promos, promoRow)
    ];

    return `<div class="h-full flex flex-col gap-2.5">
        <div class="shrink-0">${crumb('Pracownicy', esc(fullName(e)))}</div>
        ${otherJobBar}
        ${header}
        <div class="flex-1 min-h-0 grid gap-3 grid-rows-[minmax(0,1fr)] ${cols.length === 3 ? 'grid-cols-3' : 'grid-cols-1'}">${cols.join('')}</div>
    </div>`;
}

/* --- modale profilu --- */
function applyGrade(ssn, to, reason) {
    const emp = getEmp(ssn), from = emp.grade;
    emp.grade = to;
    (emp.promotions = emp.promotions || []).unshift({ from, to, by: fullName(S.me), reason, at: nowFull() });
    post('bossmenu:setGrade', { ssn, grade: to, reason });
    const up = to > from;
    toast(`${fullName(emp)} – nowy stopień: ${gradeName(to)}`, up ? 'success' : 'warn');
    EMP.off.promo = 0; refresh();
}

function openGradeModal(ssn) {
    const emp = getEmp(ssn);
    const options = [...S.grades].sort((a, b) => a.id - b.id).map(g => ({
        value: g.id, label: g.name, disabled: g.id === emp.grade,
        hint: g.id === emp.grade ? 'obecny' : g.id > emp.grade ? 'awans' : 'degradacja'
    }));
    const M = { to: S.grades.some(g => g.id === emp.grade + 1) ? emp.grade + 1 : emp.grade - 1 };
    openModal({
        icon: 'ladder', tone: 'brand', title: 'Zmień stopień', text: `${fullName(emp)} · obecnie: ${gradeName(emp.grade)}`, ok: 'Zmień stopień', needReason: true,
        body: () => `<div class="space-y-3">
            <div>${fieldLabel('Nowy stopień')}${selectHtml({ id: 'gradeSel', options, value: M.to, onChange: v => { M.to = Number(v); } })}</div>
            ${reasonField('Powód zmiany')}</div>`,
        onOk: () => {
            if (M.to === emp.grade) return toast('Wybierz inny stopień', 'error'), false;
            if (reasonValue().length < REASON_MIN) return toast(`Podaj powód (min. ${REASON_MIN} znaków)`, 'error'), false;
            applyGrade(ssn, M.to, reasonValue());
        }
    });
}

function openLicenseModal(ssn) {
    const M = { sel: null };
    const avail = () => S.licenseDefs.filter(d => !hasItem(getEmp(ssn).licenses, d.id));
    openModal({
        icon: 'certificate', tone: 'brand', live: true, noOk: true, cancel: 'Zamknij',
        title: 'Licencje', text: fullName(getEmp(ssn)),
        body: () => {
            const emp = getEmp(ssn), owned = emp.licenses || [], free = avail();
            if (!free.some(d => d.id === M.sel)) M.sel = free[0]?.id ?? null;
            return `<div class="space-y-4">
                <div>${fieldLabel(`Nadane licencje (${owned.length})`)}
                    ${owned.length ? `<ul class="space-y-2 max-h-48 overflow-y-auto pr-0.5">${owned.map(l => {
                        const d = S.licenseDefs.find(x => x.id === l.id) || { label: l.id, icon: 'license' };
                        return `<li class="flex items-center gap-3 p-2.5 rounded-xl bg-emerald-500/5 border border-emerald-500/20">
                            <div class="size-9 shrink-0 rounded-lg border flex items-center justify-center ${TONES.emerald}">${icon(d.icon || 'license', 'size-4')}</div>
                            <div class="flex-1 min-w-0"><p class="text-sm font-bold text-white truncate">${esc(d.label)}</p>
                                <p class="text-[11px] text-emerald-400">od ${esc(fmtAt(l.at))}</p></div>
                            <button data-act="licenseRemove" data-ssn="${ssn}" data-id="${l.id}" title="Odbierz licencję"
                                class="p-2 rounded-lg bg-slate-800 text-slate-300 hover:bg-brand hover:text-white transition">${icon('x', 'size-4')}</button>
                        </li>`; }).join('')}</ul>`
                    : '<p class="text-xs text-slate-500 py-2">Pracownik nie posiada żadnych licencji.</p>'}
                </div>
                <div>${fieldLabel('Nadaj nową licencję')}
                    ${free.length ? `<div class="flex gap-2">
                        <div class="flex-1 min-w-0">${selectHtml({ id: 'licSel', options: free.map(d => ({ value: d.id, label: d.label })), value: M.sel, onChange: v => { M.sel = v; } })}</div>
                        <button data-act="licenseAdd" data-ssn="${ssn}" class="shrink-0 flex items-center gap-1.5 px-4 rounded-xl text-sm font-bold text-white bg-brand hover:opacity-90 transition">${icon('plus', 'size-4')} Nadaj</button>
                    </div>` : '<p class="text-xs text-slate-500 py-2">Pracownik posiada wszystkie dostępne licencje.</p>'}
                </div></div>`;
        },
        ctx: M
    });
}

function openBadgeModal(ssn) {
    const emp = getEmp(ssn);
    openModal({
        icon: 'id', tone: 'brand', title: 'Numer odznaki', text: `${fullName(emp)}${emp.badge ? ' · obecnie #' + emp.badge : ' · brak numeru'}`, ok: 'Zapisz',
        body: `<label class="block">${fieldLabel('Numer odznaki')}
            <div class="relative"><span class="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500 text-sm font-bold">#</span>
            <input id="badgeNo" inputmode="numeric" maxlength="6" value="${esc(emp.badge || '')}" placeholder="np. 298" autocomplete="off" data-autofocus
                class="w-full bg-slate-950/60 border border-slate-800 rounded-xl pl-8 pr-3 py-2.5 text-sm font-bold text-white placeholder-slate-500 focus:border-brand/50 outline-none"></div>
            <span class="block text-[11px] text-slate-500 mt-1.5">Zostaw puste, aby usunąć numer odznaki.</span></label>`,
        onOk: () => {
            const val = $('#badgeNo').value.trim();
            const dup = val && S.employees.find(x => !sameSsn(x.ssn, ssn) && String(x.badge) === val);
            if (dup) return toast(`Numer #${val} ma już ${fullName(dup)}`, 'error'), false;
            emp.badge = val ? Number(val) : null;
            post('bossmenu:setBadge', { ssn, badge: emp.badge });
            toast(val ? `Numer odznaki: #${val}` : 'Usunięto numer odznaki', 'success'); refresh();
        }
    });
}

/* ---------- Notatka o pracowniku (edytor Quill ładowany z vendor/) ---------- */
const NOTE_MAX = 4000;           // maks. liczba znaków (bez formatowania) – serwer waliduje ponownie
const hasNote = e => !!(e?.note && String(e.note.html || '').replace(/<[^>]*>/g, '').trim());
let QUILL_P = null;
function loadQuill() {
    if (window.Quill) return Promise.resolve(window.Quill);
    if (QUILL_P) return QUILL_P;
    QUILL_P = new Promise((res, rej) => {
        const css = document.createElement('link'); css.rel = 'stylesheet'; css.href = BASE + 'vendor/quill.core.css'; document.head.appendChild(css);
        const sc = document.createElement('script'); sc.src = BASE + 'vendor/quill.js';
        sc.onload = () => window.Quill ? res(window.Quill) : rej(new Error('Quill'));
        sc.onerror = () => rej(new Error('Quill'));
        document.head.appendChild(sc);
    }).catch(err => { QUILL_P = null; throw err; });
    return QUILL_P;
}
function openNoteModal(ssn) {
    const emp = getEmp(ssn); if (!emp) return;
    const M = { busy: false, q: null, initial: '', dirty: false, warned: false };
    const tb = (cls, ic, title, val) => `<button type="button" class="${cls}" ${val ? `value="${val}"` : ''} title="${title}">${icon(ic, 'size-4')}</button>`;
    const sep = '<span class="w-px h-4 bg-slate-800 mx-1"></span>';
    const o = {
        icon: 'notes', tone: 'brand', wide: true, title: 'Notatka o pracowniku', ok: 'Zapisz notatkę',
        text: `${fullName(emp)} · ${emp.ssn}`,
        body: () => `
        <div class="rounded-xl bg-slate-950/60 border border-slate-800 focus-within:border-brand/50 transition overflow-hidden">
            <div id="noteTb" class="note-tb flex items-center flex-wrap gap-0.5 px-2 py-1.5 border-b border-slate-800 bg-slate-900/60">
                ${tb('ql-bold', 'bold', 'Pogrubienie (Ctrl+B)')}${tb('ql-italic', 'italic', 'Kursywa (Ctrl+I)')}${tb('ql-underline', 'underline', 'Podkreślenie (Ctrl+U)')}${tb('ql-strike', 'strikethrough', 'Przekreślenie')}
                ${sep}${tb('ql-header', 'heading', 'Nagłówek', '2')}${tb('ql-blockquote', 'quote', 'Cytat')}
                ${sep}${tb('ql-list', 'list', 'Lista punktowana', 'bullet')}${tb('ql-list', 'list-numbers', 'Lista numerowana', 'ordered')}
                ${sep}${tb('ql-clean', 'clear-formatting', 'Wyczyść formatowanie')}
                <span class="flex-1"></span>
                ${tb('ql-undo', 'arrow-back-up', 'Cofnij (Ctrl+Z)')}${tb('ql-redo', 'arrow-forward-up', 'Ponów (Ctrl+Y)')}
            </div>
            <div class="note-ed relative h-60">
                <div id="noteEd"></div>
                <div id="noteLoad" class="absolute inset-0 flex items-center justify-center text-xs font-semibold text-slate-500 bg-slate-950/60">Ładowanie edytora…</div>
            </div>
        </div>
        <div class="flex items-center justify-between gap-3 text-[11px] font-semibold text-slate-500">
            <span class="truncate">${hasNote(emp) ? `Ostatnia edycja: <span class="text-slate-300">${esc(emp.note.by || '—')}</span> · ${esc(fmtAt(emp.note.at))}` : 'Brak zapisanej notatki'}</span>
            <span id="noteCnt" class="font-mono whitespace-nowrap">0 / ${NOTE_MAX}</span>
        </div>`,
        beforeClose: () => {
            if (!M.dirty || M.warned) return true;
            M.warned = true; toast('Masz niezapisane zmiany – kliknij ponownie, aby je odrzucić', 'warn'); return false;
        },
        onOk: () => {
            if (!M.q || M.busy) return false;
            const html = M.q.getText().trim() ? M.q.getSemanticHTML().replace(/(<p><br><\/p>)+$/, '') : '';
            if (!M.dirty) return true;
            return modalRequest(o, M, 'bossmenu:setNote', { ssn: emp.ssn, html }, 'Nie udało się zapisać notatki', () => {
                emp.note = html ? { html, by: fullName(S.me), at: nowFull() } : null;
                toast(html ? 'Zapisano notatkę' : 'Usunięto notatkę', html ? 'success' : 'warn');
            });
        }
    };
    openModal(o);
    const ok = $('#modal [data-modal=ok]'); if (ok) { ok.disabled = true; ok.classList.add('opacity-40', 'cursor-not-allowed'); }
    loadQuill().then(Quill => {
        if (MODAL !== o || !$('#noteEd')) return;
        const q = M.q = new Quill('#noteEd', {
            placeholder: 'Wpisz notatkę o pracowniku – np. uwagi, ustalenia, umiejętności…',
            formats: ['bold', 'italic', 'underline', 'strike', 'header', 'list', 'blockquote'],
            modules: { history: { delay: 600, maxStack: 100 }, toolbar: { container: '#noteTb', handlers: { undo() { this.quill.history.undo(); }, redo() { this.quill.history.redo(); } } } }
        });
        if (hasNote(emp)) q.setContents(q.clipboard.convert({ html: emp.note.html }), 'silent');
        q.history.clear();
        M.initial = q.getSemanticHTML();
        const sync = () => {
            const n = Math.max(0, q.getLength() - 1);
            const c = $('#noteCnt'); if (c) { c.textContent = `${n} / ${NOTE_MAX}`; c.classList.toggle('text-brand', n >= NOTE_MAX); }
        };
        q.on('text-change', () => {
            if (q.getLength() - 1 > NOTE_MAX) q.deleteText(NOTE_MAX, q.getLength());
            M.dirty = q.getSemanticHTML() !== M.initial; M.warned = false; sync();
        });
        sync();
        $('#noteLoad')?.remove();
        const b = $('#modal [data-modal=ok]'); if (b) { b.disabled = false; b.classList.remove('opacity-40', 'cursor-not-allowed'); }
        q.focus(); q.setSelection(q.getLength(), 0);
    }).catch(() => { if (MODAL === o) { const l = $('#noteLoad'); if (l) l.textContent = 'Nie udało się załadować edytora (vendor/quill.js)'; } toast('Nie udało się załadować edytora', 'error'); });
}

function openRecordModal(ssn, group) {
    const emp = getEmp(ssn), G = REC_GROUPS[group];
    const M = { kind: G.kinds[0] };
    const kinds = () => `<div class="grid grid-cols-2 gap-2">${G.kinds.map(k => {
        const on = M.kind === k;
        return `<button type="button" data-act="recKind" data-kind="${k}"
            class="flex items-center justify-center gap-2 px-3 py-2.5 rounded-xl border text-sm font-bold transition ${on ? TONES[REC[k].tone] : 'bg-slate-950/40 border-slate-800 text-slate-400 hover:text-white'}">${icon(REC[k].icon, 'size-4')}${REC[k].label}</button>`;
    }).join('')}</div>`;
    openModal({
        icon: G.icon, tone: 'brand', title: `Dodaj wpis – ${G.title.toLowerCase()}`, text: fullName(emp), ok: 'Dodaj', needReason: true,
        body: () => `<div class="space-y-3"><div>${fieldLabel('Rodzaj')}<div id="recKinds">${kinds()}</div></div>${reasonField('Powód')}</div>`,
        ctx: M, renderKinds: () => { $('#recKinds').innerHTML = kinds(); },
        onOk: () => {
            if (reasonValue().length < REASON_MIN) return toast(`Podaj powód (min. ${REASON_MIN} znaków)`, 'error'), false;
            const rec = { id: 'loc' + Date.now(), kind: M.kind, by: fullName(S.me), reason: reasonValue(), at: nowFull() };
            (emp.records = emp.records || []).unshift(rec);
            post('bossmenu:addRecord', { ssn, kind: rec.kind, reason: rec.reason });
            toast(`Dodano wpis: ${REC[rec.kind].label}`, REC[rec.kind].tone === 'brand' ? 'warn' : 'success');
            EMP.off[group] = 0; refresh();
        }
    });
}

/* --- zatrudnianie (modal z SSN) --- */
function openHireModal() {
    const startGrades = S.grades.filter(g => g.id <= maxGrade() - 2).sort((a, b) => a.id - b.id);
    const M = { grade: startGrades.some(g => g.id === EMP.hireGrade) ? EMP.hireGrade : (startGrades[0]?.id ?? 0), busy: false };
    const o = {
        icon: 'user-plus', tone: 'brand', title: 'Zatrudnij pracownika', text: 'Podaj SSN gracza, którego chcesz zatrudnić', ok: 'Zatrudnij',
        body: () => `<div class="space-y-3">
            <label class="block">${fieldLabel('SSN gracza <span class="text-brand">*</span>')}
                <input id="hireSsn" maxlength="24" placeholder="np. 123-45-6789" autocomplete="off" data-autofocus
                    class="w-full bg-slate-950/60 border border-slate-800 rounded-xl px-3.5 py-2.5 text-sm font-mono font-bold text-white placeholder-slate-500 focus:border-brand/50 outline-none">
                ${IN_GAME ? '' : `<span class="block text-[11px] text-slate-500 mt-1.5">DEV: spróbuj ${Object.keys(DEV_CITIZENS).join(', ')}.</span>`}
            </label>
            <div>${fieldLabel('Stopień startowy')}${selectHtml({ id: 'hireGrade', options: startGrades.map(g => ({ value: g.id, label: g.name })), value: M.grade, onChange: v => { M.grade = Number(v); EMP.hireGrade = M.grade; } })}</div>
        </div>`,
        onOk: () => {
            if (M.busy) return false;
            const ssn = $('#hireSsn').value.trim();
            if (ssn.length < 3) return toast('Podaj SSN gracza', 'error'), false;
            if (S.employees.some(e => String(e.ssn).toLowerCase() === ssn.toLowerCase())) return toast('Ta osoba już u Ciebie pracuje', 'error'), false;
            M.busy = true;
            const btn = $('[data-modal=ok]'); if (btn) { btn.disabled = true; btn.classList.add('opacity-40', 'cursor-not-allowed'); }
            request('bossmenu:hire', { ssn, grade: M.grade }).then(res => {
                M.busy = false;
                if (!res?.ok) {
                    toast(res?.error || 'Nie udało się zatrudnić gracza', 'error');
                    const b = $('[data-modal=ok]'); if (b && MODAL === o) { b.disabled = false; b.classList.remove('opacity-40', 'cursor-not-allowed'); }
                    return;
                }
                const emp = { status: 'off', lastSeen: 0, badge: null, hiredAt: today(), hoursWeek: 0, licenses: [], records: [], promotions: [], ...res.employee, ssn, grade: M.grade };
                S.employees.push(emp);
                toast(`Zatrudniono: ${fullName(emp)}`, 'success');
                if (MODAL === o) closeModal();
                refresh();
            });
            return false;
        }
    };
    openModal(o);
}

/* ---------- Zarządzanie frakcją: finanse · stawki · webhooki ---------- */
const HOOKS = [
    { key: 'plusminus', label: 'Plusy i minusy', ic: 'circle-plus', desc: 'Dodanie i unieważnienie plusa lub minusa' },
    { key: 'commend', label: 'Pochwały i nagany', ic: 'award', desc: 'Dodanie i unieważnienie pochwały lub nagany' },
    { key: 'promo', label: 'Awanse i degradacje', ic: 'history', desc: 'Każda zmiana stopnia wraz z powodem' }
];
const HOOK_RE = /^https:\/\/(?:(?:canary|ptb)\.)?discord(?:app)?\.com\/api\/webhooks\/\d+\/[\w-]+$/;
const hookState = v => !v ? 'off' : HOOK_RE.test(v) ? 'ok' : 'bad';
const HOOK_UI = {
    off: ['Wyłączony', 'text-slate-500 bg-slate-800/60 border-slate-700/60'],
    ok: ['Aktywny', TONES.emerald],
    bad: ['Nieprawidłowy link', TONES.brand]
};
const salaryMaxOf = g => g.maxSalary ?? S.salaryMax ?? 10000;
const HOOK_TEST = 'shrink-0 flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-[11px] font-bold transition ';
const HOOK_TEST_ON = 'bg-slate-800 text-slate-200 hover:bg-sky-500/20 hover:text-sky-300';
const SAL_BTN = 'p-2 rounded-lg transition flex items-center justify-center shrink-0 ';
const SAL_ON = 'bg-brand text-white hover:opacity-90', SAL_OFF = 'bg-slate-800 text-slate-600 cursor-not-allowed';

function appFaction() {
    /* kolumna 1: stan konta + historia transakcji */
    const balance = `
    <section class="shrink-0 rounded-xl bg-slate-900/70 border border-slate-800 p-3.5 flex items-center justify-between gap-3">
        <div class="min-w-0">
            <p class="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-wide text-slate-500"><span class="text-brand">${icon('wallet', 'size-3.5')}</span>Stan konta</p>
            <p class="leading-8 font-extrabold text-white mt-1 break-all" style="font-size:${moneyFs(money(S.funds))}px">${money(S.funds)}</p>
        </div>
        <div class="flex flex-col gap-1.5 shrink-0">
            <button data-act="deposit" class="flex items-center justify-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-bold text-white bg-brand hover:opacity-90 transition">${icon('plus', 'size-3.5')}Wpłać</button>
            <button data-act="withdraw" class="flex items-center justify-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-bold text-slate-200 bg-slate-800 hover:bg-slate-700 transition">${icon('minus', 'size-3.5')}Wypłać</button>
        </div>
    </section>`;
    const txRow = t => {
        const inn = t.type === 'in';
        return `
        <li class="flex items-center gap-2.5 px-2.5 py-1.5 rounded-xl border bg-slate-950/40 border-slate-800 min-w-0">
            <div class="size-7 shrink-0 rounded-lg border flex items-center justify-center ${inn ? TONES.emerald : TONES.brand}">${icon(inn ? 'arrow-down' : 'arrow-up', 'size-4')}</div>
            <div class="flex-1 min-w-0">
                <p class="text-xs font-bold text-white truncate leading-4">${esc(t.label)}</p>
                ${t.reason ? `<p class="text-[11px] text-slate-300 line-clamp-2 break-words leading-4" title="${esc(t.reason)}">${esc(t.reason)}</p>` : ''}
                <p class="text-[10px] text-slate-500 truncate leading-4" title="${esc(t.by)} · ${esc(fmtAt(t.at))}">${esc(t.by)} · ${esc(fmtAt(t.at))}</p>
            </div>
            <p class="text-xs font-extrabold whitespace-nowrap ${inn ? 'text-emerald-400' : 'text-brand'}">${inn ? '+' : '−'}${money(t.amount)}</p>
        </li>`;
    };
    const left = `<div class="flex flex-col gap-3 min-h-0 min-w-0">${balance}${listPanel({ key: 'tx', title: 'Historia transakcji', ic: 'history', count: S.transactions.length, rows: S.transactions.map(txRow), cls: 'flex-1' })}</div>`;

    /* kolumna 2: wypłaty na rangę (stawka za godzinę, z limitem) */
    const salaryRow = g => {
        const boss = isBossGrade(g.id), max = salaryMaxOf(g), n = S.employees.filter(e => e.grade === g.id).length;
        const pct = Math.min(100, Math.round(g.salary / max * 100));
        return `
        <div data-grade-row="${g.id}" class="rounded-xl bg-slate-950/40 border border-slate-800 p-2.5">
            <div class="flex items-center gap-2.5 min-w-0">
                <div class="size-7 shrink-0 rounded-lg border flex items-center justify-center font-extrabold text-xs ${boss ? 'bg-brand/10 text-brand border-brand/30' : 'bg-slate-800 text-slate-300 border-slate-700/60'}">${g.id}</div>
                <p class="flex-1 min-w-0 text-xs font-bold text-white truncate" title="${esc(g.name)}">${esc(g.name)}</p>
                <span class="shrink-0 inline-flex items-center gap-1 text-[10px] font-semibold text-slate-500" title="${n} ${n === 1 ? 'pracownik' : 'pracowników'}">${icon('users', 'size-3')}${n}</span>
            </div>
            <div class="flex items-center gap-2 mt-2">
                <div class="relative w-[104px] shrink-0">
                    <span class="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-500 text-xs font-bold">$</span>
                    <input type="number" min="0" max="${max}" value="${g.salary}" data-salary="${g.id}"
                        class="w-full bg-slate-950/60 border border-slate-800 rounded-lg pl-6 pr-8 py-1.5 text-xs font-bold text-white focus:border-brand/50 outline-none">
                    <span class="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-500 text-[10px] font-bold">/ h</span>
                </div>
                <button data-act="saveSalary" data-id="${g.id}" disabled title="Zapisz stawkę" class="${SAL_BTN}${SAL_OFF}">${icon('check', 'size-4')}</button>
                <div class="flex-1 min-w-0">
                    <span data-salary-hint class="block text-right text-[10px] font-semibold text-slate-500 whitespace-nowrap truncate mb-1">${pct}% limitu</span>
                    <div class="h-1 rounded-full bg-slate-800 overflow-hidden"><div data-salary-bar class="h-full rounded-full ${pct >= 90 ? 'bg-amber-400' : 'bg-emerald-400'}" style="width:${pct}%"></div></div>
                </div>
            </div>
        </div>`;
    };
    const middle = `
    <section class="flex flex-col min-h-0 min-w-0 rounded-xl bg-slate-900/60 border border-slate-800 p-3">
        <div class="shrink-0 flex items-center justify-between gap-2 mb-1">
            <h3 class="flex items-center gap-2 text-[13px] font-extrabold text-white min-w-0"><span class="text-brand shrink-0">${icon('coins', 'size-4')}</span><span class="truncate">Wypłaty na rangę</span></h3>
            ${S.salaryMax != null ? `<span class="shrink-0 px-2 py-0.5 rounded-md border text-[10px] font-bold ${TONES.amber}" title="Maksymalna stawka za godzinę">Limit ${money(S.salaryMax)} / h</span>` : ''}
        </div>
        <p class="shrink-0 text-[11px] text-slate-500 mb-2.5">Stawka za godzinę pracy – na jej podstawie liczona jest proponowana wypłata pracownika.</p>
        <div class="flex-1 min-h-0 overflow-y-auto space-y-1.5 -mr-1 pr-1">${[...S.grades].sort((a, b) => b.id - a.id).map(salaryRow).join('')}</div>
    </section>`;

    /* kolumna 3: ustawienia frakcji (webhooki Discord) */
    const hookRow = h => {
        const v = S.webhooks?.[h.key] || '', st = HOOK_UI[hookState(v)];
        return `
        <div class="rounded-xl bg-slate-950/40 border border-slate-800 p-2.5">
            <div class="flex items-center gap-2.5">
                <div class="size-8 shrink-0 rounded-lg border flex items-center justify-center ${TONES.sky}">${icon(h.ic, 'size-4')}</div>
                <div class="flex-1 min-w-0">
                    <p class="text-xs font-bold text-white truncate">${h.label}</p>
                    <p class="text-[10px] leading-4 text-slate-500">${h.desc}</p>
                </div>
                <span data-hook-state="${h.key}" class="shrink-0 px-1.5 py-0.5 rounded-md border text-[9px] font-bold uppercase tracking-wide ${st[1]}">${st[0]}</span>
            </div>
            <div class="flex items-center gap-1.5 mt-2">
                <div class="relative flex-1 min-w-0">
                    <span class="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-500">${icon('link', 'size-3.5')}</span>
                    <input data-hook="${h.key}" value="${esc(v)}" spellcheck="false" autocomplete="off" placeholder="https://discord.com/api/webhooks/…"
                        class="w-full bg-slate-950/60 border border-slate-800 rounded-lg pl-8 pr-2.5 py-1.5 text-[11px] font-mono text-slate-200 placeholder-slate-600 focus:border-brand/50 outline-none">
                </div>
                <button data-act="testHook" data-key="${h.key}" ${hookState(v) === 'ok' ? '' : 'disabled'} title="Wyślij wiadomość testową (po zapisaniu linku)"
                    class="${HOOK_TEST}${hookState(v) === 'ok' ? HOOK_TEST_ON : SAL_OFF}">${icon('send', 'size-3.5')}Test</button>
            </div>
        </div>`;
    };
    const right = `
    <section class="flex flex-col min-h-0 min-w-0 rounded-xl bg-slate-900/60 border border-slate-800 p-3">
        <div class="shrink-0 flex items-center gap-2 mb-1">
            <h3 class="flex items-center gap-2 text-[13px] font-extrabold text-white min-w-0"><span class="text-brand shrink-0">${icon('building-community', 'size-4')}</span><span class="truncate">Ustawienia frakcji</span></h3>
        </div>
        <div class="flex-1 min-h-0 overflow-y-auto -mr-1 pr-1">
            <div class="flex items-center gap-1.5 mt-2 mb-1.5 text-[11px] font-extrabold text-slate-300"><span class="text-sky-400">${icon('brand-discord', 'size-4')}</span>Webhooki Discord</div>
            <p class="text-[11px] text-slate-500 mb-2.5">Powiadomienia trafiają na wskazane kanały Discord. Zostaw pole puste, aby wyłączyć dany kanał.</p>
            <div class="space-y-1.5">${HOOKS.map(hookRow).join('')}</div>
        </div>
        <div class="shrink-0 pt-2.5 mt-2 border-t border-slate-800/70">
            <button data-act="saveHooks" disabled class="w-full flex items-center justify-center gap-2 px-3 py-2 rounded-lg text-xs font-bold transition ${SAL_OFF}">${icon('check', 'size-4')}Zapisz ustawienia</button>
        </div>
    </section>`;

    return `<div class="h-full grid gap-3 grid-rows-[minmax(0,1fr)] grid-cols-[minmax(0,1fr)_minmax(0,1.05fr)_minmax(0,1.1fr)]">${left}${middle}${right}</div>`;
}

/* dynamiczna walidacja pól (wpisywanie) */
function syncSalaryRow(input) {
    const id = Number(input.dataset.salary), g = S.grades.find(x => x.id === id); if (!g) return;
    const max = salaryMaxOf(g), raw = input.value.trim(), v = raw === '' ? NaN : Number(raw);
    const bad = !Number.isFinite(v) || v < 0 || v > max, dirty = Number.isFinite(v) && v !== g.salary;
    const row = input.closest('[data-grade-row]'), btn = row.querySelector('[data-act=saveSalary]');
    input.classList.toggle('border-brand', bad); input.classList.toggle('border-slate-800', !bad);
    const pct = Number.isFinite(v) ? Math.min(100, Math.round(Math.max(0, v) / max * 100)) : 0;
    const bar = row.querySelector('[data-salary-bar]');
    bar.style.width = pct + '%'; bar.className = 'h-full rounded-full ' + (bad ? 'bg-brand' : pct >= 90 ? 'bg-amber-400' : 'bg-emerald-400');
    const hint = row.querySelector('[data-salary-hint]');
    hint.textContent = !Number.isFinite(v) ? 'Podaj kwotę' : v > max ? `Powyżej limitu (${money(max)})` : v < 0 ? 'Min. $0' : `${pct}% limitu`;
    hint.classList.toggle('text-brand', bad); hint.classList.toggle('text-slate-500', !bad);
    btn.disabled = bad || !dirty; btn.className = SAL_BTN + (bad || !dirty ? SAL_OFF : SAL_ON);
}
function syncHooks() {
    let dirty = false, bad = false;
    HOOKS.forEach(h => {
        const inp = $(`[data-hook="${h.key}"]`); if (!inp) return;
        const v = inp.value.trim(), st = hookState(v), tag = $(`[data-hook-state="${h.key}"]`);
        if (v !== (S.webhooks?.[h.key] || '')) dirty = true;
        if (st === 'bad') bad = true;
        tag.textContent = HOOK_UI[st][0]; tag.className = `shrink-0 px-1.5 py-0.5 rounded-md border text-[9px] font-bold uppercase tracking-wide ${HOOK_UI[st][1]}`;
        inp.classList.toggle('border-brand', st === 'bad'); inp.classList.toggle('border-slate-800', st !== 'bad');
        const test = $(`[data-act=testHook][data-key="${h.key}"]`);       // test tylko dla zapisanego, poprawnego linku
        if (test) { const can = hookState(S.webhooks?.[h.key] || '') === 'ok' && v === (S.webhooks?.[h.key] || ''); test.disabled = !can; test.className = HOOK_TEST + (can ? HOOK_TEST_ON : SAL_OFF); }
    });
    const btn = $('[data-act=saveHooks]'); if (!btn) return;
    const on = dirty && !bad;
    btn.disabled = !on;
    btn.className = `w-full flex items-center justify-center gap-2 px-3 py-2 rounded-lg text-xs font-bold transition ${on ? SAL_ON : SAL_OFF}`;
}

/* ---------- Historia zmian ---------- */
/* Tylko zdarzenia, których nie ma nigdzie indziej: zwolnienia, zmiany stawek, aktualizacje webhooków. */
const HIST_TYPES = {
    fire: { label: 'Zwolnienie', ic: 'user-x', tone: 'brand', group: 'fire', filter: 'Zwolnienia' },
    salary: { label: 'Zmiana stawki', ic: 'coins', tone: 'amber', group: 'salary', filter: 'Stawki' },
    webhook: { label: 'Aktualizacja webhooka', ic: 'brand-discord', tone: 'sky', group: 'webhook', filter: 'Webhooki' },
    resetHours: { label: 'Reset godzin', ic: 'refresh', tone: 'amber', group: 'resetHours', filter: 'Godziny' },
    order: { label: 'Zakup pojazdów', ic: 'shopping-cart', tone: 'sky', group: 'orders', filter: 'Zamówienia' },
    orderCancel: { label: 'Anulowanie zamówienia', ic: 'x', tone: 'amber', group: 'orders', filter: 'Zamówienia' },
    vehAssign: { label: 'Przydział pojazdu', ic: 'car', tone: 'emerald', group: 'vehicles', filter: 'Pojazdy' },
    vehRevoke: { label: 'Odebranie pojazdu', ic: 'user-minus', tone: 'amber', group: 'vehicles', filter: 'Pojazdy' },
    goodsOrder: { label: 'Zamówienie towarów', ic: 'box', tone: 'sky', group: 'orders', filter: 'Zamówienia' },
    goodsCancel: { label: 'Anulowanie zamówienia', ic: 'x', tone: 'amber', group: 'orders', filter: 'Zamówienia' },
    orderHandled: { label: 'Zamówienie przychodzące', ic: 'inbox', tone: 'emerald', group: 'orders', filter: 'Zamówienia' },
    offerChange: { label: 'Zmiana oferty', ic: 'building-store', tone: 'sky', group: 'offer', filter: 'Oferta' }
};
const plVeh = n => n === 1 ? 'pojazd' : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) ? 'pojazdy' : 'pojazdów';
const HIST_HOOK = { set: 'ustawiono nowy link', changed: 'zmieniono link', removed: 'usunięto link (kanał wyłączony)' };
const histRow = h => {
    const t = HIST_TYPES[h.type] || HIST_TYPES.fire;
    const hk = HOOKS.find(x => x.key === h.key);
    const strong = v => `<span class="font-bold text-white">${esc(v)}</span>`;
    const body = h.type === 'fire'
        ? `${strong(h.name)} <span class="text-slate-500">· ${esc(h.ssn || '—')}${h.gradeName ? ` · ${esc(h.gradeName)}` : ''}${h.vehicles ? ` · odebrano pojazdów: ${h.vehicles}` : ''}</span>`
        : h.type === 'order'
            ? `${strong(`${h.count} ${plVeh(h.count)}`)} <span class="text-slate-500">· ${money(h.total)}${h.express ? ` · szybki transport: ${h.express}` : ''}</span>
               <span class="block truncate text-[11px] text-slate-500" title="${esc((h.items || []).join(', '))}">${esc((h.items || []).join(', '))}</span>`
        : h.type === 'orderCancel'
            ? `Zamówienie ${strong(String(h.orderId || '').replace(/^ord-/, '#'))} <span class="text-slate-500">· ${h.count} ${plVeh(h.count)} · zwrot ${money(h.total)}</span>`
        : h.type === 'vehAssign'
            ? `${strong(h.vehicle)} <span class="text-slate-500">· ${esc(h.plate)}</span><span class="text-slate-500"> → </span>${strong(h.name)}${h.from ? `<span class="block text-[11px] text-slate-500">poprzednio: ${esc(h.from)}</span>` : ''}`
        : h.type === 'vehRevoke'
            ? `${strong(h.vehicle)} <span class="text-slate-500">· ${esc(h.plate)} · odebrano:</span> ${strong(h.name)}`
        : h.type === 'goodsOrder'
            ? `${strong(h.supplier)} <span class="text-slate-500">· ${h.units} szt. · ${money(h.total)}</span>
               <span class="block truncate text-[11px] text-slate-500" title="${esc((h.items || []).join(', '))}">${esc((h.items || []).join(', '))}</span>`
        : h.type === 'goodsCancel'
            ? `Zamówienie ${strong(String(h.orderId || '').replace(/^[a-z]+-/i, '#'))} <span class="text-slate-500">· ${esc(h.supplier || '')} · zwrot ${money(h.total)}</span>`
        : h.type === 'orderHandled'
            ? `Zamówienie ${strong(String(h.orderId || '').replace(/^[a-z]+-/i, '#'))} <span class="text-slate-500">· ${esc(h.buyer || '')} · ${money(h.total)} ·</span> ${strong({ accepted: 'przyjęto', rejected: 'odrzucono', delivered: 'dostarczono' }[h.action] || h.action)}${h.reason ? `<span class="block truncate text-[11px] text-slate-500" title="${esc(h.reason)}">Powód: ${esc(h.reason)}</span>` : ''}`
        : h.type === 'offerChange'
            ? `${strong(h.name)} <span class="text-slate-500">·</span> ${h.action === 'price'
                ? `<span class="text-slate-400">${money(h.from)}</span> <span class="inline-block align-[-3px] text-slate-500">${icon('arrow-right', 'size-3.5')}</span> ${strong(money(h.to))}`
                : `<span class="text-slate-500">${{ add: `dodano do oferty · ${money(h.to || 0)}`, remove: 'usunięto z oferty', hide: 'ukryto w ofercie', show: 'pokazano w ofercie', access: 'zmieniono dostęp do produktu', edit: 'zmieniono dane produktu' }[h.action] || ''}</span>`}`
        : h.type === 'resetHours'
            ? `Wszyscy pracownicy <span class="text-slate-500">· ${h.count} ${h.count === 1 ? 'osoba' : 'osób'} · wyzerowano łącznie ${esc(fmtHours(h.total))}</span>`
        : h.type === 'salary'
            ? `Stopień ${strong(h.gradeName)}<span class="text-slate-500"> · </span><span class="text-slate-400">${money(h.from)}</span> <span class="inline-block align-[-3px] text-slate-500">${icon('arrow-right', 'size-3.5')}</span> ${strong(money(h.to))}<span class="text-slate-500"> / h</span>`
            : `${strong(hk ? hk.label : h.key)}<span class="text-slate-500"> · ${esc(HIST_HOOK[h.action] || '')}</span>`;
    return entryRow({
        ic: t.ic, tone: t.tone, title: `<span class="truncate">${t.label}</span>`,
        act: `<span class="text-[10px] font-medium text-slate-500 whitespace-nowrap">${esc(shortAt(h.at))}</span>`,
        body: `<p class="text-xs leading-4 mt-0.5 text-slate-300 break-words">${body}</p>`,
        meta: `Wykonał: ${esc(h.by || '—')}`
    });
};
function appHistory() {
    const f = EMP.histFilter || 'all', all = S.history || [];
    const grp = h => (HIST_TYPES[h.type] || HIST_TYPES.fire).group;
    const list = f === 'all' ? all : all.filter(h => grp(h) === f);
    const chip = (v, l, n) => `<button data-act="histFilter" data-v="${v}" class="px-2.5 py-1 rounded-lg text-[11px] font-bold transition ${f === v ? 'bg-brand text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}">${l}<span class="ml-1 opacity-60">${n}</span></button>`;
    const groups = []; Object.values(HIST_TYPES).forEach(t => { if (!groups.some(g => g.group === t.group)) groups.push(t); });
    const chips = `<div class="flex flex-wrap justify-end gap-1.5">${chip('all', 'Wszystko', all.length)}${groups.map(t => chip(t.group, t.filter, all.filter(h => grp(h) === t.group).length)).join('')}</div>`;
    return `<div class="h-full flex flex-col min-h-0">${listPanel({ key: 'hist', title: 'Historia zmian', ic: 'history', count: list.length, rows: list.map(histRow), add: chips, cls: 'flex-1' })}</div>`;
}

/* ---------- Garaż: pojazdy firmy · katalog · zamówienia ---------- */
const GAR = { tab: 'vehicles', search: '', filter: 'all', cat: 'all', csearch: '', cart: [] };
let GAR_UID = 0;
const CART_MAX = 10;                                          // maks. pojazdów w jednym zamówieniu (serwer też powinien to sprawdzać)
const expressFee = c => Math.max(0, Number(c?.expressFee ?? S.expressFee ?? 0));      // dopłata za szybki transport (za 1 pojazd)
const goodsFee = p => Math.max(0, Number(p?.expressFee ?? S.goodsExpressFee ?? 0));    // to samo dla towarów z zamówień B2B (za 1 sztukę)
const cartLines = () => GAR.cart.map(it => ({ ...it, c: S.catalog.find(x => x.model === it.model) })).filter(l => l.c);
const lineCost = l => l.c.price + (l.express ? expressFee(l.c) : 0);
function cartTotals() {
    const ls = cartLines(), sub = ls.reduce((n, l) => n + l.c.price, 0), exp = ls.reduce((n, l) => n + (l.express ? expressFee(l.c) : 0), 0);
    return { ls, n: ls.length, nExp: ls.filter(l => l.express).length, sub, exp, total: sub + exp };
}
/* zamówienie może mieć wiele pozycji; starszy format (jeden pojazd) też jest obsługiwany */
const ordItems = o => o.items?.length ? o.items : [{ model: o.model, name: o.name, price: o.price, express: false }];
const ordTotal = o => o.total ?? o.price ?? ordItems(o).reduce((n, i) => n + i.price + (i.express ? (i.fee || 0) : 0), 0);
const ordNo = o => String(o.id || '').replace(/^[a-z]+-/i, '#');
const ORDER_ST = {
    pending: { label: 'Czeka na akceptację', ic: 'clock', tone: 'amber' },
    accepted: { label: 'W realizacji', ic: 'truck-delivery', tone: 'sky' },
    delivered: { label: 'Dostarczony', ic: 'check', tone: 'emerald' },
    rejected: { label: 'Odrzucone · zwrot środków', ic: 'ban', tone: 'brand' },
    cancelled: { label: 'Anulowane · zwrot środków', ic: 'x', tone: 'slate' }
};
const vehCount = ssn => S.vehicles.filter(v => sameSsn(v.assignedTo, ssn)).length;
const inFlight = model => S.orders.filter(o => o.status === 'pending' || o.status === 'accepted').reduce((n, o) => n + ordItems(o).filter(i => i.model === model).length, 0);
const stChip = (tone, label, ic) => `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md border text-[10px] font-bold whitespace-nowrap ${TONES[tone]}">${ic ? icon(ic, 'size-3') : ''}${label}</span>`;
const gBtn = (act, ic, label, data = '', cls = 'bg-slate-800 text-slate-200 hover:bg-slate-700') =>
    `<button data-act="${act}" ${data} class="shrink-0 flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-[11px] font-bold transition ${cls}">${icon(ic, 'size-3.5')}${label}</button>`;
const gAvatar = e => `<span class="size-7 shrink-0 rounded-lg bg-slate-800 border border-slate-700 flex items-center justify-center text-[10px] font-extrabold text-slate-200">${esc(initials(fullName(e)))}</span>`;

function garageTabs() {
    const pend = S.orders.filter(o => o.status === 'pending').length;
    const tab = (id, label, n, hot) => `
        <button data-act="gTab" data-v="${id}" class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition ${GAR.tab === id ? 'bg-brand text-white' : 'text-slate-400 hover:text-white hover:bg-slate-800'}">${label}
            ${n !== undefined ? `<span class="px-1.5 rounded-md text-[10px] ${GAR.tab === id ? 'bg-white/20 text-white' : hot ? 'bg-amber-500/20 text-amber-400' : 'bg-slate-800 text-slate-400'}">${n}</span>` : ''}</button>`;
    return `
    <div class="shrink-0 flex items-center justify-between gap-3">
        <div class="flex gap-1 p-1 rounded-xl bg-slate-900 border border-slate-800">
            ${tab('vehicles', 'Pojazdy', S.vehicles.length)}${tab('catalog', 'Katalog', GAR.cart.length || S.catalog.length, GAR.cart.length > 0)}${tab('orders', 'Zamówienia', pend || S.orders.length, pend > 0)}
        </div>
        <div class="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-slate-900 border border-slate-800 text-xs">
            <span class="text-brand">${icon('wallet', 'size-4')}</span><span class="font-bold text-slate-400">Saldo firmy</span><span class="font-extrabold text-white break-all">${money(S.funds)}</span>
        </div>
    </div>`;
}
const gSearch = (id, val, ph) => `
    <div class="relative flex-1 min-w-0">
        <span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500">${icon('search', 'size-4')}</span>
        <input id="${id}" value="${esc(val)}" placeholder="${ph}" autocomplete="off"
            class="w-full bg-slate-900 border border-slate-800 rounded-xl pl-9 pr-3 py-2 text-sm text-white placeholder-slate-500 focus:border-brand/50 outline-none">
    </div>`;
const gChips = (act, cur, items) => `<div class="flex flex-wrap gap-1 p-1 rounded-xl bg-slate-900 border border-slate-800 shrink-0">${items.map(([v, l, n]) => `
    <button data-act="${act}" data-v="${esc(v)}" class="px-3 py-1 rounded-lg text-xs font-bold transition ${cur === v ? 'bg-brand text-white' : 'text-slate-400 hover:text-white hover:bg-slate-800'}">${esc(l)}${n !== undefined ? `<span class="ml-1 opacity-60">${n}</span>` : ''}</button>`).join('')}</div>`;

/* --- zakładka: pojazdy firmy --- */
function garageVehicles() {
    const q = GAR.search.trim().toLowerCase();
    const holder = v => v.assignedTo ? getEmp(v.assignedTo) : null;
    const list = S.vehicles
        .filter(v => GAR.filter === 'all' || (GAR.filter === 'free' ? !v.assignedTo : !!v.assignedTo))
        .filter(v => { const h = holder(v); return !q || [v.name, v.model, v.plate, v.category, h ? fullName(h) : ''].some(x => String(x || '').toLowerCase().includes(q)); })
        .sort((a, b) => String(a.name).localeCompare(String(b.name)) || String(a.plate).localeCompare(String(b.plate)));
    const row = v => {
        const h = holder(v);
        return `
        <li class="flex items-center gap-3 px-3 py-2 rounded-xl border bg-slate-950/40 border-slate-800 min-w-0">
            <div class="size-9 shrink-0 rounded-lg border flex items-center justify-center ${TONES.sky}">${icon('car', 'size-5')}</div>
            <div class="flex-1 min-w-0">
                <p class="text-xs font-bold text-white truncate">${esc(v.name)}</p>
                <p class="text-[10px] text-slate-500 truncate">${esc(v.category || '—')} · <span class="font-mono">${esc(v.model)}</span></p>
            </div>
            <span class="shrink-0 px-2 py-0.5 rounded-md bg-slate-800 border border-slate-700 font-mono text-[11px] font-extrabold text-slate-100 tracking-wide">${esc(v.plate)}</span>
            <div class="w-[200px] shrink-0 min-w-0">${h
                ? `<div class="flex items-center gap-2 min-w-0">${gAvatar(h)}<div class="min-w-0"><p class="text-xs font-bold text-white truncate leading-4">${esc(fullName(h))}</p>
                    <p class="text-[10px] text-slate-500 truncate leading-4">${esc(gradeName(h.grade))}${v.assignedAt ? ` · od ${esc(shortAt(v.assignedAt))}` : ''}</p></div></div>`
                : `<div class="flex items-center gap-2">${stChip('emerald', 'Wolny', 'check')}<span class="text-[10px] text-slate-500">nieprzydzielony</span></div>`}</div>
            <div class="w-[172px] shrink-0 flex justify-end gap-1.5">${h
                ? gBtn('assignVehicle', 'user-plus', 'Zmień', `data-plate="${esc(v.plate)}"`) + gBtn('revokeVehicle', 'user-minus', 'Odbierz', `data-plate="${esc(v.plate)}"`, 'bg-slate-800 text-slate-200 hover:bg-brand hover:text-white')
                : gBtn('assignVehicle', 'user-plus', 'Przydziel', `data-plate="${esc(v.plate)}"`, 'bg-brand text-white hover:opacity-90')}</div>
        </li>`;
    };
    const nFree = S.vehicles.filter(v => !v.assignedTo).length;
    return `
    <div class="shrink-0 flex gap-3">
        ${gSearch('gSearch', GAR.search, 'Szukaj po nazwie, tablicy, kategorii lub pracowniku…')}
        ${gChips('gFilter', GAR.filter, [['all', 'Wszystkie', S.vehicles.length], ['free', 'Wolne', nFree], ['used', 'Przydzielone', S.vehicles.length - nFree]])}
    </div>
    ${listPanel({ key: 'veh', title: 'Pojazdy firmy', ic: 'car', count: list.length, rows: list.map(row), cls: 'flex-1' })}`;
}

/* --- zakładka: katalog do kupna + koszyk --- */
function cartPanel() {
    const T = cartTotals(), poor = T.total > S.funds;
    const line = l => {
        const fee = expressFee(l.c);
        return `
        <li class="rounded-xl border bg-slate-950/40 border-slate-800 p-2 space-y-1.5">
            <div class="flex items-center gap-2 min-w-0">
                <span class="text-sky-400 shrink-0">${icon('car', 'size-4')}</span>
                <p class="flex-1 min-w-0 text-xs font-bold text-white truncate" title="${esc(l.c.name)}">${esc(l.c.name)}</p>
                <span class="text-xs font-extrabold text-white whitespace-nowrap">${money(lineCost(l))}</span>
                <button data-act="cartRemove" data-uid="${l.uid}" title="Usuń z koszyka" class="p-1 rounded-md text-slate-500 hover:text-white hover:bg-brand transition">${icon('x', 'size-3.5')}</button>
            </div>
            ${fee > 0 ? `<button data-act="cartExpress" data-uid="${l.uid}" class="w-full flex items-center justify-between gap-2 px-2 py-1 rounded-lg border text-[11px] font-bold transition ${l.express
                ? 'bg-amber-500/10 border-amber-500/30 text-amber-300' : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-white hover:border-slate-700'}">
                <span class="flex items-center gap-1.5">${icon('bolt', 'size-3.5')}Szybki transport</span>
                <span class="flex items-center gap-1.5">+${money(fee)}<span class="size-3.5 rounded border flex items-center justify-center ${l.express ? 'bg-amber-400 border-amber-400 text-slate-900' : 'border-slate-600'}">${l.express ? icon('check', 'size-3') : ''}</span></span>
            </button>` : ''}
        </li>`;
    };
    const sum = (l, v, cls = 'text-slate-200') => `<div class="flex items-center justify-between text-[11px]"><span class="text-slate-500 font-semibold">${l}</span><span class="font-bold ${cls}">${v}</span></div>`;
    return `
    <aside class="w-[292px] shrink-0 flex flex-col min-h-0 rounded-xl bg-slate-900/60 border border-slate-800 p-3">
        <div class="shrink-0 flex items-center justify-between gap-2 mb-2.5">
            <h3 class="flex items-center gap-2 text-[13px] font-extrabold text-white"><span class="text-brand">${icon('shopping-cart', 'size-4')}</span>Koszyk
                <span class="px-1.5 rounded-md bg-slate-800 text-[10px] font-bold text-slate-400">${T.n}/${CART_MAX}</span></h3>
            ${T.n ? `<button data-act="cartClear" class="text-[11px] font-bold text-slate-500 hover:text-white transition">Wyczyść</button>` : ''}
        </div>
        <ul class="flex-1 min-h-0 overflow-y-auto space-y-1.5 pr-0.5">${T.n ? T.ls.map(line).join('')
            : `<li class="flex flex-col items-center gap-2 py-10 text-center text-xs text-slate-500">${icon('shopping-cart', 'size-8')}Koszyk jest pusty.<br>Dodaj pojazdy z katalogu.</li>`}</ul>
        <div class="shrink-0 mt-2.5 pt-2.5 border-t border-slate-800/70 space-y-1">
            ${sum(`Pojazdy (${T.n})`, money(T.sub))}
            ${sum(`Szybki transport (${T.nExp})`, money(T.exp), T.exp ? 'text-amber-300' : 'text-slate-200')}
            <div class="flex items-center justify-between pt-1.5"><span class="text-xs font-bold text-slate-300">Razem</span><span class="text-[17px] leading-5 font-extrabold text-white">${money(T.total)}</span></div>
            ${sum('Saldo firmy', money(S.funds), poor ? 'text-brand' : 'text-emerald-400')}
            ${poor ? `<p class="text-[11px] font-semibold text-brand">Brakuje ${money(T.total - S.funds)}</p>` : ''}
            <button data-act="cartCheckout" ${T.n && !poor ? '' : 'disabled'} class="w-full mt-1.5 flex items-center justify-center gap-2 px-3 py-2 rounded-lg text-xs font-bold transition ${T.n && !poor ? 'text-white bg-brand hover:opacity-90' : SAL_OFF}">${icon('shopping-cart', 'size-4')}Zamów${T.n ? ` (${T.n})` : ''}</button>
        </div>
    </aside>`;
}
function garageCatalog() {
    const q = GAR.csearch.trim().toLowerCase();
    const cats = [...new Set(S.catalog.map(c => c.category).filter(Boolean))];
    const cat = GAR.cat === 'all' || cats.includes(GAR.cat) ? GAR.cat : 'all';
    const list = S.catalog.filter(c => cat === 'all' || c.category === cat)
        .filter(c => !q || [c.name, c.model, c.category].some(x => String(x || '').toLowerCase().includes(q)));
    const full = GAR.cart.length >= CART_MAX;
    const card = c => {
        const own = S.vehicles.filter(v => v.model === c.model).length, fly = inFlight(c.model), inCart = GAR.cart.filter(i => i.model === c.model).length;
        return `
        <div class="rounded-xl bg-slate-900/60 border ${inCart ? 'border-brand/40' : 'border-slate-800'} overflow-hidden flex flex-col">
            <div class="relative aspect-[16/6] bg-gradient-to-br from-slate-800 to-slate-950 flex items-center justify-center text-slate-600">
                ${icon('car', 'size-9')}
                ${c.image ? `<img src="${esc(c.image)}" alt="" loading="lazy" onerror="this.remove()" class="absolute inset-0 w-full h-full object-cover">` : ''}
                <span class="absolute top-2 left-2 px-2 py-0.5 rounded-md bg-black/55 text-[10px] font-bold text-slate-200">${esc(c.category || 'Pojazd')}</span>
                ${inCart ? `<span class="absolute top-2 right-2 flex items-center gap-1 px-2 py-0.5 rounded-md bg-brand text-[10px] font-bold text-white">${icon('shopping-cart', 'size-3')}${inCart}</span>` : ''}
            </div>
            <div class="p-3 flex flex-col gap-2 flex-1">
                <div class="min-w-0"><p class="text-sm font-extrabold text-white truncate" title="${esc(c.name)}">${esc(c.name)}</p>
                    <p class="text-[10px] font-mono text-slate-500 truncate">${esc(c.model)}</p></div>
                <p class="text-[10px] text-slate-500 mt-auto">W garażu: <span class="font-bold text-slate-300">${own}</span> · w drodze: <span class="font-bold ${fly ? 'text-amber-400' : 'text-slate-300'}">${fly}</span></p>
                <div class="flex items-center justify-between gap-2">
                    <span class="text-[15px] leading-5 font-extrabold text-white">${money(c.price)}</span>
                    <button data-act="cartAdd" data-model="${esc(c.model)}" ${full ? 'disabled' : ''} class="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-[11px] font-bold transition ${full ? SAL_OFF : 'text-white bg-brand hover:opacity-90'}">${icon('shopping-cart-plus', 'size-3.5')}${full ? 'Koszyk pełny' : 'Do koszyka'}</button>
                </div>
            </div>
        </div>`;
    };
    return `
    <div class="flex-1 min-h-0 flex gap-3">
        <div class="flex-1 min-w-0 min-h-0 flex flex-col gap-3">
            <div class="shrink-0 flex gap-3">
                ${gSearch('cSearch', GAR.csearch, 'Szukaj w katalogu…')}
            </div>
            ${gChips('gCat', cat, [['all', 'Wszystkie'], ...cats.map(c => [c, c])])}
            <div class="flex-1 min-h-0 overflow-y-auto pr-1">
                ${list.length ? `<div class="grid grid-cols-[repeat(auto-fill,minmax(190px,1fr))] gap-3">${list.map(card).join('')}</div>`
                    : `<p class="text-center text-xs text-slate-400 py-12">${S.catalog.length ? 'Brak pojazdów spełniających kryteria.' : 'Katalog jest pusty.'}</p>`}
            </div>
        </div>
        ${cartPanel()}
    </div>`;
}

/* --- zakładka: zamówienia --- */
function garageOrders() {
    const row = o => {
        const st = ORDER_ST[o.status] || ORDER_ST.pending, dim = o.status === 'rejected' || o.status === 'cancelled';
        const items = ordItems(o), nExp = items.filter(i => i.express).length, names = items.map(i => i.name).join(', ');
        const devBtn = (ic, label, to) => gBtn('devOrder', ic, label, `data-id="${esc(o.id)}" data-to="${to}"`, 'bg-slate-800/70 text-slate-400 hover:text-white');
        const dev = IN_GAME ? '' : `<span class="flex items-center gap-1 pl-2 border-l border-dashed border-slate-700" title="Tylko DEV – symulacja ruchu drugiej firmy">
            <span class="text-[9px] font-extrabold text-slate-600">DEV</span>
            ${o.status === 'pending' ? devBtn('check', 'Przyjmij', 'accepted') + devBtn('ban', 'Odrzuć', 'rejected') : ''}${o.status === 'accepted' ? devBtn('truck-delivery', 'Dostarcz', 'delivered') : ''}</span>`;
        return `
        <li class="flex items-center gap-3 px-3 py-2 rounded-xl border min-w-0 ${dim ? 'bg-slate-950/20 border-slate-800/60' : 'bg-slate-950/40 border-slate-800'}">
            <div class="size-9 shrink-0 rounded-lg border flex items-center justify-center ${TONES[st.tone]}">${icon(st.ic, 'size-5')}</div>
            <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 min-w-0">
                    <p class="text-xs font-bold whitespace-nowrap ${dim ? 'text-slate-500' : 'text-white'}">Zamówienie ${esc(ordNo(o))}</p>
                    <span class="text-[11px] font-semibold whitespace-nowrap ${dim ? 'text-slate-600' : 'text-slate-400'}">${items.length} ${plVeh(items.length)}</span>
                    ${stChip(st.tone, st.label, null)}${nExp ? stChip('amber', `Szybki transport ×${nExp}`, 'bolt') : ''}
                </div>
                <p class="text-[10px] text-slate-500 truncate" title="${esc(names)}">${esc(names)}</p>
                <p class="text-[10px] text-slate-600 truncate" title="${esc(o.note || '')}">${esc(o.by)} · ${esc(fmtAt(o.at))}${o.note ? ` · ${esc(o.note)}` : ''}</p>
            </div>
            ${dev}
            <span class="shrink-0 text-xs font-extrabold ${dim ? 'text-slate-500 line-through' : 'text-white'}">${money(ordTotal(o))}</span>
            <div class="w-[112px] shrink-0 flex justify-end gap-1.5">
                ${gBtn('orderInfo', 'list-details', '', `data-id="${esc(o.id)}" title="Szczegóły"`)}
                ${o.status === 'pending' ? gBtn('cancelOrder', 'x', 'Anuluj', `data-id="${esc(o.id)}"`, 'bg-slate-800 text-slate-200 hover:bg-brand hover:text-white') : ''}
            </div>
        </li>`;
    };
    return `
    <div class="shrink-0 flex items-start gap-2.5 px-3.5 py-2.5 rounded-xl bg-sky-500/5 border border-sky-500/20 text-[11px] leading-4 text-slate-300">
        <span class="text-sky-400 shrink-0 mt-px">${icon('info-circle', 'size-4')}</span>
        <p>Zamówienia realizuje firma <span class="font-bold text-white">${esc(S.supplier || 'dostawca')}</span> – musi je zaakceptować. Środki (w tym dopłaty za szybki transport) są pobierane przy zamówieniu i wracają na konto po odrzuceniu lub anulowaniu. Zrealizowane pojazdy trafiają do garażu.</p>
    </div>
    ${listPanel({ key: 'ord', title: 'Zamówienia pojazdów', ic: 'package', count: S.orders.length, rows: S.orders.map(row), cls: 'flex-1' })}`;
}

function appGarage() {
    const body = GAR.tab === 'catalog' ? garageCatalog() : GAR.tab === 'orders' ? garageOrders() : garageVehicles();
    return `<div class="h-full flex flex-col gap-3 min-h-0">${garageTabs()}${body}</div>`;
}

/* --- modale --- */
function modalRequest(o, M, event, data, failMsg, onSuccess) {
    if (M.busy) return false;
    M.busy = true;
    const btn = $('[data-modal=ok]'); if (btn) { btn.disabled = true; btn.classList.add('opacity-40', 'cursor-not-allowed'); }
    request(event, data).then(res => {
        M.busy = false;
        if (!res?.ok) {
            toast(res?.error || failMsg, 'error');
            const b = $('[data-modal=ok]'); if (b && MODAL === o) { b.disabled = false; b.classList.remove('opacity-40', 'cursor-not-allowed'); }
            return;
        }
        onSuccess(res);
        if (MODAL === o) closeModal();
        refresh();
    });
    return false;
}
const addTx = (type, amount, label, reason) => S.transactions.unshift({ type, amount, by: fullName(S.me), label, ...(reason ? { reason } : {}), at: stamp() });

function openCheckoutModal() {
    const T = cartTotals(); if (!T.n) return toast('Koszyk jest pusty', 'error');
    const M = { busy: false };
    const row = (l, v, cls = 'text-white') => `<div class="flex items-center justify-between text-xs"><span class="text-slate-400">${l}</span><span class="font-extrabold ${cls}">${v}</span></div>`;
    const o = {
        icon: 'shopping-cart', tone: 'brand', title: `Zamówić pojazdy (${T.n})?`, text: `Zamówienie trafi do firmy ${S.supplier || 'dostawcy'}`, ok: 'Złóż zamówienie',
        body: () => {
            const t = cartTotals();
            return `<div class="space-y-3">
            <ul class="max-h-40 overflow-y-auto space-y-1 pr-0.5">${t.ls.map(l => `
                <li class="flex items-center gap-2 px-2.5 py-1.5 rounded-lg bg-slate-950/50 border border-slate-800 text-xs">
                    <span class="flex-1 min-w-0 truncate font-bold text-white">${esc(l.c.name)}</span>
                    ${l.express ? `<span class="flex items-center gap-1 text-[10px] font-bold text-amber-300 whitespace-nowrap">${icon('bolt', 'size-3')}Szybki transport</span>` : ''}
                    <span class="font-extrabold text-slate-200 whitespace-nowrap">${money(lineCost(l))}</span>
                </li>`).join('')}</ul>
            <div class="rounded-xl bg-slate-950/50 border border-slate-800 p-3 space-y-1.5">
                ${row('Pojazdy', money(t.sub))}${row('Szybki transport', money(t.exp), t.exp ? 'text-amber-300' : 'text-white')}
                <div class="border-t border-slate-800 pt-1.5">${row('Razem', money(t.total))}</div>
                ${row('Saldo konta', money(S.funds))}
                ${row('Saldo po zamówieniu', money(S.funds - t.total), S.funds - t.total < 0 ? 'text-brand' : 'text-emerald-400')}
            </div>
            <p class="text-[11px] leading-4 text-slate-400">Środki zostaną pobrane teraz i zwrócone, jeśli zamówienie zostanie odrzucone lub anulowane.</p>
        </div>`;
        },
        onOk: () => {
            const t = cartTotals();
            if (t.total > S.funds) return toast('Brak środków na koncie firmy', 'error'), false;
            return modalRequest(o, M, 'bossmenu:orderVehicles', { items: t.ls.map(l => ({ model: l.model, express: !!l.express })) }, 'Nie udało się złożyć zamówienia', res => {
                const items = t.ls.map(l => ({ model: l.model, name: l.c.name, price: l.c.price, express: !!l.express, fee: l.express ? expressFee(l.c) : 0 }));
                const order = { id: 'ord-' + Date.now(), items, total: t.total, by: fullName(S.me), at: nowFull(), status: 'pending', ...res.order };
                S.orders.unshift(order);
                S.funds = res.funds ?? S.funds - t.total;
                const names = items.map(i => i.name).join(', ');
                addTx('out', ordTotal(order), 'Zamówienie pojazdów', `${items.length} ${plVeh(items.length)}${t.nExp ? ` (w tym szybki transport: ${t.nExp})` : ''}: ${names}`);
                addHistory({ type: 'order', orderId: order.id, count: items.length, total: ordTotal(order), express: t.nExp, items: items.map(i => i.name + (i.express ? ' ⚡' : '')) });
                GAR.cart = [];
                toast('Zamówienie złożone – czeka na akceptację', 'success');
            });
        }
    };
    openModal(o);
}

function openOrderModal(id) {
    const ord = S.orders.find(x => x.id === id); if (!ord) return;
    const st = ORDER_ST[ord.status] || ORDER_ST.pending, items = ordItems(ord);
    openModal({
        icon: st.ic, tone: 'brand', noOk: true, cancel: 'Zamknij', title: `Zamówienie ${ordNo(ord)}`, text: `${ord.by} · ${fmtAt(ord.at)}`,
        body: () => `<div class="space-y-3">
            <div class="flex items-center gap-2">${stChip(st.tone, st.label, st.ic)}${ord.note ? `<span class="text-[11px] text-slate-400">${esc(ord.note)}</span>` : ''}</div>
            <ul class="max-h-52 overflow-y-auto space-y-1 pr-0.5">${items.map(i => `
                <li class="flex items-center gap-2 px-2.5 py-1.5 rounded-lg bg-slate-950/50 border border-slate-800 text-xs">
                    <span class="flex-1 min-w-0 truncate font-bold text-white">${esc(i.name)}</span>
                    ${i.express ? `<span class="flex items-center gap-1 text-[10px] font-bold text-amber-300 whitespace-nowrap">${icon('bolt', 'size-3')}Szybki transport +${money(i.fee || 0)}</span>` : ''}
                    <span class="font-extrabold text-slate-200 whitespace-nowrap">${money(i.price + (i.express ? (i.fee || 0) : 0))}</span>
                </li>`).join('')}</ul>
            <div class="flex items-center justify-between text-sm px-1"><span class="font-bold text-slate-300">Razem</span><span class="font-extrabold text-white">${money(ordTotal(ord))}</span></div>
        </div>`
    });
}

function openEmpVehicleModal(ssn) {
    if (!getEmp(ssn)) return;
    const M = { sel: null, busy: false };
    openModal({
        icon: 'car', tone: 'brand', live: true, noOk: true, cancel: 'Zamknij',
        title: 'Pojazdy pracownika', text: fullName(getEmp(ssn)),
        body: () => {
            const mine = S.vehicles.filter(v => sameSsn(v.assignedTo, ssn)), free = S.vehicles.filter(v => !v.assignedTo);
            if (!free.some(v => v.plate === M.sel)) M.sel = free[0]?.plate ?? null;
            return `<div class="space-y-4">
                <div>${fieldLabel(`Przydzielone pojazdy (${mine.length})`)}
                    ${mine.length ? `<ul class="space-y-2 max-h-60 overflow-y-auto pr-0.5">${mine.map(v => `
                        <li class="flex items-center gap-3 p-2.5 rounded-xl bg-slate-950/50 border border-slate-800">
                            <div class="size-9 shrink-0 rounded-lg border flex items-center justify-center ${TONES.sky}">${icon('car', 'size-4')}</div>
                            <div class="flex-1 min-w-0"><p class="text-sm font-bold text-white truncate">${esc(v.name)}</p>
                                <p class="text-[11px] text-slate-500 truncate">${esc(v.category || '—')}${v.assignedAt ? ` · od ${esc(shortAt(v.assignedAt))}` : ''}</p></div>
                            <span class="shrink-0 px-2 py-0.5 rounded-md bg-slate-800 border border-slate-700 font-mono text-[11px] font-extrabold text-slate-100">${esc(v.plate)}</span>
                            <button data-act="empVehRevoke" data-plate="${esc(v.plate)}" title="Odbierz pojazd"
                                class="shrink-0 p-2 rounded-lg bg-slate-800 text-slate-300 hover:bg-brand hover:text-white transition">${icon('user-minus', 'size-4')}</button>
                        </li>`).join('')}</ul>`
                    : '<p class="text-xs text-slate-500 py-2">Pracownik nie ma przydzielonych pojazdów.</p>'}
                </div>
                <div>${fieldLabel('Przydziel pojazd')}
                    ${free.length ? `<div class="flex gap-2">
                        <div class="flex-1 min-w-0">${selectHtml({ id: 'vehSel', value: M.sel, onChange: val => { M.sel = val; }, options: free.map(v => ({ value: v.plate, label: v.name, hint: v.plate })) })}</div>
                        <button data-act="empVehAssign" data-ssn="${esc(ssn)}" class="shrink-0 flex items-center gap-1.5 px-4 rounded-xl text-sm font-bold text-white bg-brand hover:opacity-90 transition">${icon('plus', 'size-4')} Przydziel</button>
                    </div>` : '<p class="text-xs text-slate-500 py-2">Brak wolnych pojazdów w garażu.</p>'}
                </div></div>`;
        },
        ctx: M
    });
}
function empVehicleAction(kind, el) {
    const M = MODAL?.ctx; if (!M || M.busy) return;
    const emp = getEmp(el.dataset.ssn || MODAL.ssn);
    const plate = kind === 'assign' ? M.sel : el.dataset.plate, v = S.vehicles.find(x => x.plate === plate);
    if (!v) return;
    const ssn = kind === 'assign' ? el.dataset.ssn : v.assignedTo, who = getEmp(ssn); if (!who) return;
    M.busy = true;
    request(kind === 'assign' ? 'bossmenu:assignVehicle' : 'bossmenu:revokeVehicle', kind === 'assign' ? { plate, ssn } : { plate }).then(res => {
        M.busy = false;
        if (!res?.ok) return toast(res?.error || 'Operacja nie powiodła się', 'error');
        if (kind === 'assign') { logVehicle('assign', v, who, v.assignedTo); v.assignedTo = ssn; v.assignedAt = nowFull(); toast(`Przydzielono ${v.name} (${v.plate}): ${fullName(who)}`, 'success'); }
        else { logVehicle('revoke', v, who); v.assignedTo = null; v.assignedAt = null; toast(`Odebrano ${v.name} (${v.plate}): ${fullName(who)}`, 'warn'); }
        refresh();
    });
}

function openAssignModal(plate) {
    const v = S.vehicles.find(x => x.plate === plate); if (!v) return;
    const emps = [...S.employees].sort((a, b) => b.grade - a.grade || fullName(a).localeCompare(fullName(b)));
    if (!emps.length) return toast('Brak pracowników', 'error');
    const cur = v.assignedTo ? getEmp(v.assignedTo) : null;
    const M = { ssn: (emps.find(e => !sameSsn(e.ssn, v.assignedTo)) || emps[0]).ssn, busy: false };
    const o = {
        icon: 'car', tone: 'brand', title: cur ? 'Zmień przydział pojazdu' : 'Przydziel pojazd', text: `${v.name} · ${v.plate}`, ok: cur ? 'Zmień' : 'Przydziel',
        body: () => `<div>${fieldLabel('Pracownik')}${selectHtml({
            id: 'asgSel', value: M.ssn, onChange: val => { M.ssn = val; },
            options: emps.map(e => ({ value: e.ssn, label: fullName(e), hint: `${gradeName(e.grade)} · pojazdów: ${vehCount(e.ssn)}` }))
        })}${cur ? `<p class="text-[11px] text-slate-500 mt-2">Obecnie przydzielony: <span class="font-semibold text-slate-300">${esc(fullName(cur))}</span> – straci ten pojazd.</p>` : ''}</div>`,
        onOk: () => {
            if (sameSsn(M.ssn, v.assignedTo)) return toast('Pojazd jest już przydzielony tej osobie', 'error'), false;
            const emp = getEmp(M.ssn); if (!emp) return toast('Nie znaleziono pracownika', 'error'), false;
            return modalRequest(o, M, 'bossmenu:assignVehicle', { plate: v.plate, ssn: emp.ssn }, 'Nie udało się przydzielić pojazdu', () => {
                logVehicle('assign', v, emp, v.assignedTo);
                v.assignedTo = emp.ssn; v.assignedAt = nowFull();
                toast(`Przydzielono ${v.name} (${v.plate}): ${fullName(emp)}`, 'success');
            });
        }
    };
    openModal(o);
}

function openRevokeModal(plate) {
    const v = S.vehicles.find(x => x.plate === plate), emp = v && getEmp(v.assignedTo); if (!v || !emp) return;
    const M = { busy: false };
    const o = {
        icon: 'user-minus', tone: 'brand', title: 'Odebrać pojazd?', ok: 'Odbierz',
        text: `${v.name} (${v.plate}) · ${fullName(emp)}`,
        onOk: () => modalRequest(o, M, 'bossmenu:revokeVehicle', { plate: v.plate }, 'Nie udało się odebrać pojazdu', () => {
            logVehicle('revoke', v, emp);
            v.assignedTo = null; v.assignedAt = null;
            toast(`Odebrano ${v.name} (${v.plate}): ${fullName(emp)}`, 'warn');
        })
    };
    openModal(o);
}

function openCancelOrderModal(id) {
    const ord = S.orders.find(x => x.id === id); if (!ord || ord.status !== 'pending') return;
    const M = { busy: false }, items = ordItems(ord);
    const o = {
        icon: 'x', tone: 'brand', title: 'Anulować zamówienie?', ok: 'Anuluj zamówienie', cancel: 'Wróć',
        text: `${ordNo(ord)} · ${items.length} ${plVeh(items.length)} · ${money(ordTotal(ord))} wróci na konto firmy.`,
        onOk: () => modalRequest(o, M, 'bossmenu:cancelOrder', { id: ord.id }, 'Nie udało się anulować zamówienia', res => {
            ord.status = 'cancelled';
            S.funds = res.funds ?? S.funds + ordTotal(ord);
            addTx('in', ordTotal(ord), 'Zwrot za zamówienie', `${ordNo(ord)}: ${items.map(i => i.name).join(', ')}`);
            addHistory({ type: 'orderCancel', orderId: ord.id, count: items.length, total: ordTotal(ord) });
            toast('Zamówienie anulowane – środki zwrócone', 'info');
        })
    };
    openModal(o);
}

/* DEV: symulacja drugiej firmy (w grze odpowiada serwer) */
function devAdvanceOrder(id, to) {
    const o = S.orders.find(x => x.id === id); if (!o) return;
    o.status = to;
    if (to === 'rejected') { o.note = 'Brak pojazdów na stanie'; S.funds += ordTotal(o); S.transactions.unshift({ type: 'in', amount: ordTotal(o), by: 'System', label: 'Zwrot za zamówienie', reason: ordNo(o), at: stamp() }); }
    if (to === 'delivered') ordItems(o).forEach(i => {
        const c = S.catalog.find(x => x.model === i.model) || {};
        S.vehicles.push({ plate: 'LS ' + String(1000 + Math.floor(Math.random() * 9000)), model: i.model, name: i.name, category: c.category, assignedTo: null, assignedAt: null, addedAt: nowFull() });
    });
    toast(`DEV: ${ORDER_ST[to].label}`, 'info');
}

/* =========================================================
   ZAMÓWIENIA (B2B) – firmy zamawiają towary u siebie nawzajem
   - Zamów: oferta wybranego dostawcy + koszyk (jedno zamówienie = jeden dostawca)
   - Moje zamówienia: towary (ta aplikacja) oraz pojazdy (z Garażu) – podgląd statusów
   - Przychodzące i Oferta: tylko dla firm-dostawców (shop.offer != null) – przyjmowanie, odrzucanie, dostawa
   Płatność z góry (jak w Garażu): kwota schodzi przy zamawianiu, wraca po odrzuceniu/anulowaniu,
   a na konto dostawcy trafia po oznaczeniu zamówienia jako dostarczone.
   ========================================================= */
const SHOP = { tab: 'order', sup: null, search: '', cat: 'all', cart: {}, note: {}, outF: 'all', outQ: '', inF: 'all', inQ: '', offQ: '', busy: false };
const SHOP_LINES = 20;               // maks. pozycji w jednym zamówieniu
const QTY_MAX = 99;                  // maks. sztuk jednej pozycji
const PRODUCT_MAX = 100000000;       // zapas, gdyby serwer nie przysłał limitu (Config.Goods.maxPrice)
const MONEY_MAX = 100000000;         // maks. kwota wpłaty/wypłaty – taka sama jak walidacja na serwerze
const priceMax = () => Number(S.maxPrice) > 0 ? Number(S.maxPrice) : PRODUCT_MAX;
const shop = () => {
    const s = S.shop = S.shop || {};
    s.suppliers = s.suppliers || []; s.out = s.out || []; s.incoming = s.incoming || []; s.companies = s.companies || [];
    if (s.offer === undefined) s.offer = null;
    return s;
};
const atKey = at => { const m = /^(\d{2})\.(\d{2})\.(\d{4})(?:\s+(\d{2}):(\d{2}))?/.exec(String(at || '')); return m ? Date.UTC(+m[3], +m[2] - 1, +m[1], +(m[4] || 0), +(m[5] || 0)) : 0; };
const sameId = (a, b) => String(a) === String(b);
/* dostęp do produktu: product.access = null/brak (wszystkie firmy) albo tablica jobów firm, które mogą zamawiać.
   Pozycje z modelem pojazdu zamawia się w Garażu (katalog), więc nie pokazują się w zamówieniach towarowych. */
const canBuy = p => p.active !== false && !p.model && (!Array.isArray(p.access) || p.access.includes(S.job.name));
const coName = job => (shop().companies || []).find(c => sameId(c.job, job))?.label || job;
const plFirm = n => n === 1 ? 'firma' : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) ? 'firmy' : 'firm';
const plPoz = n => n === 1 ? 'pozycja' : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) ? 'pozycje' : 'pozycji';

/* wspólny widok zamówienia towarów (shop.out / shop.incoming) i pojazdów (S.orders z Garażu) */
const shopLines = (o, kind) => kind === 'vehicles'
    ? ordItems(o).map(i => ({ name: i.name, qty: 1, price: i.price, fee: i.express ? (i.fee || 0) : 0, express: !!i.express }))
    : (o.items || []).map(i => ({ name: i.name, qty: i.qty || 1, price: i.price, fee: i.express ? (i.fee || 0) : 0, express: !!i.express }));
const shopTotal = (o, kind) => kind === 'vehicles' ? ordTotal(o) : (o.total ?? shopLines(o, kind).reduce((n, l) => n + (l.price + l.fee) * l.qty, 0));
const shopUnits = ls => ls.reduce((n, l) => n + l.qty, 0);
const shopSum = ls => ls.map(l => l.qty > 1 ? `${l.name} ×${l.qty}` : l.name).join(', ');
const shopCount = (ls, kind) => kind === 'vehicles' ? `${ls.length} ${plVeh(ls.length)}` : `${shopUnits(ls)} szt. · ${ls.length} ${plPoz(ls.length)}`;
const supplierName = (o, kind) => kind === 'vehicles' ? (S.supplier || 'Dostawca') : (o.supplier?.label || 'Dostawca');
const buyerName = o => o.buyer?.label || 'Firma';
const byNewest = (a, b) => atKey(b.o.at) - atKey(a.o.at);
const outList = () => [...shop().out.map(o => ({ o, kind: 'goods' })), ...S.orders.map(o => ({ o, kind: 'vehicles' }))].sort(byNewest);
const inList = () => shop().incoming.map(o => ({ o, kind: o.kind || 'goods' })).sort(byNewest);
function findShopOrder(id) {
    let o = shop().out.find(x => sameId(x.id, id)); if (o) return { o, kind: 'goods', side: 'out' };
    o = S.orders.find(x => sameId(x.id, id)); if (o) return { o, kind: 'vehicles', side: 'out' };
    o = shop().incoming.find(x => sameId(x.id, id)); if (o) return { o, kind: o.kind || 'goods', side: 'in' };
    return null;
}
const ST_FILTERS = [['all', 'Wszystkie'], ['pending', 'Oczekujące'], ['accepted', 'W realizacji'], ['delivered', 'Dostarczone'], ['closed', 'Zamknięte']];
const stMatch = (f, st) => f === 'all' || (f === 'closed' ? st === 'rejected' || st === 'cancelled' : st === f);
const orderMatch = (x, side, q) => [ordNo(x.o), side === 'out' ? supplierName(x.o, x.kind) : buyerName(x.o), shopSum(shopLines(x.o, x.kind)), x.o.by, x.o.note]
    .some(v => String(v || '').toLowerCase().includes(q));

/* dostawca wybrany w zakładce „Zamów” i jego koszyk (każdy dostawca ma osobny koszyk) */
function shopSupplier() {
    const sups = shop().suppliers;
    if (!sups.some(s => sameId(s.job, SHOP.sup))) SHOP.sup = sups[0]?.job ?? null;
    return sups.find(s => sameId(s.job, SHOP.sup)) || null;
}
const cartRaw = () => SHOP.cart[SHOP.sup] || (SHOP.cart[SHOP.sup] = []);
function shopCartTotals() {
    const sp = shopSupplier(), raw = sp ? cartRaw() : [];
    const ls = raw.map(c => ({ ...c, p: (sp.products || []).find(p => sameId(p.id, c.id) && canBuy(p)) })).filter(l => l.p);
    ls.forEach(l => { const fee = goodsFee(l.p); l.fee = l.express && fee > 0 ? fee : 0; });
    const sub = ls.reduce((n, l) => n + l.p.price * l.qty, 0);
    const exp = ls.reduce((n, l) => n + l.fee * l.qty, 0);
    return { sp, ls, lines: ls.length, units: shopUnits(ls), sub, exp, nExp: ls.filter(l => l.fee > 0).length, total: sub + exp };
}

function shopTabs() {
    const sh = shop(), pendIn = sh.incoming.filter(o => o.status === 'pending').length, cartN = shopCartTotals().lines;
    const tab = (id, label, n, hot) => `
        <button data-act="shopTab" data-v="${id}" class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition ${SHOP.tab === id ? 'bg-brand text-white' : 'text-slate-400 hover:text-white hover:bg-slate-800'}">${label}
            ${n !== undefined ? `<span class="px-1.5 rounded-md text-[10px] ${SHOP.tab === id ? 'bg-white/20 text-white' : hot ? 'bg-amber-500/20 text-amber-400' : 'bg-slate-800 text-slate-400'}">${n}</span>` : ''}</button>`;
    return `
    <div class="shrink-0 flex items-center justify-between gap-3">
        <div class="flex gap-1 p-1 rounded-xl bg-slate-900 border border-slate-800">
            ${tab('order', 'Zamów', cartN || sh.suppliers.length, cartN > 0)}${tab('mine', 'Moje zamówienia', outList().length)}${sh.offer || sh.incoming.length ? tab('in', 'Przychodzące', pendIn || sh.incoming.length, pendIn > 0) : ''}${sh.offer ? tab('offer', 'Oferta', sh.offer.products.length) : ''}
        </div>
        <div class="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-slate-900 border border-slate-800 text-xs">
            <span class="text-brand">${icon('wallet', 'size-4')}</span><span class="font-bold text-slate-400">Saldo firmy</span><span class="font-extrabold text-white break-all">${money(S.funds)}</span>
        </div>
    </div>`;
}
const shopEmpty = (ic, title, text) => `<div class="flex-1 flex flex-col items-center justify-center gap-2 text-center text-slate-500">${icon(ic, 'size-10')}<p class="text-sm font-bold text-slate-300">${title}</p><p class="text-xs max-w-xs">${text}</p></div>`;

/* --- zakładka: zamów --- */
function shopOrder() {
    const sups = shop().suppliers, sp = shopSupplier();
    if (!sp) return shopEmpty('building-store', 'Brak dostawców', 'Żadna firma nie udostępnia jeszcze swojej oferty.');
    const prods = (sp.products || []).filter(canBuy), q = SHOP.search.trim().toLowerCase();
    const cats = [...new Set(prods.map(p => p.category).filter(Boolean))];
    const cat = SHOP.cat === 'all' || cats.includes(SHOP.cat) ? SHOP.cat : 'all';
    const list = prods.filter(p => cat === 'all' || p.category === cat).filter(p => !q || [p.name, p.category, p.desc].some(x => String(x || '').toLowerCase().includes(q)));
    const full = cartRaw().length >= SHOP_LINES;
    const card = p => {
        const n = cartRaw().find(c => sameId(c.id, p.id))?.qty || 0;
        return `
        <div class="rounded-xl bg-slate-900/60 border ${n ? 'border-brand/40' : 'border-slate-800'} p-3 flex flex-col gap-2.5">
            <div class="flex items-start gap-2.5 min-w-0">
                <div class="size-10 shrink-0 rounded-xl border flex items-center justify-center ${TONES.emerald}">${icon('box', 'size-5')}</div>
                <div class="min-w-0 flex-1"><p class="text-sm font-extrabold text-white truncate" title="${esc(p.name)}">${esc(p.name)}</p>
                    <p class="text-[10px] font-semibold text-slate-500 truncate">${esc(p.category || 'Produkt')}</p></div>
                ${n ? `<span class="flex items-center gap-1 px-2 py-0.5 rounded-md bg-brand text-[10px] font-bold text-white">${icon('shopping-cart', 'size-3')}${n}</span>` : ''}
            </div>
            ${p.desc ? `<p class="text-[11px] leading-4 text-slate-400 line-clamp-2" title="${esc(p.desc)}">${esc(p.desc)}</p>` : ''}
            <div class="mt-auto flex items-center justify-between gap-2">
                <span class="text-[15px] leading-5 font-extrabold text-white">${money(p.price)}<span class="text-[10px] font-semibold text-slate-500"> / szt.</span></span>
                <button data-act="shopAdd" data-id="${esc(p.id)}" ${full && !n ? 'disabled' : ''} class="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-[11px] font-bold transition ${full && !n ? SAL_OFF : 'text-white bg-brand hover:opacity-90'}">${icon('shopping-cart-plus', 'size-3.5')}${full && !n ? 'Koszyk pełny' : 'Do koszyka'}</button>
            </div>
        </div>`;
    };
    return `
    <div class="flex-1 min-h-0 flex gap-3">
        <div class="flex-1 min-w-0 min-h-0 flex flex-col gap-3">
            <div class="shrink-0 flex gap-3">
                <div class="w-[250px] shrink-0">${selectHtml({
                    id: 'shopSup', value: sp.job, onChange: v => { SHOP.sup = v; SHOP.cat = 'all'; SHOP.search = ''; renderWin('orders'); },
                    options: sups.map(s => ({ value: s.job, label: s.label, hint: `${(s.products || []).filter(canBuy).length} prod.` }))
                })}</div>
                ${gSearch('shopSearch', SHOP.search, 'Szukaj produktu…')}
            </div>
            ${sp.desc ? `<p class="shrink-0 -mt-1 text-[11px] leading-4 text-slate-400 truncate" title="${esc(sp.desc)}">${esc(sp.desc)}</p>` : ''}
            ${cats.length > 1 ? gChips('shopCat', cat, [['all', 'Wszystkie'], ...cats.map(c => [c, c])]) : ''}
            <div class="flex-1 min-h-0 overflow-y-auto pr-1">
                ${list.length ? `<div class="grid grid-cols-[repeat(auto-fill,minmax(200px,1fr))] gap-3">${list.map(card).join('')}</div>`
                    : `<p class="text-center text-xs text-slate-400 py-12">${prods.length ? 'Brak produktów spełniających kryteria.' : 'Ten dostawca nie ma teraz żadnych produktów w ofercie.'}</p>`}
            </div>
        </div>
        ${shopCartPanel()}
    </div>`;
}
function shopCartPanel() {
    const T = shopCartTotals(), poor = T.total > S.funds, ok = T.lines && !poor;
    const stepBtn = (d, ic, id) => `<button data-act="shopQty" data-id="${esc(id)}" data-d="${d}" class="size-6 rounded-md bg-slate-800 text-slate-300 hover:bg-slate-700 hover:text-white flex items-center justify-center transition">${icon(ic, 'size-3.5')}</button>`;
    const line = l => {
        const fee = goodsFee(l.p);
        return `
        <li class="rounded-xl border bg-slate-950/40 border-slate-800 p-2 space-y-1.5">
            <div class="flex items-center gap-2 min-w-0">
                <span class="text-emerald-400 shrink-0">${icon('box', 'size-4')}</span>
                <p class="flex-1 min-w-0 text-xs font-bold text-white truncate" title="${esc(l.p.name)}">${esc(l.p.name)}</p>
                <button data-act="shopRemove" data-id="${esc(l.id)}" title="Usuń z koszyka" class="p-1 rounded-md text-slate-500 hover:text-white hover:bg-brand transition">${icon('x', 'size-3.5')}</button>
            </div>
            ${fee > 0 ? `<button data-act="shopExpress" data-id="${esc(l.id)}" class="w-full flex items-center justify-between gap-2 px-2 py-1 rounded-lg border text-[11px] font-bold transition ${l.fee
                ? 'bg-amber-500/10 border-amber-500/30 text-amber-300' : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-white hover:border-slate-700'}">
                <span class="flex items-center gap-1.5">${icon('bolt', 'size-3.5')}Szybki transport</span>
                <span class="flex items-center gap-1.5">+${money(fee)}<span class="size-3.5 rounded border flex items-center justify-center ${l.fee ? 'bg-amber-400 border-amber-400 text-slate-900' : 'border-slate-600'}">${l.fee ? icon('check', 'size-3') : ''}</span></span>
            </button>` : ''}
            <div class="flex items-center justify-between gap-2">
                <div class="flex items-center gap-1">${stepBtn(-1, 'minus', l.id)}<span class="w-8 text-center text-xs font-extrabold text-white">${l.qty}</span>${stepBtn(1, 'plus', l.id)}</div>
                <span class="text-[10px] font-semibold text-slate-500">${money(l.p.price)} × ${l.qty}</span>
                <span class="text-xs font-extrabold text-white whitespace-nowrap">${money((l.p.price + l.fee) * l.qty)}</span>
            </div>
        </li>`;
    };
    const sum = (l, v, cls = 'text-slate-200') => `<div class="flex items-center justify-between text-[11px]"><span class="text-slate-500 font-semibold">${l}</span><span class="font-bold ${cls}">${v}</span></div>`;
    return `
    <aside class="w-[292px] shrink-0 flex flex-col min-h-0 rounded-xl bg-slate-900/60 border border-slate-800 p-3">
        <div class="shrink-0 flex items-center justify-between gap-2 mb-2.5">
            <h3 class="flex items-center gap-2 text-[13px] font-extrabold text-white"><span class="text-brand">${icon('shopping-cart', 'size-4')}</span>Koszyk
                <span class="px-1.5 rounded-md bg-slate-800 text-[10px] font-bold text-slate-400">${T.lines}/${SHOP_LINES}</span></h3>
            ${T.lines ? `<button data-act="shopClear" class="text-[11px] font-bold text-slate-500 hover:text-white transition">Wyczyść</button>` : ''}
        </div>
        <ul class="flex-1 min-h-0 overflow-y-auto space-y-1.5 pr-0.5">${T.lines ? T.ls.map(line).join('')
            : `<li class="flex flex-col items-center gap-2 py-10 text-center text-xs text-slate-500">${icon('shopping-cart', 'size-8')}Koszyk jest pusty.<br>Dodaj produkty z oferty.</li>`}</ul>
        <div class="shrink-0 mt-2.5 pt-2.5 border-t border-slate-800/70 space-y-1">
            <textarea id="shopNote" rows="2" maxlength="200" placeholder="Uwagi dla dostawcy (opcjonalnie)…" class="w-full resize-none mb-1 bg-slate-950/60 border border-slate-800 rounded-lg px-2.5 py-1.5 text-[11px] text-white placeholder-slate-500 focus:border-brand/50 outline-none">${esc(SHOP.note[SHOP.sup] || '')}</textarea>
            ${sum(`Sztuk`, String(T.units))}
            ${T.exp ? sum(`Szybki transport (${T.nExp})`, money(T.exp), 'text-amber-300') : ''}
            <div class="flex items-center justify-between pt-1"><span class="text-xs font-bold text-slate-300">Razem</span><span class="text-[17px] leading-5 font-extrabold text-white">${money(T.total)}</span></div>
            ${sum('Saldo firmy', money(S.funds), poor ? 'text-brand' : 'text-emerald-400')}
            ${poor ? `<p class="text-[11px] font-semibold text-brand">Brakuje ${money(T.total - S.funds)}</p>` : ''}
            <button data-act="shopCheckout" ${ok ? '' : 'disabled'} class="w-full mt-1.5 flex items-center justify-center gap-2 px-3 py-2 rounded-lg text-xs font-bold transition ${ok ? 'text-white bg-brand hover:opacity-90' : SAL_OFF}">${icon('shopping-cart', 'size-4')}Zamów${T.lines ? ` (${T.units} szt.)` : ''}</button>
        </div>
    </aside>`;
}

/* --- wiersz zamówienia (wspólny dla „Moje zamówienia” i „Przychodzące”) --- */
function shopRow({ o, kind }, side) {
    const st = ORDER_ST[o.status] || ORDER_ST.pending, dim = o.status === 'rejected' || o.status === 'cancelled';
    const ls = shopLines(o, kind), nExp = ls.filter(l => l.express).length, id = `data-id="${esc(o.id)}" data-kind="${kind}"`;
    const party = side === 'out' ? `Dostawca: <span class="font-semibold ${dim ? 'text-slate-500' : 'text-slate-300'}">${esc(supplierName(o, kind))}</span>` : `Zamawia: <span class="font-semibold ${dim ? 'text-slate-500' : 'text-slate-300'}">${esc(buyerName(o))}</span>`;
    const why = o.status === 'rejected' ? (o.reason || o.note) : '';
    const tail = why ? `<span class="text-brand/80">Powód: ${esc(why)}</span>` : o.note ? esc(o.note) : '';
    const devBtn = (ic, label, to) => gBtn('shopDev', ic, label, `${id} data-to="${to}"`, 'bg-slate-800/70 text-slate-400 hover:text-white');
    const dev = side === 'out' && !IN_GAME ? `<span class="shrink-0 w-[188px] flex items-center justify-end gap-1 pl-2 border-l border-dashed border-slate-700" title="Tylko DEV – symulacja ruchu drugiej firmy">
            <span class="text-[9px] font-extrabold text-slate-600">DEV</span>
            ${o.status === 'pending' ? devBtn('check', 'Przyjmij', 'accepted') + devBtn('ban', 'Odrzuć', 'rejected') : ''}${o.status === 'accepted' ? devBtn('truck-delivery', 'Dostarcz', 'delivered') : ''}</span>` : '';
    const acts = side === 'out'
        ? `${gBtn('shopInfo', 'list-details', '', `${id} title="Szczegóły"`)}${o.status === 'pending' ? gBtn('shopCancel', 'x', 'Anuluj', id, 'bg-slate-800 text-slate-200 hover:bg-brand hover:text-white') : ''}`
        : `${gBtn('shopInfo', 'list-details', '', `${id} title="Szczegóły"`)}
           ${o.status === 'pending' ? gBtn('shopReject', 'ban', 'Odrzuć', id, 'bg-slate-800 text-slate-200 hover:bg-brand hover:text-white') + gBtn('shopAccept', 'check', 'Przyjmij', id, 'bg-emerald-500/15 text-emerald-300 hover:bg-emerald-500 hover:text-white') : ''}
           ${o.status === 'accepted' ? gBtn('shopDeliver', 'truck-delivery', 'Dostarczono', `${id} ${o.delivery === 'physical' ? 'title="To zamówienie jedzie lawetą (tr2). Pojazdy wpisuje do garażu dopiero oddanie aut na miejscu odbioru – z panelu zadziała tylko przy włączonym manualOverride."' : ''}`.trim(), 'bg-sky-500/15 text-sky-300 hover:bg-sky-500 hover:text-white') : ''}`;
    return `
    <li class="flex items-center gap-3 px-3 py-2 rounded-xl border min-w-0 ${dim ? 'bg-slate-950/20 border-slate-800/60' : 'bg-slate-950/40 border-slate-800'}">
        <div class="size-9 shrink-0 rounded-lg border flex items-center justify-center ${TONES[st.tone]}">${icon(st.ic, 'size-5')}</div>
        <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 min-w-0">
                <p class="text-xs font-bold whitespace-nowrap ${dim ? 'text-slate-500' : 'text-white'}">Zamówienie ${esc(ordNo(o))}</p>
                ${kind === 'vehicles' ? stChip('sky', 'Pojazdy', 'car') : stChip('emerald', 'Towary', 'box')}${stChip(st.tone, st.label, null)}${o.delivery === 'physical' && !dim ? stChip('violet', 'Laweta CD', 'truck-delivery') : ''}${nExp ? stChip('amber', `Szybki transport ×${nExp}`, 'bolt') : ''}
            </div>
            <p class="text-[10px] text-slate-500 truncate" title="${esc(shopSum(ls))}">${party} · ${esc(shopSum(ls))}</p>
            <p class="text-[10px] text-slate-600 truncate">${esc(o.by)} · ${esc(fmtAt(o.at))}${tail ? ` · ${tail}` : ''}</p>
        </div>
        ${dev}
        <div class="shrink-0 w-[92px] text-right"><p class="text-xs font-extrabold ${dim ? 'text-slate-500 line-through' : 'text-white'}">${money(shopTotal(o, kind))}</p>
            <p class="text-[10px] text-slate-500">${esc(shopCount(ls, kind))}</p></div>
        <div class="${side === 'out' ? 'w-[112px]' : 'w-[222px]'} shrink-0 flex justify-end gap-1.5">${acts}</div>
    </li>`;
}

/* --- zakładka: moje zamówienia --- */
function shopMine() {
    const all = outList(), q = SHOP.outQ.trim().toLowerCase();
    const list = all.filter(x => stMatch(SHOP.outF, x.o.status)).filter(x => !q || orderMatch(x, 'out', q));
    return `
    <div class="shrink-0 flex gap-3">
        ${gSearch('outSearch', SHOP.outQ, 'Szukaj po numerze, dostawcy lub produkcie…')}
        ${gChips('shopFOut', SHOP.outF, ST_FILTERS.map(([v, l]) => [v, l, all.filter(x => stMatch(v, x.o.status)).length]))}
    </div>
    ${listPanel({ key: 'ordOut', title: 'Moje zamówienia', ic: 'package', count: list.length, rows: list.map(x => shopRow(x, 'out')), cls: 'flex-1' })}`;
}

/* --- zakładka: przychodzące (dla dostawców) --- */
function shopIncoming() {
    const all = inList(), q = SHOP.inQ.trim().toLowerCase();
    const list = all.filter(x => stMatch(SHOP.inF, x.o.status)).filter(x => !q || orderMatch(x, 'in', q));
    const pend = all.filter(x => x.o.status === 'pending'), prog = all.filter(x => x.o.status === 'accepted');
    const open = [...pend, ...prog].reduce((n, x) => n + shopTotal(x.o, x.kind), 0);
    const stat = (ic, tone, label, value, hint = '') => `
        <div class="flex-1 min-w-0 flex items-center gap-3 px-3 py-2 rounded-xl bg-slate-900/60 border border-slate-800">
            <div class="size-9 shrink-0 rounded-lg border flex items-center justify-center ${TONES[tone]}">${icon(ic, 'size-5')}</div>
            <div class="min-w-0"><p class="text-[10px] font-bold uppercase tracking-wide text-slate-500 truncate">${label}</p>
                <p class="text-[15px] leading-5 font-extrabold text-white truncate" ${hint ? `title="${esc(hint)}"` : ''}>${value}</p></div>
        </div>`;
    const dev = IN_GAME ? '' : gBtn('shopDevIncoming', 'plus', 'DEV: nowe zamówienie', '', 'bg-slate-800/70 text-slate-400 hover:text-white');
    return `
    <div class="shrink-0 flex gap-3">
        ${stat('clock', 'amber', 'Oczekujące', pend.length)}${stat('truck-delivery', 'sky', 'W realizacji', prog.length)}${stat('coins', 'emerald', 'Wartość otwartych', money(open), 'Suma oczekujących i będących w realizacji. Środki trafią na konto firmy po oznaczeniu zamówienia jako dostarczone.')}
    </div>
    <div class="shrink-0 flex gap-3">
        ${gSearch('inSearch', SHOP.inQ, 'Szukaj po numerze, firmie lub produkcie…')}
        ${gChips('shopFIn', SHOP.inF, ST_FILTERS.map(([v, l]) => [v, l, all.filter(x => stMatch(v, x.o.status)).length]))}
    </div>
    ${listPanel({ key: 'ordIn', title: 'Zamówienia od innych firm', ic: 'inbox', count: list.length, rows: list.map(x => shopRow(x, 'in')), add: dev, cls: 'flex-1' })}`;
}

/* --- zakładka: oferta własna (dla dostawców) --- */
const accChip = p => {
    if (!Array.isArray(p.access)) return '';
    const n = p.access.length, names = p.access.map(coName).join(', ');
    return `<span title="${esc(names || 'Nikt nie może zamówić tego produktu')}">${stChip(n ? 'sky' : 'amber', n ? `Dostęp: ${n} ${plFirm(n)}` : 'Brak dostępu', 'users')}</span>`;
};
function shopOffer() {
    const of = shop().offer, q = SHOP.offQ.trim().toLowerCase();
    const list = of.products.filter(p => !q || [p.name, p.category, p.desc].some(x => String(x || '').toLowerCase().includes(q)));
    const row = p => {
        const on = p.active !== false;
        return `
        <li class="flex items-center gap-3 px-3 py-2 rounded-xl border min-w-0 ${on ? 'bg-slate-950/40 border-slate-800' : 'bg-slate-950/20 border-slate-800/60'}">
            <div class="size-9 shrink-0 rounded-lg border flex items-center justify-center ${on ? TONES.emerald : TONES.slate}">${icon('box', 'size-5')}</div>
            <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 min-w-0"><p class="text-xs font-bold truncate ${on ? 'text-white' : 'text-slate-500'}">${esc(p.name)}</p>
                    ${p.category ? stChip('slate', esc(p.category)) : ''}${p.model ? stChip('sky', esc(p.model), 'car') : ''}${Number(p.expressFee) > 0 ? stChip('amber', '⚡ +' + money(p.expressFee), 'bolt') : ''}${on ? '' : stChip('amber', 'Ukryty', 'eye')}${accChip(p)}</div>
                <p class="text-[10px] text-slate-500 truncate">${esc(p.desc || 'Brak opisu')}</p>
            </div>
            <span class="shrink-0 w-[96px] text-right text-xs font-extrabold ${on ? 'text-white' : 'text-slate-500'}">${money(p.price)}<span class="text-[10px] font-semibold text-slate-500"> / szt.</span></span>
            <button data-act="offToggle" data-id="${esc(p.id)}" role="switch" aria-checked="${on}" title="${on ? 'Ukryj w ofercie' : 'Pokaż w ofercie'}" class="relative w-9 h-5 rounded-full shrink-0 transition ${on ? 'bg-brand' : 'bg-slate-700'}">
                <span class="absolute top-0.5 left-0.5 size-4 rounded-full bg-white shadow transition-transform ${on ? 'translate-x-4' : ''}"></span></button>
            <div class="shrink-0 flex gap-1.5">
                ${gBtn('offEdit', 'edit', '', `data-id="${esc(p.id)}" title="Edytuj"`)}${gBtn('offDelete', 'trash', '', `data-id="${esc(p.id)}" title="Usuń z oferty"`, 'bg-slate-800 text-slate-200 hover:bg-brand hover:text-white')}
            </div>
        </li>`;
    };
    return `
    <div class="shrink-0 flex items-start gap-2.5 px-3.5 py-2.5 rounded-xl bg-sky-500/5 border border-sky-500/20 text-[11px] leading-4 text-slate-300">
        <span class="text-sky-400 shrink-0 mt-px">${icon('info-circle', 'size-4')}</span>
        <p>Domyślnie produkty widzą wszystkie firmy w zakładce „Zamów” – w edycji produktu możesz ograniczyć dostęp do wybranych firm. Ukryty produkt zostaje w ofercie, ale nie można go zamówić. Zmiana ceny nie wpływa na złożone już zamówienia. Dopłata „Szybki transport” doliczana jest za każdą sztukę, gdy zamawiający zaznaczy ją w koszyku.${S.vehicleSupplier ? ' Twoje pozycje z modelem pojazdu tworzą katalog w Garażu (i nie pokazują się w zamówieniach towarowych) – tam ustawiasz też dopłatę za szybki transport pojazdu.' : ''}</p>
    </div>
    <div class="shrink-0 flex gap-3">${gSearch('offSearch', SHOP.offQ, 'Szukaj w swojej ofercie…')}</div>
    ${listPanel({ key: 'offer', title: 'Moja oferta', ic: 'building-store', count: list.length, rows: list.map(row), add: gBtn('offAdd', 'plus', 'Dodaj produkt', '', 'text-white bg-brand hover:opacity-90'), cls: 'flex-1' })}`;
}

function appOrders() {
    const sh = shop();
    if ((SHOP.tab === 'in' && !(sh.offer || sh.incoming.length)) || (SHOP.tab === 'offer' && !sh.offer)) SHOP.tab = 'order';
    const body = SHOP.tab === 'mine' ? shopMine() : SHOP.tab === 'in' ? shopIncoming() : SHOP.tab === 'offer' ? shopOffer() : shopOrder();
    return `<div class="h-full flex flex-col gap-3 min-h-0">${shopTabs()}${body}</div>`;
}

/* --- koszyk: akcje --- */
function shopCartAct(type, el) {
    if (!shopSupplier()) return;
    const cart = cartRaw(), id = el.dataset.id, i = cart.findIndex(c => sameId(c.id, id));
    if (type === 'add') {
        if (i >= 0) cart[i].qty = Math.min(QTY_MAX, cart[i].qty + 1);
        else if (cart.length >= SHOP_LINES) return toast(`Maksymalnie ${SHOP_LINES} pozycji w jednym zamówieniu`, 'error');
        else cart.push({ id, qty: 1 });
    } else if (type === 'qty' && i >= 0) {
        cart[i].qty += Number(el.dataset.d);
        if (cart[i].qty > QTY_MAX) { cart[i].qty = QTY_MAX; toast(`Maksymalnie ${QTY_MAX} szt. jednego produktu`, 'warn'); }
        if (cart[i].qty < 1) cart.splice(i, 1);
    } else if (type === 'remove' && i >= 0) cart.splice(i, 1);
    else if (type === 'express' && i >= 0) cart[i].express = !cart[i].express;
    else if (type === 'clear') { cart.length = 0; SHOP.note[SHOP.sup] = ''; }
    renderWin('orders');
}

/* --- modale: zamawianie --- */
function openShopCheckout() {
    const T = shopCartTotals(); if (!T.lines) return toast('Koszyk jest pusty', 'error');
    const sp = T.sp, M = { busy: false };
    const row = (l, v, cls = 'text-white') => `<div class="flex items-center justify-between text-xs"><span class="text-slate-400">${l}</span><span class="font-extrabold ${cls}">${v}</span></div>`;
    const o = {
        icon: 'shopping-cart', tone: 'brand', title: `Zamówić towary (${T.units} szt.)?`, text: `Zamówienie trafi do firmy ${sp.label}`, ok: 'Złóż zamówienie',
        body: () => {
            const t = shopCartTotals(), note = SHOP.note[sp.job] || '';
            return `<div class="space-y-3">
            <ul class="max-h-44 overflow-y-auto space-y-1 pr-0.5">${t.ls.map(l => `
                <li class="flex items-center gap-2 px-2.5 py-1.5 rounded-lg bg-slate-950/50 border border-slate-800 text-xs">
                    <span class="flex-1 min-w-0 truncate font-bold text-white">${esc(l.p.name)}${l.fee ? ' ⚡' : ''}</span>
                    <span class="text-[11px] font-semibold text-slate-500 whitespace-nowrap">${money(l.p.price)} × ${l.qty}${l.fee ? ` <span class="text-amber-400">+${money(l.fee)}/szt.</span>` : ''}</span>
                    <span class="font-extrabold text-slate-200 whitespace-nowrap">${money((l.p.price + l.fee) * l.qty)}</span>
                </li>`).join('')}</ul>
            ${note ? `<p class="text-[11px] leading-4 text-slate-400 break-words">Uwagi: <span class="text-slate-300">${esc(note)}</span></p>` : ''}
            <div class="rounded-xl bg-slate-950/50 border border-slate-800 p-3 space-y-1.5">
                ${t.exp ? row('Szybki transport', money(t.exp), 'text-amber-300') : ''}
                ${row('Razem', money(t.total))}${row('Saldo konta', money(S.funds))}
                ${row('Saldo po zamówieniu', money(S.funds - t.total), S.funds - t.total < 0 ? 'text-brand' : 'text-emerald-400')}
            </div>
            <p class="text-[11px] leading-4 text-slate-400">Środki zostaną pobrane teraz i zwrócone, jeśli dostawca odrzuci zamówienie lub je anulujesz (dopóki czeka na akceptację).</p>
        </div>`;
        },
        onOk: () => {
            const t = shopCartTotals();
            if (t.total > S.funds) return toast('Brak środków na koncie firmy', 'error'), false;
            const note = (SHOP.note[sp.job] || '').trim();
            return modalRequest(o, M, 'bossmenu:orderGoods', { supplier: sp.job, items: t.ls.map(l => ({ id: l.id, qty: l.qty, express: !!l.fee })), note }, 'Nie udało się złożyć zamówienia', res => {
                const items = t.ls.map(l => ({ id: l.id, name: l.p.name, price: l.p.price, qty: l.qty, express: !!l.fee, fee: l.fee }));
                const order = { id: 'zam-' + Date.now(), kind: 'goods', supplier: { job: sp.job, label: sp.label }, buyer: { job: S.job.name, label: S.job.label },
                    items, total: t.total, by: fullName(S.me), at: nowFull(), status: 'pending', ...(note ? { note } : {}), ...res.order };
                shop().out.unshift(order);
                S.funds = res.funds ?? S.funds - t.total;
                addTx('out', t.total, 'Zamówienie towarów', `${sp.label}: ${shopSum(t.ls.map(l => ({ name: l.p.name + (l.fee ? ' ⚡' : ''), qty: l.qty })))}`);
                addHistory({ type: 'goodsOrder', orderId: order.id, supplier: sp.label, lines: items.length, units: t.units, total: t.total, items: items.map(i => (i.qty > 1 ? `${i.name} ×${i.qty}` : i.name) + (i.express ? ' ⚡' : '')) });
                SHOP.cart[sp.job] = []; SHOP.note[sp.job] = ''; SHOP.tab = 'mine'; EMP.off.ordOut = 0;
                toast(t.exp ? 'Zamówienie z szybkim transportem złożone – czeka na akceptację dostawcy' : 'Zamówienie złożone – czeka na akceptację dostawcy', 'success');
            });
        }
    };
    openModal(o);
}
function openShopCancelModal(id) {
    const f = findShopOrder(id); if (!f || f.kind !== 'goods' || f.o.status !== 'pending') return;
    const { o } = f, M = { busy: false }, ls = shopLines(o, 'goods'), total = shopTotal(o, 'goods');
    const mo = {
        icon: 'x', tone: 'brand', title: 'Anulować zamówienie?', ok: 'Anuluj zamówienie', cancel: 'Wróć',
        text: `${ordNo(o)} · ${supplierName(o, 'goods')} · ${money(total)} wróci na konto firmy.`,
        onOk: () => modalRequest(mo, M, 'bossmenu:cancelOrder', { id: o.id, kind: 'goods' }, 'Nie udało się anulować zamówienia', res => {
            o.status = 'cancelled';
            S.funds = res.funds ?? S.funds + total;
            addTx('in', total, 'Zwrot za zamówienie', `${ordNo(o)}: ${shopSum(ls)}`);
            addHistory({ type: 'goodsCancel', orderId: o.id, supplier: supplierName(o, 'goods'), total });
            toast('Zamówienie anulowane – środki zwrócone', 'info');
        })
    };
    openModal(mo);
}

/* --- modale: szczegóły i obsługa zamówienia przychodzącego --- */
function openShopOrderModal(id) {
    const f = findShopOrder(id); if (!f) return;
    const { o, kind, side } = f, st = ORDER_ST[o.status] || ORDER_ST.pending, ls = shopLines(o, kind);
    const why = o.status === 'rejected' ? (o.reason || o.note) : '';
    const kv = (k, v) => `<div class="flex items-center justify-between gap-3 text-xs"><span class="text-slate-500 font-semibold">${k}</span><span class="font-bold text-slate-200 text-right truncate">${v}</span></div>`;
    openModal({
        icon: st.ic, tone: 'brand', noOk: true, cancel: 'Zamknij', wide: false, title: `Zamówienie ${ordNo(o)}`, text: `${kind === 'vehicles' ? 'Pojazdy' : 'Towary'} · ${fmtAt(o.at)}`,
        body: () => `<div class="space-y-3">
            <div class="flex items-center gap-2 flex-wrap">${stChip(st.tone, st.label, st.ic)}</div>
            <div class="rounded-xl bg-slate-950/50 border border-slate-800 p-3 space-y-1.5">
                ${kv('Dostawca', esc(supplierName(o, kind)))}${kv('Zamawiający', esc(side === 'in' ? buyerName(o) : S.job.label))}${kv('Złożył', esc(o.by || '—'))}
            </div>
            ${why ? `<p class="text-[11px] leading-4 text-brand break-words">Powód odrzucenia: <span class="text-slate-300">${esc(why)}</span></p>` : (o.note ? `<p class="text-[11px] leading-4 text-slate-400 break-words">Uwagi: <span class="text-slate-300">${esc(o.note)}</span></p>` : '')}
            <ul class="max-h-48 overflow-y-auto space-y-1 pr-0.5">${ls.map(l => `
                <li class="flex items-center gap-2 px-2.5 py-1.5 rounded-lg bg-slate-950/50 border border-slate-800 text-xs">
                    <span class="flex-1 min-w-0 truncate font-bold text-white">${esc(l.name)}</span>
                    ${l.express ? `<span class="flex items-center gap-1 text-[10px] font-bold text-amber-300 whitespace-nowrap">${icon('bolt', 'size-3')}Szybki transport +${money(l.fee)}</span>` : ''}
                    ${l.qty > 1 ? `<span class="text-[11px] font-semibold text-slate-500 whitespace-nowrap">${money(l.price)} × ${l.qty}</span>` : ''}
                    <span class="font-extrabold text-slate-200 whitespace-nowrap">${money(l.price * l.qty + l.fee)}</span>
                </li>`).join('')}</ul>
            <div class="flex items-center justify-between text-sm px-1"><span class="font-bold text-slate-300">Razem</span><span class="font-extrabold text-white">${money(shopTotal(o, kind))}</span></div>
        </div>`
    });
}
function shopHandle(id, action) {            // action: accept | reject | deliver (zamówienia przychodzące – oba rodzaje)
    const f = findShopOrder(id); if (!f || f.side !== 'in') return;
    const { o, kind } = f, ls = shopLines(o, kind), total = shopTotal(o, kind), M = { busy: false };
    const next = { accept: 'accepted', reject: 'rejected', deliver: 'delivered' }[action];
    if (o.status !== (action === 'deliver' ? 'accepted' : 'pending')) return toast('Status zamówienia już się zmienił', 'error');
    const cfg = {
        accept: { icon: 'check', title: 'Przyjąć zamówienie?', ok: 'Przyjmij', text: `${ordNo(o)} · ${buyerName(o)} · ${money(total)}. Zamawiający zobaczy status „W realizacji”.` },
        reject: { icon: 'ban', title: 'Odrzucić zamówienie?', ok: 'Odrzuć', text: `${ordNo(o)} · ${buyerName(o)} · ${money(total)} wróci na konto zamawiającego.` },
        deliver: { icon: 'truck-delivery', title: 'Oznaczyć jako dostarczone?', ok: 'Dostarczono', text: `${ordNo(o)} · ${buyerName(o)}. Kwota ${money(total)} trafi na konto firmy${kind === 'vehicles' ? ', a pojazdy do garażu zamawiającego' : ''}.${o.delivery === 'physical' ? ' UWAGA: te pojazdy są/będą na lawecie `tr2` – normalnie zamówienie zamyka się samo, gdy pracownik CD odda auta na miejscu odbioru.' : ''}` }
    }[action];
    const mo = {
        icon: cfg.icon, tone: 'brand', title: cfg.title, text: cfg.text, ok: cfg.ok, needReason: action === 'reject',
        body: action === 'reject' ? () => reasonField('Powód odrzucenia', 'Np. brak towaru na stanie…') : undefined,
        onOk: () => {
            const reason = action === 'reject' ? reasonValue() : '';
            if (action === 'reject' && reason.length < REASON_MIN) return toast(`Podaj powód (min. ${REASON_MIN} znaków)`, 'error'), false;
            return modalRequest(mo, M, 'bossmenu:supplierOrder', { id: o.id, kind, action, ...(reason ? { reason } : {}) }, 'Nie udało się zmienić statusu zamówienia', res => {
                o.status = next; if (reason) o.reason = reason;
                if (action === 'deliver') { S.funds = res.funds ?? S.funds + total; addTx('in', total, 'Dostawa zamówienia', `${ordNo(o)} · ${buyerName(o)}: ${shopSum(ls)}`); }
                addHistory({ type: 'orderHandled', orderId: o.id, action: next, buyer: buyerName(o), total, ...(reason ? { reason } : {}) });
                toast({ accepted: 'Zamówienie przyjęte', rejected: 'Zamówienie odrzucone – środki wróciły do zamawiającego', delivered: `Zamówienie dostarczone – ${money(total)} na koncie firmy` }[next], next === 'rejected' ? 'warn' : 'success');
            });
        }
    };
    openModal(mo);
}

/* --- oferta: produkty --- */
let PROD_M = null;
const coBtnCls = on => `flex items-center gap-2 px-2.5 py-1.5 rounded-lg border text-left text-xs font-semibold transition ${on ? 'bg-brand/5 border-brand/40 text-white' : 'bg-slate-950/40 border-slate-800 text-slate-400 hover:border-slate-700 hover:text-slate-200'}`;
const coBox = on => `<span class="size-4 shrink-0 rounded border flex items-center justify-center ${on ? 'bg-brand border-brand text-white' : 'border-slate-600'}">${on ? icon('check', 'size-3') : ''}</span>`;
function syncAccessUI() {
    const M = PROD_M; if (!M) return;
    $$('[data-act=prodMode]').forEach(b => { const on = b.dataset.v === M.mode; b.className = `flex-1 px-3 py-1.5 rounded-lg text-xs font-bold transition ${on ? 'bg-brand text-white' : 'text-slate-400 hover:text-white hover:bg-slate-800'}`; });
    $('#prodCos')?.classList.toggle('hidden', M.mode !== 'some');
    $$('[data-act=prodCo]').forEach(b => { const on = M.sel.has(b.dataset.job); b.className = coBtnCls(on); b.querySelector('span').outerHTML = coBox(on); });
    const c = $('#prodCoCnt'); if (c) c.textContent = M.sel.size ? `Wybrano: ${M.sel.size}` : 'Nie wybrano żadnej firmy';
}
function openProductModal(id) {
    const of = shop().offer; if (!of) return;
    const p = id ? of.products.find(x => sameId(x.id, id)) : null; if (id && !p) return;
    const isVeh = S.vehicleSupplier === true;      // firma-dostawca pojazdów → jej oferta tworzy katalog w Garażu
    const cos = shop().companies, M = PROD_M = { busy: false, mode: Array.isArray(p?.access) ? 'some' : 'all', sel: new Set(Array.isArray(p?.access) ? p.access : []) };
    const inp = (idAttr, label, val, ph, extra = '') => `<label class="block">${fieldLabel(label)}<input id="${idAttr}" value="${esc(val)}" placeholder="${ph}" autocomplete="off" ${extra}
        class="w-full bg-slate-950/60 border border-slate-800 rounded-xl px-3.5 py-2.5 text-sm font-bold text-white placeholder-slate-500 focus:border-brand/50 outline-none"></label>`;
    const o = {
        icon: 'box', tone: 'brand', title: p ? 'Edytuj produkt' : 'Nowy produkt', text: p ? p.name : 'Produkt pojawi się w ofercie widocznej dla innych firm.', ok: 'Zapisz',
        body: () => `<div class="space-y-3">
            ${inp('prodName', 'Nazwa', p?.name || '', 'np. Zestaw naprawczy', 'maxlength="60" data-autofocus')}
            <div class="grid grid-cols-2 gap-3">
                ${inp('prodCat', 'Kategoria', p?.category || '', 'np. Narzędzia', 'maxlength="30"')}
                <label class="block">${fieldLabel('Cena za sztukę')}<div class="relative"><span class="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500 text-sm font-bold">$</span>
                    <input id="prodPrice" inputmode="numeric" maxlength="9" value="${esc(p?.price ?? '')}" placeholder="0" autocomplete="off"
                    class="w-full bg-slate-950/60 border border-slate-800 rounded-xl pl-7 pr-3 py-2.5 text-sm font-bold text-white placeholder-slate-500 focus:border-brand/50 outline-none"></div></label>
            </div>
            <label class="block">${fieldLabel('Opis (opcjonalnie)')}<textarea id="prodDesc" rows="2" maxlength="120" placeholder="Krótki opis widoczny dla zamawiających…"
                class="w-full resize-none bg-slate-950/60 border border-slate-800 rounded-xl px-3.5 py-2.5 text-sm text-white placeholder-slate-500 focus:border-brand/50 outline-none">${esc(p?.desc || '')}</textarea></label>
            <div class="${isVeh ? 'grid grid-cols-2 gap-3' : ''}">
                ${isVeh ? `<label class="block">${fieldLabel('Model pojazdu (spawn)')}
                    <input id="prodModel" value="${esc(p?.model || '')}" placeholder="np. caracara2" autocomplete="off" maxlength="50"
                        class="w-full bg-slate-950/60 border border-slate-800 rounded-xl px-3.5 py-2.5 text-sm font-bold text-white placeholder-slate-500 focus:border-brand/50 outline-none"></label>` : ''}
                <label class="block">${fieldLabel('Szybki transport (za sztukę)')}<div class="relative"><span class="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500 text-sm font-bold">$</span>
                    <input id="prodFee" inputmode="numeric" maxlength="9" value="${esc(p?.expressFee ?? '')}" placeholder="${esc(String(isVeh ? (S.expressFee ?? 0) : (S.goodsExpressFee ?? 0)))}" autocomplete="off"
                    class="w-full bg-slate-950/60 border border-slate-800 rounded-xl pl-7 pr-3 py-2.5 text-sm font-bold text-white placeholder-slate-500 focus:border-brand/50 outline-none"></div></label>
            </div>
            <p class="text-[11px] text-slate-500">${isVeh
                ? `Pozycje z wpisanym modelem tworzą katalog w Garażu i nie pokazują się w zamówieniach towarowych – inne firmy zamawiają je jak pojazdy. Puste pole dopłaty = kwota domyślna (${money(S.expressFee || 0)}).`
                : 'Dopłata doliczana za każdą sztukę, gdy zamawiający zaznaczy w koszyku „Szybki transport”. Puste pole = brak opcji szybkiego transportu dla tego produktu.'}</p>
            <label class="flex items-center gap-3 cursor-pointer select-none">
                <input id="prodActive" type="checkbox" class="peer sr-only" ${!p || p.active !== false ? 'checked' : ''}>
                <span class="relative w-11 h-6 rounded-full bg-slate-700 transition peer-checked:bg-brand after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:size-5 after:rounded-full after:bg-white after:shadow after:transition-transform peer-checked:after:translate-x-5"></span>
                <span class="text-xs font-semibold text-slate-300">Dostępny w ofercie</span>
            </label>
            <div>${fieldLabel('Kto może zamawiać')}
                <div class="flex gap-1 p-1 rounded-xl bg-slate-950/60 border border-slate-800">
                    <button type="button" data-act="prodMode" data-v="all" class="flex-1 px-3 py-1.5 rounded-lg text-xs font-bold transition ${M.mode === 'all' ? 'bg-brand text-white' : 'text-slate-400 hover:text-white hover:bg-slate-800'}">Wszystkie firmy</button>
                    <button type="button" data-act="prodMode" data-v="some" ${cos.length ? '' : 'disabled'} class="flex-1 px-3 py-1.5 rounded-lg text-xs font-bold transition ${cos.length ? (M.mode === 'some' ? 'bg-brand text-white' : 'text-slate-400 hover:text-white hover:bg-slate-800') : 'text-slate-600 cursor-not-allowed'}">Wybrane firmy</button>
                </div>
                <div id="prodCos" class="${M.mode === 'some' ? '' : 'hidden'} mt-2">
                    <div class="grid grid-cols-2 gap-1.5 max-h-36 overflow-y-auto pr-0.5">${cos.map(c => `
                        <button type="button" data-act="prodCo" data-job="${esc(c.job)}" class="${coBtnCls(M.sel.has(c.job))}">${coBox(M.sel.has(c.job))}<span class="truncate">${esc(c.label)}</span></button>`).join('')}</div>
                    <p id="prodCoCnt" class="text-[11px] text-slate-500 mt-1.5">${M.sel.size ? `Wybrano: ${M.sel.size}` : 'Nie wybrano żadnej firmy'}</p>
                </div>
                ${cos.length ? '' : '<p class="text-[11px] text-slate-500 mt-1.5">Serwer nie przekazał listy firm – produkt jest dostępny dla wszystkich.</p>'}
            </div>
        </div>`,
        onOk: () => {
            const name = $('#prodName').value.trim(), category = $('#prodCat').value.trim(), desc = $('#prodDesc').value.trim(), price = parseInt($('#prodPrice').value, 10), active = $('#prodActive').checked;
            if (name.length < 2) return toast('Podaj nazwę produktu (min. 2 znaki)', 'error'), false;
            if (!price || price < 1 || price > priceMax()) return toast(`Cena musi być z zakresu $1 – ${money(priceMax())}`, 'error'), false;
            const model = isVeh ? ($('#prodModel')?.value || '').trim() : '';
            if (model && !/^[A-Za-z0-9_-]{1,50}$/.test(model)) return toast('Model pojazdu: tylko litery, cyfry, - i _ (max 50 znaków)', 'error'), false;
            const feeRaw = ($('#prodFee')?.value || '').trim();
            const expressFee = feeRaw === '' ? null : parseInt(feeRaw, 10);
            if (feeRaw !== '' && (!Number.isFinite(expressFee) || expressFee < 0 || expressFee > priceMax()))
                return toast(`Dopłata za szybki transport: $0 – ${money(priceMax())}`, 'error'), false;
            const access = M.mode === 'some' ? [...M.sel] : null;
            if (access && !access.length) return toast('Wybierz co najmniej jedną firmę albo zezwól wszystkim', 'error'), false;
            if (of.products.some(x => x !== p && x.name.toLowerCase() === name.toLowerCase())) return toast('Produkt o takiej nazwie już istnieje w ofercie', 'error'), false;
            return modalRequest(o, M, 'bossmenu:saveProduct', { ...(p ? { id: p.id } : {}), name, category, desc, price, active, access,
                model: model || null, expressFee }, 'Nie udało się zapisać produktu', res => {
                const from = p?.price, wasActive = p ? p.active !== false : true, accChanged = p && JSON.stringify(p.access ?? null) !== JSON.stringify(access);
                const saved = { id: p?.id ?? 'p' + Date.now(), name, category, desc, price, active, access, model: model || null, expressFee, ...res.product };
                if (p) Object.assign(p, saved); else of.products.push(saved);
                addHistory(!p ? { type: 'offerChange', action: 'add', name, to: price }
                    : from !== price ? { type: 'offerChange', action: 'price', name, from, to: price }
                    : wasActive !== active ? { type: 'offerChange', action: active ? 'show' : 'hide', name }
                    : accChanged ? { type: 'offerChange', action: 'access', name }
                    : { type: 'offerChange', action: 'edit', name });
                toast(p ? 'Zapisano produkt' : 'Dodano produkt do oferty', 'success');
            });
        }
    };
    openModal(o);
}
function offerToggle(id) {
    const of = shop().offer, p = of?.products.find(x => sameId(x.id, id)); if (!p || SHOP.busy) return;
    const active = p.active === false;
    SHOP.busy = true;
    request('bossmenu:saveProduct', { id: p.id, name: p.name, category: p.category || '', desc: p.desc || '', price: p.price, active,
        access: Array.isArray(p.access) ? p.access : null, model: p.model ?? null, expressFee: p.expressFee ?? null }).then(res => {
        SHOP.busy = false;
        if (!res?.ok) return toast(res?.error || 'Nie udało się zmienić produktu', 'error');
        p.active = active;
        addHistory({ type: 'offerChange', action: active ? 'show' : 'hide', name: p.name });
        toast(active ? `${p.name}: widoczny w ofercie` : `${p.name}: ukryty w ofercie`, 'info');
        refresh();
    });
}
function openProductDeleteModal(id) {
    const of = shop().offer, p = of?.products.find(x => sameId(x.id, id)); if (!p) return;
    const M = { busy: false };
    const o = {
        icon: 'trash', tone: 'brand', title: 'Usunąć produkt z oferty?', ok: 'Usuń', text: `${p.name} · ${money(p.price)}. Złożone wcześniej zamówienia nie zostaną zmienione.`,
        onOk: () => modalRequest(o, M, 'bossmenu:deleteProduct', { id: p.id }, 'Nie udało się usunąć produktu', () => {
            of.products = of.products.filter(x => x !== p);
            addHistory({ type: 'offerChange', action: 'remove', name: p.name, to: p.price });
            toast('Usunięto produkt z oferty', 'warn');
        })
    };
    openModal(o);
}

/* DEV: symulacja drugiej firmy (w grze odpowiada serwer) */
function devShopOrder(id, to) {
    const f = findShopOrder(id); if (!f) return;
    if (f.kind === 'vehicles') return devAdvanceOrder(id, to);
    const { o } = f, total = shopTotal(o, 'goods');
    o.status = to;
    if (to === 'rejected') { o.reason = 'Brak towaru na stanie'; S.funds += total; S.transactions.unshift({ type: 'in', amount: total, by: 'System', label: 'Zwrot za zamówienie', reason: ordNo(o), at: stamp() }); }
    toast(`DEV: ${ORDER_ST[to].label}`, 'info');
}
function devIncomingOrder() {
    const of = shop().offer; const prods = (of?.products || []).filter(p => p.active !== false);
    if (!prods.length) return toast('DEV: dodaj najpierw produkt do oferty', 'error');
    const buyers = [['police', 'Policja LSPD', 'Sierż. Marcin Kot'], ['ems', 'Pogotowie Los Santos', 'Dr Aleksandra Wrona'], ['taxi', 'Taxi Downtown', 'Dorota Lis'], ['gastro', 'Bean Machine Coffee', 'Łukasz Sowa']];
    const b = buyers[Math.floor(Math.random() * buyers.length)], n = 1 + Math.floor(Math.random() * Math.min(3, prods.length));
    const items = [...prods].sort(() => Math.random() - .5).slice(0, n).map(p => ({ id: p.id, name: p.name, price: p.price, qty: 1 + Math.floor(Math.random() * 5) }));
    shop().incoming.unshift({ id: 'zam-' + (4000 + Math.floor(Math.random() * 900) + 100), kind: 'goods', buyer: { job: b[0], label: b[1] }, items,
        total: items.reduce((s, i) => s + i.price * i.qty, 0), by: b[2], at: nowFull(), status: 'pending' });
    toast('DEV: nowe zamówienie od innej firmy', 'info');
}

/* ---------- Ustawienia ---------- */
const SETUI = { tab: 'look' };
const SET_TABS = [
    ['look', 'Wygląd', 'palette'],
    ['notif', 'Powiadomienia', 'bell'],
    ['sound', 'Dźwięki', 'volume'],
    ['desk', 'Pulpit i okna', 'app-window'],
    ['time', 'Czas i data', 'clock']
];
/* suwaki: min/max/krok, jednostka i presety */
const SET_DEF = {
    size: {
        ic: 'arrows-maximize', title: 'Rozmiar ekranu', desc: 'Jaką część ekranu gry zajmuje interfejs.',
        min: 50, max: 95, step: 1, unit: '%', preview: true,
        presets: [[65, 'Mały'], [75, 'Średni'], [85, 'Duży'], [95, 'Maksymalny']]
    },
    scale: {
        ic: 'text-size', title: 'Skala interfejsu', desc: 'Powiększa lub zmniejsza całą zawartość (tekst, przyciski, okna) bez zmiany zajmowanego miejsca.',
        min: 80, max: 130, step: 5, unit: '%',
        presets: [[90, 'Mała'], [100, 'Domyślna'], [110, 'Większa'], [125, 'Duża']]
    },
    idle: {
        ic: 'eye', title: 'Przygaszanie poza interfejsem', desc: 'Gdy kursor jest poza panelem, całość robi się półprzezroczysta, by widać było grę.',
        min: 10, max: 100, step: 5, unit: '%', preview: true,
        presets: [[100, 'Wyłączone'], [70, 'Lekkie'], [50, 'Średnie'], [30, 'Mocne']]
    },
    notifDur: {
        ic: 'hourglass', title: 'Czas wyświetlania', desc: 'Jak długo powiadomienie pozostaje na ekranie.',
        min: 2, max: 10, step: 1, unit: ' s',
        presets: [[2, '2 s'], [3, '3 s'], [5, '5 s'], [8, '8 s']]
    },
    volume: {
        ic: 'volume', title: 'Głośność', desc: 'Głośność dźwięków interfejsu.',
        min: 0, max: 100, step: 5, unit: '%',
        presets: [[0, 'Wyciszone'], [25, 'Cichy'], [50, 'Średni'], [100, 'Głośny']]
    }
};
const SEG_WRAP = 'flex gap-1 p-1 rounded-xl bg-slate-950/50 border border-slate-800';
const PRESET_ON = 'bg-brand text-white shadow shadow-brand/20', PRESET_OFF = 'text-slate-400 hover:text-white hover:bg-slate-700/60';
const SEG_BTN = 'flex-1 min-w-0 px-2 py-1.5 rounded-lg text-[11px] font-bold truncate transition ';
const rngFill = (key, v) => `${((v - SET_DEF[key].min) / (SET_DEF[key].max - SET_DEF[key].min) * 100).toFixed(1)}%`;

/* podgląd: „ekran gry” z zaznaczonym obszarem interfejsu */
const setPreview = key => `
    <div class="relative w-[148px] shrink-0 aspect-video rounded-lg border border-slate-700/70 overflow-hidden bg-gradient-to-br from-slate-700 via-slate-800 to-slate-950">
        <div class="absolute inset-x-0 bottom-0 h-1/4 bg-black/25"></div>
        <div data-prev="${key}" class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 rounded-[5px] border border-brand/60 bg-slate-900 shadow-lg shadow-black/50 flex flex-col overflow-hidden"
            style="${key === 'size' ? `width:${CFG.size}%;height:${CFG.size}%` : `width:78%;height:78%;opacity:${CFG.idle / 100}`}">
            <div class="h-[14%] bg-slate-950/80 flex items-center gap-[3px] px-1.5"><i class="size-[3px] rounded-full bg-brand"></i><i class="size-[3px] rounded-full bg-slate-600"></i><i class="size-[3px] rounded-full bg-slate-600"></i></div>
            <div class="flex-1 grid grid-cols-3 gap-[3px] p-1.5"><i class="rounded-[2px] bg-slate-800"></i><i class="rounded-[2px] bg-slate-800"></i><i class="rounded-[2px] bg-slate-800"></i></div>
        </div>
        ${key === 'idle' ? '<span class="absolute bottom-1 right-1.5 text-[8px] font-bold text-slate-400/80">kursor poza UI</span>' : ''}
    </div>`;

const setHead = (ic, title, desc, right = '') => `
    <div class="flex items-start gap-3">
        <div class="size-10 shrink-0 rounded-xl border flex items-center justify-center ${TONES.brand}">${icon(ic, 'size-5')}</div>
        <div class="min-w-0 flex-1">
            <h3 class="text-sm font-extrabold text-white">${title}</h3>
            <p class="text-[11px] leading-4 text-slate-400 mt-0.5">${desc}</p>
        </div>
        ${right}
    </div>`;
const setBox = (inner, dim = false) => `<section class="rounded-2xl bg-slate-900/70 border border-slate-800 p-4 ${dim ? 'opacity-50' : ''}">${inner}</section>`;

/* karta z suwakiem */
const setCard = (key, dim = false) => {
    const d = SET_DEF[key], v = CFG[key];
    return setBox(`
        ${setHead(d.ic, d.title, d.desc, `<span id="lbl-${key}" class="shrink-0 px-2.5 py-1 rounded-lg bg-slate-950/60 border border-slate-800 text-sm font-extrabold text-white tabular-nums">${v}${d.unit}</span>`)}
        <div class="flex items-center gap-4 mt-4">
            <div class="flex-1 min-w-0">
                <input type="range" min="${d.min}" max="${d.max}" step="${d.step}" value="${v}" data-setting="${key}" class="rng" style="--p:${rngFill(key, v)}">
                <div class="flex justify-between mt-1.5 text-[10px] font-semibold text-slate-500"><span>${d.min}${d.unit}</span><span>${d.max}${d.unit}</span></div>
                <div class="${SEG_WRAP} mt-3">
                    ${d.presets.map(([pv, l]) => `<button data-preset="${key}:${pv}" class="${SEG_BTN}${v === pv ? PRESET_ON : PRESET_OFF}">${l}</button>`).join('')}
                </div>
            </div>
            ${d.preview ? setPreview(key) : ''}
        </div>`, dim);
};
/* karta z przełącznikiem */
const toggleCard = (key, ic, title, desc, extra = '') => {
    const on = !!CFG[key];
    return setBox(`
        ${setHead(ic, title, desc, `
        <button data-toggle="${key}" role="switch" aria-checked="${on}" class="relative w-11 h-6 rounded-full shrink-0 transition ${on ? 'bg-brand' : 'bg-slate-700'}">
            <span class="absolute top-0.5 left-0.5 size-5 rounded-full bg-white shadow transition-transform ${on ? 'translate-x-5' : ''}"></span>
        </button>`)}${extra}`);
};
/* karta z wyborem jednej opcji */
const optCard = (key, ic, title, desc, options, extra = '', dim = false) => setBox(`
    ${setHead(ic, title, desc)}
    <div class="${SEG_WRAP} mt-3">
        ${options.map(([v, l]) => `<button data-opt="${key}:${v}" class="${SEG_BTN}${String(CFG[key]) === String(v) ? PRESET_ON : PRESET_OFF}">${l}</button>`).join('')}
    </div>${extra}`, dim);
const smallBtn = (act, ic, label) => `<button data-act="${act}" class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-[11px] font-bold bg-slate-800 hover:bg-slate-700 text-slate-200 transition">${icon(ic, 'size-3.5')}${label}</button>`;
const setNote = t => `<p class="text-[11px] leading-4 text-slate-500 mt-3">${t}</p>`;

/* odśwież etykiety, suwaki, podgląd i presety bez przebudowy okna (suwak nie traci przeciągania) */
function syncSettings() {
    Object.keys(SET_DEF).forEach(key => {
        const v = CFG[key], d = SET_DEF[key];
        const lbl = $('#lbl-' + key); if (lbl) lbl.textContent = v + d.unit;
        const rng = $(`[data-setting="${key}"]`);
        if (rng) { rng.value = v; rng.style.setProperty('--p', rngFill(key, v)); }
        const pv = $(`[data-prev="${key}"]`);
        if (pv) { if (key === 'size') { pv.style.width = pv.style.height = v + '%'; } else pv.style.opacity = v / 100; }
        $$(`[data-preset^="${key}:"]`).forEach(b => {
            const on = Number(b.dataset.preset.split(':')[1]) === v;
            b.className = SEG_BTN + (on ? PRESET_ON : PRESET_OFF);
        });
    });
}
/* skutki zmiany ustawienia */
function applySetting(key) {
    if (key === 'size' || key === 'scale') { applyScreen(); clampWindows(); }
    else if (key === 'anim') applyAnim();
    else if (key === 'notifPos') { applyNotifPos(); toast('Tutaj pojawią się powiadomienia', 'info', true); }
    else if (key === 'timeFmt' || key === 'dateFmt') { tick(); refresh(); }
    else if (key === 'remember') saveLayout();
    else if (key === 'sound' && CFG.sound) sfx('success');
}

function appSettings() {
    const head = t => `<div class="px-1 text-[11px] font-extrabold uppercase tracking-wide text-slate-500">${t}</div>`;
    let body = '';
    if (SETUI.tab === 'look') body = `${head('Wygląd interfejsu')}${setCard('size')}${setCard('scale')}${setCard('idle')}`;
    else if (SETUI.tab === 'notif') {
        const off = CFG.notif === 'off';
        body = `${head('Powiadomienia')}
        ${optCard('notif', 'bell', 'Powiadomienia', 'Które komunikaty pokazywać po wykonaniu akcji. Błędy i ostrzeżenia warto zostawić zawsze.',
            [['all', 'Wszystkie'], ['errors', 'Tylko błędy i ostrzeżenia'], ['off', 'Wyłączone']],
            `<div class="flex justify-end mt-3">${smallBtn('testToast', 'player-play', 'Pokaż przykład')}</div>`)}
        ${setCard('notifDur', off)}
        ${optCard('notifPos', 'layout-board', 'Miejsce na ekranie', 'W którym rogu interfejsu pojawiają się powiadomienia.',
            [['br', 'Prawy dół'], ['bl', 'Lewy dół'], ['tr', 'Prawa góra'], ['tl', 'Lewa góra']], '', off)}`;
    } else if (SETUI.tab === 'sound') {
        body = `${head('Dźwięki interfejsu')}
        ${toggleCard('sound', 'volume', 'Dźwięki interfejsu', 'Kliknięcia, otwieranie i zamykanie okien oraz sygnały powiadomień (sukces, ostrzeżenie, błąd).',
            `<div class="flex justify-end mt-3">${smallBtn('testSound', 'player-play', 'Odtwórz próbkę')}</div>`)}
        ${setCard('volume', !CFG.sound)}`;
    } else if (SETUI.tab === 'desk') {
        const startSel = selectHtml({
            id: 'startAppSel', value: CFG.startApp,
            options: [{ value: 'none', label: 'Żadna (pusty pulpit)' }, ...Object.entries(APPS).map(([id, a]) => ({ value: id, label: a.label }))],
            onChange: v => { CFG.startApp = v; saveCfg(); }
        });
        body = `${head('Pulpit i okna')}
        ${toggleCard('anim', 'sparkles', 'Animacje', 'Płynne otwieranie okien, menu i powiadomień. Wyłącz na słabszym komputerze.')}
        ${toggleCard('remember', 'layout-board', 'Zapamiętuj układ okien', 'Położenie, rozmiar i otwarte okna wracają po ponownym uruchomieniu gry.',
            `<div class="flex justify-end mt-3">${smallBtn('clearLayout', 'refresh', 'Wyczyść zapamiętany układ')}</div>`)}
        ${setBox(`${setHead('rocket', 'Aplikacja na starcie', 'Którą aplikację otworzyć po otwarciu interfejsu.')}<div class="mt-3">${startSel}</div>
            ${setNote('Gdy zapamiętywanie układu jest włączone, a poprzednio były otwarte okna, wracają one zamiast aplikacji startowej.')}`)}`;
    } else {
        const now = new Date();
        body = `${head('Czas i data')}
        ${optCard('timeFmt', 'clock', 'Format czasu', 'Zegar na pasku zadań, widżecie i przy wpisach.', [['24', '24-godzinny (14:30)'], ['12', '12-godzinny (2:30 PM)']])}
        ${optCard('dateFmt', 'calendar', 'Format daty', 'Data na pasku zadań i przy wpisach, transakcjach oraz zatrudnieniu.',
            [['dmy', 'DD.MM.RRRR'], ['ymd', 'RRRR-MM-DD'], ['mdy', 'MM/DD/RRRR']],
            setNote(`Podgląd: <span class="font-bold text-slate-300">${esc(fmtDate(now))} · ${esc(fmtClock(now))}</span> · wpis z 27.09.2026 20:05 wygląda jak <span class="font-bold text-slate-300">${esc(fmtAt('27.09.2026 20:05'))}</span>`))}`;
    }
    const nav = SET_TABS.map(([id, label, ic]) => `
        <button data-set-tab="${id}" class="w-full flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-xs font-bold text-left transition ${SETUI.tab === id ? 'bg-brand/10 text-brand border border-brand/30' : 'text-slate-300 hover:bg-slate-800 border border-transparent'}">
            ${icon(ic, 'size-4')}<span class="truncate">${label}</span>
        </button>`).join('');
    return `
    <div class="h-full flex gap-4 min-h-0">
        <nav class="w-[176px] shrink-0 space-y-1">${nav}
            <div class="pt-3 mt-2 border-t border-slate-800/70">
                <button data-act="resetSettings" class="w-full flex items-center gap-2 px-3 py-2 rounded-xl text-[11px] font-bold text-slate-400 hover:text-white hover:bg-slate-800 transition">${icon('refresh', 'size-3.5')}Przywróć domyślne</button>
                <p class="flex items-start gap-1.5 px-3 mt-2 text-[10px] leading-4 text-slate-500"><span class="shrink-0 mt-0.5">${icon('device-floppy', 'size-3.5')}</span>Zmiany zapisują się automatycznie na tym komputerze.</p>
            </div>
        </nav>
        <div class="flex-1 min-w-0 min-h-0 overflow-y-auto space-y-3 pr-1">${body}</div>
    </div>`;
}

/* ---------- Rejestr aplikacji ---------- */
const APPS = {
    employees: { label: 'Pracownicy', icon: 'users', tone: 'brand', size: [1120, 700], render: appEmployees },
    faction: { label: 'Zarządzanie frakcją', icon: 'building-community', tone: 'amber', size: [980, 640], render: appFaction },
    garage: { label: 'Garaż', icon: 'garage', tone: 'sky', size: [1020, 640], render: appGarage },
    orders: { label: 'Zamówienia', icon: 'package', tone: 'emerald', size: [1080, 660], render: appOrders },
    history: { label: 'Historia zmian', icon: 'history', tone: 'slate', size: [820, 540], render: appHistory },
    settings: { label: 'Ustawienia', icon: 'settings', tone: 'slate', size: [840, 580], render: appSettings }
};

/* =========================================================
   POWŁOKA SYSTEMU (style, pulpit, pasek zadań)
   ========================================================= */
function injectStyles() {
    const st = document.createElement('style');
    st.textContent = `
        /* === NUI (CEF) =====================================================
           Warstwa strony MUSI byc jawnie przezroczysta - inaczej CEF maluje
           czarna warstwe zastepcza na calym ekranie (czarny ekran po starcie).
           Dodatkowo: ukrywanie ekranu dziala niezaleznie od Tailwinda. */
        /* color-scheme: dark na :root = czarny canvas CEF nad gra (patrz index.html). */
        :root { color-scheme: normal !important }
        html, body { margin: 0; padding: 0; background: transparent !important; background-color: transparent !important }
        #screen { background: transparent }
        #screen[hidden] { display: none !important }
        /* BEZ backdrop-filter! W FiveM CEF nie zna widoku gry pod NUI i rysuje
           czarny prostokat zamiast rozmycia (patrz komentarze przy powierzchniach). */
        ::-webkit-scrollbar { width: 6px; height: 6px }
        ::-webkit-scrollbar-thumb { background: #334155; border-radius: 9999px }
        ::-webkit-scrollbar-track { background: transparent }
        input[type=number]::-webkit-inner-spin-button { -webkit-appearance: none }
        input { user-select: text }
        .rng { -webkit-appearance: none; appearance: none; width: 100%; height: 6px; border-radius: 9999px; outline: none; cursor: pointer; display: block;
               background: linear-gradient(to right, #fc4444 var(--p, 50%), #1e293b var(--p, 50%)) }
        .rng::-webkit-slider-thumb { -webkit-appearance: none; width: 18px; height: 18px; border-radius: 50%; background: #fff; border: 4px solid #fc4444; box-shadow: 0 0 0 4px rgba(252,68,68,.15), 0 2px 6px rgba(0,0,0,.5); transition: box-shadow .12s }
        .rng:hover::-webkit-slider-thumb, .rng:active::-webkit-slider-thumb { box-shadow: 0 0 0 6px rgba(252,68,68,.25), 0 2px 6px rgba(0,0,0,.5) }
        .rng::-moz-range-thumb { width: 10px; height: 10px; border-radius: 50%; background: #fff; border: 4px solid #fc4444 }
        .rng::-moz-range-track { background: transparent }
        .note-ed .ql-container { font: inherit; height: 100% }
        .note-ed .ql-editor { height: 100%; overflow-y: auto; padding: 10px 14px; font-size: 13px; line-height: 1.6; color: #e2e8f0; tab-size: 4 }
        .note-ed .ql-editor, .note-ed .ql-editor * { user-select: text }
        .note-ed .ql-editor.ql-blank::before { color: #64748b; font-style: normal; left: 14px; right: 14px }
        .note-ed .ql-editor p, .note-ed .ql-editor ul, .note-ed .ql-editor ol, .note-ed .ql-editor blockquote { margin: 0 0 .35em }
        .note-ed .ql-editor h2 { font-size: 16px; font-weight: 800; color: #fff; margin: .5em 0 .25em; letter-spacing: -.01em }
        .note-ed .ql-editor strong { color: #fff; font-weight: 800 }
        .note-ed .ql-editor blockquote { border-left: 3px solid #fc4444; background: rgba(252,68,68,.06); padding: 4px 12px; border-radius: 0 8px 8px 0; color: #cbd5e1; margin: .4em 0 }
        .note-ed .ql-editor ol, .note-ed .ql-editor ul { padding-left: 1.2em }
        .note-ed .ql-editor li[data-list=bullet] > .ql-ui:before { color: #fc4444 }
        .note-ed .ql-editor li[data-list=ordered] > .ql-ui:before { color: #94a3b8; font-weight: 700 }
        .note-ed .ql-editor ::selection { background: rgba(252,68,68,.35) }
        .note-tb button { width: 30px; height: 30px; display: flex; align-items: center; justify-content: center; border-radius: 8px; color: #94a3b8; transition: background .12s, color .12s }
        .note-tb button:hover { background: #1e293b; color: #fff }
        .note-tb button.ql-active { background: rgba(252,68,68,.15); color: #fc4444 }
        .no-anim, .no-anim * { animation: none !important; transition: none !important }
        .fade-in { animation: fade .18s ease-out both }
        @keyframes fade { from { opacity: 0; transform: translateY(4px) } to { opacity: 1; transform: none } }
        .win-in { animation: winIn .16s ease-out both }
        @keyframes winIn { from { opacity: 0; transform: scale(.96) translateY(6px) } to { opacity: 1; transform: none } }
        .pop-in { animation: popIn .16s ease-out both; transform-origin: bottom center }
        @keyframes popIn { from { opacity: 0; transform: translateY(10px) scale(.98) } to { opacity: 1; transform: none } }
    `;
    document.head.appendChild(st);
}

/* rozmiar ekranu + przygasanie */
function applyScreen() {
    const os = $('#os'); if (!os) return;
    const k = CFG.scale / 100;      // zawartość skalowana transformacją; rozmiar wizualny pozostaje taki, jak w „Rozmiarze ekranu”
    os.style.width = `calc(min(${CFG.size}vw, 1700px) / ${k})`;
    os.style.height = `calc(min(${CFG.size}vh, 960px) / ${k})`;
    os.style.transform = k === 1 ? '' : `scale(${k})`;
}
function applyAnim() { $('#os')?.classList.toggle('no-anim', !CFG.anim); }
const TOAST_POS = { br: ['auto', '56px', 'auto', '12px'], bl: ['auto', '56px', '12px', 'auto'], tr: ['12px', 'auto', 'auto', '12px'], tl: ['12px', 'auto', '12px', 'auto'] };   // top, bottom, left, right
function applyNotifPos() {
    const el = $('#toasts'); if (!el) return;
    const [t, b, l, r] = TOAST_POS[CFG.notifPos] || TOAST_POS.br;
    Object.assign(el.style, { top: t, bottom: b, left: l, right: r });
}
function syncFade() {
    const os = $('#os'); if (!os) return;
    const hold = os.matches(':hover') || UI.dragging || modalOpen();
    os.style.opacity = hold ? 1 : CFG.idle / 100;
}

/* logo firmy na tapecie: <job.name>.png (np. mechanic -> mechanic.png) */
const LOGO_PATH = job => `logos/${job}.png`;      // html/logos/<job>.png (np. mechanic -> logos/mechanic.png)
const WATERMARK_OPACITY = 0.04;             // tyle samo co poprzedni napis (white/[0.04])

function renderWatermark() {
    const wm = $('#watermark'); if (!wm) return;
    const src = LOGO_PATH(S.job.name);
    if (wm.dataset.src === src) return;     // bez przeładowania, jeśli logo się nie zmieniło
    wm.dataset.src = src; wm.innerHTML = '';
    const img = new Image();
    img.alt = ''; img.draggable = false;
    img.className = 'max-h-[45%] max-w-[35%] object-contain';
    img.style.opacity = WATERMARK_OPACITY;
    img.onerror = () => img.remove();       // brak pliku = pusta tapeta
    img.src = src;
    wm.appendChild(img);
}

function buildShell() {
    document.body.className = 'bg-transparent text-slate-100 h-screen overflow-hidden font-sans antialiased selection:bg-brand selection:text-white select-none';
    document.body.innerHTML = `
    <div id="screen"${IN_GAME ? ' hidden' : ''} class="fixed inset-0 flex items-center justify-center pointer-events-none">
    <div id="os" class="pointer-events-auto relative overflow-hidden rounded-2xl bg-base border border-slate-700 ring-4 ring-black/70 shadow-2xl shadow-black/70"
         style="transition: opacity .25s ease">

        <!-- tapeta -->
        <div class="absolute inset-0 bg-base"></div>
        <div class="absolute inset-0" style="background:
            radial-gradient(900px 520px at 50% -10%, rgba(252,68,68,.17), transparent 60%),
            radial-gradient(700px 500px at 0% 100%, rgba(252,68,68,.08), transparent 60%),
            radial-gradient(600px 400px at 100% 100%, rgba(14,165,233,.06), transparent 60%)"></div>
        <div class="absolute inset-0" style="background-image:
            linear-gradient(rgba(255,255,255,.025) 1px, transparent 1px),
            linear-gradient(90deg, rgba(255,255,255,.025) 1px, transparent 1px);
            background-size: 48px 48px;
            -webkit-mask-image: radial-gradient(ellipse at center, #000 25%, transparent 75%);
            mask-image: radial-gradient(ellipse at center, #000 25%, transparent 75%)"></div>
        <div id="watermark" class="absolute inset-0 bottom-12 flex items-center justify-center pointer-events-none"></div>

        <!-- pulpit -->
        <div id="desktop" class="absolute inset-x-0 top-0 bottom-12 overflow-hidden">
            <div id="icons" class="absolute top-0 left-0 bottom-0 p-3 flex flex-col flex-wrap content-start gap-1"></div>
            <div id="widgets" class="absolute top-0 right-0 p-3 hidden md:block"></div>
            <div id="windows" class="absolute inset-0 pointer-events-none"></div>
        </div>

        <!-- menu start -->
        <div id="startmenu" class="hidden absolute bottom-14 left-1/2 -translate-x-1/2 z-[5000] w-[480px] max-w-[96vw]"></div>

        <!-- pasek zadań -->
        <footer id="taskbar" class="absolute inset-x-0 bottom-0 h-12 z-[4000] flex items-center bg-slate-950/95 border-t border-slate-800">
            <div class="flex-1 min-w-0 flex items-center px-3">
                <div id="tbJob" class="flex items-center"></div>
            </div>
            <div id="tbApps" class="flex items-center gap-1"></div>
            <div class="flex-1 min-w-0 flex items-center justify-end h-full">
                <div id="tbChips" class="hidden sm:flex items-center gap-1 mr-1"></div>
                <div class="px-3 py-1 rounded-lg text-right leading-tight hover:bg-white/5 transition">
                    <p id="tbTime" class="text-xs font-bold text-white">--:--</p>
                    <p id="tbDate" class="text-[10px] text-slate-400">--.--.----</p>
                </div>
                <button data-show-desktop title="Pokaż pulpit" class="h-full w-2.5 border-l border-slate-800 hover:bg-white/10 transition"></button>
            </div>
        </footer>

        <div id="modalRoot"></div>
        <div id="toasts" class="absolute z-[6000] space-y-2"></div>
    </div>
    </div>`;
}

/* ---------- Ikony pulpitu ---------- */
function renderIcons() {
    $('#icons').innerHTML = Object.entries(APPS).map(([id, a]) => `
        <div data-icon-app="${id}" class="w-[92px] p-2 rounded-xl flex flex-col items-center gap-1.5 cursor-default border border-transparent transition">
            <div class="size-12 rounded-2xl border flex items-center justify-center ${TONES[a.tone]}">${icon(a.icon, 'size-6')}</div>
            <span class="text-[11px] font-bold text-center text-slate-200 leading-tight">${a.label}</span>
        </div>`).join('');
    selectIcon(UI.sel);
}
function selectIcon(id) {
    UI.sel = id;
    $$('[data-icon-app]').forEach(el => {
        const on = el.dataset.iconApp === id;
        el.classList.toggle('bg-white/10', on); el.classList.toggle('border-white/10', on);
        el.classList.toggle('hover:bg-white/5', !on);
    });
}

/* ---------- Widgety ---------- */
/* ---------- Widget systemowy ----------
   Informacje do podglądu, wybierane przez gracza (Edytuj widget). Nie są klikalne i nigdzie nie przenoszą. */
const WIDGET_MAX = 6;
const countBy = st => S.employees.filter(e => statusOf(e) === st).length;
const WIDGETS = [
    { id: 'employees', i: 'users', t: 'brand', l: 'Pracownicy', v: () => S.employees.length },
    { id: 'duty', i: 'user-check', t: 'emerald', l: 'Na służbie', v: () => countBy('duty') },
    { id: 'break', i: 'clock', t: 'amber', l: 'Na przerwie', v: () => countBy('break') },
    { id: 'off', i: 'user-minus', t: 'slate', l: 'Poza służbą', v: () => countBy('off') },
    { id: 'funds', i: 'wallet', t: 'brand', l: 'Saldo firmy', v: () => money(S.funds) },
    { id: 'payout', i: 'coins', t: 'amber', l: 'Do wypłaty', v: () => money(S.employees.reduce((a, e) => a + wageOf(e), 0)) },
    { id: 'hours', i: 'briefcase', t: 'sky', l: 'Godziny pracy (suma)', v: () => fmtHours(S.employees.reduce((a, e) => a + (e.hoursWeek || 0), 0)) },
    { id: 'myHours', i: 'clock-hour-4', t: 'sky', l: 'Mój czas pracy', v: () => fmtHours(getEmp(S.me.ssn)?.hoursWeek || 0) },
    { id: 'vehicles', i: 'car', t: 'sky', l: 'Pojazdy firmy', v: () => S.vehicles.length },
    { id: 'vehFree', i: 'car', t: 'emerald', l: 'Wolne pojazdy', v: () => S.vehicles.filter(v => !v.assignedTo).length },
    { id: 'ordersOut', i: 'package', t: 'emerald', l: 'Moje zamówienia w toku', v: () => outList().filter(x => x.o.status === 'pending' || x.o.status === 'accepted').length },
    { id: 'ordersIn', i: 'inbox', t: 'amber', l: 'Zamówienia do obsługi', v: () => shop().incoming.filter(o => o.status === 'pending').length, when: () => !!shop().offer || shop().incoming.length > 0 }
];
const widgetAvail = () => WIDGETS.filter(w => !w.when || w.when());
const widgetPinned = () => (CFG.widgets || []).map(id => widgetAvail().find(w => w.id === id)).filter(Boolean);
function renderWidgets() {
    const rows = widgetPinned();
    $('#widgets').innerHTML = `
    <div class="w-56 rounded-2xl bg-slate-900/80 border border-slate-800 p-2">
        ${rows.length ? rows.map(r => `
        <div class="pointer-events-none select-none flex items-center gap-3 p-2 rounded-xl">
            <div class="size-9 shrink-0 rounded-lg border flex items-center justify-center ${TONES[r.t]}">${icon(r.i, 'size-4')}</div>
            <div class="min-w-0">
                <p class="text-[10px] font-semibold text-slate-400 uppercase tracking-wide truncate">${r.l}</p>
                <p class="font-extrabold text-white break-all leading-5" style="font-size:${valFs(r.v())}px">${r.v()}</p>
            </div>
        </div>`).join('') : '<p class="px-3 py-6 text-center text-[11px] leading-4 text-slate-500">Brak przypiętych informacji.</p>'}
        <button data-act="widgetEdit" class="w-full ${rows.length ? 'mt-1' : ''} flex items-center justify-center gap-1.5 px-2 py-1.5 rounded-lg text-[11px] font-bold text-slate-500 hover:text-white hover:bg-white/5 transition">${icon('edit', 'size-3.5')}Edytuj widget</button>
    </div>`;
    tick();
}
function openWidgetModal() {
    openModal({
        icon: 'layout-board', tone: 'brand', live: true, noOk: true, wide: true, cancel: 'Gotowe', title: 'Edytuj widget',
        get text() { return `Przypięte: ${widgetPinned().length} / ${WIDGET_MAX} · informacje widać na pulpicie, nie są klikalne`; },
        body: () => {
            const pins = widgetPinned().map(w => w.id), full = pins.length >= WIDGET_MAX;
            return `<div class="space-y-3">
            <div class="grid grid-cols-2 gap-2 max-h-[300px] overflow-y-auto pr-0.5">${widgetAvail().map(w => {
                const on = pins.includes(w.id), lock = full && !on;
                return `<button data-act="widgetPin" data-id="${w.id}" ${lock ? 'disabled' : ''} class="flex items-center gap-3 p-2.5 rounded-xl border text-left transition ${on ? 'bg-brand/5 border-brand/40' : 'bg-slate-950/40 border-slate-800'} ${lock ? 'opacity-40 cursor-not-allowed' : on ? '' : 'hover:border-slate-700'}">
                    <div class="size-9 shrink-0 rounded-lg border flex items-center justify-center ${TONES[w.t]}">${icon(w.i, 'size-4')}</div>
                    <div class="min-w-0 flex-1"><p class="text-xs font-bold text-white truncate">${w.l}</p><p class="text-[11px] font-semibold text-slate-500 truncate">${w.v()}</p></div>
                    <span class="size-5 shrink-0 rounded-md border flex items-center justify-center ${on ? 'bg-brand border-brand text-white' : 'border-slate-600'}">${on ? icon('check', 'size-3.5') : ''}</span>
                </button>`;
            }).join('')}</div>
            <div class="flex items-center justify-between text-[11px] text-slate-500">
                <span>${full ? `Osiągnięto limit ${WIDGET_MAX} pozycji – odznacz coś, aby dodać kolejną.` : 'Kliknij kafelek, aby przypiąć lub odpiąć informację.'}</span>
                <button data-act="widgetReset" class="font-bold text-slate-400 hover:text-white transition whitespace-nowrap">Przywróć domyślne</button>
            </div></div>`;
        }
    });
}

/* ---------- Pasek zadań ---------- */
function saveLayout() {
    if (!CFG.remember || !LAYOUT_READY || UI.restoring) return;
    Object.values(wins).forEach(w => { LAYOUT.geo[w.app] = { x: Math.round(w.x), y: Math.round(w.y), w: Math.round(w.w), h: Math.round(w.h), max: !!w.max }; });
    LAYOUT.open = Object.values(wins).sort((a, b) => a.z - b.z).map(w => ({ id: w.app, min: !!w.min }));
    try { localStorage.setItem(LAYOUT_KEY, JSON.stringify(LAYOUT)); } catch (e) { }
}
const touchLayout = () => { LAYOUT_READY = true; saveLayout(); };
function startWindows() {
    const saved = CFG.remember ? (LAYOUT.open || []).filter(o => APPS[o.id]) : [];
    if (saved.length) {
        UI.restoring = true;
        saved.forEach(o => openApp(o.id));
        saved.forEach(o => { if (o.min) minimizeWin(o.id); });
        UI.restoring = false;
        const top = topWindow(); if (top) focusWin(top);
    } else if (APPS[CFG.startApp]) openApp(CFG.startApp);
    LAYOUT_READY = true; saveLayout();
}
function renderTaskbar() {
    saveLayout();

    $('#tbJob').innerHTML = `<button data-act="power" title="Zamknij (Esc)" class="p-2 rounded-lg text-slate-400 hover:text-white hover:bg-brand transition">${icon('power', 'size-4')}</button>`;

    const appBtn = id => {
        const a = APPS[id], w = wins[id];
        const act = w && !w.min && UI.active === id;
        return `
        <button data-task="${id}" title="${a.label}"
            class="relative size-10 rounded-lg flex items-center justify-center transition ${act ? 'bg-white/10' : 'hover:bg-white/5'}">
            <span class="size-7 rounded-md border flex items-center justify-center ${TONES[a.tone]}">${icon(a.icon, 'size-4')}</span>
            ${w ? `<span class="absolute bottom-0.5 left-1/2 -translate-x-1/2 h-1 rounded-full transition-all ${act ? 'w-5 bg-brand' : 'w-1.5 bg-slate-500'}"></span>` : ''}
        </button>`;
    };
    $('#tbApps').innerHTML = `
        ${Object.keys(APPS).map(appBtn).join('')}`;

    $('#tbChips').innerHTML = `
        <div data-open="settings" title="Ustawienia" class="p-2 rounded-lg text-slate-400 hover:text-white hover:bg-white/5 transition">${icon('settings', 'size-4')}</div>`;
}

function tick() {
    const d = new Date();
    const set = (id, v) => { const el = $('#' + id); if (el) el.textContent = v; };
    const time = fmtClock(d);
    set('tbTime', time); set('wClock', time);
    set('tbDate', fmtDate(d));
    set('wDate', d.toLocaleDateString('pl-PL', { weekday: 'long', day: 'numeric', month: 'long' }));
}

/* ---------- Menu Start ---------- */
function renderStart() {
    $('#startmenu').innerHTML = `
    <div class="pop-in rounded-2xl bg-slate-900 border border-slate-800 shadow-2xl shadow-black/60 overflow-hidden">
        <div class="p-4">
            <div class="relative">
                <span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500">${icon('search', 'size-4')}</span>
                <input id="startSearch" value="${esc(UI.startQuery)}" placeholder="Wyszukaj aplikację…" autocomplete="off"
                    class="w-full bg-slate-950/60 border border-slate-800 rounded-xl pl-9 pr-3 py-2.5 text-sm text-white placeholder-slate-500 focus:border-brand/50 outline-none">
            </div>
            <p class="text-[11px] font-bold uppercase tracking-wide text-slate-500 mt-4 mb-2 px-1">Aplikacje</p>
            <div id="startGrid" class="grid grid-cols-3 gap-1.5"></div>
        </div>
        <div class="flex items-center gap-3 px-4 py-3 bg-slate-950/60 border-t border-slate-800">
            <div class="size-9 rounded-lg bg-brand text-white font-extrabold text-xs flex items-center justify-center">${esc(initials(fullName(S.me)))}</div>
            <div class="flex-1 min-w-0">
                <p class="text-xs font-bold text-white truncate">${esc(fullName(S.me))}</p>
                <p class="text-[11px] text-brand font-semibold truncate">${esc(gradeName(S.me.grade))} · ${esc(S.job.label)}</p>
            </div>
            <button data-act="power" title="Zamknij system" class="p-2.5 rounded-xl text-slate-400 hover:text-white hover:bg-brand/90 transition flex items-center justify-center">${icon('power', 'size-5')}</button>
        </div>
    </div>`;
    renderStartGrid();
}
function renderStartGrid() {
    const q = UI.startQuery.trim().toLowerCase();
    const list = Object.entries(APPS).filter(([, a]) => !q || a.label.toLowerCase().includes(q));
    $('#startGrid').innerHTML = list.map(([id, a]) => `
        <button data-open="${id}" class="flex flex-col items-center gap-2 p-3 rounded-xl hover:bg-white/5 transition">
            <span class="size-11 rounded-xl border flex items-center justify-center ${TONES[a.tone]}">${icon(a.icon, 'size-5')}</span>
            <span class="text-[11px] font-bold text-slate-200 text-center leading-tight">${a.label}</span>
        </button>`).join('') || `<p class="col-span-3 text-center text-xs text-slate-500 py-6">Nie znaleziono aplikacji.</p>`;
}
function toggleStart(force) {
    UI.start = force === undefined ? !UI.start : force;
    const el = $('#startmenu');
    el.classList.toggle('hidden', !UI.start);
    if (UI.start) { UI.startQuery = ''; renderStart(); setTimeout(() => $('#startSearch')?.focus(), 30); }
    renderTaskbar();
}

/* =========================================================
   OKNA
   ========================================================= */
const deskRect = () => { const d = $('#desktop'); return { width: d.offsetWidth, height: d.offsetHeight }; };   // rozmiar układu (bez skali)

function windowFrame(id) {
    const a = APPS[id];
    const ctl = (act, ic, extra = 'hover:bg-white/10') =>
        `<button data-win-act="${act}" data-win="${id}" class="w-9 h-8 rounded-md flex items-center justify-center text-slate-400 hover:text-white transition ${extra}">${icon(ic, 'size-4')}</button>`;
    return `
        <div data-drag class="h-10 shrink-0 flex items-center gap-2 pl-3 pr-1.5 bg-slate-950/70 border-b border-slate-800">
            <span class="size-6 rounded-md border flex items-center justify-center ${TONES[a.tone]}">${icon(a.icon, 'size-3.5')}</span>
            <span class="flex-1 min-w-0 truncate text-xs font-bold text-slate-200">${a.label}</span>
            ${ctl('min', 'minus')}${ctl('max', 'square')}${ctl('close', 'x', 'hover:!bg-brand')}
        </div>
        <div class="body flex-1 min-h-0 overflow-y-auto p-4"></div>
        <div data-resize class="absolute right-0 bottom-0 size-4 cursor-se-resize"></div>`;
}

function applyGeom(w) {
    const s = w.el.style;
    if (w.max) { s.left = '0px'; s.top = '0px'; s.width = '100%'; s.height = '100%'; }
    else { s.left = w.x + 'px'; s.top = w.y + 'px'; s.width = w.w + 'px'; s.height = w.h + 'px'; }
    s.zIndex = w.z;
    w.el.classList.toggle('rounded-xl', !w.max);
    w.el.classList.toggle('rounded-none', w.max);
    const mb = w.el.querySelector('[data-win-act=max]');
    if (mb) mb.innerHTML = icon(w.max ? 'copy' : 'square', 'size-4');
    const bd = w.el.querySelector('.body'); if (bd) fitLists(bd);      // dopasuj listy do nowej wysokości
}

function renderWin(id) {
    const w = wins[id]; if (!w) return;
    const body = w.el.querySelector('.body');
    const top = body.scrollTop;
    body.innerHTML = APPS[w.app].render();
    fitLists(body); scheduleFit();
    body.scrollTop = top;
}

function openApp(id) {
    toggleStart(false);
    let w = wins[id];
    if (!w) {
        const d = deskRect(), n = Object.keys(wins).length;
        const ww = Math.min(APPS[id].size[0], d.width - 16), hh = Math.min(APPS[id].size[1], d.height - 16);
        w = wins[id] = {
            app: id, w: ww, h: hh, z: ++UI.z, min: false, max: false,
            x: Math.max(8, Math.min(108 + n * 28, d.width - ww - 8)),
            y: Math.max(8, Math.min(16 + n * 28, d.height - hh - 8))
        };
        const g = CFG.remember && LAYOUT.geo[id];      // zapamiętane położenie i rozmiar
        if (g) {
            w.w = Math.max(320, Math.min(g.w, d.width)); w.h = Math.max(240, Math.min(g.h, d.height));
            w.x = Math.max(0, Math.min(g.x, d.width - w.w)); w.y = Math.max(0, Math.min(g.y, d.height - w.h));
            w.max = !!g.max;
        }
        if (!UI.restoring) sfx('open');
        w.el = document.createElement('div');
        w.el.dataset.win = id;
        w.el.className = 'win win-in pointer-events-auto absolute flex flex-col overflow-hidden border border-slate-800 bg-slate-900 shadow-2xl shadow-black/60';
        w.el.innerHTML = windowFrame(id);
        $('#windows').appendChild(w.el);
        applyGeom(w); renderWin(id); if (!UI.restoring) touchLayout();
    } else if (w.min) {
        if (!UI.restoring) sfx('open');
        w.min = false; w.el.style.display = ''; w.el.classList.remove('win-in'); void w.el.offsetWidth; w.el.classList.add('win-in');
    }
    focusWin(id);
}

function focusWin(id) {
    const w = wins[id]; if (!w) return;
    UI.active = id; w.z = ++UI.z; w.el.style.zIndex = w.z;
    $$('.win').forEach(el => {
        const on = el.dataset.win === id;
        el.classList.toggle('border-slate-600', on); el.classList.toggle('border-slate-800', !on);
        el.firstElementChild.classList.toggle('opacity-60', !on);
    });
    renderTaskbar();
}

function topWindow() {
    return Object.values(wins).filter(w => !w.min).sort((a, b) => b.z - a.z)[0]?.app || null;
}
function minimizeWin(id) {
    const w = wins[id]; if (!w) return;
    w.min = true; w.el.style.display = 'none';
    if (UI.active === id) { UI.active = topWindow(); if (UI.active) focusWin(UI.active); }
    renderTaskbar();
}
function closeWin(id) {
    const w = wins[id]; if (!w) return;
    sfx('close'); w.el.remove(); delete wins[id]; touchLayout();
    if (UI.active === id) { UI.active = topWindow(); if (UI.active) focusWin(UI.active); }
    renderTaskbar();
}
function toggleMax(id) {
    const w = wins[id]; if (!w) return;
    w.max = !w.max; applyGeom(w); focusWin(id); touchLayout();
}

/* ---------- Przeciąganie / zmiana rozmiaru ---------- */
function dragStart(e, w, mode) {
    if (w.max || e.button !== 0) return;
    e.preventDefault();
    UI.dragging = true;
    const sx = e.clientX, sy = e.clientY, ox = w.x, oy = w.y, ow = w.w, oh = w.h, d = deskRect();
    const move = ev => {
        const k = CFG.scale / 100, dx = (ev.clientX - sx) / k, dy = (ev.clientY - sy) / k;
        if (mode === 'move') {
            w.x = Math.max(120 - w.w, Math.min(ox + dx, d.width - 120));
            w.y = Math.max(0, Math.min(oy + dy, d.height - 40));
        } else {
            w.w = Math.max(420, Math.min(ow + dx, d.width - w.x));
            w.h = Math.max(300, Math.min(oh + dy, d.height - w.y));
        }
        applyGeom(w);
    };
    const up = () => { removeEventListener('pointermove', move); removeEventListener('pointerup', up); document.body.style.cursor = ''; UI.dragging = false; syncFade(); touchLayout(); };
    document.body.style.cursor = mode === 'move' ? 'default' : 'se-resize';
    addEventListener('pointermove', move); addEventListener('pointerup', up);
}

function clampWindows() {
    const d = deskRect();
    Object.values(wins).forEach(w => {
        w.w = Math.min(w.w, d.width); w.h = Math.min(w.h, d.height);
        w.x = Math.max(0, Math.min(w.x, d.width - w.w)); w.y = Math.max(0, Math.min(w.y, d.height - w.h));
        applyGeom(w);
    });
}

/* =========================================================
   AKCJE
   ========================================================= */
function refresh() {
    Object.keys(wins).forEach(renderWin);
    renderWidgets(); renderTaskbar(); renderWatermark();
    if (UI.start) renderStart();
    if (MODAL?.live) renderModal();
}

function act(type, el) {
    const emp = S.employees.find(e => e.ssn === el.dataset.ssn);

    switch (type) {
        /* nawigacja w aplikacji Pracownicy */
        case 'openProfile': EMP.view = 'profile'; EMP.ssn = el.dataset.ssn; EMP.off = { plus: 0, commend: 0, promo: 0 }; return navEmp();
        case 'backToList': EMP.view = 'list'; return navEmp();
        case 'empTab': EMP.empTab = el.dataset.v === 'rel' ? 'rel' : 'own'; return navEmp();
        case 'empRel': EMP.empTab = 'rel'; EMP.relJob = el.dataset.job; return navEmp();
        case 'openHire': return openHireModal();

        case 'openGradeModal': return openGradeModal(el.dataset.ssn);
        case 'openLicenseModal': return openLicenseModal(el.dataset.ssn);
        case 'openBadgeModal': return openBadgeModal(el.dataset.ssn);
        case 'addRecord': return openRecordModal(el.dataset.ssn, el.dataset.group);
        case 'recKind': MODAL.ctx.kind = el.dataset.kind; return MODAL.renderKinds();
        case 'voidRecord': {
            const rec = (emp.records || []).find(r => String(r.id) === el.dataset.id);
            if (!rec || rec.voided) return;
            return openModal({
                icon: 'ban', tone: 'brand', title: 'Unieważnić wpis?', text: `${REC[rec.kind].label} · ${fullName(emp)}`, ok: 'Unieważnij', needReason: true,
                body: () => `<div class="space-y-3"><div class="p-3 rounded-xl bg-slate-950/40 border border-slate-800">
                    <p class="text-sm text-slate-200 break-words">${esc(rec.reason)}</p>
                    <p class="text-[11px] text-slate-500 mt-1.5">Wystawił: <span class="text-slate-300 font-semibold">${esc(rec.by)}</span> · ${esc(fmtAt(rec.at))}</p></div>
                    ${reasonField('Powód unieważnienia')}
                    <p class="text-[11px] text-slate-500 -mt-1">Wpis zostanie w historii (wyszarzony, z Twoim nazwiskiem i powodem), ale przestanie być wliczany do statystyk. Tej operacji nie można cofnąć.</p></div>`,
                onOk: () => {
                    if (reasonValue().length < REASON_MIN) return toast(`Podaj powód (min. ${REASON_MIN} znaków)`, 'error'), false;
                    rec.voided = { by: fullName(S.me), at: nowFull(), reason: reasonValue() };
                    post('bossmenu:voidRecord', { ssn: emp.ssn, id: rec.id, reason: rec.voided.reason });
                    toast('Wpis unieważniony', 'warn'); refresh();
                }
            });
        }
        case 'histFilter':
            EMP.histFilter = el.dataset.v; EMP.off.hist = 0;
            return renderWin('history');
        case 'page': {
            const k = el.dataset.key, starts = JSON.parse(el.closest('section').querySelector('ul[data-fit]').dataset.starts || '[0]');
            let page = 0;
            starts.forEach((st, i) => { if (st <= (EMP.off[k] || 0)) page = i; });
            page = Math.min(Math.max(0, page + Number(el.dataset.dir)), starts.length - 1);
            EMP.off[k] = starts[page];
            return renderWin(el.closest('.win').dataset.win);
        }

        case 'licenseAdd': {
            const M = MODAL.ctx, def = S.licenseDefs.find(d => d.id === M.sel);
            if (!def) return;
            (emp.licenses = emp.licenses || []).push({ id: def.id, at: today() });
            post('bossmenu:setLicense', { ssn: emp.ssn, license: def.id, value: true });
            toast(`Nadano licencję: ${def.label}`, 'success'); break;
        }
        case 'licenseRemove': {
            const def = S.licenseDefs.find(d => d.id === el.dataset.id) || { id: el.dataset.id, label: el.dataset.id };
            emp.licenses = (emp.licenses || []).filter(l => l.id !== def.id);
            post('bossmenu:setLicense', { ssn: emp.ssn, license: def.id, value: false });
            toast(`Odebrano licencję: ${def.label}`, 'warn'); break;
        }

        case 'resetHours':
            return openModal({
                icon: 'refresh', tone: 'brand', title: 'Zresetować czas na służbie?',
                text: `${fullName(emp)} · obecnie ${fmtHours(emp.hoursWeek)}`, ok: 'Resetuj',
                onOk: () => {
                    emp.hoursWeek = 0;
                    post('bossmenu:resetHours', { ssn: emp.ssn });
                    toast('Zresetowano czas na służbie', 'success'); refresh();
                }
            });

        case 'resetAllHours': {
            const total = S.employees.reduce((n, e) => n + (e.hoursWeek || 0), 0);
            if (!S.employees.length || !total) return toast('Nikt nie ma naliczonych godzin', 'info');
            return openModal({
                icon: 'refresh', tone: 'brand', title: 'Zresetować godziny wszystkim?',
                text: `Czas pracy wszystkich pracowników (${S.employees.length}) zostanie wyzerowany – łącznie ${fmtHours(total)}. Tej operacji nie można cofnąć.`, ok: 'Resetuj wszystkim',
                onOk: () => {
                    addHistory({ type: 'resetHours', count: S.employees.length, total });
                    S.employees.forEach(e => { e.hoursWeek = 0; });
                    post('bossmenu:resetAllHours');
                    toast('Zresetowano godziny wszystkim pracownikom', 'success'); refresh();
                }
            });
        }

        case 'fire':
            return openModal({
                icon: 'user-x', tone: 'brand', title: 'Zwolnić pracownika?',
                text: `${fullName(emp)} (${emp.ssn}) straci dostęp do firmy.${vehCount(emp.ssn) ? ` Odebrane zostaną też przydzielone pojazdy (${vehCount(emp.ssn)}).` : ''}`, ok: 'Zwolnij',
                onOk: () => {
                    const nVeh = vehCount(emp.ssn);
                    S.vehicles.forEach(v => { if (v.assignedTo === emp.ssn) { v.assignedTo = null; v.assignedAt = null; } });
                    S.employees = S.employees.filter(e => e.ssn !== emp.ssn);
                    EMP.view = 'list';
                    post('bossmenu:fire', { ssn: emp.ssn });
                    addHistory({ type: 'fire', ssn: emp.ssn, name: fullName(emp), gradeName: gradeName(emp.grade), vehicles: nVeh });
                    toast(`Zwolniono: ${fullName(emp)}`, 'error'); refresh(); navEmp();
                }
            });

        case 'saveSalary': {
            const id = Number(el.dataset.id), g = S.grades.find(x => x.id === id);
            const val = Math.round(Number($(`[data-salary="${id}"]`).value));
            const max = salaryMaxOf(g);
            if (!Number.isFinite(val) || val < 0) return toast('Podaj poprawną stawkę', 'error');
            if (val > max) return toast(`Maksymalna stawka to ${money(max)} / h`, 'error');
            if (val === g.salary) return toast('Stawka bez zmian', 'info');
            const from = g.salary;
            g.salary = val;
            post('bossmenu:setSalary', { grade: id, salary: val });
            addHistory({ type: 'salary', grade: id, gradeName: g.name, from, to: val });
            toast(`Stawka dla „${g.name}”: ${money(val)} / h`, 'success'); break;
        }
        case 'testHook': {
            const h = HOOKS.find(x => x.key === el.dataset.key);
            if (!h || el.disabled) return;
            el.disabled = true; el.className = HOOK_TEST + SAL_OFF;
            request('bossmenu:testWebhook', { key: h.key }).then(res => {
                if (res?.ok) toast(`Wysłano test: ${h.label}`, 'success');
                else toast(res?.error || 'Nie udało się wysłać testu', 'error');
                syncHooks();
            });
            return;
        }
        case 'saveHooks': {
            const next = {}; let bad = false;
            HOOKS.forEach(h => { const v = ($(`[data-hook="${h.key}"]`)?.value || '').trim(); if (hookState(v) === 'bad') bad = true; next[h.key] = v; });
            if (bad) return toast('Popraw nieprawidłowe linki webhooków', 'error');
            const prev = S.webhooks || {};
            const changes = HOOKS.filter(h => (prev[h.key] || '') !== next[h.key]);
            if (!changes.length) return toast('Brak zmian w webhookach', 'info');
            S.webhooks = next;
            post('bossmenu:setWebhooks', next);
            changes.slice().reverse().forEach(h => addHistory({ type: 'webhook', key: h.key, action: !next[h.key] ? 'removed' : prev[h.key] ? 'changed' : 'set' }));   // każdy webhook osobnym wpisem
            toast('Zapisano ustawienia frakcji', 'success'); break;
        }

        case 'deposit':
        case 'withdraw': return moneyModal(type);
        case 'resetSettings':
            CFG = { ...CFG_DEF, widgets: [...CFG_DEF.widgets] }; saveCfg(); applyScreen(); clampWindows(); syncFade();
            applyAnim(); applyNotifPos(); tick();
            toast('Przywrócono ustawienia domyślne', 'info'); break;
        case 'testToast': toast('Tak wyglądają powiadomienia', 'success', true); return;
        case 'testSound': if (!CFG.sound) return toast('Dźwięki są wyłączone', 'info', true); sfx('success'); return;
        case 'clearLayout':
            LAYOUT = { geo: {}, open: [] }; try { localStorage.removeItem(LAYOUT_KEY); } catch (e) { }
            LAYOUT_READY = false;      // zapis wznowi się po następnej zmianie układu (otwarcie, zamknięcie, przesunięcie okna)
            toast('Wyczyszczono zapamiętany układ okien', 'info'); return;
        case 'gTab': GAR.tab = el.dataset.v; return renderWin('garage');
        case 'gFilter': GAR.filter = el.dataset.v; EMP.off.veh = 0; return renderWin('garage');
        case 'gCat': GAR.cat = el.dataset.v; return renderWin('garage');
        case 'cartAdd':
            if (GAR.cart.length >= CART_MAX) return toast(`Maksymalnie ${CART_MAX} pojazdów w jednym zamówieniu`, 'error');
            GAR.cart.push({ uid: 'c' + (++GAR_UID), model: el.dataset.model, express: false });
            return renderWin('garage');
        case 'cartRemove': GAR.cart = GAR.cart.filter(i => i.uid !== el.dataset.uid); return renderWin('garage');
        case 'cartExpress': { const it = GAR.cart.find(i => i.uid === el.dataset.uid); if (it) it.express = !it.express; return renderWin('garage'); }
        case 'openNoteModal': return openNoteModal(el.dataset.ssn);
        case 'openVehicleModal': return openEmpVehicleModal(el.dataset.ssn);
        case 'empVehAssign': return empVehicleAction('assign', el);
        case 'empVehRevoke': return empVehicleAction('revoke', el);
        case 'cartClear': GAR.cart = []; return renderWin('garage');
        case 'cartCheckout': return openCheckoutModal();
        case 'orderInfo': return openOrderModal(el.dataset.id);
        case 'assignVehicle': return openAssignModal(el.dataset.plate);
        case 'revokeVehicle': return openRevokeModal(el.dataset.plate);
        case 'cancelOrder': return openCancelOrderModal(el.dataset.id);
        case 'devOrder': devAdvanceOrder(el.dataset.id, el.dataset.to); break;
        case 'widgetEdit': return openWidgetModal();
        case 'widgetPin': {
            const id = el.dataset.id, list = CFG.widgets || (CFG.widgets = []), i = list.indexOf(id);
            if (i >= 0) list.splice(i, 1);
            else if (widgetPinned().length >= WIDGET_MAX) return toast(`Maksymalnie ${WIDGET_MAX} pozycji w widgecie`, 'warn');
            else list.push(id);
            saveCfg(); break;
        }
        case 'widgetReset': CFG.widgets = [...CFG_DEF.widgets]; saveCfg(); break;
        case 'shopTab': SHOP.tab = el.dataset.v; return renderWin('orders');
        case 'shopCat': SHOP.cat = el.dataset.v; return renderWin('orders');
        case 'shopFOut': SHOP.outF = el.dataset.v; EMP.off.ordOut = 0; return renderWin('orders');
        case 'shopFIn': SHOP.inF = el.dataset.v; EMP.off.ordIn = 0; return renderWin('orders');
        case 'shopAdd': return shopCartAct('add', el);
        case 'shopQty': return shopCartAct('qty', el);
        case 'shopRemove': return shopCartAct('remove', el);
        case 'shopExpress': return shopCartAct('express', el);
        case 'shopClear': return shopCartAct('clear', el);
        case 'shopCheckout': return openShopCheckout();
        case 'shopInfo': return openShopOrderModal(el.dataset.id);
        case 'shopCancel': return el.dataset.kind === 'vehicles' ? openCancelOrderModal(el.dataset.id) : openShopCancelModal(el.dataset.id);
        case 'shopAccept': return shopHandle(el.dataset.id, 'accept');
        case 'shopReject': return shopHandle(el.dataset.id, 'reject');
        case 'shopDeliver': return shopHandle(el.dataset.id, 'deliver');
        case 'shopDev': devShopOrder(el.dataset.id, el.dataset.to); break;
        case 'shopDevIncoming': devIncomingOrder(); break;
        case 'prodMode': if (PROD_M) { PROD_M.mode = el.dataset.v; syncAccessUI(); } return;
        case 'prodCo': if (PROD_M) { const j = el.dataset.job; PROD_M.sel.has(j) ? PROD_M.sel.delete(j) : PROD_M.sel.add(j); syncAccessUI(); } return;
        case 'offAdd': return openProductModal();
        case 'offEdit': return openProductModal(el.dataset.id);
        case 'offToggle': return offerToggle(el.dataset.id);
        case 'offDelete': return openProductDeleteModal(el.dataset.id);
        case 'power': return closeMenu();
    }
    refresh();
}

function moneyModal(type) {
    const dep = type === 'deposit';
    openModal({
        icon: dep ? 'plus' : 'minus', tone: dep ? 'brand' : 'slate',
        title: dep ? 'Wpłata na konto firmy' : 'Wypłata z konta firmy',
        text: dep ? 'Podaj kwotę, którą chcesz wpłacić.' : `Dostępne środki: ${money(S.funds)}`,
        ok: dep ? 'Wpłać' : 'Wypłać', needReason: !dep,
        body: () => `<div class="space-y-3"><div>
                ${fieldLabel('Kwota')}
                <div class="relative">
                    <span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 text-sm font-bold">$</span>
                    <input id="amount" type="number" min="1" step="1" inputmode="numeric" placeholder="0" data-autofocus
                        class="w-full bg-slate-950/60 border border-slate-800 rounded-xl pl-7 pr-3 py-2.5 text-sm font-bold text-white focus:border-brand/50 outline-none">
                </div></div>
                ${dep ? '' : reasonField('Powód wypłaty').replace(' data-autofocus', '')}</div>`,
        onOk: () => {
            const amount = parseInt($('#amount').value);
            if (!amount || amount <= 0) return toast('Podaj poprawną kwotę', 'error'), false;
            if (amount > MONEY_MAX) return toast(`Maksymalna kwota jednej operacji to ${money(MONEY_MAX)}`, 'error'), false;
            if (!dep && amount > S.funds) return toast('Firma nie ma tylu środków', 'error'), false;
            if (!dep && reasonValue().length < REASON_MIN) return toast(`Podaj powód (min. ${REASON_MIN} znaków)`, 'error'), false;
            const reason = dep ? '' : reasonValue();

            // Wcześniej: `post()` (bez odpowiedzi) + zmiana salda i toast PRZED zapisem – gdy serwer
            // odrzucił operację (brak środków / brak konta firmy), panel i tak pokazywał sukces.
            request('bossmenu:' + type, dep ? { amount } : { amount, reason }).then(res => {
                if (!res?.ok) return toast(res?.error || 'Operacja nie powiodła się', 'error');

                const funds = Number(res.funds);
                S.funds = Number.isFinite(funds) ? funds : S.funds + (dep ? amount : -amount);
                EMP.off.tx = 0;
                S.transactions.unshift({ type: dep ? 'in' : 'out', amount, by: fullName(S.me), label: dep ? 'Wpłata' : 'Wypłata', reason, at: stamp() });
                toast(`${dep ? 'Wpłacono' : 'Wypłacono'} ${money(amount)}`, 'success');
                refresh();
            });
        }
    });
}

/* =========================================================
   MODAL + TOAST
   ========================================================= */
let MODAL = null;
function openModal(o) { sfx('modal'); MODAL = o; renderModal(); setTimeout(() => $('#modal [data-autofocus]')?.focus(), 30); syncFade(); }
function renderModal() {
    const o = MODAL; if (!o) return;
    closeSelects();
    $('#modalRoot').innerHTML = `
    <div id="modal" class="absolute inset-0 z-[9000] flex items-center justify-center p-4 bg-black/75">
        <div class="${o._shown ? '' : 'fade-in'} w-full ${o.wide ? 'max-w-2xl' : 'max-w-md'} max-h-full overflow-y-auto rounded-2xl bg-slate-900 border border-slate-800 shadow-2xl p-6 space-y-4">
            <div class="flex items-center gap-3">
                <div class="size-10 shrink-0 rounded-xl flex items-center justify-center border ${TONES[o.tone === 'slate' ? 'slate' : 'brand']}">${icon(o.icon)}</div>
                <div class="min-w-0">
                    <h3 class="text-[15px] font-extrabold text-white">${esc(o.title)}</h3>
                    <p class="text-xs text-slate-400 mt-0.5 leading-4 break-words">${esc(o.text || '')}</p>
                </div>
            </div>
            ${typeof o.body === 'function' ? o.body() : (o.body || '')}
            <div class="flex gap-2 pt-1">
                <button data-modal="cancel" class="flex-1 px-4 py-2.5 rounded-xl text-sm font-bold text-slate-300 bg-slate-800 hover:bg-slate-700 transition">${esc(o.cancel || 'Anuluj')}</button>
                ${o.noOk ? '' : `<button data-modal="ok" ${o.needReason ? 'disabled' : ''} class="flex-1 px-4 py-2.5 rounded-xl text-sm font-bold text-white bg-brand hover:opacity-90 transition ${o.needReason ? 'opacity-40 cursor-not-allowed' : ''}">${esc(o.ok || 'Potwierdź')}</button>`}
            </div>
        </div>
    </div>`;
    o._shown = true;
}
function requestClose() { if (MODAL?.beforeClose && MODAL.beforeClose() === false) return; closeModal(); }
function closeModal() { $('#modalRoot').innerHTML = ''; MODAL = null; closeSelects(); syncFade(); }
const modalOpen = () => !!$('#modal');
function submitModal() { if (MODAL?.onOk && MODAL.onOk() !== false) closeModal(); }

let LAST_TOAST = { key: '', at: 0 };
function toast(msg, type = 'info', force = false) {
    // Serwer wysyła `notify` przy każdej odrzuconej akcji, a UI pokazuje `res.error` – to ten sam
    // komunikat, więc przez ~1 s nie dublujemy go na ekranie.
    const key = type + '|' + String(msg), now = Date.now();
    if (!force && LAST_TOAST.key === key && now - LAST_TOAST.at < 1000) return;
    LAST_TOAST = { key, at: now };

    sfx(type === 'success' ? 'success' : type === 'error' ? 'error' : type === 'warn' ? 'warn' : 'info');
    if (!force && (CFG.notif === 'off' || (CFG.notif === 'errors' && type !== 'error' && type !== 'warn'))) return;
    const t = {
        success: ['check', 'text-emerald-400'], error: ['alert-triangle', 'text-brand'],
        warn: ['alert-triangle', 'text-amber-400'], info: ['bell', 'text-sky-400']
    }[type];
    const el = document.createElement('div');
    el.className = 'fade-in flex items-center gap-2.5 px-4 py-3 rounded-xl bg-slate-900 border border-slate-800 shadow-xl text-xs font-bold text-white max-w-xs';
    el.innerHTML = `<span class="${t[1]}">${icon(t[0], 'size-4')}</span><span>${esc(msg)}</span>`;
    const box = $('#toasts');
    if (!box) { console.warn('[bossmenu]', msg); return; }      // powloka jeszcze nie istnieje
    box.appendChild(el);
    setTimeout(() => { el.style.transition = 'opacity .3s'; el.style.opacity = 0; setTimeout(() => el.remove(), 300); }, Math.max(1, CFG.notifDur) * 1000);
}

/* =========================================================
   ZDARZENIA (delegacja)
   ========================================================= */
function bindEvents() {
    // fokus + przeciąganie + resize
    document.addEventListener('pointerdown', e => {
        const winEl = e.target.closest('.win');
        if (winEl) {
            const w = wins[winEl.dataset.win];
            if (UI.active !== w.app || w.z !== UI.z) focusWin(w.app);
            if (e.target.closest('[data-resize]')) return dragStart(e, w, 'resize');
            if (e.target.closest('[data-drag]') && !e.target.closest('button')) dragStart(e, w, 'move');
        }
        if (UI.start && !e.target.closest('#startmenu') && !e.target.closest('[data-start-btn]')) toggleStart(false);
        if (!e.target.closest('[data-select]')) closeSelects();
        if (!e.target.closest('[data-icon-app]') && e.target.closest('#desktop')) selectIcon(null);
    });

    document.addEventListener('click', e => {
        const t = e.target;
        let el;
        if ((el = t.closest('[data-select-toggle]'))) return el.disabled ? null : toggleSelect(el.dataset.selectToggle);
        if ((el = t.closest('[data-select-option]'))) return el.disabled ? null : pickSelect(el.dataset.selectOption, el.dataset.value);
        if ((el = t.closest('[data-win-act]'))) {
            const id = el.dataset.win, a = el.dataset.winAct;
            return a === 'min' ? minimizeWin(id) : a === 'max' ? toggleMax(id) : closeWin(id);
        }
        if ((el = t.closest('[data-start-btn]'))) return toggleStart();
        if ((el = t.closest('[data-task]'))) {
            const id = el.dataset.task, w = wins[id];
            if (!w || w.min) return openApp(id);
            return UI.active === id ? minimizeWin(id) : focusWin(id);
        }
        if ((el = t.closest('[data-show-desktop]'))) {
            const any = Object.values(wins).some(w => !w.min);
            Object.keys(wins).forEach(id => any ? minimizeWin(id) : openApp(id));
            return;
        }
        if ((el = t.closest('[data-open]'))) return openApp(el.dataset.open);
        if ((el = t.closest('[data-icon-app]'))) return selectIcon(el.dataset.iconApp);
        if ((el = t.closest('[data-preset]'))) {
            const [k, v] = el.dataset.preset.split(':'); CFG[k] = Number(v); saveCfg(); syncSettings(); applySetting(k);
            return;
        }
        if ((el = t.closest('[data-set-tab]'))) { SETUI.tab = el.dataset.setTab; return renderWin('settings'); }
        if ((el = t.closest('[data-toggle]'))) { const k = el.dataset.toggle; CFG[k] = !CFG[k]; saveCfg(); applySetting(k); return renderWin('settings'); }
        if ((el = t.closest('[data-opt]'))) { const [k, v] = el.dataset.opt.split(':'); CFG[k] = v; saveCfg(); applySetting(k); return renderWin('settings'); }
        if ((el = t.closest('[data-filter]'))) { S.filter = el.dataset.filter; return renderWin('employees'); }
        if ((el = t.closest('[data-modal]'))) return el.dataset.modal === 'ok' ? submitModal() : requestClose();
        if (t.id === 'modal') return closeModal();
        if ((el = t.closest('[data-act]'))) { if (!el.disabled) act(el.dataset.act, el); }
    });

    /* delikatne „kliknięcie” przy przyciskach (poza sterowaniem okien, które mają własny dźwięk) */
    document.addEventListener('click', e => {
        const b = e.target.closest?.('button, [data-act], [data-open], [data-filter], [data-icon-app]');
        if (b && !b.disabled && !b.closest('[data-win-act]') && !b.matches('[data-icon-app]')) sfx('click');
    }, true);

    document.addEventListener('dblclick', e => {
        let el;
        if ((el = e.target.closest('[data-icon-app]'))) return openApp(el.dataset.iconApp);
        if ((el = e.target.closest('[data-drag]')) && !e.target.closest('button')) toggleMax(el.closest('.win').dataset.win);
    });

    document.addEventListener('input', e => {
        const key = e.target.dataset?.setting;
        if (key) {
            CFG[key] = Number(e.target.value); saveCfg(); syncSettings(); applySetting(key);
            return;
        }
        if (e.target.dataset?.salary !== undefined) return syncSalaryRow(e.target);
        if (e.target.dataset?.hook !== undefined) return syncHooks();
        if (e.target.id === 'modalReason') {
            const ok = $('#modal [data-modal=ok]'), bad = e.target.value.trim().length < REASON_MIN;
            if (ok) { ok.disabled = bad; ok.classList.toggle('opacity-40', bad); ok.classList.toggle('cursor-not-allowed', bad); }
            return;
        }
        if (e.target.id === 'prodPrice') { e.target.value = e.target.value.replace(/\D/g, ''); return; }
        if (e.target.id === 'shopNote') { SHOP.note[SHOP.sup] = e.target.value; return; }
        if (e.target.id === 'badgeNo') { e.target.value = e.target.value.replace(/\D/g, ''); return; }
        if (e.target.id === 'search') {
            S.search = e.target.value;
            const pos = e.target.selectionStart;
            renderWin('employees');
            const n = $('#search'); if (n) { n.focus(); n.setSelectionRange(pos, pos); }
        } else if (e.target.id === 'gSearch' || e.target.id === 'cSearch') {
            const id = e.target.id, pos = e.target.selectionStart;
            if (id === 'gSearch') { GAR.search = e.target.value; EMP.off.veh = 0; } else GAR.csearch = e.target.value;
            renderWin('garage');
            const n = $('#' + id); if (n) { n.focus(); n.setSelectionRange(pos, pos); }
        } else if (['shopSearch', 'outSearch', 'inSearch', 'offSearch'].includes(e.target.id)) {
            const id = e.target.id, pos = e.target.selectionStart, v = e.target.value;
            if (id === 'shopSearch') SHOP.search = v; else if (id === 'outSearch') { SHOP.outQ = v; EMP.off.ordOut = 0; } else if (id === 'inSearch') { SHOP.inQ = v; EMP.off.ordIn = 0; } else { SHOP.offQ = v; EMP.off.offer = 0; }
            renderWin('orders');
            const n = $('#' + id); if (n) { n.focus(); n.setSelectionRange(pos, pos); }
        } else if (e.target.id === 'startSearch') {
            UI.startQuery = e.target.value; renderStartGrid();
        }
    });

    document.addEventListener('keydown', e => {
        if (e.key === 'Enter') {
            if (modalOpen()) return (e.target.tagName === 'TEXTAREA' || e.target.closest?.('.ql-editor')) && !e.ctrlKey ? null : submitModal();
            if (e.target.id === 'startSearch') { const first = $('#startGrid [data-open]'); if (first) first.click(); }
        }
        if (e.key === 'Escape') {
            if (closeSelects()) return;
            if (modalOpen()) requestClose();
            else if (UI.start) toggleStart(false);
            else closeMenu();
        }
    });

    // zachowaj okna w obrębie pulpitu po zmianie rozmiaru ekranu
    addEventListener('resize', clampWindows);

    // przygasanie po wyjechaniu kursorem poza interfejs
    const os = $('#os');
    os.addEventListener('mouseenter', syncFade);
    os.addEventListener('mouseleave', syncFade);
    document.documentElement.addEventListener('mouseleave', syncFade);
}

/* =========================================================
   OTWIERANIE / ZAMYKANIE + INIT
   ========================================================= */
/* Pokazywanie/ukrywanie ekranu NIE moze zalezec od klas Tailwinda (gdy CSS sie nie
   wczyta, interfejs zostawal na ekranie i zaslanial gre). Atrybut [hidden] + regula
   w injectStyles() dzialaja zawsze. */
function showUI() { const s = $('#screen'); if (!s) return; s.removeAttribute('hidden'); s.classList.remove('hidden'); }
function hideUI() { const s = $('#screen'); if (!s) return; s.setAttribute('hidden', ''); s.classList.add('hidden'); }

function openMenu(data) {
    if (data) S = normalizeState({ ...S, ...data, search: '', filter: 'all', history: data.history || [] });
    EMP.view = 'list'; EMP.ssn = null;
    showUI();
    try {
        renderIcons(); refresh();
        if (!Object.keys(wins).length) startWindows();
    } catch (err) {     // bledne dane nie moga zostawic gracza z czarnym pulpitem
        console.error('[bossmenu] Blad renderowania interfejsu:', err);
        toast('Blad danych: ' + (err && err.message ? err.message : err), 'error', true);
    }
    LAYOUT_READY = true;
}
function closeMenu() {
    if (IN_GAME) { hideUI(); post('close', { action: OPEN_ACTION, success: true }); }
    else toast('Zamknięto (tryb DEV – pulpit pozostaje widoczny)', 'info');
}

// FiveM: ui.openUI(action, data) -> SendNUIMessage({ action, data }) = otwarcie; 'update' { data } / 'notify' { text, tone };
//        akcja bez `data` (np. ui.CloseUI(action) albo 'close') = zamknięcie. Zamknięcie z UI: POST /close { action, success }
let PENDING_REFRESH = false;
function applyUpdate(data) {
    S = normalizeState({ ...S, ...data });
    if (EMP.view !== 'list' && EMP.ssn && !getEmp(EMP.ssn)) { EMP.view = 'list'; EMP.ssn = null; }   // pracownik zwolniony / zniknął z listy
    const ae = document.activeElement;
    // nie przebudowuj okien, gdy gracz akurat coś wpisuje – odśwież po opuszczeniu pola
    if (ae && ae.matches?.('input, textarea, [contenteditable=true]') && $('#screen')?.contains(ae)) { PENDING_REFRESH = true; return; }
    try { refresh(); } catch (err) { console.error('[bossmenu] Blad odswiezania danych:', err); }
}
addEventListener('focusout', () => { if (PENDING_REFRESH) setTimeout(() => { const ae = document.activeElement; if (PENDING_REFRESH && !(ae && ae.matches?.('input, textarea, [contenteditable=true]'))) { PENDING_REFRESH = false; refresh(); } }, 60); });
addEventListener('message', ({ data: m }) => {
    try {
        if (!m || typeof m !== 'object' || typeof m.action !== 'string') return;
        markInGame();       // przyszła wiadomość z gry = na pewno jesteśmy w NUI; wyłącz ewentualny DEV
        if (m.action === 'update') applyUpdate(m.data || {});
        else if (m.action === 'notify') toast(String(m.text || ''), m.tone || 'info', !!m.force);
        else if (m.data) { OPEN_ACTION = m.action; DID_CHANGE = false; PENDING_REFRESH = false; openMenu(m.data); }   // dowolna akcja z danymi = otwarcie (ui.openUI(action, data))
        else { closeModal(); hideUI(); }                                                                            // ta sama akcja bez danych (ui.CloseUI(action)) albo 'close'
    } catch (err) {
        console.error('[bossmenu] Blad obslugi wiadomosci NUI:', m && m.action, err);
        if (!m || !m.data) hideUI();          // w razie bledu nigdy nie zostawiaj interfejsu na ekranie
    }
});

/* ---------- Tryb DEV (tylko poza grą) ---------- */
/* DEV włącza się WYŁĄCZNIE, gdy strona nie jest rozpoznana jako NUI (patrz NUI_URL).
   devOff() to bezpiecznik: jeśli okaże się, że jednak jesteśmy w grze (przyszła
   wiadomość z Lua albo pojawił się GetParentResourceName), tło DEV jest natychmiast
   usuwane - żaden "background" nie może zostać na ekranie gry. */
function devBackdrop() {
    DEV_ON = true;
    document.documentElement.style.setProperty('background', `#0f172a url('dev-bg.jpg') center / cover no-repeat`, 'important');   // !important, bo baza NUI wymusza transparentnosc
    const tag = document.createElement('div');
    tag.id = 'devBadge';
    tag.className = 'fixed top-3 left-3 px-2.5 py-1 rounded-lg bg-black/60 text-[10px] font-bold tracking-wide text-slate-300 pointer-events-none';
    tag.textContent = `DEV · atrapa widoku z gry · ${BUILD}`;
    document.body.appendChild(tag);
}
function devOff() {
    if (!DEV_ON) return;
    DEV_ON = false;
    document.getElementById('devBadge')?.remove();
    document.documentElement.style.removeProperty('background');
    document.documentElement.style.removeProperty('background-color');
    console.log('[bossmenu] tryb DEV wyłączony – wykryto grę (NUI)');
}
/* Wywoływane, gdy pojawi się dowód, że działamy w grze. */
function markInGame() {
    if (IN_GAME) return;
    IN_GAME = true;
    devOff();
    hideUI();
    document.documentElement.dataset.mode = 'game';
}

/* ---------- Diagnostyka NUI (wpisz w konsoli: nui_devtools) ----------
   __bossDiag()  – wypisuje raport: tryb, tło html/body, stan #screen oraz
                   WSZYSTKIE elementy, które mogą kryć ekran (tło/obraz/blur).
   __bossHide()  – awaryjne ukrycie interfejsu (bez zamykania menu w Lua). */
window.__bossDiag = function () {
    const vw = innerWidth, vh = innerHeight;
    const layers = [];
    document.querySelectorAll('body *').forEach(el => {
        const cs = getComputedStyle(el), r = el.getBoundingClientRect();
        if (cs.display === 'none' || cs.visibility === 'hidden' || Number(cs.opacity) < 0.01) return;
        const bg = cs.backgroundColor, img = cs.backgroundImage;
        const bgOn = !/^rgba?\(0, 0, 0, 0\)$|^transparent$/.test(bg);
        const imgOn = img && img !== 'none';
        const blur = cs.backdropFilter && cs.backdropFilter !== 'none';
        const big = r.width >= vw * 0.5 && r.height >= vh * 0.5;
        if (big && (bgOn || imgOn || blur)) layers.push({
            element: el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (typeof el.className === 'string' && el.className ? '.' + el.className.trim().split(/\s+/).slice(0, 3).join('.') : ''),
            tło: bg, obraz: imgOn ? img.slice(0, 70) : '—', blur: blur ? cs.backdropFilter : '—',
            rozmiar: Math.round(r.width) + '×' + Math.round(r.height), krycie: cs.opacity, z: cs.zIndex
        });
    });
    const screen = document.getElementById('screen');
    const report = {
        build: BUILD,
        tryb: IN_GAME ? 'GRA (NUI)' : 'DEV (przeglądarka)',
        devAktywny: DEV_ON,
        resource: typeof GetParentResourceName === 'function' ? GetParentResourceName() : null,
        adres: location.href,
        protokół: location.protocol,
        'screen ukryty': screen ? screen.hasAttribute('hidden') : 'brak #screen',
        'screen display': screen ? getComputedStyle(screen).display : null,
        'html tło': getComputedStyle(document.documentElement).backgroundColor,
        'body tło': getComputedStyle(document.body).backgroundColor,
        'color-scheme': getComputedStyle(document.documentElement).colorScheme + '  (musi być "normal" – "dark" = czarny canvas CEF)',
        'elementy w body': [...document.body.children].map(e => e.tagName.toLowerCase() + (e.id ? '#' + e.id : '')),
        'warstwy kryjące ekran': layers
    };
    console.log('%c[bossmenu] DIAGNOZA ' + BUILD, 'color:#fc4444;font-weight:bold');
    console.log(report);
    if (layers.length) console.table(layers);
    else console.log('%cBrak elementów kryjących ekran w tej stronie.', 'color:#22c55e');
    return report;
};
window.__bossHide = function () { hideUI(); closeModal(); console.log('[bossmenu] interfejs wymuszenie ukryty'); };

addEventListener('error', e => console.error('[bossmenu] Blad JS:', e.message, `${e.filename}:${e.lineno}:${e.colno}`));

injectStyles();
buildShell();
applyScreen(); applyAnim(); applyNotifPos();
bindEvents();
setInterval(tick, 10000);
try { renderIcons(); renderTaskbar(); renderWidgets(); renderWatermark(); }
catch (err) { console.error('[bossmenu] Blad startu interfejsu:', err); }
document.documentElement.dataset.mode = IN_GAME ? 'game' : 'dev';
document.documentElement.dataset.build = BUILD;
console.log(`[bossmenu] build ${BUILD} · tryb: ${IN_GAME ? 'GRA (NUI)' : 'DEV (przeglądarka)'}`
    + (IN_GAME ? ` · resource: ${typeof GetParentResourceName === 'function' ? GetParentResourceName() : '(shim jeszcze nie ma)'}` : '')
    + ' · diagnostyka: __bossDiag()');
if (IN_GAME) hideUI();                                               // w grze czekamy na 'open'
else { devBackdrop(); openMenu(MOCK); }                              // w przeglądarce – dane testowe
/* Straznik: jesli shim FiveM pojawi sie chwile po starcie, przelacz na tryb gry. */
if (!IN_GAME) {
    let tries = 0;
    const t = setInterval(() => {
        if (typeof GetParentResourceName === 'function') { clearInterval(t); markInGame(); }
        else if (++tries > 40) clearInterval(t);      // 10 s i koniec – zwykla przegladarka
    }, 250);
}
