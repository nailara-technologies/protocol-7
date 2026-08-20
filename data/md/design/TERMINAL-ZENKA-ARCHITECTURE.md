## [:< ##

# UI adapter system — application / presentation separation

## core principle

application logic runs independently of the UI backend that renders it.
a "model manager app" sends abstract UI commands — show_list, show_detail,
prompt_confirm, update_status — and the active UI adapter translates those
to whichever rendering system is in use: curses, GTK3, web, SDL.

this means:
  - switching UI backend requires zero changes to app logic
  - multiple clients can attach to the same running app simultaneously
  - the same app is accessible from terminal, browser, or GTK3 window
  - UI adapters compose a global P7 style independent of the app

parallel to the storage adapter pattern:
  models.storage.adapter.{invoke,lmstudio,native}.*
  ui.adapter.{curses,web,gtk3,sdl}.*


## existing UI infrastructure

    amos-term zenka (48 modules)
        3D SHM buffer, multi-client, GTK3 rendering, FUSE/9P export
        → ui.adapter.amos_term wraps this

    terminal.curses_ui (2 modules, thin)
        Curses::UI language/widget base
        → ui.adapter.curses expands this

    web zenka + template zenka (39 modules)
        httpd.process_template, web.template_cache, context.template.render
        mustache with recursive include/when/static
        already renders HTML — needs UI template expansion for structured views
        → ui.adapter.web extends template system with UI-aware templates

    protocol-7-menu (GTK3)
        global P7 menu/launcher — could receive UI plugin slots
        → ui.adapter.gtk3 plugin system + global P7 style application

    pager zenka (48 modules)
        virtual buffer, filter/sort chains, data sources, viewport render
        → shared data layer used by all UI adapters (not adapter-specific)


## UI adapter interface

each adapter implements ui.adapter.{name}.*:

    ui.adapter.{name}.init         (app_id, config)
        → open/attach display surface for this backend
        → curses: init screen; web: register route; gtk3: open window

    ui.adapter.{name}.render_list  (items, selected, filters, meta)
        → display a paginated, filterable list
        → curses: Curses::UI listbox; web: table template; gtk3: TreeView

    ui.adapter.{name}.render_detail  (record, template_name)
        → display a single record using a named template
        → all adapters share the same template definitions
        → curses: text panel; web: detail page; gtk3: form widget

    ui.adapter.{name}.prompt_confirm  (message, options)
        → blocking confirmation dialog
        → curses: modal box; web: JS confirm or inline form; gtk3: dialog

    ui.adapter.{name}.update_status  (text, counts, key_hints)
        → update status bar / footer area

    ui.adapter.{name}.handle_event  (event)
        → translate backend-specific input to abstract app actions
        → curses: key codes → :action:scroll_down:, :action:filter:, etc.
        → web: HTTP POST → same abstract actions
        → gtk3: GDK events → same abstract actions


## shared template layer

templates are backend-independent where possible:

    ui templates defined once in YAML/mustache:
        ui.template.model_detail
        ui.template.model_list_row
        ui.template.image_detail
        ui.template.statusbar

    each adapter renders the same template to its format:
        curses  → plain text with ANSI color codes
        web     → HTML (via web.template_cache + httpd.process_template)
        gtk3    → Pango markup / widget property bindings
        sdl     → pixel-rendered text surfaces

    context.template.resolve already handles recursive include/when/static
    — extend with ui.* namespace templates and adapter hints


## UI backends — scope and status

    curses (terminal.curses_ui)
        status: 2 modules, thin — needs widget expansion
        scope:  interactive terminal apps, nshell integration
        style:  P7 ANSI color palette, box-drawing characters

    web (web + httpd + template zenki)
        status: template rendering solid; UI template layer = new
        scope:  localhost browser (127.0.0.1:port) or project websites
        uses:   documentation browser, source code browser, model manager UI,
                deduplication tree viewer, global system configuration,
                zenka-specific management panels
        style:  P7 CSS stylesheet, shared with GTK3 theme

    gtk3 (protocol-7-menu + amos-term)
        status: protocol-7-menu exists; plugin slots = new
        scope:  desktop widgets, floating panels, system tray integration
        global P7 style applied at adapter level — apps inherit it
        plugin feature: apps register UI plugins → menu discovers + loads them

    sdl (future)
        status: not started — placeholder in design
        scope:  full-screen kiosk, embedded displays, gaming-style UI
        shares same abstract action protocol as other adapters

    amos-term (3D buffer)
        status: 48 modules, well-developed
        scope:  multi-client terminal with 3D history, GTK3 rendering
        role:   display backend for curses adapter (or standalone)
        FUSE/9P export enables other processes to read buffer state


## apps that run on top of the adapter layer

application logic lives in ui.app.* (or zenka.cmd.*) — never in adapters.

    ui.app.models
        → model manager: list, filter, inspect, install, remove, archive
        → data: models.storage.adapter.{invoke,lmstudio}.discover
        → actions: :action:install:, :action:remove:, :action:repair:

    ui.app.image
        → image archive browser: grid, cull, quality score view
        → data: image db from invoke output dir
        → actions: :action:keep:, :action:compress:, :action:regen:

    ui.app.source
        → source code browser (protocol-7 codebase)
        → data: pager.source.file-list over git tree
        → web adapter: replaces static docs site with live browsable tree

    ui.app.config
        → global system configuration editor
        → data: cfg/ tree via data zenka
        → available on web adapter for remote admin

    ui.app.network
        → zenka network explorer: sessions, routing, stats
        → data: cube list commands + v7 status
        → gtk3 adapter: floating panel alongside protocol-7-menu


## global P7 style system

    style defined once, applied by each adapter:
        ui.style.colors       ANSI palette / CSS vars / GTK3 CSS / SDL palette
        ui.style.typography   font choices per backend
        ui.style.borders      box-drawing / CSS borders / GTK3 frames
        ui.style.spacing      padding/margin constants

    protocol-7-menu enforces style on GTK3 plugins
    web adapter loads P7 CSS stylesheet for all UI templates
    curses adapter uses P7 ANSI palette constants


## relation to existing zenki

    models zenka    → data source for ui.app.models
    template zenka  → rendering engine for web + curses adapters
    amos-term zenka → display backend for curses adapter
    pager zenka     → virtual list/filter for all adapters
    httpd zenka     → HTTP transport for web adapter
    coding zenka    → can spawn ui.app.* for interactive task review


## implementation order

step 1 — curses adapter foundation
    terminal.curses_ui.widget.list  (pager → Curses::UI listbox)
    terminal.curses_ui.widget.detail
    terminal.curses_ui.keybindings
    standalone ui.app.models using curses adapter + invoke adapter

step 2 — web adapter UI templates
    extend web/httpd template system with ui.template.* namespace
    ui.adapter.web.render_list, render_detail (HTML output)
    ui.app.models accessible at localhost:port/models
    ui.app.source: source code browser on project website

step 3 — gtk3 adapter plugin slots
    protocol-7-menu plugin registration protocol
    ui.adapter.gtk3.plugin.register / load
    global P7 style application
    ui.app.models as GTK3 plugin panel

step 4 — shared template layer
    ui.template.* definitions shared across adapters
    context.template.resolve extended with adapter hints
    single template → multiple output formats

step 5 — sdl adapter (future)
    when display use cases require it


## key design constraint

the abstract action protocol uses P7-style notation:
    :action:scroll_down:      not --scroll-down or keyCode=40
    :action:filter: text      consistent with :dry-run: and p7c conventions

app logic receives abstract actions; adapters translate input → actions.
this is the same principle as route-send vs direct socket calls —
the transport is irrelevant to the message content.

#,,.,,,..,,,.,,.,,...,...,..,,..,,,..,,.,,.,,,..,,...,...,.,,,.,.,,,.,,,,,.,,,
#JZ6BG5FAQDXWMIHHPTXKNFV7LMWYGEJYEAM575ZEER3ZI3G6X6KM47GZ44MYGCBIV3NGB5VAZTZAW
#\\\|25LH4WJDDJXFPINLMXASCXUSLTXU7BT4BWLEX6R55UYPQHDES66 \ / AMOS7 \ YOURUM ::
#\[7]I3S4YSRI66FESSXCYCGNB65VFJLCKY25RZRWL2WCA3K2OBOLNIDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
