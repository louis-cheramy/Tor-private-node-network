from flask import Flask, jsonify, send_file
from stem.control import Controller
import stem
import os
import requests

app = Flask(__name__)

# Chemin (monte en lecture seule depuis le volume du service onion) ou le fichier
# "hostname" genere par Tor contient l'adresse .onion du service cache.
ONION_HOSTNAME_PATH = "/shared/onion/hostname"

# Le client Tor expose un proxy SOCKS sur ce host/port a l'interieur du reseau Docker.
TOR_SOCKS_HOST = "172.28.0.6"
TOR_SOCKS_PORT = 9050


def get_onion_hostname():
    """Lit l'adresse .onion ecrite par Tor dans le volume partage."""
    try:
        with open(ONION_HOSTNAME_PATH, "r") as f:
            return f.read().strip()
    except Exception as e:
        print(f"Impossible de lire l'adresse onion: {e}")
        return None


def get_tor_circuits(host, port=9051, password="demo"):
    circuits_data = []
    try:
        print(f"Connexion au Control Port de {host}:{port}")
        # Connexion au Control Port du conteneur cible
        with Controller.from_port(address=host, port=port) as controller:
            controller.authenticate(password=password)
            print(f"Authentification réussie sur {host}:{port}")

            # On recupere d'abord les flux (streams) actifs pour savoir quels
            # circuits transportent reellement du trafic.
            streams_by_circ = {}
            try:
                for stream in controller.get_streams():
                    if stream.circ_id:
                        streams_by_circ.setdefault(stream.circ_id, []).append({
                            "id": stream.id,
                            "status": stream.status,
                            "target": stream.target,
                            "purpose": getattr(stream, "purpose", None),
                        })
            except Exception as e:
                print(f"Impossible de recuperer les streams sur {host}: {e}")

            # Récupération de tous les circuits en cours
            for circ in controller.get_circuits():
                # On extrait les surnoms (Nicknames) des relais traversés
                path = [router[1] for router in circ.path]
                attached_streams = streams_by_circ.get(circ.id, [])

                # Un circuit est considere "utilise" s'il transporte au moins un
                # flux, OU s'il s'agit d'un circuit de rendez-vous d'un service
                # cache (la route effective vers/depuis le .onion).
                purpose = circ.purpose or ""
                is_rendezvous = "REND" in purpose
                active = len(attached_streams) > 0 or (
                    is_rendezvous and circ.status == "BUILT"
                )

                print(
                    f"Circuit {circ.id}: status={circ.status}, purpose={circ.purpose}, "
                    f"path={path}, streams={len(attached_streams)}, active={active}"
                )
                circuits_data.append({
                    "id": circ.id,
                    "status": circ.status,
                    "purpose": circ.purpose,
                    "path": path,
                    "streams": attached_streams,
                    "active": active,
                    "is_rendezvous": is_rendezvous,
                })
    except Exception as e:
        print(f"Erreur de connexion à {host}: {e}")
        return [{"error": str(e)}]

    return circuits_data


def build_full_routes(client_circuits=None, onion_circuits=None):
    """Reconstitue le trajet complet client -> service cache.

    Pour un service cache, le client et le service ne partagent pas un seul
    circuit : ils se rejoignent sur un relais commun, le "point de rendez-vous"
    (le dernier relais de chaque circuit ..._REND).

    On apparie donc chaque circuit HS_CLIENT_REND (cote client) avec un circuit
    HS_SERVICE_REND (cote onion) qui se termine sur le meme relais, puis on
    recolle les deux moities :

        client -> [relais client...] -> POINT DE RENDEZ-VOUS <- [relais service...] <- service
    """
    if client_circuits is None:
        client_circuits = get_tor_circuits("172.28.0.6")
    if onion_circuits is None:
        onion_circuits = get_tor_circuits("172.28.0.5")

    def rend_circuits(circuits):
        return [
            c for c in circuits
            if isinstance(c, dict) and not c.get("error")
            and "REND" in (c.get("purpose") or "") and c.get("path")
        ]

    client_rend = rend_circuits(client_circuits)
    onion_rend = rend_circuits(onion_circuits)

    routes = []
    used_service_ids = set()
    for cc in client_rend:
        rendezvous = cc["path"][-1]  # dernier relais cote client = point de rendez-vous

        # On cherche un circuit cote service qui se termine sur le meme relais.
        match = None
        for sc in onion_rend:
            if sc["id"] in used_service_ids:
                continue
            if sc["path"] and sc["path"][-1] == rendezvous:
                match = sc
                break
        if match:
            used_service_ids.add(match["id"])

        if match:
            # cote service : relais jusqu'au point de rendez-vous, sans le RP lui-meme
            service_to_rp = match["path"][:-1]
            # trajet complet : client -> ... -> RP <- ... <- service
            combined = (
                ["client (tor-client)"]
                + cc["path"]
                + list(reversed(service_to_rp))
                + ["service .onion"]
            )
        else:
            combined = ["client (tor-client)"] + cc["path"] + ["? (cote service inconnu)"]

        routes.append({
            "rendezvous": rendezvous,
            "complete": match is not None,
            "active": bool(cc.get("active")) or bool(match and match.get("active")),
            "client_id": cc["id"],
            "client_path": cc["path"],
            "service_id": match["id"] if match else None,
            "service_path": match["path"] if match else None,
            "combined_path": combined,
        })

    return routes


# Route pour afficher la page web (le HTML)
@app.route("/")
def index():
    return send_file("index.html")


# Route API qui renvoie les trajets complets reconstitues (client <-> service)
@app.route("/api/full-routes")
def api_full_routes():
    return jsonify({"routes": build_full_routes()})


# Route API qui renvoie l'adresse .onion du service cache
@app.route("/api/onion")
def api_onion():
    hostname = get_onion_hostname()
    if hostname:
        return jsonify({"onion": hostname})
    return jsonify({"onion": None, "error": "Adresse .onion pas encore disponible"})


# Route API que notre page web va interroger en Javascript
@app.route("/api/circuits")
def api_circuits():
    return jsonify({
        "client": get_tor_circuits("172.28.0.6"),
        "onion": get_tor_circuits("172.28.0.5")
    })


# Route API qui declenche une vraie requete vers le service .onion via le proxy
# SOCKS du client Tor. Cela force Tor a utiliser (et donc reveler) une route,
# que l'on peut ensuite voir surlignee dans le dashboard.
@app.route("/api/test-onion")
def api_test_onion():
    hostname = get_onion_hostname()
    if not hostname:
        return jsonify({"ok": False, "error": "Adresse .onion indisponible"})

    proxies = {
        "http": f"socks5h://{TOR_SOCKS_HOST}:{TOR_SOCKS_PORT}",
        "https": f"socks5h://{TOR_SOCKS_HOST}:{TOR_SOCKS_PORT}",
    }
    url = f"http://{hostname}/"
    try:
        r = requests.get(url, proxies=proxies, timeout=30)
        return jsonify({
            "ok": True,
            "url": url,
            "status_code": r.status_code,
            "length": len(r.content),
        })
    except Exception as e:
        return jsonify({"ok": False, "url": url, "error": str(e)})


if __name__ == "__main__":
    # On écoute sur le port 3000
    app.run(host="0.0.0.0", port=3000)
