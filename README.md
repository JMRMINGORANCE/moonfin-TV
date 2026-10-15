# TaquitoFlix

Cliente de Jellyfin con aspecto de plataforma de streaming para Android, Android TV y televisores Samsung (Tizen). La mascota es Taquito 🐶.

Basado en [Moonfin](https://github.com/Moonfin-Client/Moonfin-Core) (GPL-2.0). Este repo no copia todo su código. Contiene:

- `patches/cine-ui.patch`: cambios sobre archivos de Moonfin (tema, navegación, rutas, nombre, servidor por defecto, idioma).
- `overlay/`: pantallas nuevas completas (portada, ficha, bibliotecas, Seerr y componentes comunes).
- `branding/`: dibujo de Taquito (`taquito_head.svg`), logotipo (`taquitoflix_wordmark.svg`), generadores de fondos del protector (`make_wallpapers.py`) y de las capas animadas (`make_layers.py`) y `rebrand.py`, que en cada compilación cambia los textos a TaquitoFlix y genera todos los iconos, banners y pantallas de carga.
- `tizen/`: empaquetado para Samsung.

GitHub Actions descarga la versión de Moonfin indicada en `UPSTREAM_REF`, aplica el parche, copia `overlay/`, ejecuta `branding/rebrand.py` y compila.

## Qué trae

- **Servidor**: en el primer arranque se conecta solo a `https://tv.josemingorance.es`; también aparece ya escrito al añadir un servidor.
- **Idioma**: interfaz y audio en español por defecto, sin subtítulos (se activan en Ajustes → Idioma y subtítulos).
- **¿Quién está viendo?**: con varios perfiles guardados, se elige perfil al abrir la app; avatares de colores y Taquito si no hay foto.
- **Inicio**: cabecera destacada con **tráiler automático** (en silencio; en Samsung se queda la imagen) y botones Reproducir, Más info y **Mi lista**; *Seguir viendo*, **Recién descargado para ti** (lo que pediste en Seerr y ya está listo), **Lo último añadido** (con etiqueta NUEVO), *Top 10*, filas **Porque viste…** y el resto.
- **Bibliotecas**: siempre ordenadas con lo último añadido primero (también la rejilla de *Ver todo*). Seerr mantiene su propio orden.
- **Seerr**: todas las categorías del explorador (tendencias, populares, próximos estrenos, géneros, estudios, cadenas, lista de seguimiento y las filas creadas en Seerr) directamente en su pantalla, con etiqueta **YA DESCARGADA** en lo que ya tienes y **DESCARGANDO 45 %** mientras se descarga (si Seerr está conectado a Radarr/Sonarr). Sin solicitudes ni problemas: con la aprobación automática, el botón de películas y series dice **Descargar**.
- **Buscador**: busca a la vez en tu biblioteca y en Seerr (lo que no tienes sale con el botón Descargar), con búsqueda por voz en Android.
- **Ajustes propios de TaquitoFlix**: tu perfil sobre un fondo de Taquito (cambiar de perfil, cerrar sesión) y nueve categorías con el resumen de lo que tienen puesto: *Idioma y subtítulos* (con vista previa en directo del aspecto de los subtítulos), *Reproducción*, *Portada* (qué filas ves), *Perfil y seguridad* (PIN, perfil al abrir, control parental), *Seerr*, *Descargas*, *Protector de pantalla* (tele), *Servidor* y *Acerca de y ayuda*. Fuera temas, estilos, modo infantil y demás ajustes que solo tenían sentido en Moonfin. Sin asistente de bienvenida.
- **Taquito te avisa**: búsquedas sin resultados, servidor o Seerr sin conexión… con el perro y un botón de reintentar en lugar de mensajes técnicos.
- **Reproducción estilo Netflix**: saltos de 10 s (configurables), barra roja y solo los accesos útiles (Episodios, Audio, Subtítulos, Velocidad, Calidad y Enviar). Si el servidor rechaza el vídeo directo, la app lo pide transcodificado antes de mostrar un error. Botón de saltar intro y créditos.
- **Siguiente episodio estilo Netflix**: al empezar los créditos (si el servidor los tiene marcados) aparece una tarjeta con la imagen del siguiente episodio, «Ver créditos» y «Siguiente episodio», que se va llenando durante la cuenta atrás.
- **Seguir viendo limpio**: oculta lo que llevas más de 3 meses sin tocar (se puede desactivar en Ajustes).
- **Sagas en la portada**: filas automáticas con las colecciones del servidor (Harry Potter, Marvel…), en orden de estreno.
- **Taquito animado al cargar**: al abrir la app y en las esperas del reproductor, Taquito mueve las orejas, bota y parpadea (las capas salen de `branding/make_layers.py`).
- **Protector de pantalla con Taquito** (tele): tras unos minutos sin usar el mando pasan tres fondos dibujados de Taquito (noche de cine, durmiendo bajo la luna y estilo pop) con zoom lento, la hora y el logo. Se ajusta en *Ajustes → Tu TaquitoFlix*. Los fondos salen de `branding/make_wallpapers.py`.
- **Cabecera viva en la tele**: al moverte por las filas, arriba aparece la imagen, los datos y la sinopsis del título enfocado.
- **Menú rápido**: mantener pulsada una carátula (o mantener OK en el mando) en *Seguir viendo* ofrece Reproducir, Ver ficha, Quitar de Seguir viendo, Marcar como visto y Más opciones.
- **Aviso de llegada**: al abrir la app, «Ya puedes ver…» con lo que se descargó desde Seerr mientras estaba cerrada.
- **Actualizaciones**: cada compilación tiene un número que crece (`v2.7.0.N`) y la app avisa sola de que hay versión nueva.
- **Ficha de detalle** estilo Netflix también para lo que aún no tienes (con Descargar) y navegación con mando al estilo de las plataformas de streaming. Android TV muestra *Seguir viendo* en la pantalla de inicio de la tele.
- **Android**: id `es.josemingorance.taquitoflix`, nombre *TaquitoFlix*.

Lo que conserva el nombre Moonfin a propósito: las rutas y mensajes del plugin Moonfin de tu servidor (`/Moonfin/...`), el nombre con el que la app se presenta al servidor y los nombres internos del código. Cambiarlos rompería Seerr y la sincronización con el plugin.

## Actualizar Moonfin sin romper la interfaz

- El código de TaquitoFlix vive casi todo en archivos propios (`overlay/`, `branding/`), que Moonfin nunca toca. El parche sobre archivos de Moonfin es pequeño y los textos se cambian por clave en `rebrand.py`, no por línea.
- La versión de Moonfin está fijada en `UPSTREAM_REF`: una actualización de Moonfin nunca entra sola en las apps.
- Cada lunes, la tarea **Actualizar base de Moonfin** comprueba si hay cambios. Si los hay, aplica la interfaz encima (con fusión de 3 vías) y comprueba que todo compila:
  - **Si encaja**: guarda la nueva versión en `UPSTREAM_REF`, regenera el parche y lanza la compilación. Sale una Release nueva sin hacer nada.
  - **Si no encaja**: no toca nada, las apps siguen con la versión anterior y se abre un aviso (*Issue*) con el detalle para corregirlo.
- También se puede lanzar a mano desde *Actions → Actualizar base de Moonfin → Run workflow*.
- Para volver a la versión anterior de Moonfin basta con restaurar el valor previo de `UPSTREAM_REF` (está en el historial).

## Descargas

Cada compilación publica una **Release** `vX.Y.Z.N` con `TaquitoFlix_Android_v*.apk`, `TaquitoFlix_AndroidTV_v*.apk` y `TaquitoFlix_Tizen_v*_sin-firmar.wgt`.

## Samsung (Tizen)

El `.wgt` hay que firmarlo con un certificado Samsung ligado a tu TV (Tizen Studio → *Certificate Manager*), o añadir al repo los secretos `TIZEN_AUTHOR_P12_BASE64`, `TIZEN_AUTHOR_PASSWORD`, `TIZEN_DISTRIBUTOR_P12_BASE64` y `TIZEN_DISTRIBUTOR_PASSWORD` para que la Release lo incluya ya firmado.

## Firma de los APK

Con los secretos `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS` y `ANDROID_KEY_PASSWORD` todas las versiones se firman igual y se actualizan sin desinstalar.

## Licencia

GPL-2.0, como Moonfin. Basado en el trabajo de Moonfin-Client y Jellyfin.
