# Ejemplo de uso de Kong

## Setup
El ejemplo usa Docker Compose, así que: https://docs.docker.com/compose/install/

Si eso está instalado, ejecutar `start.sh`. El script crea una red de Docker, configura la base de datos, y levanta Kong en los puertos default (8000 y 8001; los puertos de SSL y clustering están inhabilitados en el ejemplo).

Si se quisieran cambiar los puertos, modificar el docker-compose.yml. Ej.: Si en lugar de el 8000, se quisiera usar el 9590, cambiar la linea `- "8000:8000"` por `- "9590:8000"`.

Para verificar que Kong esté funcionando, hacer un request a `http://localhost:8000`.

## APIs y consumers
Objetivo: Crear dos consumers (fun_person y sad_person) y dos endpoints (funapi y sadapi). Autenticados por API keys, el Consumer 1 solo tendrá acceso al Endpoint 1, y el Consumer 2 solo podrá acceder al Endpoint 2.

### APIs

El endpoint `/fun` va a redirigir a https://imgur.com

    curl -d 'name=funapi' -d 'upstream_url=https://imgur.com' -d 'uris=/fun' localhost:8001/apis

Pero solamente los miembros del grupo `funny_people` puede ir ahí

    curl -d 'name=acl' -d 'config.whitelist=funny_people' localhost:8001/apis/funapi/plugins

Lo mismo, pero con `/sad`, redirigiendo a https://httpbin.org/get

    curl -d 'name=sadapi' -d 'upstream_url=https://httpbin.org/get' -d 'uris=/sad' localhost:8001/apis

Como debe ser, solo la `sad_people` puede ir ahí

    curl -d 'name=acl' -d 'config.whitelist=sad_people' localhost:8001/apis/sadapi/plugins

Actualmente, Kong sabe que solamente tiene que dejar pasar a `funny_people` o `sad_people`, dependiendo del endpoint. Si intentamos consumir alguna API, como no sabe quien somos, nos va a rebotar (`curl http://localhost:8000/fun`). Por tanto, tenemos que darle una forma de autenticar a quien quiera consumir el servicio. Para eso, habilitamos el plugin de Key Authentication en cada API:

    curl -d 'name=key-auth' -d 'config.key_names=apikey' localhost:8001/apis/funapi/plugins
    curl -d 'name=key-auth' -d 'config.key_names=apikey' localhost:8001/apis/sadapi/plugins

Ahora si se le pega de nuevo (`curl http://localhost:8000/fun`), el mensaje es que no se encontró una key en el request (si le mandaramos una, sería inválida)

### Consumers

Creamos un par de personas, una feliz y otra no tanto

    curl -d 'username=fun_person' localhost:8001/consumers
    curl -d 'username=sad_person' localhost:8001/consumers

Y les creamos API keys

    # El "-d ''" es para mandar un POST vacío, y que las keys se autogeneren.
    # Si se quisiera, se podrían settear API keys predefinidas
    curl -d '' localhost:8001/consumers/fun_person/key-auth
    curl -d '' localhost:8001/consumers/sad_person/key-auth

Si ahora intentáramos consumir las APIs con las keys generadas, aún nos rebotaría diciendo que no tenemos acceso, ya que los usuarios no son parte de ningún grupo. Por ahora:

    curl -d 'group=fun_people' localhost:8001/consumers/fun_person/acls
    curl -d 'group=sad_people' localhost:8001/consumers/sad_person/acls

Ahora si hacemos los requests de nuevo, pero autenticándonos con las API keys generadas, Kong va a poder saber quien es el que llama, y decidir si deja pasar el request o no, en base a qué grupo pertenece:

    # Usar las API keys generadas antes, éstas son de ejemplo
    curl -H 'apikey:mVDmnK0YwgA3cTKRc8CA83Y7bM8hrVK9' localhost:8000/fun
    curl -H 'apikey:NJZ0kGCsGiwPAMMFF5iR40LYFzKSXotV' localhost:8000/sad

Si se usan las API keys invertidas (léase, la `sad_person` quisiera consumir la `funapi`), Kong rechaza el request diciendo que el usuario no está habilitado a consumir el servicio.
