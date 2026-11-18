#!/usr/bin/env python3
"""Convierte el API dump oficial de Roblox (tools/sim/data/API-Dump.json) en una tabla Lua
(tools/sim/data/api.lua) que usa el simulador para validar clases, propiedades, metodos,
eventos y enums que usa el codigo del juego."""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(HERE, "data", "API-Dump.json")
dst = os.path.join(HERE, "data", "api.lua")
d = json.load(open(src, encoding="utf-8"))

def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

out = ["-- GENERADO por gen_api.py; no editar", "local C, E = {}, {}"]
for c in d["Classes"]:
    tags = [t for t in (c.get("Tags") or []) if isinstance(t, str)]
    props, methods, events, callbacks = [], [], [], []
    for m in c["Members"]:
        mtags = [t for t in (m.get("Tags") or []) if isinstance(t, str)]
        name = m["Name"]
        if m["MemberType"] == "Property":
            v = m["ValueType"]; s = m["Security"]
            f = ["c=%s" % q(v["Category"][0]), "t=%s" % q(v["Name"])]
            if s["Read"] != "None": f.append("rsec=true")
            if s["Write"] != "None": f.append("wsec=true")
            if "ReadOnly" in mtags: f.append("ro=true")
            if "NotScriptable" in mtags: f.append("ns=true")
            if "Deprecated" in mtags: f.append("dep=true")
            props.append("[%s]={%s}" % (q(name), ",".join(f)))
        elif m["MemberType"] == "Function":
            sec = m["Security"] if isinstance(m["Security"], str) else m["Security"].get("Read", "None")
            f = []
            if sec != "None": f.append("sec=true")
            if "Deprecated" in mtags: f.append("dep=true")
            methods.append("[%s]={%s}" % (q(name), ",".join(f)))
        elif m["MemberType"] == "Event":
            sec = m["Security"] if isinstance(m["Security"], str) else m["Security"].get("Read", "None")
            events.append("[%s]=%s" % (q(name), "false" if sec != "None" else "true"))
        elif m["MemberType"] == "Callback":
            callbacks.append("[%s]=true" % q(name))
    out.append("C[%s]={super=%s,tags={%s},props={%s},methods={%s},events={%s},callbacks={%s}}" % (
        q(c["Name"]), q(c["Superclass"]), ",".join("%s=true" % t for t in tags),
        ",".join(props), ",".join(methods), ",".join(events), ",".join(callbacks)))
for e in d["Enums"]:
    items = ",".join("[%s]=%d" % (q(i["Name"]), i["Value"]) for i in e["Items"])
    out.append("E[%s]={%s}" % (q(e["Name"]), items))
out.append("return {classes=C, enums=E}")
open(dst, "w", encoding="utf-8").write("\n".join(out) + "\n")
print("api.lua:", len(d["Classes"]), "clases,", len(d["Enums"]), "enums,", os.path.getsize(dst)//1024, "KB")
