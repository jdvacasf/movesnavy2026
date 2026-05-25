# Arquitectura

## Objetivo

Separar datos, construccion del nivel, transiciones y logica de mision para que el proyecto escale sin seguir creciendo en un solo script.

## Flujo De Ejecucion

1. `main_level.gd` carga `level_data.gd`.
2. `level_builder.gd` construye las celdas, suelos y plataformas.
3. `main_level.gd` aplica spawns y limites de camara.
4. `mission_controller.gd` conecta terminal, HUD y estado global.
5. `transition_controller.gd` crea los portales entre celdas vecinas.
6. `guard.gd` corre su IA de patrulla y deteccion.

## Responsabilidades Por Archivo

### `main_level.gd`

Actua como coordinador. No deberia contener logica de construccion compleja ni reglas de juego.

### `level_data.gd`

Define los niveles como datos. La fuente de verdad del mapa es la matriz 2D de cada nivel.

### `level_builder.gd`

Instancia nodos de nivel a partir de la matriz. Convierte cada celda en una pantalla jugable.

### `transition_controller.gd`

Crea areas de transicion en los bordes donde exista una celda vecina. Teletransporta jugador y guardia entre pantallas.

### `mission_controller.gd`

Centraliza terminal, HUD, pausa, victoria, derrota y reinicio visual de la partida.

### `guard.gd`

Implementa la IA del enemigo con estados de patrulla, alerta, persecucion, busqueda y retorno.

## Principios

- Los datos del nivel viven fuera del flujo principal.
- El nivel se puede ampliar tocando datos, no copiando scripts.
- La derrota depende de captura real, no de una deteccion instantanea.
- La transicion entre pantallas debe ser generada, no manual.

