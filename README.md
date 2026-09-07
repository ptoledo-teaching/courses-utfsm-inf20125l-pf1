# PF1: Depuración mediante `printf`

## Introducción

Un programa puede compilar sin warnings y aun así producir resultados incorrectos. En esos casos, los test cases permiten detectar que existe un problema, pero no necesariamente indican en qué parte del código se origina.

Esta actividad introduce una metodología de depuración mediante instrumentación. Se agregarán mensajes temporales para observar el flujo de ejecución y los valores utilizados en los cálculos. Luego se desarrollará una función auxiliar que permitirá habilitar o deshabilitar globalmente esos mensajes sin eliminar sus llamadas.

El laboratorio contiene diez test cases. Los primeros cuatro funcionan correctamente desde el comienzo y servirán como casos de control. Los seis restantes presentan problemas que se investigarán con un nivel de orientación decreciente: los dos primeros se desarrollarán paso a paso, los dos siguientes contarán con indicaciones generales y los dos últimos requerirán seleccionar de manera prácticamente autónoma qué información observar.

### Prerrequisitos

- Saber navegar por directorios y ejecutar programas desde la terminal
- Saber compilar programas en C con `gcc`
- Saber editar código con `vim`
- Saber utilizar redirecciones y consultar códigos de salida
- Saber ejecutar y analizar una suite de test cases
- Tener disponibles Bash, `gcc`, `vim` y `diff`

### Objetivo general

- Diagnosticar y corregir errores lógicos mediante la observación del flujo de ejecución y del estado interno de un programa

### Objetivos específicos

- Reproducir errores mediante test cases específicos
- Agregar mensajes temporales para identificar qué bloque de una estructura condicional se ejecuta
- Observar valores internos relevantes mediante `printf`
- Desarrollar una función auxiliar para centralizar los mensajes de depuración
- Habilitar y deshabilitar globalmente la instrumentación
- Acotar mediante una condición los mensajes producidos dentro de un ciclo
- Ajustar la estrategia de observación a partir de la evidencia obtenida
- Corregir errores lógicos de manera incremental
- Ejecutar pruebas de regresión después de cada corrección

### Estructura inicial

```text
workspace/
├── code/
│   └── armamento.c
├── tests/
│   ├── test001.expected
│   ├── test001.in
│   ├── test002.expected
│   ├── test002.in
│   ├── test003.expected
│   ├── test003.in
│   ├── test004.expected
│   ├── test004.in
│   ├── test005.expected
│   ├── test005.in
│   ├── test006.expected
│   ├── test006.in
│   ├── test007.expected
│   ├── test007.in
│   ├── test008.expected
│   ├── test008.in
│   ├── test009.expected
│   ├── test009.in
│   ├── test010.expected
│   └── test010.in
└── scripts/
    ├── check.sh
    └── tests-run.sh
```

El programa se editará y compilará directamente dentro de `workspace/code`. El script `tests-run.sh` ejecuta la suite y compara la salida completa de cada caso con su archivo `.expected`.

El script `check.sh` permite revisar el estado de la actividad. Comprueba la compilación, las correcciones realizadas, la instrumentación desarrollada, el resultado de la suite y los permisos solicitados.

## Contexto

La Alianza Rebelde prepara un escuadrón para atacar varias instalaciones imperiales. Antes de autorizar el despegue, el sistema del hangar debe comprobar que la nave cuente con suficientes torpedos de protones y que su sistema de puntería se encuentre calibrado.

El programa organiza la información de la misión y la procesa en varias etapas antes de generar el informe final. Por lo tanto, un valor incorrecto puede haberse originado antes del punto en que aparece en la salida. No es necesario comprender todo el programa antes de comenzar a trabajar: la instrumentación permitirá seguir los datos relevantes a través de sus distintas funciones.

El programa implementado en `armamento.c` recibe cinco números enteros, uno por línea:

1. La cantidad de torpedos cargados en la nave
2. La cantidad de objetivos de la misión
3. La cantidad de torpedos que deben permanecer como reserva
4. La desviación inicial del sistema de puntería
5. La cantidad de ciclos de calibración que deben ejecutarse

Cada objetivo requiere exactamente dos torpedos. La cantidad restante se calcula restando de la carga inicial todos los torpedos requeridos por los objetivos.

Cada ciclo de calibración reduce la desviación en una unidad. La desviación nunca puede ser negativa: una vez que alcanza cero, los ciclos adicionales deben mantenerla en ese valor. El sistema de puntería se considera `LISTA` cuando su desviación final es menor o igual que dos; en caso contrario, se considera `PENDIENTE`.

La misión se considera `AUTORIZADA` solamente cuando se cumplen ambas condiciones:

- La cantidad de torpedos restantes es mayor o igual que la reserva
- El sistema de puntería se encuentra `LISTA`

Si alguna de estas condiciones no se cumple, la misión se considera `CANCELADA`.

Para una entrada válida, el programa debe mostrar:

```text
Torpedos requeridos: <CANTIDAD>
Torpedos restantes: <CANTIDAD>
Desviacion final: <CANTIDAD>
Punteria: <LISTA|PENDIENTE>
Mision: <AUTORIZADA|CANCELADA>
```

Si la entrada no contiene cinco números enteros o alguno de ellos se encuentra fuera del rango aceptado, el programa muestra un mensaje de error mediante `stderr` y termina con un código distinto de cero. Todos los test cases de esta actividad contienen entradas válidas.

## Actividad

### 1. Preparar y observar el programa

#### 1.1. Inspeccionar los archivos entregados

Desde la raíz del repositorio, ingresar al directorio `workspace`. Inspeccionar el contenido de `code`, `tests` y `scripts`, y luego revisar `code/armamento.c` sin modificarlo aún.

Identificar el punto de entrada, las estructuras de datos principales y el orden general en que se procesa la información. No es necesario comprender todavía cada cálculo. Ubicar también la función `debug_valor`, que contiene un marcador `TODO` porque corresponde a un placeholder que deberá ser completado durante la actividad. Inicialmente, esta función no produce ningún mensaje.

#### 1.2. Compilar el programa

Construir el comando necesario para compilar `code/armamento.c` con `-Wall`, `-Wextra`, `-Werror` y `-std=c11`. El ejecutable debe llamarse `armamento` y quedar dentro de `code`.

El programa compila sin warnings. Esto confirma que el compilador pudo generar el ejecutable, pero no demuestra que sus cálculos y decisiones sean correctos.

#### 1.3. Ejecutar la suite inicial

Revisar los permisos de `scripts/tests-run.sh` y agregar permiso de ejecución para el propietario. El script recibe la ruta del ejecutable y el directorio que contiene los test cases.

Construir el comando necesario para ejecutar la suite desde `workspace`. La ejecución inicial debe mostrar cuatro pruebas exitosas y seis pruebas fallidas:

```text
PASS:  test001
PASS:  test002
PASS:  test003
PASS:  test004
FAIL:  test005
FAIL:  test006
FAIL:  test007
FAIL:  test008
FAIL:  test009
FAIL:  test010
```

Los cuatro primeros test cases servirán como casos de control. Después de cada corrección se ejecutará nuevamente la suite para comprobar que estos casos continúen entregando `PASS`.

### 2. Investigar paso a paso una decisión

#### 2.1. Reproducir `test005`

Inspeccionar `test005.in` y `test005.expected`. Ejecutar manualmente el programa utilizando `test005.in` como entrada y guardar la salida en `test005.out`. Comparar el resultado obtenido con el esperado mediante `diff -u`.

Calcular manualmente la cantidad de torpedos requeridos y restantes. Comparar esos valores con la reserva y comprobar si el sistema de puntería se encuentra listo.

#### 2.2. Observar la decisión

Abrir `armamento.c` con `vim` y ubicar el punto del programa en que se determina si la misión puede realizarse. En ese bloque, agregar temporalmente una llamada a `printf` antes de cada retorno asociado con esta decisión. Utilizar mensajes distintos, precedidos por `DEBUG:`, para identificar qué bloque se ejecuta.

Agregar también un mensaje que muestre en una misma línea la cantidad restante, la reserva y el estado de la puntería. Volver a compilar y ejecutar solamente `test005`.

Las nuevas líneas no forman parte de la salida especificada: su propósito es mostrar cómo se tomó la decisión. Contrastar la información observada con las dos condiciones definidas en el contexto.

#### 2.3. Corregir la decisión

Corregir el operador que produce el error, retirar las llamadas temporales a `printf` y volver a compilar. Repetir manualmente `test005` y comprobar que ahora coincida con su resultado esperado.

Ejecutar la suite completa. Desde `test001` hasta `test005` deben entregar `PASS`; los cinco casos restantes todavía deben entregar `FAIL`.

### 3. Investigar paso a paso un cálculo

#### 3.1. Reproducir `test006`

Inspeccionar la entrada, el resultado esperado y el resultado obtenido para `test006`. Comparar, en particular, la cantidad de objetivos con la cantidad de torpedos requeridos que informa el programa.

#### 3.2. Observar los valores del cálculo

Ubicar el punto del programa en que se calcula la cantidad de torpedos requeridos. Antes de que el resultado sea devuelto o almacenado, agregar temporalmente una llamada a `printf` que muestre en una misma línea:

- La cantidad de objetivos
- La cantidad de torpedos necesarios por objetivo
- El resultado calculado por la función

Anteponer `DEBUG:` al mensaje y utilizar el marcador `%d` para mostrar cada número entero. Volver a compilar y ejecutar solamente `test006`.

Interpretar la relación entre los tres números. Por cada objetivo, la cantidad requerida debe aumentar en dos torpedos. Comprobar si el cálculo observado representa esta regla.

#### 3.3. Corregir el cálculo

Corregir la expresión que produce el cálculo incorrecto y retirar la llamada temporal a `printf`. Volver a compilar y repetir `test006` hasta que su salida coincida con `test006.expected`.

Ejecutar nuevamente la suite. Desde `test001` hasta `test006` deben entregar `PASS`; los cuatro casos restantes deben continuar entregando `FAIL`.

### 4. Desarrollar una función auxiliar de depuración

#### 4.1. Implementar `debug_valor`

En `armamento.c` se encuentran la variable global `debug_enabled` y `debug_valor`, incorporada como un placeholder y señalada mediante un marcador `TODO`. Reemplazar el contenido asociado con ese marcador por una implementación que cumpla los siguientes requisitos:

- Debe recibir una etiqueta y un valor entero
- Debe consultar `debug_enabled` antes de producir cualquier mensaje
- Cuando la instrumentación esté habilitada, debe escribir mediante `stderr` una línea con el formato `DEBUG: <ETIQUETA>=<VALOR>`
- Cuando la instrumentación esté deshabilitada, no debe producir ninguna salida

La variable global ya utiliza `0` para representar el estado deshabilitado. Utilizar un valor distinto de cero para habilitar temporalmente la instrumentación.

#### 4.2. Utilizar la función auxiliar

Agregar llamadas a `debug_valor` para observar la cantidad de torpedos requeridos, la cantidad restante y la desviación final, una vez que cada valor haya sido calculado. Utilizar, respectivamente, las etiquetas `requeridos`, `restantes` y `desviacion_final`.

Habilitar la instrumentación y ejecutar manualmente un caso de control. Comprobar que los mensajes aparezcan mediante `stderr`. Luego deshabilitarla, volver a ejecutar el mismo caso y comprobar que esos mensajes desaparezcan sin eliminar las llamadas agregadas.

A partir de este punto, utilizar `debug_valor` para toda la instrumentación adicional. Las llamadas pueden permanecer en el programa porque su salida se controla globalmente mediante `debug_enabled`.

### 5. Investigar con orientación general

#### 5.1. Investigar `test007`

Revisar la entrada y los resultados de `test007`. Este caso no solicita ciclos de calibración, por lo que la desviación inicial y la desviación final deben coincidir.

Comparar el valor observado con el límite que determina si la puntería se encuentra lista. Habilitar `debug_enabled` y utilizar `debug_valor` para comprobar qué valor participa en esa decisión. Corregir la causa del problema sin modificar el test case.

Deshabilitar la instrumentación, recompilar y comprobar que `test007` entregue `PASS`.

Ejecutar nuevamente la suite y confirmar que desde `test001` hasta `test007` entreguen `PASS`.

#### 5.2. Investigar `test008`

Revisar cuántos ciclos de calibración solicita `test008` y cuánto debería disminuir la desviación. El resultado obtenido inicialmente indica que no se ejecuta la cantidad esperada de actualizaciones.

Habilitar la instrumentación y agregar llamadas a `debug_valor` dentro del ciclo de calibración para observar el número del ciclo y la desviación. Utilizar esta evidencia para corregir el problema sin alterar la cantidad de ciclos recibida por el programa.

Deshabilitar la instrumentación, recompilar y comprobar que `test008` entregue `PASS`. Al ejecutar la suite, desde `test001` hasta `test008` deben entregar `PASS`.

### 6. Investigar con mayor autonomía

En los dos casos siguientes se debe aplicar el mismo proceso utilizado anteriormente: reproducir el problema, comparar los archivos, formular una pregunta, seleccionar los valores relevantes, instrumentar el programa, interpretar la evidencia, corregir la causa y ejecutar nuevamente la suite. Las instrucciones ya no indicarán qué función contiene el problema ni qué expresión debe modificarse.

#### 6.1. Investigar `test009` mediante una traza condicional

El caso `test009` solicita 300 ciclos de calibración. Imprimir todas las iteraciones produciría una traza extensa que dificultaría reconocer el comportamiento relevante.

Agregar dentro del ciclo una llamada a `debug_valor` con la etiqueta `ciclo`, protegida por una condición local. Elegir la condición de modo que al ejecutar `test009` se muestren entre una y diez iteraciones. Agregar dentro de la misma condición las observaciones adicionales que se consideren necesarias.

Utilizar la traza acotada para investigar por qué la desviación no permanece en el valor establecido por la especificación. Corregir el problema, pero conservar la instrumentación condicional con `debug_enabled` deshabilitado.

Recompilar y comprobar que `test009` entregue `PASS`.

Ejecutar nuevamente la suite y confirmar que desde `test001` hasta `test009` entreguen `PASS`.

#### 6.2. Investigar `test010`

Investigar `test010` de manera autónoma. Determinar qué parte de la salida no coincide, decidir qué información interna permitiría explicar la diferencia y utilizar `debug_valor` para obtenerla.

Corregir solamente la causa respaldada por la evidencia. Deshabilitar la instrumentación, recompilar y comprobar que `test010` entregue `PASS`.

### 7. Comprobar todas las correcciones

#### 7.1. Deshabilitar la instrumentación

Confirmar que `debug_enabled` tenga el valor `0`. Mantener implementada la función `debug_valor`, las tres llamadas agregadas en 4.2 y la instrumentación condicional desarrollada en 6.1.

Retirar cualquier llamada directa a `printf` utilizada temporalmente para depurar los dos primeros casos. La salida mediante `stdout` debe contener solamente las cinco líneas definidas en el contexto y `stderr` no debe contener mensajes para una entrada válida.

#### 7.2. Ejecutar una prueba de regresión

Volver a compilar con las mismas opciones utilizadas anteriormente. Si aparece un warning, leerlo, corregir el problema informado y repetir la compilación.

Ejecutar la suite completa. Los diez test cases deben entregar `PASS`:

```text
PASS:  test001
PASS:  test002
PASS:  test003
PASS:  test004
PASS:  test005
PASS:  test006
PASS:  test007
PASS:  test008
PASS:  test009
PASS:  test010
```

Esta prueba de regresión permite comprobar que las seis correcciones resolvieron los casos investigados sin afectar los cuatro casos de control.

### 8. Verificación final

#### 8.1. Habilitar el script de verificación

Revisar los permisos de `scripts/check.sh` y agregar permiso de ejecución para el propietario.

#### 8.2. Ejecutar la verificación

Ejecutar `scripts/check.sh` desde `workspace`. El script informa qué actividades están completas y cuáles permanecen pendientes.
