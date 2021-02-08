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
    command: --api.insecure=true --providers.docker
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```
Please note that this command enables Traefik dashboard: `--api.insecure=true`. You may consider turning it off on production.

You can save the template by clicking `Create custom template`. Now you're going to be moved to the list of custom teplates. Go ahead and click the item you have just created and then `Deploy the stack`. Traefik should be up and running within a minute. If you enabled the dashboard, it should be available at http://0.0.0.0:8080 .

# Deploy Night Sheep API
In your Portainer instance enter `App templates` -> `Custom templates` -> `Add custom template`. Add title and description, set platform to `Linux` and type to `Swarm`. In your web editor paste following YAML code:
```yaml
version: '3.4'

services:
  nightsheepapi:
    image: edwardzieminski/nightsheepapi:latest
    build:
      context: .
      dockerfile: NightSheepAPI/Dockerfile
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:80
    ports:
      - 78:80
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nightsheepapi.rule=Host(`nightsheepapi.localhost`)"
      - "traefik.http.routers.nightsheepapi.entrypoints=web"
  whoami:
    image: traefik/whoami
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.whoami.rule=Host(`whoami.localhost`)"
      - "traefik.http.routers.whoami.entrypoints=web"
```

Please note environment variable `ASPNETCORE_ENVIRONMENT`. It can take one of three values: `Development`, `Staging`, `Production`. If you pick Development, you will be able to use Swagger.