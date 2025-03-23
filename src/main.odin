package main

import "core:log"
import "core:fmt"
import "core:mem"
import "core:time"
import "core:strings"
import "core:strconv"
import "core:reflect"
import "core:math"
import "core:math/linalg"

import stbi "vendor:stb/image"

import sdl "vendor:sdl3"
import im "imgui"
import "imgui/imgui_impl_sdl3"
import "imgui/imgui_impl_sdlgpu3"

// @TODO: https://www.gafferongames.com/post/fix_your_timestep/

WINDOW_WIDTH  :: 1024
WINDOW_HEIGHT :: 768

DISABLE_DOCKING :: #config(DISABLE_DOCKING, false)

vec2 :: [2]f32
vec3 :: [3]f32
vec4 :: [4]f32
RGB  :: vec3
RGBA :: vec4
mat4 :: matrix[4,4]f32

WORLD_RIGHT   :: vec3{1, 0,  0}
WORLD_UP      :: vec3{0, 1,  0}
WORLD_FORWARD :: vec3{0, 0, -1}

SDL_MOUSEKEY_COUNT :: 6

Game_Memory :: struct {
  window:     ^sdl.Window              `hide`,
  device:     ^sdl.GPUDevice           `hide`,
  pipeline:   ^sdl.GPUGraphicsPipeline `hide`,
  im_context: ^im.Context              `hide`,

  vertex_buf: ^sdl.GPUBuffer  `hide`,
  index_buf:  ^sdl.GPUBuffer  `hide`,
  texture:    ^sdl.GPUTexture `hide`,
  sampler:    ^sdl.GPUSampler `hide`,

  proj_mat:       mat4 `hide`,
  last_ticks:     u64  `hide`,
  rotation:       f32  `min_max:"0,360" angle`,
  rotation_delta: f32  `min_max:"0,360" angle`,  // in radians
  fov:            f32  `min_max:"30,110" angle`, // in radians

  clear_color:     RGBA `spacing no_alpha`,
  show_imgui_demo: bool,

  camera:       Camera,
  mouse_locked: bool `hide`,
  delta_time:   f32  `hide`,

  // input state
  key_down:   #sparse[sdl.Scancode]bool `hide`,
  mouse_down: [SDL_MOUSEKEY_COUNT]bool `hide`,
  mouse_pos:  vec2 `spacing read_only`,

  using frame: struct {
    key_pressed:    #sparse[sdl.Scancode]bool `hide`,
    key_released:   #sparse[sdl.Scancode]bool `hide`,
    mouse_pressed:  [SDL_MOUSEKEY_COUNT]bool `hide`,
    mouse_released: [SDL_MOUSEKEY_COUNT]bool `hide`,
    scroll_delta:   f32  `read_only`,
    mouse_delta:    vec2 `read_only`,
  },
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
  g_mem.frame = {}

  ticks           := sdl.GetTicks()
  g_mem.delta_time = f32(ticks - g_mem.last_ticks) / sdl.MS_PER_SECOND
  g_mem.last_ticks = ticks

  event: sdl.Event
  for sdl.PollEvent(&event) {
    if event.type == .QUIT do return true
    if event.type == .KEY_DOWN && event.key.scancode == .ESCAPE {
      g_mem.mouse_locked = !g_mem.mouse_locked
      _ = sdl.SetWindowRelativeMouseMode(g_mem.window, g_mem.mouse_locked)
    }

    process_input_events(&event)
    if !g_mem.mouse_locked do imgui_impl_sdl3.ProcessEvent(&event)
  }

  window_size: [2]i32
  sdl.GetWindowSize(g_mem.window, &window_size.x, &window_size.y)

  aspect_ratio := f32(window_size.x) / f32(window_size.y)

  // update
  g_mem.rotation = wrap_radians(g_mem.rotation + g_mem.rotation_delta * g_mem.delta_time)
  g_mem.proj_mat = linalg.matrix4_perspective(g_mem.fov, aspect_ratio, 0.001, 1000)

  update_camera(&g_mem.camera)

  // render
  cmd_buffer := sdl.AcquireGPUCommandBuffer(g_mem.device)
  swapchain_tex: ^sdl.GPUTexture

  assert(sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buffer, g_mem.window, &swapchain_tex, nil, nil))

  view_mat  := linalg.matrix4_look_at_f32(g_mem.camera.position, g_mem.camera.position + g_mem.camera.direction, WORLD_UP)
  model_mat := linalg.matrix4_translate_f32({0, 0, 0}) * linalg.matrix4_rotate_f32(g_mem.rotation, WORLD_UP)
  ubo := UBO{
    mvp = g_mem.proj_mat * view_mat * model_mat,
  }

  if swapchain_tex != nil {
    // MARK: render pass
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
      sdl.BindGPUVertexBuffers(render_pass, 0, &(sdl.GPUBufferBinding{ buffer = g_mem.vertex_buf }), 1)
      sdl.BindGPUIndexBuffer(render_pass, { buffer = g_mem.index_buf }, ._16BIT)
      sdl.PushGPUVertexUniformData(cmd_buffer, 0, &ubo, size_of(ubo))
      sdl.BindGPUFragmentSamplers(render_pass, 0, &(sdl.GPUTextureSamplerBinding{
        texture = g_mem.texture,
        sampler = g_mem.sampler,
      }), 1)
      sdl.DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0)
    }

    imgui_impl_sdlgpu3.NewFrame()
    imgui_impl_sdl3.NewFrame()
    im.NewFrame()

    if g_mem.show_imgui_demo {
      im.ShowDemoWindow()
    }

    ui_game_memory("Game Memory")

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

// MARK: init
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
    num_samplers:        u32,
  ) -> ^sdl.GPUShader {
    return sdl.CreateGPUShader(device, {
      code_size           = len(code),
      code                = raw_data(code),
      entrypoint          = "main",
      format              = {.SPIRV},
      stage               = stage,
      num_uniform_buffers = num_uniform_buffers,
      num_samplers        = num_samplers,
    })
  }

  vert_shader := create_shader(g_mem.device, VERT_SHADER_CODE, .VERTEX,   num_uniform_buffers = 1, num_samplers = 0)
  frag_shader := create_shader(g_mem.device, FRAG_SHADER_CODE, .FRAGMENT, num_uniform_buffers = 0, num_samplers = 1)

  TEXTURE_BYTES :: #load("../res/texture.jpg")

  image_size: [2]i32
  pixels := stbi.load_from_memory(raw_data(TEXTURE_BYTES), cast(i32) len(TEXTURE_BYTES), &image_size.x, &image_size.y, nil, 4)
  pixels_bytes := image_size.x * image_size.y * 4
  assert(pixels != nil)

  g_mem.texture = sdl.CreateGPUTexture(g_mem.device, {
    format = .R8G8B8A8_UNORM,
    usage  = {.SAMPLER},
    width  = u32(image_size.x),
    height = u32(image_size.y),
    layer_count_or_depth = 1,
    num_levels           = 1,
  })

  tex_transfer_buf := sdl.CreateGPUTransferBuffer(g_mem.device, {
    usage = .UPLOAD,
    size  = u32(pixels_bytes),
  })
  assert(tex_transfer_buf != nil)

  tex_transfer_mem := cast([^]byte)sdl.MapGPUTransferBuffer(g_mem.device, tex_transfer_buf, false)
  mem.copy(tex_transfer_mem, pixels, int(pixels_bytes))

  stbi.image_free(pixels)

  // describe vertex attributes and vertex buffers in the pipeline
  Vertex :: struct {
    pos:   vec3,
    color: RGB,
    uv:    vec2,
  }

  vertices := []Vertex {
    { pos = {-.5,  .5, 0}, color = {1, 0, 0}, uv = {0, 0} }, // tl
    { pos = { .5,  .5, 0}, color = {0, 1, 0}, uv = {1, 0} }, // tr
    { pos = {-.5, -.5, 0}, color = {0, 0, 1}, uv = {0, 1} }, // bl
    { pos = { .5, -.5, 0}, color = {1, 1, 0}, uv = {1, 1} }, // br
  }
  vertices_bytes := len(vertices) * size_of(vertices[0])

  g_mem.vertex_buf = sdl.CreateGPUBuffer(g_mem.device, {
    usage = {.VERTEX},
    size  = u32(vertices_bytes),
  })
  assert(g_mem.vertex_buf != nil)

  indices := []u16 {
    0, 1, 2,
    2, 1, 3,
  }
  indices_bytes := len(indices) * size_of(indices[0])

  g_mem.index_buf = sdl.CreateGPUBuffer(g_mem.device, {
    usage = {.INDEX},
    size  = u32(indices_bytes),
  })
  assert(g_mem.index_buf != nil)

  // upload vertex data to vertex buffer
  // * create transfer buffer (cpu -> gpu)
  transfer_buf := sdl.CreateGPUTransferBuffer(g_mem.device, {
    usage = .UPLOAD,
    size  = u32(vertices_bytes + indices_bytes), // +indices
  })
  assert(transfer_buf != nil)

  // * map transfer buffer memory & copy from cpu
  transfer_mem := cast([^]byte) sdl.MapGPUTransferBuffer(g_mem.device, transfer_buf, false)
  mem.copy(transfer_mem, raw_data(vertices), vertices_bytes)
  mem.copy(transfer_mem[vertices_bytes:], raw_data(indices), indices_bytes)
  sdl.UnmapGPUTransferBuffer(g_mem.device, transfer_buf)

  // * begin copy pass
  {
    copy_cmd_buf := sdl.AcquireGPUCommandBuffer(g_mem.device)
    defer assert(sdl.SubmitGPUCommandBuffer(copy_cmd_buf))

    copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
    defer sdl.EndGPUCopyPass(copy_pass)

    // upload vertices
    sdl.UploadToGPUBuffer(
      copy_pass,
      { transfer_buffer = transfer_buf },
      { buffer = g_mem.vertex_buf, size = u32(vertices_bytes) },
      false,
    )

    // upload indices
    sdl.UploadToGPUBuffer(
      copy_pass,
      { transfer_buffer = transfer_buf, offset = u32(vertices_bytes) },
      { buffer = g_mem.index_buf, size = u32(indices_bytes) },
      false,
    )

    sdl.UploadToGPUTexture(
      copy_pass,
      { transfer_buffer = tex_transfer_buf },
      { texture = g_mem.texture, w = u32(image_size.x), h = u32(image_size.y), d = 1 },
      false,
    )

    // * end copy pass and submit
  }

  sdl.ReleaseGPUTransferBuffer(g_mem.device, transfer_buf)
  sdl.ReleaseGPUTransferBuffer(g_mem.device, tex_transfer_buf)

  g_mem.sampler = sdl.CreateGPUSampler(g_mem.device, {})

  vertex_attrs := []sdl.GPUVertexAttribute {
    {
      // position attr
      location = 0,
      format   = .FLOAT3,
      offset   = u32(offset_of(Vertex, pos)),
    },
    {
      // color attr
      location = 1,
      format   = .FLOAT3,
      offset   = u32(offset_of(Vertex, color)),
    },
    {
      // uv attr
      location = 2,
      format   = .FLOAT2,
      offset   = u32(offset_of(Vertex, uv)),
    },
  }

  g_mem.pipeline = sdl.CreateGPUGraphicsPipeline(g_mem.device, {
    vertex_shader      = vert_shader,
    fragment_shader    = frag_shader,
    primitive_type     = .TRIANGLELIST,
    vertex_input_state = {
      num_vertex_buffers         = 1,
      vertex_buffer_descriptions = &(sdl.GPUVertexBufferDescription {
        slot = 0,
        pitch = size_of(Vertex),
      }),
      num_vertex_attributes = u32(len(vertex_attrs)),
      vertex_attributes     = raw_data(vertex_attrs),
    },
    target_info = {
      num_color_targets         = 1,
      color_target_descriptions = &(sdl.GPUColorTargetDescription{
        format = sdl.GetGPUSwapchainTextureFormat(g_mem.device, g_mem.window),
      }),
    },
  })

  sdl.ReleaseGPUShader(g_mem.device, vert_shader)
  sdl.ReleaseGPUShader(g_mem.device, frag_shader)

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

  // MARK: init camera
  g_mem.mouse_locked = true
  init_camera(&g_mem.camera)
}

@(export)
game_shutdown :: proc() {
  free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
  defer sdl.Quit()
  defer sdl.DestroyWindow(g_mem.window)
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
  return key_pressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
  return key_pressed(.F6)
}

// // @MARK: ui_render
ui_game_memory :: #force_inline proc(title: cstring) {
  if im.Begin(title) {
    for field in reflect.struct_fields_zipped(Game_Memory) {
      hide := strings.contains(cast(string)field.tag, "hide")
      if hide do continue

      read_only := strings.contains(cast(string)field.tag, "read_only")
      spacing   := strings.contains(cast(string)field.tag, "spacing")

      field_value := reflect.struct_field_value(&g_mem, field)
      field_ptr   := rawptr(uintptr(g_mem) + field.offset)
      field_name  := __(field.name)

      im.BeginDisabled(read_only); defer im.EndDisabled()
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
          } else if _, ok = field_value.(vec2); ok {
            ptr := cast(^vec2) field_ptr

            w := im.CalcItemWidth() / 2 - 10
            im.Text(field_name)

            im.SetNextItemWidth(w)
            im.DragFloat("x", &ptr.x, format = "%.1f")

            im.SameLine()

            im.SetNextItemWidth(w)
            im.DragFloat("y", &ptr.y, format = "%.1f")
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
        // case: im.Text("%s", field_name)
      }
    }
  }
  im.End()
}

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
