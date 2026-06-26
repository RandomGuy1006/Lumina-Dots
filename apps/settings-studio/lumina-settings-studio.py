#!/usr/bin/env python3
"""Lumina Settings Studio — v1.0 Appearance, Wallpaper, and Mood pages."""
from __future__ import annotations
import argparse, json, os, re, shutil, subprocess, sys
from collections import deque
from dataclasses import asdict, replace
from pathlib import Path
from typing import Any, Callable

APP_ROOT = Path(__file__).resolve().parents[1]; sys.path.insert(0, str(APP_ROOT / "lib"))
from lumina_core.app import LuminaApplication
from lumina_core.errors import DependencyUnavailable
from lumina_core.glass import GLASS_PRESETS, GlassConfig, GlassMode, apply_glass_layerrules, load_glass_config, save_glass_config
from lumina_core.ipc import emit_settings_changed
from lumina_core.mood import MOOD_PROFILES, Mood, apply_mood, current_mood
from lumina_core.schema import validate_config
from lumina_core.theme import regenerate_tokens
from lumina_core.toasts import LuminaToastOverlay, toast
from lumina_core.subprocesses import run_command
from lumina_core.wallpaper import generate_directory_thumbnails, wallpaper_candidates
from lumina_core.windows import close_on_escape

CONFIG_HOME = Path(os.environ.get("LUMINA_CONFIG_HOME", Path.home() / ".config/lumina"))
SCHEMA_HOME = Path(__file__).with_name("schemas")

DEFAULTS = {
    "appearance": {"icon_theme": "Adwaita", "cursor_theme": "Adwaita", "font": "Inter 11", "lock_screen": {"clock_style": "minimal", "auto_set_from_mood": True, "show_battery": True, "show_date": True, "blur_strength": 5}},
    "wallpaper": {"directory": str(Path.home() / "Pictures/Wallpapers"), "auto_rotate": False, "rotation_interval": 30, "animated": False, "transition": "fade", "transition_duration": 1.2},
    "mood": {"mood": "nature", "auto_detect": True, "auto_sound": False, "auto_clock": True, "auto_glass": True, "color_temperature": 5500},
    "palette-overrides": {"colors": {}},
}
PAGES = ("appearance", "wallpaper", "mood")

def validate_document(name: str, data: dict[str, Any]) -> None:
    validate_config(name, data)

def load_document(name: str) -> dict[str, Any]:
    try:
        loaded = json.loads((CONFIG_HOME / f"{name}.json").read_text(encoding="utf-8"))
        return {**DEFAULTS[name], **loaded}
    except (FileNotFoundError, OSError, json.JSONDecodeError, TypeError): return dict(DEFAULTS[name])

def write_document(name: str, data: dict[str, Any]) -> None:
    validate_document(name, data); CONFIG_HOME.mkdir(parents=True, exist_ok=True)
    path = CONFIG_HOME / f"{name}.json"; tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8"); os.replace(tmp, path); emit_settings_changed(name, data)

def lumina_command(name: str) -> list[str] | None:
    installed = shutil.which(name)
    if installed: return [installed]
    candidate = Path(__file__).resolve().parents[2] / "local-bin" / ".local" / "bin" / name
    if not candidate.exists(): return None
    return [sys.executable, str(candidate)] if os.name == "nt" else [str(candidate)]

def run_lumina(name: str, *args: str, timeout: float = 5) -> None:
    command = lumina_command(name)
    if command is None: return
    subprocess.Popen([*command, *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

class SettingsStudioApp(LuminaApplication):
    def __init__(self, page: str = "appearance", section: str = ""):
        self.initial_page, self.initial_section = page, section
        self.undo_stack: deque[tuple[str, dict[str, Any], str]] = deque(maxlen=10)
        self.documents = {name: load_document(name) for name in DEFAULTS}
        self.rows: list[tuple[Any, str, str]] = []
        self.pages: dict[str, Any] = {}
        self.stack: Any | None = None
        self.wallpaper_picker: Any | None = None
        super().__init__("lumina-settings-studio", "Lumina Settings")

    def _accessible(self, widget: Any, name: str, description: str) -> Any:
        try: widget.update_property([self.Gtk.AccessibleProperty.LABEL, self.Gtk.AccessibleProperty.DESCRIPTION], [name, description])
        except (AttributeError, TypeError): pass
        page = getattr(widget, "_lumina_page", "")
        self.rows.append((widget, f"{name} {description}".lower(), page)); return widget

    def _mark_page(self, widget: Any, page: str) -> Any:
        try: setattr(widget, "_lumina_page", page)
        except Exception: pass
        for index in range(len(self.rows) - 1, -1, -1):
            row_widget, text, page_name = self.rows[index]
            if row_widget is widget and not page_name:
                self.rows[index] = (row_widget, text, page)
                break
        return widget

    def _set_button_accessible(self, widget: Any, name: str, description: str) -> None:
        try: widget.update_property([self.Gtk.AccessibleProperty.LABEL, self.Gtk.AccessibleProperty.DESCRIPTION], [name, description])
        except (AttributeError, TypeError): pass

    def _change(self, document: str, key: str, value: Any, label: str, callback: Callable[[], None] | None = None) -> None:
        old = json.loads(json.dumps(self.documents[document])); new = {**old, key: value}
        try:
            write_document(document, new); self.undo_stack.append((document, old, label)); self.documents[document] = new
            if callback: callback()
            toast(f"{label} updated", category="success")
        except Exception as exc: toast(f"Error: {exc}", category="error")

    def _change_nested(self, document: str, parent: str, key: str, value: Any, label: str) -> None:
        old = json.loads(json.dumps(self.documents[document])); nested = {**old[parent], key: value}; new = {**old, parent: nested}
        try:
            write_document(document, new)
            if document == "appearance" and parent == "lock_screen":
                self._sync_lockscreen_to_hyprlock(nested)
            self.undo_stack.append((document, old, label)); self.documents[document] = new; toast(f"{label} updated", category="success")
        except Exception as exc: toast(f"Error: {exc}", category="error")

    def _sync_lockscreen_to_hyprlock(self, lock_cfg: dict[str, Any]) -> None:
        strength = max(0, min(10, int(lock_cfg.get("blur_strength", 5))))
        blur_size = int(round(strength * 1.6))
        blur_passes = 0 if strength == 0 else max(1, min(5, int(round(strength * 0.6))))
        path = Path.home() / ".config/hypr/hyprlock.conf"
        text = path.read_text(encoding="utf-8")
        replacements = {
            "blur_size": blur_size,
            "blur_passes": blur_passes,
        }
        for key, value in replacements.items():
            pattern = rf"^(\s*{key}\s*=\s*)\d+(\s*(?:#.*)?$)"
            text, count = re.subn(pattern, rf"\g<1>{value}\2", text, count=1, flags=re.MULTILINE)
            if count != 1:
                raise ValueError(f"hyprlock.conf missing unique {key} anchor")
        tmp = path.with_suffix(".conf.tmp")
        tmp.write_text(text, encoding="utf-8")
        tmp.replace(path)

    def _undo(self, *_args: Any) -> bool:
        if not self.undo_stack: return False
        document, old, label = self.undo_stack.pop()
        if document == "glass":
            restored = dict(old); restored["mode"] = GlassMode(restored["mode"]); cfg = GlassConfig(**restored); save_glass_config(cfg); apply_glass_layerrules(cfg)
        else:
            write_document(document, old); self.documents[document] = old
        toast(f"Reverted: {label}", category="success"); return True

    def _set_glass_property(self, key: str, value: float) -> None:
        cfg=load_glass_config(); old=asdict(cfg); old["mode"]=cfg.mode.value
        if key in {"blur_size","blur_passes"}: value=int(value)
        updated=replace(cfg,**{key:value}); payload=asdict(updated); payload["mode"]=updated.mode.value; validate_document("glass",payload); self.undo_stack.append(("glass",old,key.replace("_"," ").title())); save_glass_config(updated); run_lumina("lumina-glass","reload"); toast(f"{key.replace('_',' ').title()} updated",category="success")

    def _set_glass_flag(self, key: str, value: bool) -> None:
        cfg=load_glass_config(); old=asdict(cfg); old["mode"]=cfg.mode.value
        updated=replace(cfg,**{key:value}); payload=asdict(updated); payload["mode"]=updated.mode.value; validate_document("glass",payload); self.undo_stack.append(("glass",old,key.replace("_"," ").title())); save_glass_config(updated); run_lumina("lumina-glass","reload"); toast(f"{key.replace('_',' ').title()} updated",category="success")

    @staticmethod
    def _rgba_hex(rgba: Any) -> str:
        return f"#{round(rgba.red*255):02x}{round(rgba.green*255):02x}{round(rgba.blue*255):02x}"

    def _combo(self, title: str, values: list[str], selected: str, changed: Callable[[str], None], description: str) -> Any:
        row = self.Adw.ComboRow(title=title, model=self.Gtk.StringList.new(values)); row.set_selected(max(0, values.index(selected) if selected in values else 0))
        row.connect("notify::selected", lambda item, _p: changed(values[item.get_selected()])); return self._accessible(row, title, description)

    def _switch(self, title: str, active: bool, changed: Callable[[bool], None], description: str) -> Any:
        row = self.Adw.SwitchRow(title=title, active=active); row.connect("notify::active", lambda item, _p: changed(item.get_active())); return self._accessible(row, title, description)

    def appearance_page(self) -> Any:
        page = self.Adw.PreferencesPage(title="Appearance", name="appearance"); glass = self.Adw.PreferencesGroup(title="Glass")
        cfg = load_glass_config(); modes = [m.value for m in GlassMode]
        def set_glass(value: str) -> None:
            old=asdict(load_glass_config()); old["mode"]=load_glass_config().mode.value; selected = GLASS_PRESETS[GlassMode(value)]; payload=asdict(selected); payload["mode"]=value; validate_document("glass",payload)
            self.undo_stack.append(("glass",old,"Glass Mode")); save_glass_config(selected); run_lumina("lumina-glass","reload"); toast(f"Glass: {value} applied")
        glass.add(self._mark_page(self._combo("Glass Mode", modes, cfg.mode.value, set_glass, "Controls blur and opacity for all Lumina surfaces."), "appearance"))
        advanced = self.Adw.ExpanderRow(title="Advanced glass"); self._accessible(advanced, "Advanced glass", "Fine tune every schema-owned Glass Engine setting.")
        for title, key, value, lower, upper, step in (("Opacity","opacity",cfg.opacity,0,1,.01),("Blur","blur_size",cfg.blur_size,0,40,1),("Blur Passes","blur_passes",cfg.blur_passes,0,5,1),("Saturation","saturation",cfg.saturation,.8,2,.01),("Noise","noise",cfg.noise,0,.08,.001),("Brightness","brightness",cfg.brightness,.7,1.2,.01)):
            row = self.Adw.ActionRow(title=title); scale=self.Gtk.Scale.new(self.Gtk.Orientation.HORIZONTAL,self.Gtk.Adjustment(value,lower,upper,step,step*5,0)); self._set_button_accessible(scale,title,f"Adjust {title.lower()} from {lower:g} to {upper:g}."); scale.set_size_request(160,-1); scale.connect("value-changed",lambda item,k=key:self._set_glass_property(k,item.get_value())); row.add_suffix(scale); advanced.add_row(self._mark_page(self._accessible(row, title, f"Adjust {title.lower()} from {lower:g} to {upper:g}."), "appearance"))
        tint = self.Adw.EntryRow(title="Tint Color", text=cfg.tint_color); tint.connect("apply", lambda row:self._set_glass_property("tint_color", row.get_text()))
        advanced.add_row(self._mark_page(self._accessible(tint, "Tint Color", "Set the Glass Engine tint color as a hex value."), "appearance"))
        advanced.add_row(self._mark_page(self._switch("Performance Mode", cfg.performance_mode, lambda v:self._set_glass_flag("performance_mode",v), "Halve Glass Engine blur size and passes."), "appearance"))
        advanced.add_row(self._mark_page(self._switch("Battery Mode", cfg.battery_mode, lambda v:self._set_glass_flag("battery_mode",v), "Force effective minimal glass without changing the selected preset."), "appearance"))
        glass.add(advanced); page.add(glass)
        style = self.Adw.PreferencesGroup(title="Style")
        accent = self.Adw.ActionRow(title="Accent Color", subtitle="Derived from wallpaper; choose an override")
        if hasattr(self.Gtk,"ColorDialogButton"):
            color=self.Gtk.ColorDialogButton(dialog=self.Gtk.ColorDialog(title="Accent Color")); self._set_button_accessible(color,"Accent Color","Choose a manual accent color override."); color.connect("notify::rgba",lambda button,_p:self._change("palette-overrides","colors",{"primary":self._rgba_hex(button.get_rgba())},"Accent Color",lambda:regenerate_tokens(None,self.documents["palette-overrides"]))); accent.add_suffix(color)
        style.add(self._mark_page(self._accessible(accent, "Accent Color", "Override or regenerate the wallpaper-derived accent color."), "appearance"))
        discovered=sorted({p.name for root in (Path("/usr/share/icons"),Path.home()/".icons") if root.exists() for p in root.iterdir() if p.is_dir()}) or ["Adwaita"]
        style.add(self._mark_page(self._combo("Icon Theme", discovered, self.documents["appearance"]["icon_theme"], lambda v: self._change("appearance", "icon_theme", v, "Icon Theme",lambda:run_command(["gsettings","set","org.gnome.desktop.interface","icon-theme",v])), "Choose the desktop icon theme."), "appearance"))
        style.add(self._mark_page(self._combo("Cursor Theme", discovered, self.documents["appearance"]["cursor_theme"], lambda v: self._change("appearance", "cursor_theme", v, "Cursor Theme",lambda:run_command(["gsettings","set","org.gnome.desktop.interface","cursor-theme",v])), "Choose the pointer theme."), "appearance"))
        font = self.Adw.ActionRow(title="Font", subtitle=self.documents["appearance"]["font"])
        if hasattr(self.Gtk,"FontDialogButton"):
            font_button=self.Gtk.FontDialogButton(dialog=self.Gtk.FontDialog(title="Interface Font")); self._set_button_accessible(font_button,"Font","Choose the interface font."); font_button.connect("notify::font-desc",lambda button,_p:self._change("appearance","font",button.get_font_desc().to_string(),"Font",lambda:run_command(["gsettings","set","org.gnome.desktop.interface","font-name",button.get_font_desc().to_string()]))); font.add_suffix(font_button)
        style.add(self._mark_page(self._accessible(font, "Font", "Choose the interface font."), "appearance")); page.add(style)
        lock = self.Adw.PreferencesGroup(title="Lock Screen"); lock_cfg = self.documents["appearance"]["lock_screen"]
        lock.add(self._mark_page(self._combo("Clock Style", ["cyber", "minimal", "android", "terminal", "material", "windows"], lock_cfg["clock_style"], lambda v:self._change_nested("appearance","lock_screen","clock_style",v,"Clock Style"), "Choose the lock-screen clock layout."), "appearance"))
        lock.add(self._mark_page(self._switch("Auto-set from Mood", lock_cfg["auto_set_from_mood"], lambda v:self._change_nested("appearance","lock_screen","auto_set_from_mood",v,"Lock-screen mood sync"), "Allow the Mood Engine to choose the lock-screen clock style."), "appearance"))
        lock.add(self._mark_page(self._switch("Show battery", lock_cfg["show_battery"], lambda v:self._change_nested("appearance","lock_screen","show_battery",v,"Lock-screen battery"), "Display battery status on the lock screen."), "appearance")); lock.add(self._mark_page(self._switch("Show date", lock_cfg["show_date"], lambda v:self._change_nested("appearance","lock_screen","show_date",v,"Lock-screen date"), "Display the date on the lock screen."), "appearance"))
        blur = self.Adw.SpinRow.new(self.Gtk.Adjustment(lock_cfg["blur_strength"],0,10,1,1,0),1,0); blur.set_title("Blur strength"); blur.connect("notify::value",lambda row,_p:self._change_nested("appearance","lock_screen","blur_strength",int(row.get_value()),"Lock-screen blur")); lock.add(self._mark_page(self._accessible(blur, "Blur strength", "Lock-screen background blur from zero to ten."), "appearance")); page.add(lock); return page

    def wallpaper_page(self) -> Any:
        page=self.Adw.PreferencesPage(title="Wallpaper", name="wallpaper"); group=self.Adw.PreferencesGroup(title="Wallpaper Experience"); data=self.documents["wallpaper"]
        directory=self.Adw.EntryRow(title="Wallpaper directory", text=data["directory"])
        def directory_changed(row: Any) -> None:
            chosen = row.get_text(); self._change("wallpaper", "directory", chosen, "Wallpaper directory"); self._populate_wallpaper_picker(chosen)
        directory.connect("apply", directory_changed)
        folder= self.Gtk.Button(icon_name="folder-open-symbolic",tooltip_text="Choose wallpaper directory"); self._set_button_accessible(folder,"Choose wallpaper directory","Open a folder picker for wallpapers."); directory.add_suffix(folder)
        if hasattr(self.Gtk,"FileDialog"):
            dialog=self.Gtk.FileDialog(title="Wallpaper directory")
            def selected(d:Any,result:Any)->None:
                chosen=d.select_folder_finish(result).get_path(); directory.set_text(chosen); self._change("wallpaper","directory",chosen,"Wallpaper directory"); self._populate_wallpaper_picker(chosen)
            folder.connect("clicked",lambda *_:dialog.select_folder(self.window,None,selected))
        group.add(self._mark_page(self._accessible(directory,"Wallpaper directory","Folder containing wallpaper images."), "wallpaper"))
        interval=self.Adw.SpinRow.new(self.Gtk.Adjustment(data["rotation_interval"],5,1440,5,30,0),5,0); interval.set_title("Rotation Interval"); interval.set_visible(data["auto_rotate"]); interval.connect("notify::value",lambda row,_p:self._change("wallpaper","rotation_interval",int(row.get_value()),"Rotation Interval"))
        def rotate_changed(value:bool)->None:
            interval.set_visible(value); self._change("wallpaper","auto_rotate",value,"Auto-rotate",lambda:run_command(["systemctl","--user","enable" if value else "disable","--now","lumina-wallpaper-rotate.timer"]))
        group.add(self._mark_page(self._switch("Auto-rotate", data["auto_rotate"],rotate_changed,"Automatically rotate wallpapers using the user timer."), "wallpaper")); group.add(self._mark_page(self._accessible(interval,"Rotation Interval","Minutes between automatic wallpaper changes."), "wallpaper"))
        group.add(self._mark_page(self._switch("Animated wallpaper support",data["animated"],lambda v:self._change("wallpaper","animated",v,"Animated wallpaper support"),"Allow video wallpapers when supported."), "wallpaper"))
        group.add(self._mark_page(self._combo("Transition style",["fade","zoom","wipe","none"],data["transition"],lambda v:self._change("wallpaper","transition",v,"Transition style"),"Choose the wallpaper transition or disable motion."), "wallpaper"))
        duration=self.Adw.SpinRow.new(self.Gtk.Adjustment(float(data["transition_duration"]),0,5,.1,.5,0),.1,1); duration.set_title("Transition duration"); duration.connect("notify::value",lambda row,_p:self._change("wallpaper","transition_duration",round(float(row.get_value()),1),"Transition duration"))
        group.add(self._mark_page(self._accessible(duration,"Transition duration","Seconds for wallpaper transitions; reduced motion forces zero."), "wallpaper")); page.add(group)
        picker=self.Adw.ExpanderRow(title="Wallpaper picker", subtitle="Preview cached thumbnails from the wallpaper directory"); self.wallpaper_picker=picker; self._accessible(picker,"Wallpaper picker","Choose a wallpaper using thumbnail previews.")
        self._populate_wallpaper_picker(data["directory"]); preview_group=self.Adw.PreferencesGroup(title="Wallpaper Previews"); preview_group.add(self._mark_page(picker,"wallpaper")); page.add(preview_group); return page

    def _populate_wallpaper_picker(self, directory: str) -> None:
        picker = self.wallpaper_picker
        if picker is None: return
        try:
            while True:
                row = picker.get_row_at_index(0)
                if row is None: break
                picker.remove(row)
        except AttributeError:
            pass
        thumbnails = generate_directory_thumbnails(directory)
        candidates = wallpaper_candidates(directory)
        if not candidates:
            empty = self.Adw.ActionRow(title="No wallpapers found", subtitle=directory)
            picker.add_row(self._accessible(empty, "No wallpapers found", "The selected wallpaper directory has no supported images."))
            return
        for path in candidates:
            row = self.Adw.ActionRow(title=path.name, subtitle=str(path.parent)); row.set_activatable(True)
            thumb = thumbnails.get(str(path))
            if thumb and Path(thumb).exists():
                picture = self.Gtk.Picture.new_for_filename(thumb); picture.set_size_request(96,54); row.add_prefix(picture)
            button = self.Gtk.Button(icon_name="preferences-desktop-wallpaper-symbolic", tooltip_text="Apply wallpaper")
            self._set_button_accessible(button, f"Apply {path.name}", "Set this wallpaper through the Lumina wallpaper cascade.")
            button.connect("clicked", lambda _button, selected=str(path): run_lumina("lumina-wallpaper", selected))
            row.connect("activated", lambda _row, selected=str(path): run_lumina("lumina-wallpaper", selected))
            row.add_suffix(button); picker.add_row(self._accessible(row, path.name, "Wallpaper thumbnail preview and apply action."))

    def mood_page(self) -> Any:
        page=self.Adw.PreferencesPage(title="Mood",name="mood"); group=self.Adw.PreferencesGroup(title="Mood Engine"); data=self.documents["mood"]
        selected=current_mood(); current=self.Adw.ActionRow(title="Current Mood",subtitle=f"{MOOD_PROFILES[selected].emoji} {MOOD_PROFILES[selected].display_name}"); current.set_activatable(True); current.connect("activated",lambda *_:self._show_mood_picker(current)); group.add(self._mark_page(self._accessible(current,"Current Mood","Open an eight-card mood picker."), "mood"))
        temperature=self.Adw.SpinRow.new(self.Gtk.Adjustment(data["color_temperature"],2700,6500,100,500,0),100,0); temperature.set_title("Color temperature"); temperature.set_visible(not data["auto_detect"]); temperature.connect("notify::value",lambda row,_p:self._change("mood","color_temperature",int(row.get_value()),"Color temperature",lambda:regenerate_tokens(None,self.documents["palette-overrides"],int(row.get_value()))))
        def autodetect(value:bool)->None: temperature.set_visible(not value); self._change("mood","auto_detect",value,"Mood auto-detect")
        group.add(self._mark_page(self._switch("Auto-detect from wallpaper",data["auto_detect"],autodetect,"Choose a mood from the wallpaper palette in a background task."), "mood"))
        group.add(self._mark_page(self._switch("Auto-start ambient sound",data["auto_sound"],lambda v:self._change("mood","auto_sound",v,"Ambient sound"),"Start the configured mood sound when available."), "mood"))
        group.add(self._mark_page(self._switch("Auto-set clock style",data["auto_clock"],lambda v:self._change("mood","auto_clock",v,"Clock style"),"Coordinate the lock-screen clock with mood."), "mood"))
        group.add(self._mark_page(self._switch("Auto-adjust glass mode",data["auto_glass"],lambda v:self._change("mood","auto_glass",v,"Glass adjustment"),"Coordinate glass mode with mood."), "mood"))
        group.add(self._mark_page(self._accessible(temperature,"Color temperature","Manual color temperature from 2700 to 6500 Kelvin."), "mood")); page.add(group); return page

    def _show_mood_picker(self, current_row: Any) -> None:
        dialog=self.Adw.Dialog(title="Choose Mood"); grid=self.Gtk.Grid(column_spacing=8,row_spacing=8,margin_top=16,margin_bottom=16,margin_start=16,margin_end=16)
        for index,mood in enumerate(Mood):
            profile=MOOD_PROFILES[mood]; button=self.Gtk.Button(label=f"{profile.emoji}\n{profile.display_name}"); button.set_tooltip_text(f"{profile.display_name} mood: {profile.glass_mode.value} glass, {profile.sound_pack or 'no'} sounds, motion {profile.motion_speed:g}×")
            self._set_button_accessible(button, f"{profile.display_name} mood", f"Apply {profile.display_name} mood.")
            def choose(_button:Any, selected:Mood=mood, p:Any=profile)->None:
                old=dict(self.documents["mood"]); new={**old,"mood":selected.value,"color_temperature":p.color_temperature}
                try:
                    write_document("mood", new); self.undo_stack.append(("mood",old,"Mood")); self.documents["mood"]=new; apply_mood(selected,old["auto_sound"],old["auto_glass"],old["auto_clock"]); current_row.set_subtitle(f"{p.emoji} {p.display_name}"); dialog.close()
                except Exception as exc: toast(f"Error: {exc}", category="error")
            button.connect("clicked",choose); grid.attach(button,index%4,index//4,1,1)
        dialog.set_child(grid); dialog.present(self.window)

    def build(self, window: Any) -> None:
        close_on_escape(window)
        Gtk, Adw = self.Gtk, self.Adw; split=Adw.NavigationSplitView(); side_box=Gtk.Box(orientation=Gtk.Orientation.VERTICAL); search=Gtk.SearchEntry(placeholder_text="Search settings")
        self._set_button_accessible(search, "Search settings", "Filter visible settings by name or description.")
        sidebar=Gtk.ListBox(); side_box.append(sidebar); stack=Gtk.Stack(hexpand=True,vexpand=True); pages={"appearance":self.appearance_page(),"wallpaper":self.wallpaper_page(),"mood":self.mood_page()}; self.pages=pages; self.stack=stack
        for name,page in pages.items():
            row=Gtk.ListBoxRow(); row.set_child(Gtk.Label(label=name.title(),xalign=0)); row.page_name=name; sidebar.append(row); stack.add_named(page,name)
        def filter_settings(entry: Any) -> None:
            query = entry.get_text().strip().lower()
            first_page = None
            for widget, text, page_name in self.rows:
                visible = not query or query in text
                widget.set_visible(visible)
                if visible and query and first_page is None and page_name:
                    first_page = page_name
            if first_page:
                stack.set_visible_child_name(first_page)
        sidebar.connect("row-selected",lambda _box,row: stack.set_visible_child_name(row.page_name) if row else None); search.connect("search-changed",filter_settings)
        split.set_sidebar(Adw.NavigationPage.new(side_box,"Settings")); split.set_content(Adw.NavigationPage.new(stack,"Settings"))
        header=Adw.HeaderBar(); header.set_title_widget(search); content=Gtk.Box(orientation=Gtk.Orientation.VERTICAL); content.append(header); content.append(split)
        overlay=LuminaToastOverlay(content); window.set_content(overlay.widget); stack.set_visible_child_name(self.initial_page if self.initial_page in pages else "appearance")
        if self.initial_section:
            needle=self.initial_section.replace("-"," ").lower(); target=next((widget for widget,text,page_name in self.rows if needle in text and (not self.initial_page or page_name == self.initial_page)),None)
            if target is not None: target.grab_focus()
        undo=self.Gio.SimpleAction.new("undo",None); undo.connect("activate",self._undo); self.application.add_action(undo); self.application.set_accels_for_action("app.undo",["<Control>z"])

def main(argv: list[str]|None=None)->int:
    p=argparse.ArgumentParser(prog="lumina-settings-studio"); p.add_argument("--page",choices=PAGES,default="appearance"); p.add_argument("--section",default=""); p.add_argument("--validate",action="store_true"); args=p.parse_args(argv)
    if args.validate:
        for name in DEFAULTS: validate_document(name,load_document(name))
        print("Settings schemas valid"); return 0
    try:return SettingsStudioApp(args.page,args.section).run(sys.argv)
    except DependencyUnavailable: print(json.dumps({"page":args.page,"section":args.section,"mood":current_mood().value})); return 0
if __name__=="__main__":raise SystemExit(main())
