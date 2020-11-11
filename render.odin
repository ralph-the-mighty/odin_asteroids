package main

import "core:math/linalg"
import "core:math"
import sdl "shared:odin-sdl2"
import sdl_ttf "shared:odin-sdl2/ttf"
// import sdl_image "shared:odin-sdl2/image"
import "core:mem"
import "core:strings"



translate :: proc(origin, point: linalg.Vector2) -> linalg.Vector2 {
  return point + origin;
}

rotate :: proc(angle: f32, point: linalg.Vector2) -> linalg.Vector2 {
  result: linalg.Vector2 = ---;
  result.x = point.x * math.cos(angle) - point.y * math.sin(angle);
  result.y = point.x * math.sin(angle) + point.y * math.cos(angle);
  return result;
}


transform :: proc(angle: f32, origin, point: linalg.Vector2) -> linalg.Vector2 {
  return translate(origin, rotate(angle, point));
}




draw_rect :: proc(surface: ^sdl.Surface, rx, ry, rw, rh: i32, r, g, b: u32) {
    
  row: ^u8 = cast(^u8)surface.pixels;
    for y in 0..<surface.h {
      pixel := cast(^u32)row;
      for x in 0..<surface.w {
        if x >= rx && x <= rx + rw && y >= ry && y <= ry + rh {
          pixel^ = (b) | (g << 8) | (r << 16);
        }
       pixel = mem.ptr_offset(pixel, 1);
      }
      row = mem.ptr_offset(row, int(surface.pitch));
    }
}



plot_point :: proc(surface: ^sdl.Surface, px, py: i32, r, g, b: u32){
    
    x := px;
    y := py;

    if x < 0 do x += SCREEN_WIDTH;
    if y < 0 do y += SCREEN_HEIGHT;
    
    if x >= SCREEN_WIDTH  do x -= SCREEN_WIDTH;
    if y >= SCREEN_HEIGHT do y -= SCREEN_HEIGHT;

    pixel_ptr := mem.ptr_offset(cast(^u32)surface.pixels, int((y * surface.pitch / 4) + x));
    //*Pixel = SDL_MapRGB(Surface->format, R, G, B);
    pixel_ptr^ = (b) | (g << 8) | (r << 16);
}



plot_point_blend :: proc(surface: ^sdl.Surface, px, py: i32, brightness: u8) {
    
    x := px;
    y := py;

    if x < 0 do x += SCREEN_WIDTH;
    if y < 0 do y += SCREEN_HEIGHT;
    
    if x >= SCREEN_WIDTH  do x -= SCREEN_WIDTH;
    if y >= SCREEN_HEIGHT do y -= SCREEN_HEIGHT;
    
    pixel_ptr := mem.ptr_offset(cast(^u32)surface.pixels, int((y * surface.pitch / 4) + x));
    if (brightness > u8(pixel_ptr^)) {
        pixel_ptr^ = (u32(brightness)) | (u32(brightness) << 8) | (u32(brightness) << 16);
    }
}








import "core:fmt";
draw_line_wu_coords :: proc (surface: ^sdl.Surface, _x0, _y0, _x1, _y1: i32) {
    //TODO(Josh): swap function

    x0 := _x0;
    x1 := _x1;
    y0 := _y0;
    y1 := _y1;

    if(x0 > x1){
        temp_x := x0;
        temp_y := y0;
        
        x0 = x1;
        y0 = y1;
        
        x1 = temp_x;
        y1 = temp_y;
    }
    
    
    delta_x := x0 - x1;
    delta_y := y0 - y1;
    slope := f32(delta_y) / f32(delta_x);
    
    
    if(x0 == x1){
        //vertical line
        for y in min(y0, y1)..<max(y0, y1) {
            plot_point_blend(surface, x0, y, 0xff);
        }
    } else if (y0 == y1) {
        //horizontal line
        for x in min(x0, x1)..<max(x0, x1) {
          plot_point_blend(surface, x, y0, 0xff);
        }
    } else if abs(slope) == 1 {
        //diagonal line
        x := x0;
        y := y0;
        for x <= x1 {
            plot_point_blend(surface, x, y, 0xff);
            x += 1;
            y += i32(slope);
        }
    } else if  abs(slope) < 1 {
        //shallow line
        //draw begin
        plot_point(surface, x0, y0, 0xff, 0xff, 0xff);
        y := f32(y0) + slope;
        for x in (x0 + 1)..<x1 {
            y_int, y_frac := math.modf(y);
            i1 := 1 - y_frac;
            i2 :=     y_frac;
            plot_point_blend(surface, x, i32(y_int),     u8(i1 * 0xff));
            plot_point_blend(surface, x, i32(y_int + 1), u8(i2 * 0xff));
            y += slope;
        }
        //draw end
        plot_point_blend(surface, x1, y1, 0xff);
        
    } else {
        //deep line
        if (y0 < y1) {
            plot_point_blend(surface, x0, y0, 0xff);
            x := f32(x0) + 1 / slope;
            for y in (y0 + 1)..<y1 {
              x_int, x_frac := math.modf(x);
              i1 := 1 - x_frac;
              i2 :=     x_frac;
              plot_point_blend(surface, i32(x_int),      y, u8(i1 * 0xff));
              plot_point_blend(surface, i32(x_int + 1) , y, u8(i2 * 0xff));
              x += 1 / slope;
            }
            plot_point_blend(surface, x1, y1, 0xff);
        } else {
            plot_point(surface, x0, y0, 0xff, 0xff, 0xff);
            x := f32(x0) - 1 / slope;
            for y := y0 - 1; y > y1; y -= 1 {
              x_int, x_frac := math.modf(x);
              i1 := 1 - x_frac;
              i2 :=     x_frac;
              plot_point_blend(surface, i32(x_int),      y, u8(i1 * 0xff));
              plot_point_blend(surface, i32(x_int + 1) , y, u8(i2 * 0xff));
              x -= 1 / slope;  
            }
            plot_point_blend(surface, x1, y1, 0xff);
        }
    }
}

draw_line_wu_vector :: proc(surface: ^sdl.Surface, p1, p2: linalg.Vector2) {
  draw_line_wu_coords(surface, i32(p1.x), i32(p1.y), i32(p2.x), i32(p2.y));
}


draw_line_wu :: proc{
  draw_line_wu_vector,
  draw_line_wu_coords
};



draw_triangle :: proc(surface: ^sdl.Surface, p1, p2, p3: linalg.Vector2) {
  draw_line_wu(surface, i32(p1.x), i32(p1.y), i32(p2.x), i32(p2.y));
  draw_line_wu(surface, i32(p2.x), i32(p2.y), i32(p3.x), i32(p3.y));
  draw_line_wu(surface, i32(p3.x), i32(p3.y), i32(p1.x), i32(p1.y));
}



draw_player :: proc(surface: ^sdl.Surface, player: ^Player) {
    
  p1, p2, p3, perp_rotation: linalg.Vector2;
    
  perp_rotation.x =  player.rotation.y;
  perp_rotation.y = -player.rotation.x;
    
  p1 = player.pos + (perp_rotation * 6) - (player.rotation * 5);
  p2 = player.pos - (perp_rotation * 6) - (player.rotation * 5);
  p3 = player.pos + player.rotation * 15;
    
    
  draw_triangle(surface, p1, p2, p3);

  // draw flame   
  if is_down(.Up) && ((frame >> 1) & 0x1) == 1 {
    p1 := p1 - (player.rotation * 2) - perp_rotation * 3;
    p2 := p2 - (player.rotation * 2) + perp_rotation * 3;
    p3 := player.pos - (player.rotation * 10);
        
    draw_triangle(surface, p1, p2, p3);
  }   
    
}


draw_marker :: proc(surface: ^sdl.Surface, x, y: i32, r, g, b: u32) {
  plot_point(surface, x, y, r, g, b); 
  plot_point(surface, x, y + 1, r, g, b); 
  plot_point(surface, x, y - 1, r, g, b); 
  plot_point(surface, x + 1, y, r, g, b); 
  plot_point(surface, x - 1, y, r, g, b);
}



draw_asteroids :: proc(surface: ^sdl.Surface, game: ^GameState) {

  for a in game.asteroids {
    j: int;
    for ; j < len(a.vertices) - 1; j += 1 {
      draw_line_wu(surface, transform(a.rot, a.pos, a.vertices[j]), transform(a.rot, a.pos, a.vertices[j + 1]));
    }
    
    draw_line_wu(surface, transform(a.rot, a.pos, a.vertices[j]), transform(a.rot, a.pos, a.vertices[0]));
    
    if(debug_mode) { 
      draw_marker(surface, i32(a.pos.x), i32(a.pos.y), 255, 0, 0);
    }
  }
}


draw_bullets :: proc(surface: ^sdl.Surface, game: ^GameState) {
    
  for b in &game.bullets {
    trail_length := 5;
    trail_pos := b.pos;
    trail_dir := -linalg.normalize(b.vel);
    plot_point(surface, i32(b.pos.x), i32(b.pos.y), 0xff, 0xff, 0xff);
    for i in 1..trail_length {
      plot_point(surface, i32(trail_pos.x), i32(trail_pos.y), u32(0xff / i), u32(0xff / i), u32(0xff / i));
      trail_pos = trail_pos + trail_dir;
    }
  }
}



fade :: proc(surface: ^sdl.Surface) {
  for row in 0..<surface.h {
    for byte_index in 0..<surface.pitch {
      byte_ptr := mem.ptr_offset(cast(^byte)surface.pixels, int(row * surface.pitch + byte_index));
      if byte_ptr^ > 0 {
        byte_ptr^ -= 1;
      }
    }
  }
}


draw :: proc(game: ^GameState, surface: ^sdl.Surface) { 
  sdl.fill_rect(surface, nil, sdl.map_rgb(surface.format, 0, 0, 0));
  draw_asteroids(surface, game);
  draw_bullets(surface, game);
  draw_player(surface, &(game.player));

  draw_string(surface, arial, "HERE IS YOUR SCORE", 500, 500);
}


wrap_pos :: proc (pos: ^linalg.Vector2) {
    if pos.x < 0 do pos.x += SCREEN_WIDTH;
    if pos.y < 0 do pos.y += SCREEN_HEIGHT;
    
    if pos.x >= SCREEN_WIDTH  do pos.x -= SCREEN_WIDTH;
    if pos.y >= SCREEN_HEIGHT do pos.y -= SCREEN_HEIGHT;
}




/*
draw_rect :: proc(surface: ^sdl.Surface, rx, ry, rw, rh: i32, r, g, b: u32) {
    
  row: ^u8 = cast(^u8)surface.pixels;
    for y in 0..<surface.h {
      pixel := cast(^u32)row;
      for x in 0..<surface.w {
        if x >= rx && x <= rx + rw && y >= ry && y <= ry + rh {
          pixel^ = (b) | (g << 8) | (r << 16);
        }
       pixel = mem.ptr_offset(pixel, 1);
      }
      row = mem.ptr_offset(row, int(surface.pitch));
    }
}
*/




draw_string :: proc(surface: ^sdl.Surface, font: ^sdl_ttf.Font, s: string, x, y: i32) {
  // char_width := 8;
  // for c, i in s {
  //   draw_char(surface, u8(c), u32(x) + u32(char_width) * u32(i), y);
  // }

  //TODO: clone_to_csring leaks. Use a temp allocator, or free the string
  cs := strings.clone_to_cstring(s);
  text_surface := sdl_ttf.render_utf8_solid(font, cs, sdl.Color{255, 255, 255, 255});
  pos := sdl.Rect{x=x, y=y};
  sdl.upper_blit(text_surface, nil, surface, &pos);
  sdl.free_surface(text_surface);
  mem.free(&cs);
}


draw_char :: proc(surface: ^sdl.Surface, char: u8, x, y: u32) {



  bit_size : i32 = 1;
  
  // for row in 0..<8 {
  //   for col in 0..<8 {
  //     if (bitmaps[char - 65][row] >> uint(8 - col) & 0x1) == 1 {
  //       draw_rect(surface, i32(x) + i32(col) * bit_size,
  //                          i32(y) + i32(row) * bit_size, 
  //                          bit_size, bit_size - 1, 
  //                          0xff, 0xff, 0xff);
  //     }
  //   }
  // }

  for row in 0..<8 {
    for col in 0..<8 {
      bitmap_index: u8;
      if char == ' ' {
        bitmap_index = 0;
      } else {
        bitmap_index = char - 64;
      }
      if (bitmaps[bitmap_index][row] >> uint(7 - col) & 0x1) == 1 {
        plot_point(surface, i32(x) + i32(col), i32(y) + i32(row), 0xff, 0xff, 0xff);
      }
    }
  }
}
