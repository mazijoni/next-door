# Eksamensplan – IKT2004 Tverrfaglig praktisk eksamen

**Elev:** Maze – MAZE_Development  
**Skole:** Kuben videregående skole  
**Fag:** Informasjonsteknologi, IKT2004  
**Eksamenstid:** 5 timer

---

## Prosjektbeskrivelse

Jeg skal lage et 3D spill i Godot 4 der spilleren sniker seg inn i et hus.  
Hovedfokuset på eksamensdagen er å implementere et egenutviklet pathfinding-system til en AI-fiende, slik at den beveger seg naturlig rundt vegger og hindringer.

Jeg har allerede laget grunnleggende spillerbevegelse og en fiende fra forberedelsestiden.  
Prosjektet er versjonskontrollert med Git og hostet på GitHub under **MAZE_Development**.

---

## Teknologier

- **Godot 4** – spillmotor
- **GDScript** – programmeringsspråk
- **Egenutviklet pathfinding (A\*)** – rutefinding uten innebygde systemer
- **Git / GitHub** – versjonskontroll og kodelagring
- **MySQL** – database for bruker og progress
- **Raspberry Pi** – server som hoster MySQL-databasen

---

## Hva jeg skal gjøre på eksamensdagen

### 1. Egenutviklet pathfinding til AI-fienden
Implementere A* pathfinding fra scratch i GDScript.  
Fienden bruker et grid-basert kart over banen, finner korteste vei rundt vegger og oppdaterer pathen kontinuerlig.

**Hvorfor eget system:**  
Ved å lage pathfinding selv viser jeg at jeg faktisk forstår algoritmen – ikke bare bruker et ferdig verktøy. A* er industristandard for spillpathfinding og gir full kontroll over fiendeatferden.

**Hvorfor ikke NavigationMesh:**  
Godots innebygde system er en black box – jeg kan ikke forklare hva som skjer inni. Et egenutviklet system viser dypere forståelse.

### 2. Fiendeatferd
Koble pathfindingen til fiendeatferd – fienden patruljerer eller jager spilleren basert på posisjon og synsfelt.

### 3. Versjonskontroll med Git / GitHub
Committe kode underveis på eksamensdagen til GitHub-repoet under MAZE_Development.  
Viser arbeidsprosess og gir backup av koden.

### 4. MySQL-database på Raspberry Pi *(hvis tid)*
Sette opp MySQL på en Raspberry Pi som kjører som lokal server.  
Lage tabeller for å lagre brukerdata og spillprogress.

**Tabeller:**
- `users` – brukernavn, hashet passord
- `progress` – bruker-ID, nivå, poeng, sist lagret

**Hvorfor Raspberry Pi:**  
En ekte server som kjører en databasetjeneste – dette er reell drift, ikke bare teori.

---

## Hva jeg skal si til sensor (stikkord)

### Hva
- 3D snike-spill i Godot 4
- Spilleren sniker seg inn i et hus
- AI-fiende med egenutviklet pathfinding
- Versjonskontroll med Git / GitHub
- MySQL-database på Raspberry Pi

### Hvordan
- A* algoritme – grid over banen, open/closed list, heuristikk
- Fienden oppdaterer path hvert sekund eller ved bevegelse
- Git commit underveis – viser arbeidsprosess
- MySQL tabeller: users, progress
- Godot kobler til databasen via HTTP eller direkte

### Hvorfor
- A* fordi det er raskere enn BFS og gir optimal vei
- Eget system fordi jeg lærer mer og kan forklare hvert steg
- Git fordi profesjonell arbeidsflyt og backup
- Raspberry Pi fordi det er en ekte driftsoppgave – ikke bare lokalt

### Alternativer jeg vurderte
- NavigationMesh – for enkel, kan ikke forklare innmaten
- Lokal fillagring – ikke skalerbart, fungerer ikke fra annet sted
- SQLite – enklere men ikke en ekte server/tjeneste

### Etikk og sikkerhet
- Passord lagres hashet, ikke i klartekst
- Personvern – kun nødvendig data lagres
- GDPR nevnes kort

---

## Kjerneelementdekning

| Kjerneelement | Hvordan jeg dekker det |
|---|---|
| Løsningsarkitektur og systemutvikling | Spillarkitektur, A* pathfinding, database-tilkobling |
| Utviklingsprosesser og kreativ problemløsning | Egenutviklet A*, Git workflow, feilsøking underveis |
| IT-støtte og kommunikasjon | Spillet gir spilleren tydelig feedback og brukeropplevelse |
| Driftstøtte | MySQL på Raspberry Pi – setter opp og konfigurerer en databasetjeneste |
| Etikk, lovverk og yrkesutøvelse | Personvern, GDPR, sikker lagring av brukerdata |
| Informasjonssikkerhet | Hashede passord, sikker databasetilkobling |

---

## Eventuelle forbedringer om tid tillater

- Synsfelt (line of sight) for fienden
- Lydeffekter når fienden oppdager spilleren
- Login-skjerm i spillet koblet til databasen