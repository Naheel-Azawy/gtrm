using Gtk;
using Vte;
using Pango;

class MainWindow : Gtk.Window {

	// options
	public string[]        trm_args;
	public string          dims          = "85x20";
	public bool            transparent   = false;
	public bool            oncursor      = false;
	public bool            stay          = true;
	public bool            floating      = false;
	public Vte.CursorShape cursor        = Vte.CursorShape.BLOCK;
	public string          font_name     = "monospace";
	public float           font_size     = 12;

	private Vte.Terminal trm;
	private float        font_size_cur;

	public MainWindow() {
		var shell = Environment.get_variable("SHELL");
		if (shell == null) {
			shell = "bash";
		}
		this.trm_args = new string[]{shell};
	}

	public void build() {
		// load font from env
		var font = GLib.Environment.get_variable("FONT_SIZE");
		if (font != null && font.length > 0) {
			var font_sp = font.split(":size=");
			if (font_sp.length == 2) {
				this.font_name = font_sp[0];
				this.font_size = float.parse(font_sp[1]);
			}
		}
		this.font_size_cur = this.font_size;

		// transparent window
		var screen = this.get_screen();
		if (this.transparent) {
			var visual = screen.get_rgba_visual();
			if (visual != null && screen.is_composited())
				this.set_visual(visual);
		}
		this.set_app_paintable(true);

		// container
		var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		box.set_property("name", "maincontainer");
		this.add(box);

		// terminal
		this.trm = new Vte.Terminal();
		box.pack_start(this.trm, true, true, 0);
		this.trm.bold_is_bright      = true;
		this.trm.enable_bidi         = false;
		this.trm.enable_sixel        = true;
		this.trm.cursor_shape        = this.cursor; // BLOCK, IBEAM, UNDERLINE
		this.trm.cursor_blink_mode   = Vte.CursorBlinkMode.OFF; // SYSTEM, ON, OFF
		this.trm.scroll_on_output    = true;
		this.trm.scroll_on_keystroke = true;
		this.trm.scrollback_lines    = 0;
		this.trm.set_clear_background(false);
		this.set_font();

		// colors
		var fg = Gdk.RGBA();
		var bg = Gdk.RGBA();
		var palette = new Gdk.RGBA[16];
		fg.parse("#ffffff");
		bg.parse("#000000");
		palette[ 0].parse("#000000");
		palette[ 1].parse("#b90101");
		palette[ 2].parse("#01b901");
		palette[ 3].parse("#b9b901");
		palette[ 4].parse("#0101d7");
		palette[ 5].parse("#b901b9");
		palette[ 6].parse("#01b9b9");
		palette[ 7].parse("#cfcfcf");
		palette[ 8].parse("#747474");
		palette[ 9].parse("#e60101");
		palette[10].parse("#01e601");
		palette[11].parse("#e6e601");
		palette[12].parse("#5454e6");
		palette[13].parse("#e601e6");
		palette[14].parse("#01e6e6");
		palette[15].parse("#e6e6e6");
		this.trm.set_colors(fg, bg, palette);

		// css
		var provider = new Gtk.CssProvider();
		try {
			var css = "#maincontainer { background-color: rgba(0, 0, 0, 0.5); }";
			provider.load_from_data(css, css.length);
			Gtk.StyleContext.add_provider_for_screen(
				screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
		} catch (Error e) {
			stderr.printf("Failed loading CSS\n");
		}

		// signals
		this.destroy.connect(Gtk.main_quit);
		this.key_press_event.connect(this.on_key_press);
		this.focus_out_event.connect(this.on_focus_out);
		this.trm.child_exited.connect(Gtk.main_quit);
		this.trm.window_title_changed.connect(() => this.title = this.trm.window_title);

		// size
		string[] sp = this.dims.split("x");
		this.trm.set_size(int.parse(sp[0]), int.parse(sp[1]));

		// location
		if (this.oncursor) {
			this.window_position = Gtk.WindowPosition.MOUSE;
		} else {
			this.window_position = Gtk.WindowPosition.CENTER;
		}
	}

	private bool on_key_press(Gtk.Widget self, Gdk.EventKey ev) {
		var k     = ev.keyval;
		var ctrl  = (ev.state & Gdk.ModifierType.CONTROL_MASK) != 0;
        var shift = (ev.state & Gdk.ModifierType.SHIFT_MASK)   != 0;

		if (k == Gdk.Key.Escape && !this.stay) {
			// quit
			Gtk.main_quit();
			return true;

		} else if ((k == Gdk.Key.Page_Up && ctrl && shift) ||
				   (k == Gdk.Key.plus && ctrl)) {
			// zoom in
			this.font_size_cur += 1;
			this.set_font();
			return true;

		} else if ((k == Gdk.Key.Page_Down && ctrl && shift) ||
				   (k == Gdk.Key.minus && ctrl)) {
			// zoom out
			this.font_size_cur -= 1;
			this.set_font();
			return true;

		} else if (k == Gdk.Key.equal && ctrl) {
			// zoom reset
			this.font_size_cur = this.font_size;
			this.set_font();
			return true;

		} else if (k == Gdk.Key.H && ctrl) {
			// copy html
			this.trm.copy_clipboard_format(Vte.Format.HTML);
			return true;

		} else if (k == Gdk.Key.C && ctrl) {
			// copy
			this.trm.copy_clipboard_format(Vte.Format.TEXT);
			return true;

		} else if (k == Gdk.Key.V && ctrl) {
			// paste
			this.trm.paste_clipboard();
			return true;

		}

		return false;
	}

	private bool on_focus_out(Gtk.Widget self, Gdk.EventFocus ev) {
		if (!this.stay)
			Gtk.main_quit();
		return false;
	}

	private void set_font() {
		var font = Pango.FontDescription.from_string(this.font_name);
		font.set_size((int) this.font_size_cur * Pango.SCALE);
		this.trm.set_font(font);
	}

	public new void show() {
		this.trm.spawn_async(
			Vte.PtyFlags.DEFAULT, // PtyFlags pty_flags
			null,                 // string? working_directory
			this.trm_args,        // string[] argv
			null,                 // string[]? envv
			0,                    // SpawnFlags spawn_flags
			null,                 // owned SpawnChildSetupFunc? child_setup
			-1,                   // int timeout
			null,                 // Cancellable? cancellable
			null);                //TerminalSpawnAsyncCallback? callback

		if (this.floating) {
			this.resizable = false;
			this.show_all();
			this.resizable = true; // to stay floating in a tiling wm
		} else {
			this.show_all();
		}
	}
}

void args_help(string[] args) {
	print("usage: %s [OPTION]...\n", args[0]);
	print("\n");
	print("Options:\n");
	print("  -d, --dims STR     terminal dimensions in characters\n");
	print("  -f, --float        floating window\n");
	print("  -c, --oncursor     floating window located at the current mouse position\n");
	print("  -t, --transparent  transparent window\n");
	print("  -p, --pop STR      pop up window\n");
	print("  -s, --sh STR       run commands in /bin/sh -c\n");
	print("  -e [ARG]...        run commands in args\n");
	print("      --help         show this help\n");
}

bool args_parse(MainWindow win, string[] args) {
	for (int i = 1; i < args.length; ++i) {
		switch (args[i]) {
		case "--dims":
		case "-d":
			win.dims = args[++i];
			break;

		case "--float":
		case "-f":
			win.floating = true;
			break;

		case "--oncursor":
		case "-c":
			win.floating = true;
			win.oncursor = true;
			break;

		case "--pop":
		case "-p":
			win.stay        = false;
			win.floating    = true;
			win.transparent = true;
			win.cursor      = Vte.CursorShape.IBEAM;
			win.trm_args = {"sh", "-c", args[++i] + ";read"};
			break;

		case "--transparent":
		case "-t":
			win.transparent = true;
			break;

		case "--sh":
		case "-s":
			win.trm_args = {"sh", "-c", args[++i]};
			break;

		case "-e":
			win.trm_args = new string[]{};
			++i;
			for (; i < args.length; ++i) {
				win.trm_args += args[i];
			}
			break;

		default:
			args_help(args);
			return false;
		}
	}

	return true;
}

int main (string[] args) {
	Gtk.init(ref args);

	var win = new MainWindow();

	if (!args_parse(win, args)) {
		return 1;
	}

	win.build();
	win.show();
	Gtk.main();

    return 0;
}