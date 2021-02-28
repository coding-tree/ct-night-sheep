# Deploy Portainer
In the example Portainer is deployed on Docker Swarm.

In your Linux terminal enter following commands to deploy a Portainer stack in Docker Swarm mode.
```bash
curl -L https://downloads.portainer.io/portainer-agent-stack.yml -o portainer-agent-stack.yml
docker stack deploy -c portainer-agent-stack.yml portainer
```
Your Portainer will be available on http://0.0.0.0:9000 . You have to enter it within 15 minutes after deployment and set your admin password.

# Deploy Traefik

In your Portainer web UI enter `App templates` -> `Custom templates` -> `Add custom template`. Add *title* (suggested: `traefik`) and *description*, set platform to `Linux` and type to `Swarm`. In your web editor paste following YAML code:
```yaml
version: '3'

services:
  reverse-proxy:
    image: traefik:v2.4
    command: 
      --api.insecure=true 
      --providers.docker 
      --providers.docker.swarmMode=true 
      --providers.docker.exposedByDefault=false 
      --providers.docker.network=traefik_default 
      --entryPoints.http-entry-point.address=:80
      --entryPoints.https-entry-point.address=:443
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    deploy:
      placement:
        constraints:
          - node.role == manager
```
**WARNING!!!** Parameter `--api.insecure=true` enables Traefik dashboard. You may consider removing it along with 8080 port binding on production servers (8080 port is for Traefik's dashboard).

You can save the template by clicking `Create custom template`. Now you're going to be moved to the list of custom templates. As you do not have to enter any variables' values, you can go ahead and click the item you have just created and click `Deploy the stack` button. Traefik should be up and running within a minute. If you enabled the dashboard, it should be available at http://0.0.0.0:8080 .

**WARNING!!!** If you your app template has different name than `traefik` and you deployed your Traefik stack directly from App template menu, Traefik stack & service are going to have the same name as your app template. This is going to cause that the service is going to be attached to a network of a name: **app-template-name_default**. You have to reflect this network name in the above pasted YAML and in environment variable while deploying Night Sheep API stack (please see further documentation).

# Deploy Night Sheep API

In your Portainer web UI enter `App templates` -> `Custom templates` -> `Add custom template`. Add *title* (suggested: `nightsheepapi`) and *description*, set platform to `Linux` and type to `Swarm`. In your web editor paste following YAML code:
```yaml
version: '3.4'

services:
  nightsheepapi:
    image: edwardzieminski/nightsheepapi:${API_VERSION:-latest}
    environment:
      - ASPNETCORE_ENVIRONMENT=${API_ENVIRONMENT:-Production}
      - ASPNETCORE_URLS=http://+:5000
    networks:
      - traefik
    deploy:
      labels:
        # request Traefik to load this service
        - "traefik.enable=true"
        # docker network
        - "traefik.docker.network=${TRAEFIK_NETWORK:-traefik_default}"
        # load balancer
        - "traefik.http.services.${TRAEFIK_SERVICE:?}.loadbalancer.server.port=5000"
        - "traefik.http.services.${TRAEFIK_SERVICE:?}.loadbalancer.server.scheme=http"
        # custom response headers
        - "traefik.http.middlewares.${TRAEFIK_SERVICE:?}.headers.customresponseheaders.server=${TRAEFIK_MIDDLEWARE_RESPONSE_HEADER_SERVER:-nightsheep-server}"
        # router for HTTP
        - "traefik.http.routers.${TRAEFIK_ROUTER_HTTP:?}.rule=Host(`${TRAEFIK_ROUTER_HTTP_RULE_HOST:?}`)"
        - "traefik.http.routers.${TRAEFIK_ROUTER_HTTP:?}.entrypoints=${TRAEFIK_ENTRYPOINT_HTTP:?}"
        - "traefik.http.routers.${TRAEFIK_ROUTER_HTTP:?}.service=${TRAEFIK_SERVICE:?}"
        - "traefik.http.routers.${TRAEFIK_ROUTER_HTTP:?}.middlewares=${TRAEFIK_SERVICE:?}"
networks:
  traefik:
    external:
      name: ${TRAEFIK_NETWORK:-traefik_default}
```

Now because you have to enter several environment variable values you cannot deploy the stack directly from `App templates` screen.

In order to deploy a stack, enter `Stacks` screen in your Portainer web UI and click `Add stack` button. Enter your stack name and note it (you need to assign the same value to `TRAEFIK_SERVICE` environment variable). Now switch the build method to `Custom template` and select your Night Sheep API app template. App template's YAML is going to appear on your screen.

Now you have to assign values to environment variables. All the variables are mandatory, however some of the variables have default values, so you do not have to assign anything to them if you are ok with the default value. To add variables along with their values click `add environment variable` button in `Environment` section. You can find the full list of variables in the table below.

| **Variable name**                             | **Description**                                                                                                                                          | **Default value**   | **Allowed/suggested values**                                                                                                                                             |
|-----------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **API_VERSION**                               | Docker Hub image tag.                                                                                                                                    | `latest`            | **suggested:** `latest`, `0.1.1`                                                                                                                                         |
| **API_ENVIRONMENT**                           | API environment.                                                                                                                                         | `Production`        | **only allowed values:** `Production`, `Staging`, `Development`                                                                                                          |
| **TRAEFIK_NETWORK**                           | Docker network to which the Traefik Service is going to be attached.                                                                                     | `traefik_default`   |                                                                                                                                                                          |
| **TRAEFIK_SERVICE**                           | Service name in Traefik. Should be the same as the service name in Docker.                                                                               | -                   | **suggested:** `nightsheepapi-prod`, `nightsheepapi-stg`, `nightsheepapi-dev`                                                                                            |
| **TRAEFIK_MIDDLEWARE_RESPONSE_HEADER_SERVER** | `Server` header that Traefik is going to attach in HTTP responses.                                                                                       | `nightsheep-server` |                                                                                                                                                                          |
| **TRAEFIK_ROUTER_HTTP**                       | Name of a router for HTTP traffic in Traefik.                                                                                                            | -                   | **suggested:** `nightsheepapi-prod-http`, `nightsheepapi-stg-http`, `nightsheepapi-dev-http`                                                                             |
| **TRAEFIK_ROUTER_HTTP_RULE_HOST**             | Domain/host name to be matched with HTTP router. Traefik is going to match the router when *Host* header in HTTP request matches value of this variable. | -                   | **suggested for local deployment:** `nightsheepapi.localhost`, `nightsheepapi-stg.localhost`, `nightsheepapi-dev.localhost`. For public deployment just use your domain. |
| **TRAEFIK_ENTRYPOINT_HTTP**                   | Name of Traefik HTTP entry point (port 80) entered in the Traefik config as a CLI param.                                                                 | -                   | **suggested if Traefik config without changes:** `http-entry-point`                                                                                                      |

If you are deploying the app on your local computer, you have to setup your hosts file. You will find it at `/etc/hosts` (Linux & MacOS) or `C:\Windows\System32\drivers\etc\hosts` (Windows).
```
127.0.0.1       nightsheepapi-dev.localhost
127.0.0.1	nightsheepapi-stg.localhost
127.0.0.1	nightsheepapi.localhost
```

# Enabling HTTPS
This subject is not covered yet. Only proper entrypoint is created in Traefik parameters, but the rest is not configured.