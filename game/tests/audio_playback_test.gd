extends SceneTree
func _init():call_deferred('run')
func run():
 var audio=load('res://ui/cafe_audio.gd').new();root.add_child(audio)
 for key in audio.sounds.keys()+['music']:
  var stream=audio.music.stream if key=='music' else audio.sounds[key]
  if key=='music':assert(stream.loop_end<stream.data.size()/2,'Loop end must be an existing PCM sample, not EOF')
  assert(stream.data.size()>0)
  var playback=stream.instantiate_playback();playback.start()
  for i in range(300):
   var frames=playback.mix_audio(1.0,2048)
   assert(frames.size()<=2048)
  assert(not playback.is_playing() or key=='music')
 audio.queue_free();await process_frame
 print("PASS: bounded PCM loop and native WAV mixing through stream ends/music loop")
 quit()
