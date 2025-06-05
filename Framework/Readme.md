# 🔍 ReconMasta

ReconMasta es un framework profesional y modular de **reconocimiento ofensivo**, ideal para **bug bounty hunters** y **pentesters**. Automatiza la enumeración de subdominios, escaneo de hosts, detección de tecnologías, toma de screenshots, OSINT y más.

---

## ⚙️ Requisitos

- Linux (Ubuntu recomendado)
- Go (>=1.20)
- Python 3
- jq, curl, git, unzip
- Chromium instalado (para aquatone)
- Acceso a internet 😎

---

## ⚙️ Parámetros disponibles
| Opción          | Descripción                                            |
| --------------- | ------------------------------------------------------ |
| `-h`, `--help`  | Muestra esta ayuda                                     |
| `-v`            | Modo detallado (verbose 1)                             |
| `-vv`           | Modo muy detallado (verbose 2)                         |
| `-d`, `--debug` | Modo depuración: traza todos los comandos en `run.log` |
| `--nuclei`      | Ejecuta automáticamente el módulo de `nuclei`          |
| `--no-nuclei`   | Omite el escaneo de vulnerabilidades con `nuclei`      |

## 🚀 Instalación

```bash
git clone https://github.com/tuusuario/ReconMasta.git
cd ReconMasta/Framework
chmod +x install.sh
./install.sh
```

El script instalará también las dependencias de Python indicadas en
`requirements.txt`.

## Uso básico

```bash
./reconmasta.sh -d -v -o resultados
```

## Contribución

¡Las contribuciones son bienvenidas! Abre un issue o un pull request para sugerir mejoras.
