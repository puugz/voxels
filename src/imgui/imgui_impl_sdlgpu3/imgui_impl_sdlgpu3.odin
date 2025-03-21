package imgui_impl_sdlgpu3

import imgui "../"
import sdl "vendor:sdl3"

when      ODIN_OS == .Windows { foreign import lib "../imgui_windows_x64.lib" }
else when ODIN_OS == .Linux   { foreign import lib "../imgui_linux_x64.a" }
else when ODIN_OS == .Darwin  {
  when ODIN_ARCH == .amd64 { foreign import lib "../imgui_darwin_x64.a" } else { foreign import lib "../imgui_darwin_arm64.a" }
}

// imgui_impl_sdlgpu3.h
// Last checked (2db3e9d)
Init_Info :: struct {
  Device:            ^sdl.GPUDevice,       // = nullptr
  ColorTargetFormat: sdl.GPUTextureFormat, // = SDL_GPU_TEXTUREFORMAT_INVALID
  MSAASamples:       sdl.GPUSampleCount,   // = SDL_GPU_SAMPLECOUNT_1
}

@(link_prefix="ImGui_ImplSDLGPU3_")
foreign lib {
  Init            :: proc(info: ^Init_Info) -> bool ---
  Shutdown        :: proc() ---
  NewFrame        :: proc() ---
  PrepareDrawData :: proc(draw_data: ^imgui.DrawData, command_buffer: ^sdl.GPUCommandBuffer) ---
  RenderDrawData  :: proc(draw_data: ^imgui.DrawData, command_buffer: ^sdl.GPUCommandBuffer, render_pass: ^sdl.GPURenderPass, pipeline: ^sdl.GPUGraphicsPipeline = nil) ---

  CreateDeviceObjects  :: proc() ---
  DestroyDeviceObjects :: proc() ---
  CreateFontsTexture   :: proc() ---
  DestroyFontsTexture  :: proc() ---
}
