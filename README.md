# ASCII ARPG

ARPG isométrico point-and-click. El mundo se simula en 3D y se dibuja como terminal: un filtro ASCII en screen-space convierte color, luz y siluetas en glifos.

Versión **0.1.0**. Godot **4.7** (Forward+).

## Qué hay ahora

- Caballero (KayKit) con click-to-move, ataque cuerpo a cuerpo y hechizo de Fuego.
- Bosque procedural: árboles, rocas, pasto, fogón y agua caminable con ondas por pisada.
- Ciclo día/noche de 2 minutos (60 s cada fase, con amanecer y atardecer).
- Bárbaros que agroean, persiguen, pegan y reaparecen.
- Esencia al matar, árbol de magia y maná.

## Requisitos

- [Godot 4.7.2](https://godotengine.org/download) (build **Mono** o estándar; el juego está en GDScript).
- Windows, Linux o macOS.

## Cómo correrlo

1. Abrí Godot e importá esta carpeta (`ascii-RPG`).
2. La escena principal es `Scenes/World.tscn`.
3. F5, o desde consola:

```bash
Godot_v4.7.2-stable_mono_win64.exe --path "ruta/al/ascii-RPG"
```

La ventana es 1280×720, con stretch `viewport`.

## Controles

| Acción | Input |
| --- | --- |
| Mover | Clic izquierdo en el suelo |
| Atacar | Clic izquierdo en un bárbaro |
| Mostrar / ocultar HUD | `H` o el botón **HUD** |
| Árbol de magia | `T` (con el HUD abierto) |
| Bola de fuego | `1` (hace falta desbloquear **Fuego**) |

El HUD arranca oculto. El clic sobre botones del HUD no mueve al personaje.

## Cómo se juega

1. Caminá por el claro. Hay un bárbaro cerca del fogón y más en el bosque.
2. Clic en un enemigo: el caballero se acerca y pega (18 de daño, ~2 m).
3. Cada muerte da **8 esencia**. Los bárbaros reaparecen a los 12 s.
4. `H` → `T` → clic en **Fuego** (cuesta 12 esencia, dos muertes).
5. `1` lanza la bola de fuego: 12 de maná, 26 de daño, alcance ~12 m.

Vida 80. Maná 50, se regenera solo. Si te matan, reaparecés en el origen a los 3 s. Las otras runas del árbol (Rayo, Hielo, Sangre, Vacío, Vida) todavía están selladas.

## Mundo

El piso, la navegación y el bosque se arman al entrar a la escena. El agua se puede cruzar y cada paso levanta una onda. De noche el fogón toma más fuerza y el sol da una vuelta continua, sin saltos de luz.

El post-proceso ASCII vive en un `CanvasLayer` sobre la vista 3D. El HUD se dibuja **arriba** del filtro, para que orbes y texto se lean.

## Carpetas

```
Scenes/     World, Player, Mob
Scripts/    movimiento, combate, magia, HUD, bosque, ciclo
Shaders/    ascii, agua, suelo, orbes del HUD
Models/     KayKit (personajes) y Kenney Nature Kit
```

## Créditos

Assets **CC0**, listados también en `Models/ATTRIBUTION.txt`:

- [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers) — Kay Lousberg. Caballero, bárbaro, armas y animaciones.
- [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) — Kenney. Árboles, rocas, pasto, fogón.

Motor: [Godot](https://godotengine.org/) 4.7.

## Estado

MVP jugable: moverse, pelear, crecer un poco y tirar un hechizo. Falta inventario, más ramas del árbol, más tipos de enemigo y un segundo bioma.
