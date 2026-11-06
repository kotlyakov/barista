extends SceneTree
const Service=preload("res://orders/service.gd")
var failures=0
func check(ok: bool,text: String) -> void:
 if not ok:failures+=1;push_error(text)
func _init() -> void:
 if not ResourceLoader.exists("res://persistence/store_v2.gd"):
  print("FAIL: v2 atomic store absent");quit(1);return
 var Store=load("res://persistence/store_v2.gd")
 var root="user://test-v2-store-"+str(Time.get_ticks_usec())
 var st=Store.new(root)
 check(st.read_latest().error=="EMPTY","new profile is distinct from damaged profile")
 var s=Service.new()
 check(st.save(s.snapshot()).ok,"save empty initial cup")
 s.data.money=500
 check(st.save(s.snapshot()).ok,"second generation saved")
 check(st.read_latest().snapshot.money==500,"newest validated generation chosen")
 var f=FileAccess.open(root+"/slot1.json",FileAccess.WRITE);f.store_string("partial");f.close()
 var recovered=st.read_latest()
 check(recovered.ok and recovered.recovered and recovered.snapshot.money==0,"damaged latest slot falls back to validated backup")
 f=FileAccess.open(root+"/slot0.json",FileAccess.WRITE);f.store_string("bad");f.close()
 check(st.read_latest().error=="CORRUPT" and not st.save(s.snapshot()).ok,"both corrupt cannot silently become new career")
 var future=Store.new(root+"-future")
 check(future.save(s.snapshot()).ok,"prepare unknown-version fixture")
 var path=root+"-future/slot0.json"
 var env=JSON.parse_string(FileAccess.get_file_as_string(path));env.schema_version=3
 f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(env));f.close()
 check(future.read_latest().error=="UNSUPPORTED_VERSION" and not future.save(s.snapshot()).ok,"future version never overwritten")
 var invalid=s.snapshot();invalid.money=-1
 check(not future.save(invalid).ok,"invalid snapshot rejected before filesystem mutation")
 var near_store=Store.new(root+"-precision")
 var near=Service.new();near.spawn_visit("guest-01","cappuccino");near.advance(74.99999999999999)
 check(near_store.save(near.snapshot()).ok,"save strictly before patience deadline")
 var exact=near_store.read_latest()
 check(exact.ok,"acknowledged near-deadline save must immediately load")
 if exact.ok:check(exact.snapshot.clock==74.99999999999999,"clock preserved at full binary precision")
 var generation=Store.new(root+"-generation")
 var first=Service.new();generation.save(first.snapshot());first.data.money=80;generation.save(first.snapshot())
 var generation_path=root+"-generation/slot0.json"
 var header=JSON.parse_string(FileAccess.get_file_as_string(generation_path));header.sequence=3
 f=FileAccess.open(generation_path,FileAccess.WRITE);f.store_string(JSON.stringify(header));f.close()
 var latest=generation.read_latest()
 check(latest.ok and latest.snapshot.money==80 and latest.recovered,"generation metadata is bound to digest; one-bit change cannot roll back wallet")
 if failures==0:print("PASS: v2 two-slot writes, checksum/recovery, corruption and future-version protection")
 quit(0 if failures==0 else 1)
