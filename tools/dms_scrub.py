import getpass,json,re,sys
r=json.load(open(sys.argv[1]))
KEYS=re.compile(r'(ssid|bssid|mac|address|hwaddr|serial|uuid|hostname|ip|gateway|dns|name|alias|connection|device_path|path|id|userName|realName|userPath)$',re.I)
SAFE_PARENTS={"outputs","gpus","capabilities"}
SAFE_KEYS={"method","service","driver","vendor","displayName","fullName","pciId","id"}
pat=[(re.compile(r'([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}'),'00:00:00:00:00:00'),(re.compile(r'\b\d{1,3}(\.\d{1,3}){3}\b'),'192.0.2.1'),
     (re.compile(r'\b[0-9a-f]{0,4}(:[0-9a-f]{0,4}){3,7}\b',re.I),'2001:db8::1'),(re.compile(r'/home/[^/"]+'),'/home/user'),
     (re.compile(re.escape(getpass.getuser()),re.I),'user'),(re.compile(r'[+-]\d\d:\d\d"'),'+00:00"')]
n=[0]
def s(v,k="",parent=""):
    if isinstance(v,dict): return {kk:s(vv,kk,k or parent) for kk,vv in v.items()}
    if isinstance(v,list): return [s(x,k,parent) for x in v]
    if isinstance(v,str):
        if KEYS.search(k) and parent not in SAFE_PARENTS and k not in SAFE_KEYS: n[0]+=1; return f"<{k}-{n[0]}>"
        for p,rep in pat: v=p.sub(rep,v)
    return v
o=s(r); t=json.dumps(o,indent=1)
for p,rep in pat: t=p.sub(rep,t)
assert getpass.getuser().lower() not in t.lower()
open(sys.argv[2],"w").write(t); print("scrubbed",n[0])
