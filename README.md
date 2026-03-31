# Demo Tor Docker (vase clos)

Ce projet cree une demo multi-conteneurs autour de Tor avec:

- `onion-web`: un service cache Tor (v3) qui expose une page web
- `tor-client`: un client Tor qui teste l'acces au service `.onion`
- `relay1`, `relay2`, `relay3`: trois conteneurs relais de demo
- dashboard web en temps reel expose par `tor-client` sur `http://127.0.0.1:38080`

## Prerequis

- Docker Desktop avec Docker Compose active

## Lancer la demo

```powershell
docker compose up --build
```

Au premier demarrage:

- `onion-web` genere automatiquement l'adresse `.onion`
- `tor-client` demarre Tor + un dashboard HTTP local

## Ouvrir le dashboard client

Le dashboard tourne dans le conteneur `tor-client` mais est publie sur votre machine:

```powershell
http://127.0.0.1:38080
```

Depuis l'interface, le bouton "Envoyer une requete reelle" lance une vraie requete `curl` vers le service `.onion` en passant par le proxy SOCKS Tor du client.

## Recuperer l'adresse onion

```powershell
docker compose exec onion-web sh -lc "cat /var/lib/tor/hidden_service/hostname"
```

## Tester manuellement depuis le client (optionnel)

```powershell
$onion = docker compose exec onion-web sh -lc "cat /var/lib/tor/hidden_service/hostname"
docker compose exec tor-client sh -lc "curl --socks5-hostname 127.0.0.1:9050 http://$onion"
```

## Observer les logs

```powershell
docker compose logs -f onion-web tor-client relay1 relay2 relay3
```

## Verifier qu'aucun noeud externe n'est utilise

Le compose tourne en reseau Docker interne (`internal: true`) et les noeuds Tor client/onion sont forces sur les relais `DemoRelay01/02/03` (`StrictNodes 1` + `EntryNodes` + `MiddleNodes`).

1) Rebuild et redemarrage propre:

```powershell
docker compose down -v
docker compose up --build -d
```

2) Verifier qu'il n'y a pas de sortie Internet possible depuis les conteneurs:

```powershell
docker compose exec tor-client sh -lc "ping -c 1 1.1.1.1 || true"
docker compose exec relay1 sh -lc "ping -c 1 8.8.8.8 || true"
```

Ces tests doivent echouer (pas d'acces externe).

3) Verifier que la requete onion fonctionne quand meme via Tor interne:

```powershell
$onion = docker compose exec onion-web sh -lc "cat /var/lib/tor/hidden_service/hostname"
docker compose exec tor-client sh -lc "curl --socks5-hostname 127.0.0.1:9050 http://$onion"
```

4) Inspecter les circuits Tor depuis le client (ControlPort local):

```powershell
docker compose exec tor-client sh -lc "python3 - <<'PY'
import socket
s = socket.create_connection(('127.0.0.1', 9051))
s.sendall(b'AUTHENTICATE\r\nGETINFO circuit-status\r\nQUIT\r\n')
print(s.recv(65535).decode('utf-8', 'replace'))
s.close()
PY"
```

Tu dois voir des circuits construits; ensuite compare les fingerprints affiches avec ceux de tes relais:

```powershell
docker compose exec relay1 sh -lc "cat /var/lib/tor/fingerprint"
docker compose exec relay2 sh -lc "cat /var/lib/tor/fingerprint"
docker compose exec relay3 sh -lc "cat /var/lib/tor/fingerprint"
```

5) Observer les logs Tor pour confirmer l'usage des noeuds locaux:

```powershell
docker compose logs -f tor-client onion-web relay1 relay2 relay3
```

Les connexions OR doivent rester dans le sous-reseau `172.28.0.0/16`.

## Arreter la demo

```powershell
docker compose down
```

## Notes importantes

- Cette maquette est orientee pedagogie.
- Les relais sont des relais de demo dans l'environnement Docker local.
- Pour un relais Tor public de production, il faut une configuration reseau publique dediee (ports ouverts, contact valide, politique de sortie, monitoring).
