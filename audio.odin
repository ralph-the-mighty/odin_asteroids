package main;

import "core:fmt";
import "core:os";
import sdl "shared:odin-sdl2";
import sdl_ttf "shared:odin-sdl2/ttf"
// import sdl_image "shared:odin-sdl2/image"
import "core:math/linalg";
import "core:math/rand";
import "core:math";
import "core:mem";
import "core:slice";





SDL_AUDIO_S16 :: 0x8010;
SDL_MIX_MAXVOLUME :: 128;




audio_pos: ^u8;
audio_len: u32;


sound_loaded: bool;
wav_length: u32;
wav_buffer: ^u8;






MAX_WAVS :: 4;
wav_count := 0;

Wav :: struct {
  buffer: ^u8,
  length: u32,
  spec: sdl.Audio_Spec
}

wavs: [MAX_WAVS]Wav;



MAX_CHANNELS :: 16;

Channel :: struct {
  wav: ^Wav,
  cursor: u32,
  volume: i32,
  playing: bool
}

channels: [MAX_CHANNELS]Channel;






mixaudio :: proc(unused: rawptr, stream: ^u8, len: i32) {
  assert(len >= 0);
  mem.zero(rawptr(stream), int(len));
  

  for channel in &channels {
    if !channel.playing {
      continue;
    }

    out_len := u32(len);
    remainder := channel.wav.length - channel.cursor;
    if u32(len) > remainder {
      out_len = remainder;
      channel.playing = false;
    }
    sdl.mix_audio(stream,
                  slice.ptr_add(channel.wav.buffer, int(channel.cursor)), 
                  out_len,
                  channel.volume);
    
    if channel.playing {
      channel.cursor += out_len;
    } else {
      channel.cursor = 0;
    }
  }
}



load_wav :: proc(file: cstring) {
  if wav_count >= MAX_WAVS {
    fmt.printf("Couldn't load %s: Wav files already at max capacity (%d)\n", file, MAX_WAVS);
    os.exit(1);
  }

  wav := &wavs[wav_count];

  if sdl.load_wav_rw(sdl.rw_from_file(file, "rb"), 1, &wav.spec, &wav.buffer, &wav.length) == nil {
    fmt.printf("Couldn't load %s: %s\n", file, sdl.get_error());
    os.exit(1);
  }
  wav_count += 1;
}



play_sound :: proc(wav_index, volume: i32) {
  for channel, i in &channels {
    if !channel.playing { //find a channel that is currently not being used to initialize
      fmt.printf("qeueing sound on channel %d\n", i);
      sdl.lock_audio();
      channel.wav = &wavs[wav_index];
      channel.cursor = 0;
      channel.volume = volume;
      channel.playing = true;
      sdl.unlock_audio();
      break;
    }
  }
}


init_sound :: proc() {
  spec: sdl.Audio_Spec;

  spec.freq = 44100;
  spec.format = 32784;
  spec.channels = 2;
  spec.samples = 4096;
  spec.padding = 0;
  spec.size = 0;
  spec.callback = cast(sdl.Audio_Callback)mixaudio;
  spec.userdata = nil;

  if (sdl.open_audio(&spec, nil) < 0) {
    fmt.printf("Couldn't open audio: %s\n", sdl.get_error());
    os.exit(1);
  }
  sdl.pause_audio(0);
}