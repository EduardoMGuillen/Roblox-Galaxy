#!/usr/bin/env python3
"""Ejecuta pruebas del juego en el simulador de Roblox (Lua 5.4 del sistema via ctypes).

  python3 tools/sim/run.py                      -> todas las pruebas de tools/sim/tests/
  python3 tools/sim/run.py tools/sim/tests/x.lua -> una prueba
"""
import ctypes
import ctypes.util
import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load_lua():
    for name in ("liblua5.4.so.0", "liblua5.4.so", ctypes.util.find_library("lua5.4") or ""):
        if not name:
            continue
        try:
            return ctypes.CDLL(name)
        except OSError:
            pass
    raise SystemExit("No se encontro liblua5.4 (instala el paquete liblua5.4-0)")


BOOT = r'''
local root, test = ...
SIM_ROOT = root
local function handler(e) return debug.traceback(tostring(e), 2) end
local ok, err = xpcall(function()
  local SIM = assert(loadfile(root .. "/tools/sim/harness.lua"))(root)
  for k, v in pairs(SIM.G) do if _G[k] == nil then _G[k] = v end end
  local chunk = assert(loadfile(test))
  chunk(SIM)
end, handler)
if not ok then io.stderr:write("FALLO: " .. tostring(err) .. "\n") os.exit(1) end
os.exit(0)
'''


def run_one(test):
    L = load_lua()
    L.luaL_newstate.restype = ctypes.c_void_p
    st = ctypes.c_void_p(L.luaL_newstate())
    L.luaL_openlibs(st)
    L.luaL_loadbufferx.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_char_p]
    L.lua_pushstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    L.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ssize_t, ctypes.c_void_p]
    L.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    L.lua_tolstring.restype = ctypes.c_char_p
    code = BOOT.encode()
    if L.luaL_loadbufferx(st, code, len(code), b"=boot", None) != 0:
        print(L.lua_tolstring(st, -1, None).decode())
        sys.exit(2)
    L.lua_pushstring(st, ROOT.encode())
    L.lua_pushstring(st, os.path.abspath(test).encode())
    sys.stdout.flush()
    r = L.lua_pcallk(st, 2, 0, 0, 0, None)
    if r != 0:
        print(L.lua_tolstring(st, -1, None).decode())
        sys.exit(1)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--child" in sys.argv:
        run_one(args[0])
        return
    subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "build.py"), "--tree-only"])
    tests = args or sorted(glob.glob(os.path.join(ROOT, "tools", "sim", "tests", "*.lua")))
    failed = 0
    for t in tests:
        print("=== " + os.path.relpath(t, ROOT))
        sys.stdout.flush()
        rc = subprocess.call([sys.executable, os.path.abspath(__file__), "--child", t])
        if rc != 0:
            failed += 1
            print("    -> FALLO (codigo %d)" % rc)
    print("\n%d prueba(s), %d fallo(s)" % (len(tests), failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
