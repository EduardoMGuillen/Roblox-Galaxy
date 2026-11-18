# PLANET COLLECTOR

Simulador multijugador de colección espacial para Roblox, construido a partir de
`PLANET COLLECTOR.pdf` (manual maestro de diseño, arte y desarrollo).

Coleccionas planetas abriendo cápsulas, los colocas en órbita alrededor de la estrella de tu
universo personal, generas Energy, mejoras, desbloqueas cinco sistemas, evolucionas mundos,
asciendes y enseñas tu universo a otros jugadores.

## Cómo abrir y jugar

1. Abre **Roblox Studio** → *File → Open from File…* → `PlanetCollector.rbxlx`.
2. Pulsa **Play** (F5). Todo el mundo y la interfaz se generan por código al arrancar, así que en
   modo edición el Workspace se ve vacío: es normal.
3. Para que el progreso se guarde hay que publicar el lugar (*File → Publish to Roblox*) y activar
   *Game Settings → Security → Enable Studio Access to API Services*. Sin eso el juego funciona en
   **modo de prueba** (te avisa en pantalla y no guarda).
4. Para probar trading y visitas: *Test → Clients and Servers* con 2 jugadores.

Ajustes recomendados al publicar: máximo **12 jugadores** por servidor (hay 12 parcelas de
universo; se cambia en `Config.World.PlotCount`).

## Qué incluye

| Área | Contenido |
|---|---|
| **Cosmic Hub** | Núcleo holográfico, Capsule Station (6 máquinas), Galactic Market, Leaderboard, Portal Room, Event Terminal, tableros de probabilidades, skyline y planetas lejanos |
| **Universo personal** | Parcela por jugador con plataforma de observación, estrella central, 8 órbitas por sistema, planetas que orbitan y rotan, terminales, tableros de producción y portal de regreso |
| **5 sistemas** | Solar, Nebula, Void (núcleo de gravedad), Celestial (adornos dorados) e Infinity (portales), cada uno con tema, multiplicador, requisitos y colección |
| **25 planetas** | Los 15 del manual con su rareza, tipo y producción de referencia, más 10 complementarios (lunas y mundos avanzados); 7 rarezas |
| **Variantes** | Shiny, Golden, Rainbow y Cosmic, independientes de la rareza |
| **6 cápsulas** | Starter → Infinity, compradas solo con Energy, con probabilidades reales visibles y tirada en servidor; apertura x1/x3/x10 |
| **Economía** | Producción pasiva con desglose, 12 sinergias por sistema, 10 mejoras (Energy y Cosmic Cores), ganancias sin conexión con tope |
| **Progresión** | Desbloqueo de sistemas, slots orbitales, evolución a forma Prime, Galactic Ascension, colecciones con recompensa, 3 descubrimientos secretos con pistas |
| **Social** | Trading con doble confirmación, visitas de solo lectura, 5 clasificaciones persistentes |
| **Retención** | Misiones diarias y semanales, 4 eventos cósmicos con calendario de servidor (Meteor Shower, Solar Eclipse, Supernova, Cosmic Storm), tutorial |
| **Interfaz** | HUD + 14 paneles (inventario, cápsulas, sistemas, mejoras, ascensión, trading, misiones, colección, estadísticas, tienda cosmética, teleport, ranking, evento, ajustes), escalado para móvil |
| **Persistencia** | DataStore con candado de sesión, reintentos, autosave, versionado y carga segura |

## Estructura del proyecto

```
PlanetCollector.rbxlx        Lugar listo para abrir en Studio (generado)
default.project.json         Mapa del proyecto (compatible con Rojo)
src/shared/                  -> ReplicatedStorage.Shared
  Config.luau                Tablas de balance centrales
  Definitions/               Planetas, cápsulas, rarezas, variantes, sistemas, sinergias,
                             mejoras, ascensión, misiones, eventos, cosméticos (solo datos)
  Progression.luau           Lógica pura: producción, sinergias, requisitos, costes
  Profile.luau               Plantilla del perfil, validación y migraciones
  PlanetVisual.luau          Constructor único del modelo 3D de cualquier planeta
  Assets.luau                Ids de assets gratuitos del Creator Store
src/server/                  -> ServerScriptService.Server
  Main.server.luau           Arranque: mundo + servicios
  Net.luau                   Remotes con validación de tipos, rangos y límites de frecuencia
  Services/                  Data, Player, Economy, Capsule, Inventory, PlanetPlacement,
                             Production, Upgrade, Rebirth, Galaxy, Trading, Event, Mission,
                             Universe, Discovery, Leaderboard, Cosmetic
  World/                     Environment, HubBuilder, UniverseBuilder
src/client/                  -> StarterPlayerScripts.Client
  Main.client.luau           Arranque del cliente
  ClientState.luau           Copia local del estado autorizado por el servidor
  Controllers/               UI, Capsule, Trade, Universe, Camera, Audio, Hub, Tutorial, Effects
  UI/                        Theme, Kit (componentes) y Panels/ (una pantalla por archivo)
assets/                      manifest.json (autor y alternativas de cada asset) y vistas previas
tools/                       build.py y simulador de pruebas
```

### Diferencias con la jerarquía sugerida en el manual

- **La interfaz no vive en StarterGui**: se genera por código en `src/client/UI`. Motivo técnico: el
  proyecto se construye y se prueba sin Studio, y así cada pantalla es un archivo de texto revisable.
- **Sin plantillas en ServerStorage**: los planetas, cápsulas y universos se construyen a partir de
  datos (`PlanetVisual`, `HubBuilder`, `UniverseBuilder`), de modo que añadir un planeta es añadir
  una entrada en `PlanetDefinitions.luau`.
- **Remotes adicionales** a los nueve iniciales (vender, bloquear, evolucionar, slots, sistemas,
  teletransporte, ajustes, cosméticos, meteoritos…), todos registrados en `Net.luau`.

## Cambiar el balance o añadir contenido

Todo es configurable sin tocar lógica:

- Precios, topes y tiempos: `src/shared/Config.luau`.
- Un planeta nuevo: una entrada en `Definitions/PlanetDefinitions.luau` y su id en el `Pools` de
  alguna cápsula de `CapsuleDefinitions.luau`.
- Probabilidades: `Odds` de cada cápsula (deben sumar 100; hay una prueba que lo comprueba).
- Requisitos de sistemas, slots y ascensión: `GalaxyDefinitions.luau`, `AscensionDefinitions.luau`.

Después de editar: `python3 tools/build.py` regenera `PlanetCollector.rbxlx`.
Con [Rojo](https://rojo.space) instalado también funciona `rojo serve` / `rojo build`.

## Pruebas

No hace falta Studio para ejecutar las pruebas automáticas:

```
python3 tools/sim/run.py
```

`tools/sim` es un simulador del runtime de Roblox (sobre la librería Lua 5.4 del sistema) que
ejecuta el código real del juego —servidor y uno o varios clientes— y valida cada clase, propiedad,
método, evento y enum contra el volcado oficial de la API de Roblox.

| Prueba | Qué cubre |
|---|---|
| `01_shared` | Definiciones (probabilidades suman 100, todo planeta es obtenible, valores del manual), producción, sinergias, reconciliación de perfiles corruptos |
| `02_server_core` | Jugador nuevo, cápsulas, saldo justo/insuficiente, spam de remotes, colocación (slot bloqueado, planeta ajeno, sistema bloqueado, mover sin duplicar), producción, venta, mejoras, guardar/volver, ganancias sin conexión, carga fallida y candado de otra sesión |
| `03_server_progression` | Desbloqueo de sistemas, secretos, evolución, misiones, trading (rechazo, oferta modificada, doble confirmación, desconexión), visitas de solo lectura, ascensión (requisitos, reinicio y conservación), eventos, meteoritos, leaderboard |
| `04_client` | Arranque del cliente, HUD, los 14 paneles, apertura de cápsula con animación y salto, colocación por interfaz, render y animación orbital, vista orbital, clic en planeta, ajustes, todos los ProximityPrompts |
| `05_client_social` | Dos clientes: trading completo por interfaz, visita e inspección, salida del propietario, los cinco temas de sistema, tienda, misiones, colección, ascensión con doble confirmación, meteoritos |

Herramientas extra:

- `tools/sim/tools/economy_bot.lua`: un bot juega con los servicios reales del servidor y muestra
  cuándo alcanza cada hito (`BOT_HOURS=16 python3 tools/sim/run.py tools/sim/tools/economy_bot.lua`).
  Con el balance actual, un jugador activo llega a la 1.ª ascensión en ~11 min, a la 2.ª en ~35 min,
  a la 3.ª en ~1,5 h, a la 4.ª en ~7 h y desbloquea Infinity en ~11 h de juego.
- `tools/sim/preview.py`: vista previa aproximada de la geometría del mundo.
- `tools/sim/tools/dump_ui.lua` + `tools/sim/preview_ui.py`: vista previa del HUD y de cada panel a
  cualquier resolución (`VIEWPORT=844x390` para un móvil apaisado), útil para detectar solapamientos.

La interfaz tiene dos disposiciones: normal (escritorio y tablet) y compacta (pantallas de menos de
600 px de alto, p. ej. móviles en horizontal), y los paneles se escalan para caber siempre.

### Lo que estas pruebas no pueden comprobar

El simulador no dibuja: **no se ha hecho Play Test en Roblox Studio**. Queda por verificar en Studio:

- El aspecto final (iluminación, bloom, materiales, tamaño del texto en carteles) y el rendimiento
  en móvil.
- Que las texturas de terceros del Creator Store cargan dentro de tu experiencia. Si alguna no
  carga, el juego lo detecta al arrancar (`AssetCheck`) y usa materiales integrados en su lugar.
- La orientación de la cara inferior del skybox y los sonidos (elegidos por nombre, no escuchados).
- El comportamiento real de DataStores y OrderedDataStores con el juego publicado.

Si algo falla en Studio, la ventana *Output* indicará el archivo y la línea.

## Seguridad y datos

- El servidor es la autoridad de Energy, recompensas, inventario, colocación, mejoras, ascensión,
  trading, misiones y guardado. El cliente solo pide y muestra.
- Cada remote valida tipos, longitudes y rangos, comprueba propiedad, aplica cooldown y un límite
  de ráfaga, y responde de forma controlada (`Net.luau`).
- Si la carga de datos falla, el jugador **no** empieza con un perfil nuevo (se evita sobrescribir
  datos válidos): se le expulsa con un mensaje. Un candado de sesión impide que dos servidores
  escriban el mismo perfil.
- El trading revalida propiedad y estado justo antes de transferir. Cada perfil se guarda por
  separado, así que un fallo de DataStore justo después de un intercambio podría dejar guardado
  solo uno de los dos lados; se guarda inmediatamente para reducir esa ventana.

## Monetización

No hay compras con Robux. Las cápsulas se compran solo con Energy ganada jugando y muestran sus
probabilidades reales. `Config.GamePasses.VIP` está preparado (en 0 = desactivado) por si se añade
un pase cosmético.

## Créditos de assets

Texturas, anillos, skybox y sonidos son assets gratuitos del Creator Store de Roblox. El autor, el
id y las alternativas de cada uno están en `assets/manifest.json`; las hojas de contacto, en
`assets/preview/`.
