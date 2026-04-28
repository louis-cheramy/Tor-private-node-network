from flask import Flask, jsonify, send_file
from stem.control import Controller
import stem

app = Flask(__name__)

def get_tor_circuits(host, port=9051, password="demo"):
    circuits_data = []
    try:
        print(f"Connexion au Control Port de {host}:{port}")
        # Connexion au Control Port du conteneur cible
        with Controller.from_port(address=host, port=port) as controller:
            controller.authenticate(password=password)
            print(f"Authentification réussie sur {host}:{port}")
            
            # Récupération de tous les circuits en cours
            for circ in controller.get_circuits():
                # On extrait les surnoms (Nicknames) des relais traversés
                path = [router[1] for router in circ.path]
                print(f"Circuit {circ.id}: status={circ.status}, purpose={circ.purpose}, path={path}")
                circuits_data.append({
                    "id": circ.id,
                    "status": circ.status,
                    "purpose": circ.purpose,
                    "path": path
                })
    except Exception as e:
        print(f"Erreur de connexion à {host}: {e}")
        return [{"error": str(e)}]
        
    return circuits_data

# Route pour afficher la page web (le HTML)
@app.route("/")
def index():
    return send_file("index.html")

# Route API que notre page web va interroger en Javascript
@app.route("/api/circuits")
def api_circuits():
    return jsonify({
        "client": get_tor_circuits("172.28.0.6"),
        "onion": get_tor_circuits("172.28.0.5")
    })

if __name__ == "__main__":
    # On écoute sur le port 3000
    app.run(host="0.0.0.0", port=3000)