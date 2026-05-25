# Navy Moves Redux Docs

Documentacion principal del proyecto.

## Entradas Rapidas

- [Vision general](architecture.md)
- [Sistema de niveles](levels.md)
- [Gameplay y controles](gameplay.md)
- [Roadmap tecnico](roadmap.md)

## Estado Del Proyecto

Navy Moves Redux es una prueba de concepto en Godot 4 para un juego de sigilo 2D con scroll lateral.

Ya existen:

- Movimiento horizontal y salto.
- Guardia con patrulla, alerta, persecucion, busqueda y retorno.
- Mision en dos pasos: hackear terminal y escapar por la salida.
- HUD minimo de mision.
- Nivel generado desde una matriz 2D.
- Transiciones automaticas entre celdas vecinas.

## Estructura De Alto Nivel

- `main_level.gd`: orquestador fino del nivel.
- `level_data.gd`: catalogo de niveles y matriz por `level_id`.
- `level_builder.gd`: genera geometria y spawns.
- `transition_controller.gd`: crea portales entre pantallas vecinas.
- `mission_controller.gd`: controla HUD, terminal, pausa, victoria y derrota.
- `guard.gd`: IA del enemigo.
- `player.gd`: control del jugador.

## Como Empezar A Editar

1. Para cambiar el layout, edita `level_data.gd`.
2. Para cambiar geometria comun, toca `level_builder.gd`.
3. Para ajustar IA, edita `guard.gd`.
4. Para cambiar textos de HUD o flujo de mision, usa `mission_controller.gd`.
