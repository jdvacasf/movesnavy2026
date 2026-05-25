# Sistema De Niveles

## Fuente De Datos

Los niveles pueden vivir en dos sitios:

- `level_data.gd` como fallback local.
- `levels/<level_id>.json` como formato principal para contenido nuevo.

`main_level.gd` pide un `level_id` y `level_data.gd` resuelve ese id. Si existe `res://levels/<level_id>.json`, se carga desde ahi. Si no, usa el catalogo local.

## Formato General

```json
{
  "id": "facility_branching",
  "screen_width": 640,
  "screen_height": 360,
  "floor_height": 40,
  "templates": {
    "start_corridor": {
      "floor": true,
      "platforms": []
    }
  },
  "matrix": [
    [
      {
        "id": "dock_start",
        "template": "start_corridor",
        "player_spawn": [110, 280]
      }
    ]
  ]
}
```

## Campos Principales

- `id`: identificador logico del nivel.
- `screen_width`: ancho de una pantalla base.
- `screen_height`: alto de una pantalla base.
- `floor_height`: grosor del suelo comun.
- `templates`: catalogo reutilizable de celdas base.
- `matrix`: arreglo 2D de pantallas.

## Plantillas Reutilizables

Cada celda puede declarar `template`. El cargador resuelve primero la plantilla y luego aplica overrides de la celda.

Ejemplo:

```json
{
  "id": "power_room",
  "template": "switch_room",
  "switches": [
    {
      "id": "security_switch",
      "unlock_doors": ["exit_gate"]
    }
  ]
}
```

## Campos De Celda

- `id`: identificador de la pantalla.
- `floor`: activa o desactiva el suelo.
- `player_spawn`: posicion local del jugador `[x, y]`.
- `guard_spawn`: posicion local del guardia `[x, y]`.
- `terminal_spawn`: posicion local de la terminal `[x, y]`.
- `exit_spawn`: posicion local de la salida `[x, y]`.
- `platforms`: plataformas extra.
- `doors`: puertas o barreras activables.
- `switches`: interruptores que abren puertas o desactivan camaras.
- `cameras`: zonas de vigilancia.
- `elevators`: accesos interactivos que mueven al jugador a otra celda.

## Entidades Nuevas

### `platforms`

```json
{
  "position": [250, 245],
  "size": [150, 20],
  "color": [0.47, 0.37, 0.28, 1.0]
}
```

### `doors`

```json
{
  "id": "exit_gate",
  "position": [560, 272],
  "size": [28, 112],
  "open": false
}
```

### `switches`

```json
{
  "id": "security_switch",
  "position": [520, 280],
  "size": [40, 48],
  "prompt": "Press E to reroute power",
  "unlock_doors": ["exit_gate"],
  "disable_cameras": ["cam_upper_bridge", "cam_exit_branch"]
}
```

### `cameras`

```json
{
  "id": "cam_upper_bridge",
  "position": [320, 130],
  "size": [300, 150],
  "color": [0.25, 0.85, 1.0, 0.12]
}
```

### `elevators`

```json
{
  "id": "lift_a_mid",
  "position": [110, 292],
  "size": [72, 84],
  "target_cell": [1, 0],
  "target_position": [110, 292],
  "prompt": "Press E to ride up"
}
```

- `target_cell`: columna y fila destino.
- `target_position`: posicion local dentro de la celda destino.

## Reglas De La Matriz

- Cada fila es una banda horizontal.
- Cada columna representa una pantalla vecina.
- `null` crea un hueco vacio.
- La posicion real se calcula con `column * screen_width` y `row * screen_height`.
- Las transiciones se siguen generando automaticamente entre celdas adyacentes existentes.

## Nivel De Referencia

`levels/facility_branching.json` es ahora el ejemplo principal del proyecto. Demuestra:

- plantillas reutilizables,
- varias filas y ramas,
- puertas desbloqueables,
- camaras desactivables,
- elevadores interactivos,
- contenido cargado desde datos externos.
