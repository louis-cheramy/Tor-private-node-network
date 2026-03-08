# Demo Tor Docker (vase clos)

Ce projet cree une demo multi-conteneurs autour de Tor avec:

- `onion-web`: un service cache Tor (v3) qui expose une page web
- `tor-client`: un client Tor qui teste l'acces au service `.onion`
- `relay1`, `relay2`, `relay3`: trois conteneurs relais de demo

## Prerequis

- Docker Desktop avec Docker Compose active

## Lancer la demo

```powershell
docker compose up --build
```

Au premier demarrage:

- `onion-web` genere automatiquement l'adresse `.onion`
- `tor-client` attend cette adresse puis tente une requete via SOCKS5

## Recuperer l'adresse onion

```powershell
docker compose exec onion-web sh -lc "cat /var/lib/tor/hidden_service/hostname"
```

## Tester manuellement depuis le client

```powershell
$onion = docker compose exec onion-web sh -lc "cat /var/lib/tor/hidden_service/hostname"
docker compose exec tor-client sh -lc "curl --socks5-hostname 127.0.0.1:9050 http://$onion"
```

## Observer les logs

```powershell
docker compose logs -f onion-web tor-client relay1 relay2 relay3
```

## Arreter la demo

```powershell
docker compose down
```

## Notes importantes

- Cette maquette est orientee pedagogie.
- Les relais sont des relais de demo dans l'environnement Docker local.
- Pour un relais Tor public de production, il faut une configuration reseau publique dediee (ports ouverts, contact valide, politique de sortie, monitoring).
