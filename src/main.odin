package main

import "core:log"
import "core:fmt"
import "core:time"
import "core:strings"
import "core:strconv"
import "core:reflect"
import "core:math"
import "core:math/linalg"

import sdl "vendor:sdl3"
import im "imgui"
import "imgui/imgui_impl_sdl3"
import "imgui/imgui_impl_sdlgpu3"

WINDOW_WIDTH  :: 1024
WINDOW_HEIGHT :: 768
ASPECT_RATIO  :: f32(WINDOW_WIDTH) / f32(WINDOW_HEIGHT)

DISABLE_DOCKING :: #config(DISABLE_DOCKING, false)

vec2 :: [2]f32
vec3 :: [3]f32
vec4 :: [4]f32
RGB  :: vec3
RGBA :: vec4
mat4 :: matrix[4,4]f32

Game_Memory :: struct {
  window:     ^sdl.Window              `hide`,
  device:     ^sdl.GPUDevice           `hide`,
  pipeline:   ^sdl.GPUGraphicsPipeline `hide`,
  im_context: ^im.Context              `hide`,

  proj_mat:       mat4 `hide`,
  last_ticks:     u64  `hide`,
  rotation:       f32  `min_max:"0,360" angle`,
  rotation_delta: f32  `min_max:"0,360" angle`,  // in radians
  fov:            f32  `min_max:"30,110" angle`, // in radians

  clear_color:     RGBA `spacing no_alpha`,
  show_imgui_demo: bool,
}

game_memory_default :: #force_inline proc() -> Game_Memory {
  return {
    rotation_delta = linalg.to_radians(f32(90)),
    fov            = linalg.to_radians(f32(70)),
    clear_color    = rgba(0x101010FF),
  }
}

// shader uniform buffer object struct
UBO :: struct #max_field_align(16) {
  mvp: mat4,
}

g_mem: ^Game_Memory

// MARK: tick
@(export)
game_tick :: proc() -> (quit: bool) {
  ticks           := sdl.GetTicks()
  delta_time      := f32(ticks - g_mem.last_ticks) / sdl.MS_PER_SECOND
  g_mem.last_ticks = ticks

  event: sdl.Event
  for sdl.PollEvent(&event) {
    imgui_impl_sdl3.ProcessEvent(&event)

    #partial switch event.type {
      case .QUIT:                                         return true
      case .KEY_DOWN: if event.key.scancode == .ESCAPE do return true
    }
  }

  // update
  g_mem.rotation = wrap_radians(g_mem.rotation + g_mem.rotation_delta * delta_time)
  g_mem.proj_mat = linalg.matrix4_perspective(g_mem.fov, ASPECT_RATIO, 0.001, 1000)

  // render
  cmd_buffer := sdl.AcquireGPUCommandBuffer(g_mem.device)
  swapchain_tex: ^sdl.GPUTexture

  assert(sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buffer, g_mem.window, &swapchain_tex, nil, nil))

  model_mat := linalg.matrix4_translate_f32({0, 0, -5}) * linalg.matrix4_rotate_f32(g_mem.rotation, {0, 1, 0})
  ubo := UBO{
    mvp = g_mem.proj_mat * model_mat,
  }

  if swapchain_tex != nil {
    // MARK: clear render pass
    {
      color_target := sdl.GPUColorTargetInfo{
        texture     = swapchain_tex,
        clear_color = cast(sdl.FColor) g_mem.clear_color,
        load_op     = .CLEAR,
        store_op    = .STORE,
      }

      render_pass := sdl.BeginGPURenderPass(cmd_buffer, &color_target, 1, nil)
      defer sdl.EndGPURenderPass(render_pass)

      sdl.BindGPUGraphicsPipeline(render_pass, g_mem.pipeline)
      sdl.PushGPUVertexUniformData(cmd_buffer, 0, &ubo, size_of(ubo))
      sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)
    }

    imgui_impl_sdlgpu3.NewFrame()
    imgui_impl_sdl3.NewFrame()
    im.NewFrame()

    if g_mem.show_imgui_demo {
      im.ShowDemoWindow()
    }

    ui_game_memory("Game Memory")
    // ui_render()

    im.Render()
    draw_data := im.GetDrawData()

    // MARK: imgui render pass
    {
      color_target := sdl.GPUColorTargetInfo{
        texture  = swapchain_tex,
        load_op  = .LOAD,
        store_op = .STORE,
      }

      imgui_impl_sdlgpu3.PrepareDrawData(draw_data, cmd_buffer)
      imgui_render_pass := sdl.BeginGPURenderPass(cmd_buffer, &color_target, 1, nil)
      defer sdl.EndGPURenderPass(imgui_render_pass)
      imgui_impl_sdlgpu3.RenderDrawData(draw_data, cmd_buffer, imgui_render_pass)
    }

    when !DISABLE_DOCKING {
      // backup_ctx := sdl.GL_GetCurrentContext()
      // im.UpdatePlatformWindows()
      // im.RenderPlatformWindowsDefault()
      // sdl.GL_MakeCurrent(g_mem.window, backup_ctx)
    }
  }

  assert(sdl.SubmitGPUCommandBuffer(cmd_buffer))

  return
}

@(export)
game_init :: proc() {
  if g_mem == nil {
    g_mem  = new(Game_Memory)
    g_mem^ = game_memory_default()
  }

  assert(sdl.Init({ .VIDEO }), "Could not init SDL3")
  when ODIN_DEBUG {
    sdl.SetLogPriorities(.VERBOSE)
    // use custom callback to make sdl call core:log
  }

  g_mem.last_ticks = sdl.GetTicks()

  g_mem.window = sdl.CreateWindow("title", WINDOW_WIDTH, WINDOW_HEIGHT, { .OPENGL, .RESIZABLE })
  assert(g_mem.window != nil, "Could not create window")

  g_mem.device = sdl.CreateGPUDevice({.SPIRV}, ODIN_DEBUG, nil)
  assert(g_mem.device != nil, "Could not create GPU device")

  assert(sdl.ClaimWindowForGPUDevice(g_mem.device, g_mem.window))

  VERT_SHADER_CODE :: #load("../shaders/shader.spv.vert")
  FRAG_SHADER_CODE :: #load("../shaders/shader.spv.frag")

  create_shader :: proc(
    device:             ^sdl.GPUDevice,
    code:                []u8,
    stage:               sdl.GPUShaderStage,
    num_uniform_buffers: u32,
  ) -> ^sdl.GPUShader {
    return sdl.CreateGPUShader(device, {
      code_size           = len(code),
      code                = raw_data(code),
      entrypoint          = "main",
      format              = {.SPIRV},
      stage               = stage,
      num_uniform_buffers = num_uniform_buffers,
    })
  }

  vert_shader := create_shader(g_mem.device, VERT_SHADER_CODE, .VERTEX, 1)
  frag_shader := create_shader(g_mem.device, FRAG_SHADER_CODE, .FRAGMENT, 0)

  g_mem.pipeline = sdl.CreateGPUGraphicsPipeline(g_mem.device, {
    vertex_shader   = vert_shader,
    fragment_shader = frag_shader,
    primitive_type  = .TRIANGLELIST,
    target_info     = {
      num_color_targets         = 1,
      color_target_descriptions = &(sdl.GPUColorTargetDescription{
        format = sdl.GetGPUSwapchainTextureFormat(g_mem.device, g_mem.window),
      }),
    },
  })

  sdl.ReleaseGPUShader(g_mem.device, vert_shader)
  sdl.ReleaseGPUShader(g_mem.device, frag_shader)

  // window_size: [2]i32
  // assert(sdl.GetWindowSize(g_mem.window, &window_size.x, &window_size.y))

  // aspect_ratio := f32(window_size.x) / f32(window_size.y)

  // MARK:init imgui
  im.CHECKVERSION()
  g_mem.im_context = im.CreateContext() // io.Fonts

  im.SetCurrentContext(g_mem.im_context)

  ROUNDING :: 4
  style := &g_mem.im_context.Style
  style.WindowRounding    = ROUNDING
  style.ChildRounding     = ROUNDING
  style.FrameRounding     = ROUNDING
  style.PopupRounding     = ROUNDING
  style.ScrollbarRounding = ROUNDING
  style.GrabRounding      = ROUNDING
  style.WindowTitleAlign  = {0.5, 0.5}

  io := im.GetIO()
  io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad}

  when !DISABLE_DOCKING {
    io.ConfigFlags += {.DockingEnable, .ViewportsEnable}

    style.Colors[im.Col.WindowBg].w = 1
  }

  // im.FontAtlas_AddFontFromFileTTF(io.Fonts, "assets/1980.ttf", 20.0)
  im.StyleColorsDark()

  // im.FontAtlas_Build(io.Fonts)

  imgui_impl_sdl3.InitForSDLGPU(g_mem.window)
  imgui_impl_sdlgpu3.Init(&(imgui_impl_sdlgpu3.Init_Info {
    Device            = g_mem.device,
    ColorTargetFormat = sdl.GetGPUSwapchainTextureFormat(g_mem.device, g_mem.window),
    MSAASamples       = ._1,
  }))
}

@(export)
game_shutdown :: proc() {
  free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
  defer sdl.Quit()
  defer sdl.DestroyWindow(g_mem.window)
  // defer sdl.GL_DestroyContext(g_mem.gl_context)
  // defer rl.Close()
  defer im.DestroyContext()
  defer imgui_impl_sdl3.Shutdown()
  defer imgui_impl_sdlgpu3.Shutdown()
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
  im.SetCurrentContext(g_mem.im_context)
}

@(export)
game_force_reload :: proc() -> bool {
  return im.IsKeyPressed(.F5, false)
  // return false
}

@(export)
game_force_restart :: proc() -> bool {
  return im.IsKeyPressed(.F6, false)
  // return false
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
ui_game_memory :: #force_inline proc(title: cstring) {
  if im.Begin(title) {
    for field in reflect.struct_fields_zipped(Game_Memory) {
      hide := strings.contains(cast(string)field.tag, "hide")
      if hide do continue

      disabled := strings.contains(cast(string)field.tag, "disabled")
      spacing  := strings.contains(cast(string)field.tag, "spacing")

      field_value := reflect.struct_field_value(&g_mem, field)
      field_ptr   := rawptr(uintptr(g_mem) + field.offset)
      field_name  := __(field.name)

      im.BeginDisabled(disabled); defer im.EndDisabled()
      if spacing do im.NewLine()

      #partial switch type in field.type.variant {
        case reflect.Type_Info_Integer:
          if _, ok := field_value.(u64); ok {
            im.InputInt(field_name, cast(^i32) field_ptr, flags = {.ReadOnly})
          }
        case reflect.Type_Info_Float:
          if _, ok := field_value.(f32); ok {
            slider := strings.contains(cast(string)field.tag, "slider")
            angle  := strings.contains(cast(string)field.tag, "angle")
            drag   := strings.contains(cast(string)field.tag, "drag")
            min, max: f32
 
            if value, ok := reflect.struct_tag_lookup(field.tag, "min_max"); ok {
              if res, err := strings.split(value, ",", context.temp_allocator); err == .None {
                if len(res) >= 2 {
                  min = cast(f32) strconv.atof(res[0])
                  max = cast(f32) strconv.atof(res[1])
                }
              }
            }

            ptr := cast(^f32) field_ptr
            // im.SetNextItemWidth(180)
            if drag {
              im.DragFloat(field_name, ptr, 1, min, max)
            } else if angle {
              im.SliderAngle(field_name, ptr, min, max)
            } else if slider {
              im.SliderFloat(field_name, ptr, min, max)
            } else {
              im.InputFloat(field_name, ptr)
            }
          }
        case reflect.Type_Info_Boolean:
          if _, ok := field_value.(bool); ok {
            im.Checkbox(field_name, cast(^bool) field_ptr)
          }
        case reflect.Type_Info_Array:
          if _, ok := field_value.([3]f32); ok {
            // RGB Color
            ptr := cast(^[3]f32) field_ptr
            im.ColorEdit3(field_name, ptr)
          } else if _, ok = field_value.([4]f32); ok {
            // RGBA Color
            no_alpha := strings.contains(cast(string)field.tag, "no_alpha")

            flags: im.ColorEditFlags
            if no_alpha do flags += {.NoAlpha}

            ptr := cast(^[4]f32) field_ptr
            im.ColorEdit4(field_name, ptr, flags)
          }
        // case reflect.Type_Info_Matrix:
        //   if _, ok := field_value.(mat4); ok {
        //     mat := cast(^mat4) field_ptr

        //     w := im.CalcItemWidth() / 4

        //     im.Text(field_name)
        //     for y in 0 ..< 4 {
        //       for x in 0 ..< 4 {
        //         im.PushIDInt(i32(x + y * 4))
        //         im.SetNextItemWidth(w)
        //         im.InputFloat("##", &mat[x][y])
        //         im.SameLine()
        //         im.PopID()
        //       }
        //       im.NewLine()
        //     }
        //   }
        case: im.Text("%s", field_name)
      }
    }
  }
  im.End()
}

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

// @MARK: util
__ :: proc(str: string) -> cstring {
  return strings.clone_to_cstring(str, context.temp_allocator)
}

rgba :: proc(color: u32) -> (out: RGBA) {
  out.r = f32((color >> 24) & 0xFF) / 255.0
  out.g = f32((color >> 16) & 0xFF) / 255.0
  out.b = f32((color >>  8) & 0xFF) / 255.0
  out.a = f32( color        & 0xFF) / 255.0
  return
}

wrap_radians :: proc(rad: f32) -> (wrapped: f32) {
  // return f32(linalg.mod(rad + linalg.TAU, 2 * linalg.TAU) - linalg.TAU)
  wrapped = linalg.mod(rad, linalg.TAU)
  if wrapped < 0 do wrapped += linalg.TAU
  return
}
