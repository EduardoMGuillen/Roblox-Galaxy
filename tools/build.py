#!/usr/bin/env python3
"""Construye PlanetCollector.rbxlx (archivo de lugar de Roblox Studio) a partir de src/.

Usa las mismas convenciones que Rojo (default.project.json):
  Nombre.server.luau -> Script      Nombre.client.luau -> LocalScript
  Nombre.luau        -> ModuleScript carpeta            -> Folder
  carpeta con init.luau / init.server.luau / init.client.luau -> el script toma el nombre de la carpeta

Tambien genera tools/sim/data/tree.lua, que el simulador de pruebas usa para montar el mismo arbol.
No necesita dependencias externas:  python3 tools/build.py
"""
import json
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(ROOT, "default.project.json")
OUT = os.path.join(ROOT, "PlanetCollector.rbxlx")
TREE_LUA = os.path.join(ROOT, "tools", "sim", "data", "tree.lua")

SCRIPT_CLASSES = {"server": "Script", "client": "LocalScript", "module": "ModuleScript"}


class Node:
    def __init__(self, name, cls, source=None, file=None):
        self.name = name
        self.cls = cls
        self.source = source
        self.file = file
        self.props = {}
        self.children = []


def script_kind(filename):
    """Devuelve (nombre, tipo) si el archivo es un script Luau."""
    for ext in (".luau", ".lua"):
        if filename.endswith(ext):
            base = filename[: -len(ext)]
            if base.endswith(".server"):
                return base[: -len(".server")], "server"
            if base.endswith(".client"):
                return base[: -len(".client")], "client"
            return base, "module"
    return None, None


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def node_from_path(name, path):
    rel = os.path.relpath(path, ROOT)
    if os.path.isfile(path):
        _, kind = script_kind(os.path.basename(path))
        if kind is None:
            return None
        return Node(name, SCRIPT_CLASSES[kind], read(path), rel)
    entries = sorted(os.listdir(path))
    node = None
    for e in entries:
        base, kind = script_kind(e)
        if base == "init" and kind is not None:
            node = Node(name, SCRIPT_CLASSES[kind], read(os.path.join(path, e)), os.path.join(rel, e))
    if node is None:
        node = Node(name, "Folder")
    for e in entries:
        full = os.path.join(path, e)
        if os.path.isdir(full):
            child = node_from_path(e, full)
        else:
            base, kind = script_kind(e)
            if kind is None or base == "init":
                continue
            child = node_from_path(base, full)
        if child is not None:
            node.children.append(child)
    return node


def node_from_spec(name, spec):
    if "$path" in spec:
        node = node_from_path(name, os.path.join(ROOT, spec["$path"]))
        if node is None:
            raise SystemExit("ruta invalida en el proyecto: " + spec["$path"])
    else:
        cls = spec.get("$className") or (name if name in SERVICES else "Folder")
        node = Node(name, cls)
    node.props.update(spec.get("$properties", {}))
    for key, sub in spec.items():
        if not key.startswith("$"):
            node.children.append(node_from_spec(key, sub))
    return node


SERVICES = {
    "Workspace", "Lighting", "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage",
    "StarterGui", "StarterPack", "StarterPlayer", "SoundService", "Players", "Teams", "TextChatService",
    "StarterPlayerScripts", "StarterCharacterScripts", "HttpService", "MaterialService",
}


# Enums que el proyecto puede fijar por nombre (formato Rojo) -> valor numerico en el XML
ENUM_PROPS = {
    "Technology": {"Voxel": 1, "Compatibility": 2, "ShadowMap": 3, "Future": 4},
}


# ---------------------------------------------------------------- XML
class Writer:
    def __init__(self):
        self.out = []
        self.ref = 0

    def prop(self, name, value):
        if name in ENUM_PROPS and isinstance(value, str):
            return '<token name="%s">%d</token>' % (name, ENUM_PROPS[name][value])
        if isinstance(value, bool):
            return '<bool name="%s">%s</bool>' % (name, "true" if value else "false")
        if isinstance(value, dict):
            t = value["type"]
            v = value["value"]
            if t == "token":
                return '<token name="%s">%d</token>' % (name, v)
            if t == "float":
                return '<float name="%s">%s</float>' % (name, repr(float(v)))
            if t == "int":
                return '<int name="%s">%d</int>' % (name, v)
            if t == "Color3":
                return '<Color3 name="%s"><R>%s</R><G>%s</G><B>%s</B></Color3>' % (name, v[0], v[1], v[2])
            raise SystemExit("tipo de propiedad no soportado: " + t)
        if isinstance(value, (int, float)):
            return '<float name="%s">%s</float>' % (name, repr(float(value)))
        return '<string name="%s">%s</string>' % (name, escape(str(value)))

    def item(self, node, depth):
        ind = "  " * depth
        self.ref += 1
        self.out.append('%s<Item class="%s" referent="RBX%d">' % (ind, node.cls, self.ref))
        self.out.append(ind + "  <Properties>")
        self.out.append('%s    <string name="Name">%s</string>' % (ind, escape(node.name)))
        for k, v in node.props.items():
            self.out.append(ind + "    " + self.prop(k, v))
        if node.source is not None:
            src = node.source.replace("]]>", "]]]]><![CDATA[>")
            self.out.append('%s    <ProtectedString name="Source"><![CDATA[%s]]></ProtectedString>' % (ind, src))
        self.out.append(ind + "  </Properties>")
        for c in node.children:
            self.item(c, depth + 1)
        self.out.append(ind + "</Item>")


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_tree_lua(top_nodes):
    lines = ["-- GENERADO por tools/build.py; no editar", "return {"]

    def walk(node, path):
        p = path + [node.name]
        lines.append("  { path = { %s }, class = %s, file = %s }," % (
            ", ".join(lua_str(x) for x in p), lua_str(node.cls), lua_str(node.file) if node.file else "nil"))
        for c in node.children:
            walk(c, p)

    for n in top_nodes:
        walk(n, [])
    lines.append("}")
    os.makedirs(os.path.dirname(TREE_LUA), exist_ok=True)
    with open(TREE_LUA, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main():
    project = json.load(open(PROJECT, encoding="utf-8"))
    tree = project["tree"]
    top = []
    for key, spec in tree.items():
        if key.startswith("$"):
            continue
        top.append(node_from_spec(key, spec))

    write_tree_lua(top)
    if "--tree-only" in sys.argv:
        print("tree.lua actualizado")
        return

    w = Writer()
    w.out.append('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
                 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
                 'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">')
    w.out.append("  <External>null</External>")
    w.out.append("  <External>nil</External>")
    for n in top:
        w.item(n, 1)
    w.out.append("</roblox>")
    data = "\n".join(w.out) + "\n"
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(data)

    def count(node):
        s = 1 if node.source is not None else 0
        return s + sum(count(c) for c in node.children)

    def lines(node):
        s = node.source.count("\n") + 1 if node.source is not None else 0
        return s + sum(lines(c) for c in node.children)

    print("OK  %s  (%d scripts, %d lineas de Luau, %d KB)" % (
        os.path.relpath(OUT, ROOT), sum(count(n) for n in top), sum(lines(n) for n in top), len(data) // 1024))


if __name__ == "__main__":
    main()
