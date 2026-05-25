# Navy Moves Redux - Backlog corto

Este archivo resume el foco actual. La documentacion viva del proyecto esta en [docs/README.md](docs/README.md).

## Estado actual

- Jugador con movimiento y salto.
- Guardia con patrulla, alerta, persecucion, busqueda y captura.
- Mision en dos pasos: hackear terminal y escapar por la salida.
- HUD minimo con estado de mision.
- Nivel generado desde una matriz de pantallas.
- Transiciones automaticas entre celdas vecinas.
- Arquitectura separada en `level_data.gd`, `level_builder.gd`, `transition_controller.gd` y `mission_controller.gd`.

## Siguiente paso

1. Separar tipos de pantalla por plantilla: pasillo, sala de terminal, sala de guardia, hueco, ascensor.
2. Introducir camaras de seguridad o interruptores como obstaculos extra.
3. Añadir puertas, elevadores y rutas verticales.
4. Hacer que el contenido de cada celda pueda venir de datos externos.
5. Escalar la matriz a varias filas y ramas.

## Regla de mantenimiento

- Si cambia el layout, se documenta primero en `docs/levels.md`.
- Si cambia la estrategia del nivel, se actualiza la entrada correspondiente en `LEVELS` dentro de `level_data.gd`.
