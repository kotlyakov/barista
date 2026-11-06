extends Node
# Synthesized preview candidate; no imported music or final audio approval implied.
var music=AudioStreamPlayer.new()
var voices={}
var active=false
var muted=false
var last_effect=-1000
var sounds={}
var diagnostic_path=""
var previous_trace=""
var trace_file
func begin_diagnostics(path: String) -> void:
 diagnostic_path=path
 if FileAccess.file_exists(path): previous_trace=FileAccess.get_file_as_string(path)
 trace_file=FileAccess.open(path,FileAccess.WRITE)
 trace("Barista 0.3.1 diagnostic | "+OS.get_name()+" "+OS.get_version()+" | "+OS.get_model_name()+" | audio "+AudioServer.get_driver_name())
func trace(event: String) -> void:
 if trace_file and trace_file.get_position()<65536:
  trace_file.store_line(str(Time.get_ticks_msec())+" "+event)
  trace_file.flush()
func report() -> String:
 var result="BARISTA AUDIO REPORT 0.3.1\nPREVIOUS RUN\n"+previous_trace+"\nCURRENT RUN\n"+(FileAccess.get_file_as_string(diagnostic_path) if diagnostic_path!="" else "unavailable")
 if OS.get_name()=="Android":
  # Android restricts this unprivileged reader to our own UID. No READ_LOGS permission.
  var output=[]
  var status=OS.execute("/system/bin/logcat",PackedStringArray(["-d","-b","crash","-t","100"]),output)
  result+="\nAPP CRASH BUFFER ("+str(status)+")\n"+"".join(output).right(20000)
 return result
func _exit_tree() -> void:
 trace("audio exit before stop")
 music.stop()
 for player in voices.values():player.stop();player.stream=null
 music.stream=null
 if trace_file: trace_file.close()
func tone(seconds: float,frequency: float,noise=false) -> AudioStreamWAV:
 var stream=AudioStreamWAV.new()
 stream.mix_rate=22050
 stream.format=AudioStreamWAV.FORMAT_16_BITS
 var bytes=PackedByteArray()
 var count=int(seconds*stream.mix_rate)
 bytes.resize(count*2)
 for i in range(count):
  var t=float(i)/stream.mix_rate
  var envelope=minf(1,t*40)*minf(1,(seconds-t)*12)
  var sample=sin(TAU*frequency*t)*.16
  if noise: sample=sin(i*12.9898+sin(i*.72)*15)*.07+sample*.3
  bytes.encode_s16(i*2,int(sample*envelope*32767))
 stream.data=bytes
 return stream
func _ready() -> void:
 trace("audio ready begin")
 add_child(music)
 var loop=AudioStreamWAV.new()
 loop.mix_rate=22050
 loop.format=AudioStreamWAV.FORMAT_16_BITS
 var bytes=PackedByteArray()
 var count=loop.mix_rate*8
 bytes.resize(count*2)
 var chords=[[130.81,164.81,196.0],[110.0,130.81,164.81],[87.31,110.0,130.81],[98.0,123.47,146.83]]
 for i in range(count):
  var t=float(i)/loop.mix_rate
  var beat=fmod(t,2)
  var sample=0.0
  for frequency in chords[int(t/2)]: sample+=sin(TAU*frequency*t)*.025*minf(1,beat*8)*exp(-beat*1.4)
  bytes.encode_s16(i*2,int(sample*32767))
 loop.data=bytes
 loop.loop_mode=AudioStreamWAV.LOOP_FORWARD
 loop.loop_end=count
 music.stream=loop
 for id in ["grind","brew","steam"]: sounds[id]=tone(.13,80 if id=="grind" else 150,id!="brew")
 sounds.coins=tone(.22,1200)
 for id in sounds:
  var player=AudioStreamPlayer.new();player.stream=sounds[id];voices[id]=player;add_child(player)
 trace("audio ready complete")
func set_active(value: bool,prefs: Dictionary) -> void:
 trace("set_active begin active="+str(value)+" muted="+str(prefs.get("muted",false)))
 active=value
 muted=prefs.get("muted",false)
 music.volume_db=linear_to_db(maxf(.0001,prefs.master*prefs.music))
 for player in voices.values():player.volume_db=linear_to_db(maxf(.0001,prefs.master*prefs.effects))
 if DisplayServer.get_name()=="headless": return
 if active and not muted:
  if not music.playing: music.play()
  music.stream_paused=false
 else:
  music.stream_paused=true
  for player in voices.values():player.stop()
 trace("set_active returned")
func effect(id: String) -> void:
 if not active or muted or Time.get_ticks_msec()-last_effect<90 or not sounds.has(id): return
 if DisplayServer.get_name()=="headless": return
 last_effect=Time.get_ticks_msec()
 trace("effect "+id+" before play")
 voices[id].play()
 trace("effect "+id+" play returned")
