extends RefCounted
const Schema=preload("res://persistence/service_schema.gd")
const MAX_BYTES=1048576
var directory: String
func _init(path="user://saves/v2") -> void:directory=path
static func digest(sequence: int,payload: String) -> String:
 return ("2\n"+str(sequence)+"\n"+payload).sha256_text()
func read_slot(index: int) -> Dictionary:
 var path=directory+"/slot"+str(index)+".json"
 if not FileAccess.file_exists(path):return {"state":"MISSING"}
 var f=FileAccess.open(path,FileAccess.READ)
 if f==null or f.get_length()>MAX_BYTES:return {"state":"BAD"}
 var parser=JSON.new()
 if parser.parse(f.get_as_text())!=OK or not parser.data is Dictionary:return {"state":"BAD"}
 var e=parser.data
 if Schema.integer(e.get("schema_version"),3):return {"state":"FUTURE"}
 if e.get("schema_version")!=2 or not Schema.integer(e.get("sequence"),1) or not e.get("payload") is String:return {"state":"BAD"}
 if (int(e.sequence)-1)%2!=index or e.get("sha256")!=digest(int(e.sequence),e.payload):return {"state":"BAD"}
 if parser.parse(e.payload)!=OK or not Schema.valid(parser.data):return {"state":"BAD"}
 return {"state":"VALID","sequence":int(e.sequence),"snapshot":parser.data,"digest":e.sha256}
func read_latest() -> Dictionary:
 var a=read_slot(0);var b=read_slot(1)
 if a.state=="FUTURE" or b.state=="FUTURE":return {"ok":false,"error":"UNSUPPORTED_VERSION"}
 var valid=[]
 if a.state=="VALID":valid.append(a)
 if b.state=="VALID":valid.append(b)
 if valid.is_empty():return {"ok":false,"error":"EMPTY" if a.state=="MISSING" and b.state=="MISSING" and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)) else "CORRUPT"}
 if valid.size()==2 and a.sequence==b.sequence and a.digest!=b.digest:return {"ok":false,"error":"CONFLICT"}
 var chosen=valid[0]
 if valid.size()==2 and valid[1].sequence>chosen.sequence:chosen=valid[1]
 return {"ok":true,"sequence":chosen.sequence,"snapshot":chosen.snapshot,"recovered":a.state=="BAD" or b.state=="BAD"}
func save(snapshot_data: Dictionary,expected_sequence=-1) -> Dictionary:
 if not Schema.integer(expected_sequence,-1):return {"ok":false,"error":"INVALID_GENERATION"}
 if not Schema.valid(snapshot_data):return {"ok":false,"error":"INVALID_STATE"}
 var previous=read_latest()
 if not previous.ok and previous.error!="EMPTY":return previous
 if expected_sequence>=0 and int(previous.get("sequence",0))!=expected_sequence:return {"ok":false,"error":"STALE_WRITE"}
 var sequence=int(previous.get("sequence",0))+1
 if not Schema.integer(sequence,1):return {"ok":false,"error":"SEQUENCE_OVERFLOW"}
 var payload=JSON.stringify(snapshot_data,"",true,true)
 var parser=JSON.new()
 if parser.parse(payload)!=OK or not Schema.valid(parser.data):return {"ok":false,"error":"INVALID_SERIALIZED_STATE"}
 var envelope=JSON.stringify({"schema_version":2,"sequence":sequence,"payload":payload,"sha256":digest(sequence,payload)})
 if envelope.to_utf8_buffer().size()>MAX_BYTES:return {"ok":false,"error":"TOO_LARGE"}
 if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))!=OK:return {"ok":false,"error":"DIRECTORY"}
 var target=directory+"/slot"+str((sequence-1)%2)+".json"
 var temp=target+".tmp"
 var access=DirAccess.open(directory)
 if access==null:return {"ok":false,"error":"DIRECTORY"}
 if access.is_link(ProjectSettings.globalize_path(temp)):return {"ok":false,"error":"UNSAFE_TEMP_LINK"}
 if FileAccess.file_exists(temp) and DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))!=OK:return {"ok":false,"error":"TEMP_CLEANUP"}
 var f=FileAccess.open(temp,FileAccess.WRITE)
 if f==null:return {"ok":false,"error":"WRITE"}
 f.store_string(envelope);f.flush()
 var status=f.get_error();f.close()
 if status!=OK:return {"ok":false,"error":"FLUSH"}
 if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(target))!=OK:return {"ok":false,"error":"RENAME"}
 return {"ok":true,"sequence":sequence}
