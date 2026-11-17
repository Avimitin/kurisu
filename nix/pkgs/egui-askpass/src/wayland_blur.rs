//! Request the same compositor blur protocol as Kitty. Winit 0.30 only exposes
//! KDE blur, so use its public native handles without patching the toolkit.

use std::sync::Arc;

use anyhow::Result;
use raw_window_handle::{HasDisplayHandle, HasWindowHandle, RawDisplayHandle, RawWindowHandle};
use wayland_client::{
    Connection, Dispatch, EventQueue, Proxy, QueueHandle, WEnum,
    backend::{Backend, ObjectId},
    delegate_noop,
    globals::{GlobalListContents, registry_queue_init},
    protocol::{
        wl_compositor::WlCompositor, wl_region::WlRegion, wl_registry, wl_surface::WlSurface,
    },
};
use wayland_protocols::ext::background_effect::v1::client::{
    ext_background_effect_manager_v1::{self, ExtBackgroundEffectManagerV1},
    ext_background_effect_surface_v1::ExtBackgroundEffectSurfaceV1,
};
use winit::window::Window;

pub struct BackgroundBlur {
    effect: ExtBackgroundEffectSurfaceV1,
    manager: ExtBackgroundEffectManagerV1,
    connection: Connection,
    events: EventQueue<BlurEvents>,
    state: BlurEvents,
    // Keep the borrowed display/surface alive until all Wayland objects above
    // have been dropped. Struct fields are dropped in declaration order.
    _window: Arc<Window>,
}

impl BackgroundBlur {
    pub fn new(window: Arc<Window>) -> Result<Option<Self>> {
        let (RawDisplayHandle::Wayland(display), RawWindowHandle::Wayland(surface)) = (
            window.display_handle()?.as_raw(),
            window.window_handle()?.as_raw(),
        ) else {
            return Ok(None);
        };
        // SAFETY: these are Winit's live libwayland handles. The retained Arc
        // keeps them alive; this guest backend never disconnects Winit's display.
        let backend = unsafe { Backend::from_foreign_display(display.display.as_ptr().cast()) };
        let connection = Connection::from_backend(backend);
        let (globals, mut events) = registry_queue_init::<BlurEvents>(&connection)?;
        let handle = events.handle();
        let Ok(manager) = globals.bind::<ExtBackgroundEffectManagerV1, _, _>(&handle, 1..=1, ())
        else {
            return Ok(None);
        };
        let mut state = BlurEvents::default();
        events.roundtrip(&mut state)?;
        if !state.supported {
            manager.destroy();
            connection.flush()?;
            return Ok(None);
        }
        let compositor: WlCompositor = globals.bind(&handle, 1..=1, ())?;
        // SAFETY: borrowing the existing wl_surface does not take ownership or
        // replace Winit's event handlers. The window outlives this proxy.
        let surface_id =
            unsafe { ObjectId::from_ptr(WlSurface::interface(), surface.surface.as_ptr().cast())? };
        let surface = WlSurface::from_id(&connection, surface_id)?;
        let effect = manager.get_background_effect(&surface, &handle, ());
        let region = compositor.create_region(&handle, ());
        let size = window.inner_size().to_logical::<i32>(window.scale_factor());
        region.add(0, 0, size.width, size.height);
        effect.set_blur_region(Some(&region));
        region.destroy();
        // The region is copied by the compositor and takes effect with Winit's
        // next surface commit. Do not commit or destroy Winit's surface here.
        connection.flush()?;
        Ok(Some(Self {
            effect,
            manager,
            connection,
            events,
            state,
            _window: window,
        }))
    }

    pub fn dispatch(&mut self) {
        // Winit reads the shared display. Drain only this extension's event queue.
        let _ = self.events.dispatch_pending(&mut self.state);
    }
}

impl Drop for BackgroundBlur {
    fn drop(&mut self) {
        self.effect.destroy();
        self.manager.destroy();
        let _ = self.connection.flush();
    }
}

#[derive(Default)]
struct BlurEvents {
    supported: bool,
}

impl Dispatch<ExtBackgroundEffectManagerV1, ()> for BlurEvents {
    fn event(
        state: &mut Self,
        _: &ExtBackgroundEffectManagerV1,
        event: ext_background_effect_manager_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let ext_background_effect_manager_v1::Event::Capabilities { flags } = event {
            state.supported = matches!(flags, WEnum::Value(flags) if flags.contains(ext_background_effect_manager_v1::Capability::Blur));
        }
    }
}

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for BlurEvents {
    fn event(
        _: &mut Self,
        _: &wl_registry::WlRegistry,
        _: wl_registry::Event,
        _: &GlobalListContents,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

delegate_noop!(BlurEvents: ignore WlCompositor);
delegate_noop!(BlurEvents: ignore WlRegion);
delegate_noop!(BlurEvents: ignore ExtBackgroundEffectSurfaceV1);
