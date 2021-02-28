# Deploy Portainer
In our example Portainer is deployed on Docker Swarm.

In your Linux terminal enter following lines:
```bash
curl -L https://downloads.portainer.io/portainer-agent-stack.yml -o portainer-agent-stack.yml
docker stack deploy -c portainer-agent-stack.yml portainer
```
Your Portainer will be available on http://0.0.0.0:9000 . You have to enter it within 15 minutes after deploy and set your admin password.

# Deploy Traefik
In your Portainer instance enter `App templates` -> `Custom templates` -> `Add custom template`. Add title and description, set platform to `Linux` and type to `Swarm`. In your web editor paste following YAML code:
```yaml
version: '3'

services:
  reverse-proxy:
    image: traefik:v2.4
    command: 
      --api.insecure=true 
      --providers.docker 
      --providers.docker.swarmMode=true 
      --providers.docker.useBindPortIP=true 
      --providers.docker.exposedByDefault=false 
      --providers.docker.network=traefik-for-nightsheepapi_default 
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
Please note that parameter `--api.insecure=true` enables Traefik dashboard. You may consider removing it together with 8080 port mapping on production (8080 port is for Traefik's dashboard).

You can save the template by clicking `Create custom template`. Now you're going to be moved to the list of custom teplates. Go ahead and click the item you have just created and then `Deploy the stack`. Traefik should be up and running within a minute. If you enabled the dashboard, it should be available at http://0.0.0.0:8080 .

# Deploy Night Sheep API
In your Portainer instance enter `App templates` -> `Custom templates` -> `Add custom template`. Add title and description, set platform to `Linux` and type to `Swarm`. In your web editor paste following YAML code:
```yaml
version: '3.4'

services:
  nightsheepapi:
    image: edwardzieminski/nightsheepapi:latest
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:5002
    ports:
      - 5002:5002
    networks:
      - traefik
    deploy:
      labels:
        # request Traefik to load this service
        - "traefik.enable=true"
        # docker network
        - "traefik.docker.network=traefik-for-nightsheepapi_default"
        # load balancer
        - "traefik.http.services.nightsheepapi-dev.loadbalancer.server.port=5002"
        - "traefik.http.services.nightsheepapi-dev.loadbalancer.server.scheme=http"
        # custom response headers
        - "traefik.http.middlewares.secure-headers.headers.customresponseheaders.server=Traefik-for-NightSheepAPI"
        # router for HTTP
        - "traefik.http.routers.nightsheepapi-dev-http.rule=Host(`nightsheepapi-dev.localhost`)"
        - "traefik.http.routers.nightsheepapi-dev-http.entrypoints=http-entry-point"
        - "traefik.http.routers.nightsheepapi-dev-http.service=nightsheepapi-dev"
        - "traefik.http.routers.nightsheepapi-dev-http.middlewares=secure-headers"
networks:
  traefik:
    external:
      name: traefik-for-nightsheepapi_default
```

Now you can follow the same steps as for Traefik stack in order to deploy the API stack.

Please remember to set proper domain/hostname in router rules. In this sample I have set the domain `nightsheepapi-dev.localhost` in `/etc/hosts` file (windows equivalent: `C:\Windows\System32\drivers\etc`) and then used this domain in router rules.

# Other environments than development

The above listings show how to deploy development environment. If you want to deploy other enviroments you have to make several changes. In this folder you can find sample yml files for all environments development. The list of differences:
- Change `ASPNETCORE_ENVIRONMENT` variable to one of the values: `Development`, `Staging`, `Production`.
- Change the port in `ASPNETCORE_URLS` variable `5002` (dev), `5001` (staging), `5000` (prod).
- Change service name in all labels to the name of your choice (suggested names: `nightsheepapi-dev`, `nightsheepapi-stg`, `nightsheepapi`). The name should be consistent with your app template name -> docker stack name -> docker service name.
- Change the port in load balancer label to the same one as in environment variables.
- Change router name in all labels to the name of your choice (suggested names: `nightsheepapi-dev-http`, `nighsheepapi-stg-http`, `nightsheepapi-prod-http`). Please note that if you are going to use i.e. HTTPS you need to repeat (and maybe modify) all router lines for another entrypoint.
- Change host name in router rules
- Change service name in router settings

The files uploaded in this folder can be used to deploy all environments at once using following domains: `http://nighsheepapi-dev.localhost`, `http://nighsheepapi-stg.localhost`, `http://nighsheepapi.localhost`. You have to set those domains in your `/etc/hosts` file first.

```
127.0.0.1   nightsheepapi-dev.localhost
127.0.0.1	nightsheepapi-stg.localhost
127.0.0.1	nightsheepapi.localhost
```

# Enabling HTTPS
This subject is not covered yet. Only proper entrypoint is created in Traefik parameters, but the rest is not configured.