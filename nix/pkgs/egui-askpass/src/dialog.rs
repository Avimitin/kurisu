use std::{
    collections::VecDeque,
    path::{Path, PathBuf},
    process::Command,
    sync::mpsc,
    time::{Duration, Instant},
};

use crate::{
    caller_icon, process,
    prompt::{KeyIdentity, Kind},
    transport::{self, Event, Prompt},
    wayland_blur,
};
use anyhow::Result;
use eframe::egui::{
    self, Align2, Color32, FontData, FontDefinitions, FontFamily, FontId, Id, Key, Pos2, Rect,
    RichText, Stroke, StrokeKind, TextureHandle, Vec2, ViewportCommand, pos2, vec2,
};
use zeroize::{Zeroize, Zeroizing};

const SIZE: Vec2 = vec2(360., 384.);
const HANDOFF: Duration = Duration::from_millis(1200);
const TEXT: Color32 = Color32::from_rgb(245, 245, 247);

fn color(rgb: u32) -> Color32 {
    Color32::from_rgb((rgb >> 16) as u8, (rgb >> 8) as u8, rgb as u8)
}

fn input_id() -> Id {
    Id::unique("secret")
}

struct Dialog {
    server: Option<transport::Server>,
    blur: Option<wayland_blur::BackgroundBlur>,
    key: KeyIdentity,
    pin: Zeroizing<String>,
    kind: Kind,
    prompt: String,
    requester: String,
    app_icon_path: Option<PathBuf>,
    app_icon: Option<TextureHandle>,
    active: Option<Prompt>,
    queue: VecDeque<Prompt>,
    last_id: Option<u64>,
    close_at: Option<Instant>,
    focus_input: bool,
    events: mpsc::Receiver<Event>,
    fingerprint: TextureHandle,
    demo: bool,
}

impl Dialog {
    fn clear_input(&mut self, ctx: &egui::Context) {
        self.pin.zeroize();
        ctx.data_mut(|data| data.remove::<egui::text_edit::TextEditState>(input_id()));
    }

    fn show_prompt(&mut self, prompt: Prompt, ctx: &egui::Context) {
        if self.kind.interactive() && self.active.is_some() {
            self.queue.push_back(prompt);
            return;
        }
        self.clear_input(ctx);
        let mut key = KeyIdentity::from_prompt(&prompt.request.prompt);
        // Direct ssh includes a filename in the PIN prompt, while ssh-agent
        // includes the fingerprint. Carry the preceding touch identity forward.
        if prompt.request.kind == Kind::Pin
            && self.kind == Kind::Touch
            && self.prompt.starts_with("Confirm user presence for key ")
            && key.fingerprint.is_none()
            && key.kind == self.key.kind
        {
            key.fingerprint = self.key.fingerprint.clone();
        }
        // Only reuse a filename for a subsequent touch prompt when its key
        // fingerprint matches. A different key must not inherit the old name.
        if prompt.request.kind == Kind::Touch
            && key.kind == self.key.kind
            && key.fingerprint.is_some()
            && key.fingerprint == self.key.fingerprint
        {
            key.filename = self.key.filename.clone();
        }
        self.key = key;
        self.kind = prompt.request.kind;
        self.prompt = prompt.request.prompt.clone();
        self.requester = prompt.request.requester.clone();
        if self.app_icon_path != prompt.request.app_icon {
            self.app_icon_path = prompt.request.app_icon.clone();
            self.app_icon = self
                .app_icon_path
                .as_deref()
                .and_then(|path| load_app_icon(ctx, path));
        }
        self.last_id = Some(prompt.id);
        self.active = Some(prompt);
        self.close_at = None;
        self.focus_input = true;
        ctx.send_viewport_cmd(ViewportCommand::Focus);
    }

    fn event(&mut self, event: Event, ctx: &egui::Context) {
        match event {
            Event::Show(prompt) => self.show_prompt(prompt, ctx),
            Event::ParentExited => self.cancel(ctx),
            Event::Disconnected(id) if self.last_id == Some(id) => {
                self.active = None;
                self.clear_input(ctx);
                if !self.advance_pending(ctx) {
                    // OpenSSH may finish a notification just before asking for a PIN.
                    self.close_at = Some(Instant::now() + HANDOFF);
                }
            }
            Event::Disconnected(id) => self.queue.retain(|prompt| prompt.id != id),
        }
    }

    fn submit(&mut self, ctx: &egui::Context) {
        if !self.kind.interactive() {
            if self.demo {
                self.cancel(ctx);
            }
            return;
        }
        if self.kind == Kind::Pin && self.pin.is_empty() {
            return;
        }
        if let Some(prompt) = self.active.take() {
            prompt.respond(Some(if self.kind == Kind::Confirm {
                "yes"
            } else {
                &self.pin
            }));
        }
        self.clear_input(ctx);
        if self.advance_pending(ctx) {
            return;
        }
        if self.kind == Kind::Pin {
            self.kind = Kind::Touch;
            ctx.request_repaint();
        } else {
            self.retire();
            ctx.send_viewport_cmd(ViewportCommand::Close);
        }
    }

    fn advance_pending(&mut self, ctx: &egui::Context) -> bool {
        let Some(prompt) = self.queue.pop_front() else {
            return false;
        };
        self.show_prompt(prompt, ctx);
        true
    }

    fn cancel(&mut self, ctx: &egui::Context) {
        self.retire();
        if let Some(prompt) = self.active.take() {
            prompt.respond(None);
        }
        for prompt in self.queue.drain(..) {
            prompt.respond(None);
        }
        self.clear_input(ctx);
        ctx.send_viewport_cmd(ViewportCommand::Close);
    }

    fn retire(&self) {
        if let Some(server) = &self.server {
            server.retire();
        }
    }

    fn input_field(&mut self, ui: &mut egui::Ui) {
        let ctx = ui.ctx().clone();
        if self.focus_input {
            ctx.memory_mut(|memory| memory.request_focus(input_id()));
            self.focus_input = false;
        }
        if ctx.input_mut(|input| input.consume_key(egui::Modifiers::CTRL, Key::U)) {
            self.clear_input(&ctx);
        }
        let width = ui.available_width();
        let (field, _) = ui.allocate_exact_size(vec2(width, 32.), egui::Sense::hover());
        ui.painter()
            .rect_filled(field, 7., Color32::from_black_alpha(100));
        let focused = ctx.memory(|memory| memory.has_focus(input_id()));
        ui.painter().rect_stroke(
            field,
            7.,
            Stroke::new(1., color(if focused { 0x5288c5 } else { 0x656569 })),
            StrokeKind::Inside,
        );
        ui.put(
            field,
            egui::TextEdit::singleline(&mut *self.pin)
                .id(input_id())
                .password(true)
                .frame(egui::Frame::NONE.inner_margin(egui::Margin::symmetric(10, 5)))
                .return_key(None)
                .font(FontId::proportional(14.))
                .text_color(TEXT)
                .hint_text(if self.kind == Kind::Pin {
                    "PIN"
                } else {
                    "Password or passphrase"
                })
                .align(Align2::LEFT_CENTER)
                .desired_width(width)
                .min_size(field.size())
                .char_limit(1022),
        );
        // Password editing should not retain previous values in undo history.
        if let Some(mut state) = egui::text_edit::TextEditState::load(&ctx, input_id()) {
            state.clear_undoer();
            state.store(&ctx, input_id());
        }
        self.pin.retain(|ch| !ch.is_control());
        if self.pin.len() > 1022 {
            let mut end = 1022;
            while !self.pin.is_char_boundary(end) {
                end -= 1;
            }
            self.pin.truncate(end);
        }
    }

    fn icon(&self, ui: &egui::Ui, origin: Pos2, size: f32) {
        let painter = ui.painter();
        let center = origin + Vec2::splat(size * 0.45);
        painter.circle_filled(center, size * 0.45, color(0xededf0));
        let glyph = Rect::from_center_size(center, Vec2::splat(size * 0.7));
        if self.kind == Kind::Touch {
            let time = ui.input(|input| input.time) as f32;
            let opacity = 0.85 + 0.15 * (time * std::f32::consts::TAU / 1.8).cos();
            painter.image(
                self.fingerprint.id(),
                glyph,
                Rect::from_min_max(Pos2::ZERO, pos2(1., 1.)),
                Color32::WHITE.gamma_multiply(opacity),
            );
            ui.ctx().request_repaint_after(Duration::from_millis(33));
        } else {
            security_key(painter, glyph);
        }
        let badge =
            Rect::from_min_size(origin + Vec2::splat(size * 0.68), Vec2::splat(size * 0.32));
        painter.rect_filled(badge, size * 0.08, color(0x303136));
        painter.rect_stroke(
            badge,
            size * 0.08,
            Stroke::new(2., color(0xededf0)),
            StrokeKind::Inside,
        );
        if let Some(icon) = &self.app_icon {
            let scale = (badge.width() - 3.) / icon.size_vec2().max_elem();
            painter.image(
                icon.id(),
                Rect::from_center_size(badge.center(), icon.size_vec2() * scale),
                Rect::from_min_max(Pos2::ZERO, pos2(1., 1.)),
                Color32::WHITE,
            );
        } else {
            painter.text(
                badge.center(),
                Align2::CENTER_CENTER,
                ">_",
                FontId::proportional(size * 0.17),
                TEXT,
            );
        }
    }
}

impl eframe::App for Dialog {
    fn logic(&mut self, ctx: &egui::Context, _: &mut eframe::Frame) {
        if let Some(blur) = &mut self.blur {
            blur.dispatch();
        }
        while let Ok(event) = self.events.try_recv() {
            self.event(event, ctx);
        }
        if let Some(deadline) = self.close_at {
            if Instant::now() >= deadline {
                self.cancel(ctx);
            } else {
                ctx.request_repaint_after(deadline.saturating_duration_since(Instant::now()));
            }
        }
        if ctx.input(|input| input.viewport().close_requested()) {
            self.cancel(ctx);
        }
    }

    fn ui(&mut self, ui: &mut egui::Ui, _: &mut eframe::Frame) {
        let ctx = ui.ctx().clone();
        if ctx.input(|input| input.key_pressed(Key::Escape)) {
            self.cancel(&ctx);
            return;
        }
        let touch = self.kind == Kind::Touch;
        let specialized = matches!(self.kind, Kind::Pin | Kind::Touch);
        let has_icon = specialized || self.kind.input();
        let has_continue = self.kind.interactive() || (self.demo && touch);
        let panel = ui.max_rect();
        // Only the panel is translucent. Niri owns blur, outer corners and border.
        ui.painter()
            .rect_filled(panel, 0., Color32::from_rgba_unmultiplied(38, 35, 34, 210));
        let width = panel.width() - 48.;
        let message = if specialized {
            format!(
                "“{}” wants to use {}.",
                self.requester,
                self.key.description()
            )
        } else {
            self.prompt.clone()
        };
        let message = centered_text(ui, message, width - 12.);
        let instruction = specialized.then(|| {
            centered_text(
                ui,
                if touch {
                    "Touch your security key to allow this."
                } else {
                    "Enter your PIN to allow this."
                }
                .into(),
                width,
            )
        });
        let title_height = ui
            .painter()
            .layout_no_wrap(self.requester.clone(), bold_font(18.), TEXT)
            .size()
            .y;
        let controls_height = if self.kind.input() { 32. + 12. } else { 0. }
            + if has_continue { 36. + 8. } else { 0. }
            + 36.;
        let fixed_height = if has_icon { 72. + 12. } else { 0. }
            + title_height
            + 8.
            + instruction.as_ref().map_or(0., |text| 12. + text.size().y)
            + 12.
            + controls_height;
        let message_height = message
            .size()
            .y
            .min((panel.height() - 48. - fixed_height).max(18.));
        let content_height = fixed_height + message_height;
        let content = Rect::from_min_size(
            panel.min + vec2(24., ((panel.height() - content_height) * 0.5).max(24.)),
            vec2(width, content_height),
        );
        let mut submit = false;
        let mut dismiss = false;
        ui.scope_builder(
            egui::UiBuilder::new()
                .max_rect(content)
                .layout(egui::Layout::top_down(egui::Align::Center)),
            |ui| {
                ui.spacing_mut().item_spacing.y = 0.;
                if has_icon {
                    let (rect, _) = ui.allocate_exact_size(vec2(72., 72.), egui::Sense::hover());
                    self.icon(ui, rect.min, 72.);
                    ui.add_space(12.);
                }
                ui.add(
                    egui::Label::new(RichText::new(&self.requester).font(bold_font(18.)))
                        .truncate(),
                )
                .on_hover_text(&self.requester);
                ui.add_space(8.);
                // Only the message scrolls. Long names/fingerprints cannot push
                // the PIN field or buttons outside the fixed-size window.
                egui::ScrollArea::vertical()
                    .id_salt(("prompt", self.last_id, self.kind as u8))
                    .max_height(message_height)
                    .auto_shrink([false, true])
                    .show(ui, |ui| {
                        ui.add(egui::Label::new(message))
                            .on_hover_text(self.key.details());
                    });
                if let Some(instruction) = instruction {
                    ui.add_space(12.);
                    ui.add(egui::Label::new(instruction));
                }
                ui.add_space(12.);
                if self.kind.input() {
                    self.input_field(ui);
                    ui.add_space(12.);
                }
                if has_continue {
                    let (rect, _) = ui.allocate_exact_size(vec2(width, 36.), egui::Sense::hover());
                    submit = dialog_button(
                        ui,
                        rect,
                        if touch {
                            "Simulate touch"
                        } else if self.kind == Kind::Pin {
                            "Confirm"
                        } else if self.kind == Kind::Confirm {
                            "Allow"
                        } else {
                            "Continue"
                        },
                        true,
                        self.kind != Kind::Pin || !self.pin.is_empty(),
                    );
                    ui.add_space(8.);
                }
                let (rect, _) = ui.allocate_exact_size(vec2(width, 36.), egui::Sense::hover());
                dismiss = dialog_button(
                    ui,
                    rect,
                    if self.kind.interactive() {
                        "Cancel"
                    } else {
                        "Dismiss"
                    },
                    false,
                    true,
                );
            },
        );
        if dismiss {
            self.cancel(&ctx);
        } else if submit || ctx.input(|input| input.key_pressed(Key::Enter)) {
            self.submit(&ctx);
        }
    }

    fn clear_color(&self, _: &egui::Visuals) -> [f32; 4] {
        Color32::TRANSPARENT.to_normalized_gamma_f32()
    }
}

fn centered_text(ui: &egui::Ui, text: String, width: f32) -> std::sync::Arc<egui::Galley> {
    let mut job = egui::text::LayoutJob::simple(text, FontId::proportional(15.), TEXT, width);
    job.halign = egui::Align::Center;
    ui.painter().layout_job(job)
}

fn bold_font(size: f32) -> FontId {
    FontId::new(size, FontFamily::Name("dialog-bold".into()))
}

fn load_app_icon(ctx: &egui::Context, path: &Path) -> Option<TextureHandle> {
    let metadata = std::fs::metadata(path).ok()?;
    if !metadata.is_file() || metadata.len() > 4 * 1024 * 1024 {
        return None;
    }
    let mut reader = image::ImageReader::open(path).ok()?;
    let mut limits = image::Limits::default();
    limits.max_image_width = Some(2048);
    limits.max_image_height = Some(2048);
    reader.limits(limits);
    let image = reader.decode().ok()?.thumbnail(96, 96).into_rgba8();
    Some(ctx.load_texture(
        "caller-app",
        egui::ColorImage::from_rgba_unmultiplied(
            [image.width() as usize, image.height() as usize],
            image.as_raw(),
        ),
        egui::TextureOptions::LINEAR,
    ))
}

fn dialog_button(ui: &mut egui::Ui, rect: Rect, label: &str, primary: bool, enabled: bool) -> bool {
    ui.scope_builder(egui::UiBuilder::new().max_rect(rect), |ui| {
        if !enabled {
            ui.disable();
        }
        let fill = if primary {
            color(if enabled { 0x3478d5 } else { 0x354b65 })
        } else {
            Color32::from_white_alpha(48)
        };
        ui.put(
            rect,
            egui::Button::new(RichText::new(label).font(bold_font(14.)).color(if enabled {
                TEXT
            } else {
                color(0x8a99ac)
            }))
            .fill(fill)
            .stroke(Stroke::new(
                1.,
                if primary {
                    color(0x4b88d9)
                } else {
                    Color32::from_white_alpha(32)
                },
            ))
            .corner_radius(8.),
        )
        .clicked()
    })
    .inner
}

// The same flat security-key geometry as the original SVG, painted directly to
// avoid bringing in an SVG renderer for this one small icon.
fn security_key(painter: &egui::Painter, rect: Rect) {
    let rotate = |point: Pos2| {
        let point = point - pos2(50., 50.);
        let (sin, cos) = (-std::f32::consts::PI / 6.).sin_cos();
        rect.center()
            + vec2(point.x * cos - point.y * sin, point.x * sin + point.y * cos)
                * (rect.width() / 100.)
    };
    let rounded = |min: Pos2, size: Vec2, radius: f32, fill: Color32| {
        let max = min + size;
        let mut points = Vec::new();
        for (center, start) in [
            (pos2(max.x - radius, min.y + radius), -90.),
            (max - Vec2::splat(radius), 0.),
            (pos2(min.x + radius, max.y - radius), 90.),
            (min + Vec2::splat(radius), 180.),
        ] {
            for step in 0..=6 {
                let angle = (start + step as f32 * 15.).to_radians();
                points.push(rotate(center + vec2(angle.cos(), angle.sin()) * radius));
            }
        }
        painter.add(egui::Shape::convex_polygon(points, fill, Stroke::NONE));
    };
    rounded(pos2(37., 7.), vec2(26., 25.), 3., color(0xa9afb8));
    rounded(pos2(42., 13.), vec2(5., 7.), 0., color(0x626975));
    rounded(pos2(53., 13.), vec2(5., 7.), 0., color(0x626975));
    rounded(pos2(31., 28.), vec2(38., 62.), 10., color(0x323640));
    painter.circle_filled(rotate(pos2(50., 49.)), rect.width() * 0.1, color(0xd8bd79));
    painter.circle_filled(
        rotate(pos2(50., 78.)),
        rect.width() * 0.045,
        color(0xededf0),
    );
}

fn configure_fonts(ctx: &egui::Context) {
    let mut fonts = FontDefinitions::default();
    let proportional = fonts.families[&FontFamily::Proportional].clone();
    fonts
        .families
        .insert(FontFamily::Name("dialog-bold".into()), proportional);
    for (name, query, family, weight) in [
        (
            "dialog-text",
            "sans-serif:weight=regular",
            FontFamily::Proportional,
            400.,
        ),
        (
            "dialog-bold",
            "sans-serif:weight=bold",
            FontFamily::Name("dialog-bold".into()),
            700.,
        ),
    ] {
        // Respect the system fontconfig sans-serif choice.
        let Ok(output) = Command::new("fc-match")
            .args(["-f", "%{file}\n%{index}", query])
            .output()
        else {
            continue;
        };
        if !output.status.success() {
            continue;
        }
        let matched = String::from_utf8_lossy(&output.stdout);
        let mut lines = matched.lines();
        let Some(path) = lines.next() else { continue };
        let Ok(bytes) = std::fs::read(path) else {
            continue;
        };
        let mut font = FontData::from_owned(bytes);
        font.index = lines
            .next()
            .and_then(|index| index.parse::<u32>().ok())
            .unwrap_or(0)
            & 0xffff;
        // Fontconfig's high index bits encode a variable-font named instance,
        // not a collection face. Select weight through egui's variation API.
        font.tweak.coords.push(b"wght", weight);
        fonts.font_data.insert(name.into(), font.into());
        fonts
            .families
            .entry(family)
            .or_default()
            .insert(0, name.into());
    }
    ctx.set_fonts(fonts);
}

pub fn preview() -> Result<()> {
    run_ui(None)
}

pub fn run(
    server: transport::Server,
    events: mpsc::Receiver<Event>,
    initial: Prompt,
) -> Result<()> {
    run_ui(Some((server, events, initial)))
}

fn run_ui(session: Option<(transport::Server, mpsc::Receiver<Event>, Prompt)>) -> Result<()> {
    let (server, events, initial) = match session {
        Some((server, events, initial)) => (Some(server), Some(events), Some(initial)),
        None => (None, None, None),
    };
    let demo = server.is_none();
    let fingerprint =
        image::load_from_memory(include_bytes!("../assets/fingerprint.png"))?.into_rgba8();
    let image = egui::ColorImage::from_rgba_unmultiplied(
        [fingerprint.width() as usize, fingerprint.height() as usize],
        fingerprint.as_raw(),
    );
    let options = eframe::NativeOptions {
        renderer: eframe::Renderer::Glow,
        viewport: egui::ViewportBuilder::default()
            .with_app_id("egui-askpass")
            .with_title(if demo {
                "Security key — Preview"
            } else {
                "Security key"
            })
            .with_inner_size(SIZE)
            .with_min_inner_size(SIZE)
            .with_max_inner_size(SIZE)
            .with_resizable(false)
            .with_maximize_button(false)
            .with_minimize_button(false)
            .with_decorations(false)
            .with_transparent(true),
        centered: true, // Used on X11; Wayland placement belongs to the compositor.
        persist_window: false,
        ..Default::default()
    };
    let result = eframe::run_native(
        "egui-askpass",
        options,
        Box::new(move |cc| {
            let mut visuals = egui::Visuals::dark();
            visuals.override_text_color = Some(TEXT);
            cc.egui_ctx.set_visuals(visuals);
            configure_fonts(&cc.egui_ctx);
            let (sender, receiver) = mpsc::channel();
            if let Some(events) = events {
                let ctx = cc.egui_ctx.clone();
                std::thread::spawn(move || {
                    while let Ok(event) = events.recv() {
                        if sender.send(event).is_err() {
                            break;
                        }
                        ctx.request_repaint();
                    }
                });
            }
            let blur = cc
                .winit_window()
                .cloned()
                .and_then(|window| wayland_blur::BackgroundBlur::new(window).ok().flatten());
            let app_icon_path = if demo {
                caller_icon::for_parent()
            } else {
                None
            };
            let app_icon = app_icon_path
                .as_deref()
                .and_then(|path| load_app_icon(&cc.egui_ctx, path));
            let mut dialog = Dialog {
                server,
                blur,
                key: if demo {
                    KeyIdentity::from_prompt("Enter PIN for ED25519-SK key ~/.ssh/id_ed25519_sk: ")
                } else {
                    KeyIdentity::default()
                },
                pin: Zeroizing::new(String::new()),
                kind: Kind::Pin,
                prompt: String::new(),
                requester: if demo {
                    process::parent_name()
                } else {
                    String::new()
                },
                app_icon_path,
                app_icon,
                active: None,
                queue: VecDeque::new(),
                last_id: None,
                close_at: None,
                focus_input: true,
                events: receiver,
                fingerprint: cc.egui_ctx.load_texture(
                    "fingerprint",
                    image,
                    egui::TextureOptions::LINEAR
                        .with_mipmap_mode(Some(egui::TextureFilter::Linear)),
                ),
                demo,
            };
            if let Some(prompt) = initial {
                dialog.show_prompt(prompt, &cc.egui_ctx);
            }
            Ok(Box::new(dialog))
        }),
    );
    result.map_err(|error| anyhow::anyhow!("could not run the askpass window: {error}"))
}
