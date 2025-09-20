#!/usr/bin/env python3
import argparse, hashlib, json, os, time
def sha256(s): return hashlib.sha256(s.encode("utf-8")).hexdigest()
def load(p): return open(p,"r",encoding="utf-8").read() if os.path.exists(p) else ""
def stub(name):
    now=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    o={"agent":name,"agent_version":"v1","utc":now,"human_summary":f"{name} stub",
       "findings":[],"suggested_patches":[],"telemetry_schema_updates":[],"repro_scenarios":[],
       "actionable_priority":3,"confidence":0.5}
    js=json.dumps(o, separators=(",",":")); o["evidence_hash"]=sha256(js); return o
ap=argparse.ArgumentParser(); ap.add_argument("--diff",default="ci/diff.txt"); ap.add_argument("--telemetry",default="ci/telemetry.jsonl"); ap.add_argument("--repo",default=os.getenv("GITHUB_REPOSITORY","local/repo")); args=ap.parse_args()
diff, tel = load(args.diff), load(args.telemetry)
outs=[stub(a) for a in ["dpsk","nemo","grok","qwen","z","gemini","gpt"]]
blob=diff+tel+"".join(json.dumps(o,separators=(",",":")) for o in outs)
bundle={"title":"Roundtable Stub – bootstrap","utc":time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),"repo":args.repo,"summary":"Bootstrap run; replace with real API calls.","provenance":{"content_hash":"sha256:"+sha256(blob),"agent_hashes":{o["agent"]:"sha256:"+o["evidence_hash"] for o in outs}},"attachments":[],"labels":["roundtable","stub"],"actions":[]}
os.makedirs("chronicle",exist_ok=True); path=f"chronicle/{time.strftime('%Y%m%dT%H%M%SZ')}-roundtable-bootstrap.json"; open(path,"w",encoding="utf-8").write(json.dumps(bundle,indent=2)); print("wrote",path)
