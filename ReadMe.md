# Firmware von Freifunk Paderborn

Dieses Repository beherbergt die Skripte, um die Firmware von Freifunk Paderborn zu bauen.
Die Inhalte dieses Repositories werden unter einer "2-clause BSD" Lizenz veröffentlicht, Details sind der Datei [LICENSE](https://git.c3pb.de/freifunk-pb/firmware/blob/master/LICENSE) zu entnehmen.

Beim Bauen der Firmware werden weitere Git-Repositories heruntergeladen und benutzt:

* Basis: [Gluon](https://github.com/freifunk-gluon/gluon)
* Site-Repository: [FFPB](https://git.c3pb.de/freifunk-pb/site-ffpb)

## Vorbereitung / Umgebung

Es gibt zwei Möglichkeiten, die Firmware zu bauen. Entweder in einem [Docker](https://www.docker.com)-Container
oder "nativ" auf einem Debian/Ubuntu-System. Der Weg über Docker ist der empfohlene Weg für alle, die die Firmware
nur nachbauen wollen - der Docker-Weg ermöglicht vergleichbare Builds.

Hinweis für MacOS-Nutzer: derzeit scheint die Volume-Mount-Funktionalität defekt zu sein (siehe auch [docker issue #4023](https://github.com/docker/docker/issues/4023)), ~~bis ein Workaround existiert~~ wird die Nutzung von Linux empfohlen.

### Docker-Container

Man benötigt Docker, gawk und git:
```bash
sudo apt-get install gawk git
sudo apt-get install docker.io || wget -qO- https://get.docker.com/ | sh
docker pull ffpb/build
```

Das Docker-Repository `ffpb/build` kann auch selbst erstellt werden: `docker build -t ffpb/build docker` (wenn das Git-Repository, in dem diese ReadMe liegt, ausgecheckt wurde)

### Entwickler-System

Als Requirements sind die allgemeinen Build-Tools sowie libfaketime nötig. Zum Bauen des gcc in der Toolchain sind noch drei weitere Bibliotheken notwendig:
```bash
sudo apt-get install build-essential git gawk python subversion unzip p7zip-full \
  faketime lib{gmp,mpfr,mpc}-dev zlib1g-dev ncurses-dev
```

## Bauen

Klone das Repository in dem diese ReadMe liegt, falls noch nicht geschehen und wechsle in das Verzeichnis:
```bash
git clone https://git.c3pb.de/freifunk-pb/firmware.git
cd firmware
```

Rufe `build.sh` bzw. `docker-build.sh` auf und übergebe folgende Umgebungsvariablen:

* **BASE** gibt die Gluon-Version an, als Basis benutzt werden soll (z.B. 'v2014.4')
* **BRANCH** ist der Name des Firmware-Branches (also /stable/, /testing/ oder /experimental/)
* **VERSION** wird die Versions-Nr. der neuen Firmware (kann bei BRANCH=experimental) weggelassen werden
* **BROKEN** falls "1", erzeuge ebenfalls Firmware-Images für ungetestete Plattformen (default: "0")
* **MAKEJOBS** spezifiziert die Anzahl der parallel laufenden Compiler-Prozesse (falls nicht angegeben, wird ein Prozess pro CPU/Kern gestartet)
* **TARGET** ein Liste durch Leerzeichen separierter Hardware-Zielplattformen (falls nicht angegeben, werden Images für alle bekannten Plattformen erzeugt)
* **PRIORITY** spezifiziert die maximale Anzahl an Tagen, die ein Knoten das Einspielen des Updates verzögern darf
* **VERBOSE** falls "1", schaltet Debug-Ausgaben mit an - dies ist nur notwendig wenn Fehler beim Build auftreten


### Beispiele

```bash
# Baut eine testing-Firmware auf Basis von Gluon 2014.4
BASE=v2014.4 BRANCH=testing VERSION=0.6~rc1 ./build.sh

# Baut eine experimental-Firmware auf Basis des aktuellen Gluon-Master (nur für Experten)
BASE=master BRANCH=experimental ./build.sh
```

Nach erfolgreichem Build-Vorgang liegt die Firmware fertig paketiert im `output/` Verzeichnis und in `versions/` wurde (außer bei BRANCH=experimental) eine Versions-Informationsdatei abgelegt. Mit dieser (nur der Name) kann `build-version.sh` die gegebene Version erneut bauen.


## Kontroll-Build einer Firmware

Klone das Repository in dem diese ReadMe liegt, falls noch nicht geschehen und wechsle in das Verzeichnis:
```bash
git clone https://git.c3pb.de/freifunk-pb/firmware.git
cd firmware
```

Im Verzeichnis `versions` liegen alle bekannten Firmware-Versionen. Durch Aufruf von `build-version.sh` und Übergabe des Dateinamens (ohne Pfad) wird diese Version erneut gebaut. Es werden zwei Umgebungsvariablen unterstützt:
* **VERBOSE=1** funktioniert wie beim normalen Build und aktiviert Debug-Ausgaben
* **NO_DOCKER=1** benutzt `build.sh` statt `docker-build.sh` zum Bau

Die Nutzung von Docker zur Überprüfung von Builds wird dringend empfohlen, da Docker Unterschiede zwischen den Build-Rechnern ausgleicht und die Binaries so einfacher überprüfbar werden.

### Beispiele

```bash
./build_version.sh 0.6.1_stable # baut Version '0.6.1_stable' erneut
NO_DOCKER=1 ./build_version.sh 0.6.1_stable # ohne Docker-Umgebung erneut bauen
```