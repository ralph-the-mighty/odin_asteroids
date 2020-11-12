package main

import "core:fmt";
import "core:os";
import sdl "shared:odin-sdl2";
import sdl_ttf "shared:odin-sdl2/ttf"
// import sdl_image "shared:odin-sdl2/image"
import "core:math/linalg";
import "core:math/rand";
import "core:math";



TURN_RATE      :: math.PI * 2.0; // radians / sec
THRUST_VEL     :: 500;           // pixels  / sec^2
PLAYER_MAX_VEL :: 400;           // pixels  / sec
PLAYER_MIN_VEL :: 0;             // pixels  / sec
BULLET_VEL     :: 500;           // pixels  / sec



SCREEN_WIDTH  :: 620;
SCREEN_HEIGHT :: 480;


KeyState :: struct {
  is_down, was_down: bool
};

is_down :: proc(key: sdl.Scancode) -> bool {
  return Keys[key].is_down;
}

was_down :: proc(key: sdl.Scancode) -> bool {
  return Keys[key].was_down;
}

came_down :: proc(key: sdl.Scancode) -> bool {
  return is_down(key) && !was_down(key);
}


gWindow: ^sdl.Window;
gScreenSurface: ^sdl.Surface;
gRenderer: ^sdl.Renderer;

Keys: [1024]KeyState;

running := true;
paused := false;
debug_mode := false;
frame : uint;


Player :: struct {
  pos, vel, rotation: linalg.Vector2
};

Asteroid :: struct {
    //in object space
    vertices: [5]linalg.Vector2,
    size, rot, rot_vel: f32,
    gen: int,
    pos, vel: linalg.Vector2
};


Bullet :: struct {
    pos, vel: linalg.Vector2,
    lifetime: f32
};

Particle :: struct {
  pos, vel: linalg.Vector2,
  lifetime: f32,
  size: f32
}



GameMode :: enum {
  MENU,
  GAME
}





particles :[dynamic]Particle;


explosion :: proc(pos: linalg.Vector2) {
  for i in 0..100 {
    p := Particle{
      pos = pos,
      lifetime = rand.float32_range(0.25, 0.75)
    };
    vel := rand.float32_range(50, 200);
    angle := rand.float32_range(0, 2 * math.PI);
    p.vel.x = math.cos(angle) * vel;
    p.vel.y = math.sin(angle) * vel;
    append(&particles, p);
  }
} 




GameState :: struct {
  mode: GameMode,

  menu_cursor: int,

  player: Player,
  score: uint,
  asteroids: [dynamic]Asteroid,
  bullets: [dynamic]Bullet
};


global_game_state: GameState;

SDL_Init :: proc() -> bool {
  success := true;
    
  //Initialize SDL
  if sdl.init(.Video | .Events | .Timer) < 0 {
    fmt.printf("SDL failed to initialize! SDL_Error: %s\n", sdl.get_error());
    success = false;
  } else {
    //Create Window
    gWindow = sdl.create_window("asdf", i32(sdl.Window_Pos.Undefined), i32(sdl.Window_Pos.Undefined), SCREEN_WIDTH, SCREEN_HEIGHT, .Shown);
    if gWindow == nil {
      fmt.printf("Window could not be created! SDL_Error: %s\n", sdl.get_error());
      success = false;
    } else {
      //Get window surface
      gScreenSurface = sdl.get_window_surface(gWindow);
    }
  }
  return success;
}

close :: proc() {
  sdl.destroy_window(gWindow);
  gWindow = nil;
  sdl.quit();
}


process_events :: proc() {
    
    //Update keymap
    for key in &Keys {
        key.was_down = key.is_down;
    }
    
    //Event Loop
    e: sdl.Event ;
    for sdl.poll_event(&e) != 0 {
        if(e.type == .Quit) {
            running = false;
        }else if(e.type == .Key_Down) {
            scancode := e.key.keysym.scancode;
            Keys[scancode].was_down = Keys[scancode].is_down;
            Keys[scancode].is_down = true;
        }else if(e.type == .Key_Up) {
            scancode := e.key.keysym.scancode;
            Keys[scancode].was_down = Keys[scancode].is_down;
            Keys[scancode].is_down = false;
        }
    }
}


new_game :: proc(game: ^GameState) {
    game.mode = .GAME;
    game.player.pos = {320, 240};
    game.player.rotation.y = 1;
    gen_asteroids(game, 10);
}


gen_asteroid :: proc(game: ^GameState, pos: linalg.Vector2, size: f32, gen: int) {
    a: Asteroid;
    a.pos = pos;
    a.size = size;
    a.gen = gen;
    
    for i in 0..<5 {
      angle := f32(i) * (2 * math.PI) / 5;
      distance: f32 = rand.float32_range(a.size / 4, a.size);
      a.vertices[i] = {math.cos(angle) * (distance), math.sin(angle) * distance};
    }
    
    
    //adjust points so that origin is center of gravity;
    sum: linalg.Vector2;
    f, twicearea: f32;
    
    for i in 0..<5 {
        p1 := a.vertices[i];
        p2 := a.vertices[(i + 1) % 5];
        f = (p1.x * p2.y - p2.x * p1.y);
        sum.x += (p1.x + p2.x) * f;
        sum.y += (p1.y + p2.y) * f;
        twicearea += f;
    }
    
    for i in 0..<5 {
        a.vertices[i].x -= (sum.x / (twicearea * 3));
        a.vertices[i].y -= (sum.y / (twicearea * 3));
    }
    
    a.vel = {rand.float32_range(-50, 50), rand.float32_range(-50, 50)};
    a.rot_vel = rand.float32_range(-5, 5);
    
    append(&game.asteroids, a);
    
}



gen_asteroids:: proc(game: ^GameState, count: int) {
    
  for i in 0..<count {
    pos: linalg.Vector2 = {f32(i) * 50, f32(i) * 50 };
    gen_asteroid(game, pos, 50, 2);
  }
}


point_in_polygon :: proc(p: linalg.Vector2, vertices: []linalg.Vector2) -> bool {
  odd := false;
  j := len(vertices) - 1;
  for i := 0; i < len(vertices); i += 1 {
    // TODO(JOSH): check for and skip points  that are colinear with a side?
    //check for horizontal cast intersection
    if vertices[i].y < p.y && vertices[j].y >= p.y || vertices[j].y < p.y && vertices[i].y >= p.y {
      // calculate intersection
      if vertices[i].x + (p.y - vertices[i].y) / (vertices[j].y - vertices[i].y) * (vertices[j].x - vertices[i].x) < p.x {
        odd = !odd;
      }
    }
    j = i;
  }
  return odd;
}


wrap_position :: proc(pos: ^linalg.Vector2) {
  if pos.x < 0 do pos.x += SCREEN_WIDTH;
  if pos.y < 0 do pos.y += SCREEN_HEIGHT;
    
  if pos.x >= SCREEN_WIDTH  do pos.x -= SCREEN_WIDTH;
  if pos.y >= SCREEN_HEIGHT do pos.y -= SCREEN_HEIGHT;
}


update_particles :: proc(dt: f32) {
      //update bullets
  for p, i in &particles {
    p.lifetime -= dt;
      
    if p.lifetime <= 0 {
      unordered_remove(&particles, i);
      continue;
    }
    p.pos = p.pos + p.vel * dt;
    wrap_position(&p.pos);
  }
}


update :: proc(game: ^GameState, dt: f32) {
  frame += 1;

  if came_down(.Escape) {
    running = false;
  }

  switch game.mode {
    case .MENU:
      if is_down(.Return) {
        switch game.menu_cursor {
          case 0:
            game.mode = .GAME;
            new_game(game);
          case 1:
            //nothing
          case 2:
            running = false;
        }
      }
      if came_down(.Up) {
        game.menu_cursor = (game.menu_cursor - 1) % 3;
      }
      if came_down(.Down) {
        game.menu_cursor = (game.menu_cursor + 1) % 3;
      }
    case .GAME:

        
      if came_down(.P) {
        paused = !paused;
      }
      
      if came_down(.D) {
        debug_mode = !debug_mode;
      }
        
      if came_down(.G) {
        gen_asteroids(&global_game_state, 10);
      }

      if came_down(.K) {
        if len(game.asteroids) > 0 do pop(&game.asteroids);
      }

      if came_down(.Space) {
        b: Bullet;
        b.lifetime = 2;
        b.pos = game.player.pos + game.player.rotation * 15;
        b.vel = game.player.rotation * BULLET_VEL;
        append(&game.bullets, b);
      }
        
      if paused do return;



      //update player
      if is_down(.Left) {
        new_rotation: linalg.Vector2;
        new_rotation.x = game.player.rotation.x * math.cos(-TURN_RATE * dt) - game.player.rotation.y * math.sin(-TURN_RATE * dt);
        new_rotation.y = game.player.rotation.x * math.sin(-TURN_RATE * dt) + game.player.rotation.y * math.cos(-TURN_RATE * dt);
          
        game.player.rotation = new_rotation;
      }
      
      if is_down(.Right) {
        new_rotation: linalg.Vector2;
        new_rotation.x = game.player.rotation.x * math.cos(TURN_RATE * dt) - game.player.rotation.y * math.sin(TURN_RATE * dt);
        new_rotation.y = game.player.rotation.x * math.sin(TURN_RATE * dt) + game.player.rotation.y * math.cos(TURN_RATE * dt);
          
        game.player.rotation = new_rotation;
      }
      
      if is_down(.Up) {
        game.player.vel = game.player.vel + game.player.rotation * THRUST_VEL * dt;
        if linalg.length(game.player.vel) > PLAYER_MAX_VEL {
          game.player.vel = linalg.normalize(game.player.vel) * PLAYER_MAX_VEL;
        }
      }

      
      game.player.pos += game.player.vel * dt;
      wrap_position(&(game.player.pos));



      //update asteroids
      for a in &game.asteroids {
        a.pos.x += a.vel.x * dt;
        a.pos.y += a.vel.y * dt;
        a.rot += a.rot_vel * dt;
        if a.rot >= 2 * math.PI {
            a.rot -= 2 * math.PI;
        }
        
        wrap_position(&a.pos);
      }

      //update bullets
      for b, i in &game.bullets {
        b.lifetime -= dt;
          
        if b.lifetime <= 0 {
          unordered_remove(&game.bullets, i);
          continue;
        }
          
        b.pos = b.pos + b.vel * dt;
        wrap_position(&b.pos);
      }

      //update particles
      update_particles(dt);


        //collision detection
        //TODO: fix bug where two bullets destroy the same asteroid at the same time
      for a, a_index in &game.asteroids {
        transformed_points: [5]linalg.Vector2;
        for v, i in a.vertices {
          transformed_points[i] = transform(a.rot, a.pos, v);
        }
        for b, b_index in &game.bullets {
          if point_in_polygon(b.pos, transformed_points[:]) {
            if(a.gen > 0) {
              gen_asteroid(game, a.pos, a.size * 0.75, a.gen - 1);
              gen_asteroid(game, a.pos, a.size * 0.75, a.gen - 1);
            }
            explosion(b.pos);
            unordered_remove(&game.bullets, b_index);
            unordered_remove(&game.asteroids, a_index);
            game.score += 10;
          }
        }
      }
    }

}


arial: ^sdl_ttf.Font;
minecraft: ^sdl_ttf.Font;



load_font :: proc(font_path: cstring, size: i32) -> ^sdl_ttf.Font {
  font := sdl_ttf.open_font(font_path, size);
  if font == nil {
    fmt.printf("Could not open font: %s\n", font_path);
    os.exit(1);
  }
  return font;
}


main :: proc() {
  if !SDL_Init() {
    fmt.println("Could not initialize SDL");
    os.exit(1);
  }

  gRenderer := sdl.create_renderer(gWindow, -1, sdl.Renderer_Flags(0));


  //font initialization
  if sdl_ttf.init() == -1 {
    fmt.println("Could not initialize sdl_ttf");
    os.exit(1);
  }

  arial     = load_font("assets/arial.ttf", 32);
  minecraft = load_font("assets/minecraft.ttf", 16);

  global_game_state.mode = .MENU;
	

  seconds_per_tick := 1.0 / f32(sdl.get_performance_frequency());
  dt: f32 = 1.0 / 60.0;
  current_time := f32(sdl.get_performance_counter()) * seconds_per_tick;
  accumulator: f32 = 0.0;

  for running {
    new_time := f32(sdl.get_performance_counter()) * seconds_per_tick;
    frame_time := new_time - current_time;
    current_time = new_time;
    accumulator += frame_time;

    for accumulator >= dt {
      process_events();
      update(&global_game_state, dt);
      accumulator -= dt;
    }

    
    draw(&global_game_state, gScreenSurface);

    sdl.update_window_surface(gWindow);

  }

  close();
}