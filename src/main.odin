package main

import "core:fmt"
import "core:time"
import "core:strings"
// import "core:math/linalg"

// import rl "vendor:raylib/rlgl"
import sdl "vendor:sdl3"
// import im "imgui"
// import imgui_impl_sdl3 "imgui/sdl3"
// import imgui_impl_opengl3 "imgui/opengl3"

WINDOW_WIDTH  :: 1024
WINDOW_HEIGHT :: 768

DISABLE_DOCKING :: #config(DISABLE_DOCKING, false)

vec2 :: [2]f32
vec3 :: [2]f32

Game_Memory :: struct {
  window:     ^sdl.Window,
  gl_context: sdl.GLContext,
  // im_ctx:     ^im.Context,
  test: int,
}

g_mem: ^Game_Memory

@(export)
game_tick :: proc() -> bool {
  event: sdl.Event
  for sdl.PollEvent(&event) {
    #partial switch event.type {
      case .QUIT:                                         return false
      case .KEY_DOWN: if event.key.scancode == .ESCAPE do return false
    }

    // imgui_impl_sdl3.ProcessEvent(&event)
  }

  // imgui_impl_opengl3.NewFrame()
  // imgui_impl_sdl3.NewFrame()
  // im.NewFrame()

  // ui_render()

  // im.Render()
  // imgui_impl_opengl3.RenderDrawData(im.GetDrawData())

  // when !DISABLE_DOCKING {
  //   backup_ctx := sdl.GL_GetCurrentContext()
  //   im.UpdatePlatformWindows()
  //   im.RenderPlatformWindowsDefault()
  //   sdl.GL_MakeCurrent(g_mem.window, backup_ctx)
  // }

  sdl.GL_SwapWindow(g_mem.window)

  return true
}

@(export)
game_init :: proc() {
  if g_mem == nil {
    g_mem = new(Game_Memory)
  }

  assert(sdl.Init({ .VIDEO }), "Could not init SDL3")

  sdl.GL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, cast(i32) sdl.GL_CONTEXT_PROFILE_CORE)
  sdl.GL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, 4)
  sdl.GL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, 3)
  sdl.SetHint(sdl.HINT_MOUSE_FOCUS_CLICKTHROUGH, "1")

  g_mem.window = sdl.CreateWindow("title", WINDOW_WIDTH, WINDOW_HEIGHT, { .OPENGL, .RESIZABLE })
  assert(g_mem.window != nil, "Could not create window")

  g_mem.gl_context = sdl.GL_CreateContext(g_mem.window)

  // rl.LoadExtensions(cast(rawptr)sdl.GL_GetProcAddress)
  // rl.Init(WINDOW_WIDTH, WINDOW_HEIGHT)

  // rl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
  // rl.MatrixMode(rl.PROJECTION)
  // rl.LoadIdentity()
  // rl.Ortho(0, WINDOW_WIDTH, WINDOW_HEIGHT, 0, 0, 1)
  // rl.MatrixMode(rl.MODELVIEW)
  // rl.LoadIdentity()

  // MARK:init imgui
  // im.CHECKVERSION()
  // g_mem.im_ctx = im.CreateContext() // io.Fonts

  // im.SetCurrentContext(g_mem.im_ctx)

  // style := &g_mem.im_ctx.Style
  // style.WindowRounding    = 4
  // style.FrameRounding     = 4
  // style.ChildRounding     = 4
  // style.ScrollbarRounding = 4
  // style.WindowTitleAlign  = {0.5, 0.5}
  // // style.WindowBorderSize = 0

  // io := im.GetIO()
  // io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad}

  // when !DISABLE_DOCKING {
  //   io.ConfigFlags += {.DockingEnable, .ViewportsEnable}

  //   style.Colors[im.Col.WindowBg].w = 1
  // }

  // // im.FontAtlas_AddFontFromFileTTF(io.Fonts, "assets/1980.ttf", 20.0)
  // im.StyleColorsDark()

  // // im.FontAtlas_Build(io.Fonts)

  // imgui_impl_sdl3.InitForOpenGL(g_mem.window, g_mem.gl_context)
  // imgui_impl_opengl3.Init()
}

@(export)
game_shutdown :: proc() {
  free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
  defer sdl.Quit()
  defer sdl.DestroyWindow(g_mem.window)
  defer sdl.GL_DestroyContext(g_mem.gl_context)
  // defer rl.Close()
  // defer im.DestroyContext()
  // defer imgui_impl_sdl3.Shutdown()
  // defer imgui_impl_opengl3.Shutdown()
}

@(export)
game_memory :: proc() -> rawptr {
  return g_mem
}

@(export)
game_memory_size :: proc() -> int {
  return size_of(Game_Memory)
}

@(export)
game_hot_reload :: proc(mem: rawptr) {
  g_mem = (^Game_Memory)(mem)

  // Here you can also set your own global variables. A good idea is to make
  // your global variables into pointers that point to something inside
  // `g_mem`.
  // im.SetCurrentContext(g_mem.im_ctx)
}

@(export)
game_force_reload :: proc() -> bool {
  // return im.IsKeyPressed(.F5, false)
  return false
}

@(export)
game_force_restart :: proc() -> bool {
  // return im.IsKeyPressed(.F6, false)
  return false
}

// World :: struct {
//   name:        string,
//   last_played: string,
//   created_at:  string,
//   size:        string,
//   favorite:    bool,
// }

// @(rodata)
// WORLDS : []World =
// {
//   { "1121",          "Today, 09:44",     "Today, 13:05",     "121 MB", true  },
//   { "aaa",           "2022/10/16 18:01", "2022/10/16 18:01", "0 B",    true  },
//   { "aaaaaaaaaaaa",  "2022/10/17 22:45", "2022/10/17 22:43", "372 MB", true  },
//   { "ccccc",         "2022/11/01 17:40", "2022/10/31 21:38", "220 MB", true  },
//   { "33333",         "Today, 10:12",     "Today, 10:12",     "0 B",    false },
//   { "q",             "2022/10/14 03:52", "2022/10/14 03:52", "0 B",    false },
//   { "aaaaaaaaaaaaa", "2022/10/14 03:52", "2022/10/14 02:58", "1 GB",   false },
//   { "d",             "2022/10/16 18:06", "2022/10/16 18:06", "1 GB",   false },
//   { "da",            "2022/10/16 02:31", "2022/10/16 02:31", "0 B",    false },
//   { "dada",          "2022/10/16 02:35", "2022/10/16 02:35", "0 B",    false },
// }

// // @MARK: ui_render
// ui_render :: proc() {
//   im.ShowDemoWindow()
//   im.ShowStyleEditor(nil)

//   display_size := im.GetIO().DisplaySize

//   window_size := im.Vec2{display_size.x * 0.63, display_size.y * 0.66}
//   im.SetNextWindowSize(window_size, .Always)

//   // window_pos := im.Vec2{(display_size.x - window_size.x) * 0.5, (display_size.y - window_size.y) * 0.5}
//   // im.SetNextWindowPos(window_pos, .Always)

//   @(static)
//   buf: [256]byte

//   // im.PushStyleVarImVec2(.WindowTitleAlign, {0.5, 0.5}); defer im.PopStyleVar()

//   // 30px high window title
//   // 10px padding
//   // 30px search box
//   // 10px padding
//   // world table // 25px table header

//   @(static)
//   selected_item := -1
//   @(static)
//   last_click_time: time.Time

//   if im.Begin("Controls", nil, { .NoCollapse, .NoTitleBar }) {
//     content_size := im.GetContentRegionAvail()
//     any_selected := selected_item != -1

//     if im.Button("Create New", {content_size.x, 40}) {
//       if im.BeginPopupModal("Create New World", nil, {}) {
//         im.Text("balls")
//         im.EndPopup()
//       }
//     }

//     im.BeginDisabled(!any_selected)
//     if im.Button("Load World",   {content_size.x, 40}) {}
//     if im.Button("Rename World", {content_size.x, 40}) {}
//     if im.Button("Delete World", {content_size.x, 40}) {}
//     im.EndDisabled()

//     if im.Button("Back", {content_size.x, 40}) {
//       selected_item = -1
//     }

//     im.End()
//   }

//   if im.Begin("Select World", nil, { .NoCollapse, .NoMove, .NoResize, .NoScrollbar, .NoTitleBar }) {
//     defer im.End()

//     // window_size := im.GetWindowSize()
//     content_size := im.GetContentRegionAvail()

//     im.SetNextItemWidth(content_size.x)
//     im.InputTextWithHint("##World_Search", "Search...", cstring(raw_data(buf[:])), len(buf))
//     // im.Separator()

//     // im.SetNextItemWidth(content_size.x)
//     // im.SetNextWindowSize({content_size.x, content_size.y * 0.9}, .Always)
//     // im.SetNextWindowSize({600, 200}, .Always)

//     if im.BeginChild("List", {}, {.Borders}) {
//       defer im.EndChild()

//       content_size = im.GetContentRegionAvail()

//       for world, idx in WORLDS {
//         im.PushIDInt(cast(i32) idx);    defer im.PopID()
//         if idx > 0 && idx < len(WORLDS) do im.Separator()

//         pos := im.GetItemRectMin()
//         size := im.Vec2{}
//         // size := im.GetItemRectSize()
//         size.x = content_size.x
//         size.y = 50

//         // double-click
//         is_selected := selected_item == idx
//         if im.Selectable("##test", is_selected, {.AllowDoubleClick}, size) {
//           now := time.now()
//           if is_selected && time.diff(last_click_time, now) > 250 * time.Millisecond {
//             fmt.println("DOUBLE CLICK")
//           }
//           selected_item = idx
//           last_click_time = now
//         }

//         draw_list := im.GetWindowDrawList()
//         // im.DrawList_AddRect(draw_list, pos, pos + size, im.GetColorU32(.Border), 5, {}, 2)

//         {
//           cy := im.GetCursorPosY(); defer im.SetCursorPosY(cy)
//           cx := im.GetCursorPosX(); defer im.SetCursorPosY(cx)
//           im.SetCursorPosY(cy - 43)
//           im.SetCursorPosX(cx + 10)

//           im.TextColored({1,1,1,1}, temp_cstr(world.name))
//           im.SetCursorPosX(cx + 10)
//           im.TextColored({0.5, 0.51, 0.56, 1}, temp_cstr(world.last_played))
//         }
//       }
//     }

//     // flags := im.TableFlags_Borders | im.TableFlags_RowBg |
//     //          im.TableFlags_Sortable | im.TableFlags_ScrollY

//     // if im.BeginTable("##world_table", 4, flags) {
//     //   im.TableSetupColumn("Name", {})        // .45
//     //   im.TableSetupColumn("Last played", {}) // .26
//     //   im.TableSetupColumn("Created at", {})  // .19
//     //   im.TableSetupColumn("Size", {})        // .08
//     //   im.TableSetupScrollFreeze(0, 1)
//     //   im.TableHeadersRow()
      
//     //   for &world, idx in WORLDS {
//     //     im.TableNextRow()
        
//     //     im.TableSetColumnIndex(0)
//     //     {
//     //       im.PushIDInt(cast(i32) idx); defer im.PopID()
//     //       im.PushStyleColor(.FrameBg, 0x00000000); defer im.PopStyleColor()
//     //       im.Checkbox("##", &world.favorite); im.SameLine()
//     //       im.Text("%s", world.name) // Unicode star
//     //     }
        
//     //     im.TableSetColumnIndex(1)
//     //     im.Text("%s", world.last_played)
        
//     //     im.TableSetColumnIndex(2)
//     //     im.Text("%s", world.created_at)
        
//     //     im.TableSetColumnIndex(3)
//     //     im.Text("%s", world.size)
//     //   }
//     //   im.EndTable()
//     // }
  
//     // im.Spacing()
//     // im.Separator()
//     // im.Spacing()

//     // im.SetCursorPosX((window_size.x - (5 * 110)) * 0.5)
//   }
// }

// // @MARK: util
// temp_cstr :: proc(str: string) -> cstring {
//   return strings.clone_to_cstring(str, context.temp_allocator)
// }
