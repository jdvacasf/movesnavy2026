# Gameplay Y Controles

## Bucle Basico

1. Moverse por la instalacion.
2. Evitar al guardia.
3. Encontrar el terminal.
4. Hackearlo para desbloquear la salida.
5. Llegar a la puerta de escape.
6. Interactuar con la salida para completar la mision.

## Controles

- `ui_left` / `ui_right`: mover al jugador.
- `jump`: saltar.
- `interact`: usar terminales.
- `restart`: reiniciar la escena.
- `ui_cancel`: pausar o reanudar.

## Estados De Mision

- `PLAYING`: la partida esta activa.
- `PAUSED`: la accion queda congelada.
- `SUCCESS`: el objetivo se completo.
- `FAILED`: el guardia capturo al jugador.

## IA Del Guardia

El guardia usa una maquina de estados:

- `PATROL`: recorre su ruta.
- `ALERT`: confirma una posible deteccion.
- `CHASE`: persigue al jugador.
- `SEARCH`: revisa la ultima posicion vista.
- `RETURN`: vuelve a su punto de origen.

## Regla Importante

Ver al jugador no termina la partida. La derrota solo ocurre cuando el guardia lo captura.

## Progresion De Mision

- Antes del hack, la salida permanece bloqueada.
- Al hackear el terminal, la salida se desbloquea.
- La victoria solo ocurre al alcanzar y usar la salida.
