# Eksamensplan

---

## Prosjektbeskrivelse

Jeg skal lage deler av et 3D spill i Godot 4.6 der spilleren sniker seg inn i et hus.  
Hovedfokuset på eksamensdagen er å implementere et egenutviklet pathfinding-system til en AI-fiende, slik at den beveger seg naturlig rundt vegger og hindringer.
TODO: Forklar hva et pathfinding-system er for noe

Jeg har allerede laget grunnleggende spillerbevegelse tidligere og en fiende fra forberedelsestiden.  
Prosjektet er versjonskontrollert med Git og hostet på GitHub under **MAZE_Development**. Endringer etter dagen blir lagt in som en ny commit.

TODO: Forklar hva du skal gjøre rundt database

---

## Teknologier

- **Godot 4.6** – spillmotor
- **GDScript** – programmeringsspråk
- **Egenutviklet pathfinding (A\*)** – rutefinding uten innebygde systemer
- **MAZE_Development Workspace** – egenutviklet prosjektplattform (maze-development.com/workspace) med Kanban, versjonskontroll og GitHub-integrasjon
- **MySQL** – database for bruker og progress
- **Raspberry Pi** – server som hoster MySQL-databasen

TODO: Skriv en hel setning på hver an de som forklarer hva de er eller hvorfor.
---

## Hva jeg skal gjøre på eksamensdagen

### 1. Egenutviklet pathfinding til AI-fienden
Implementere A* pathfinding fra scratch i GDScript.  
Fienden bruker et grid-basert kart over banen, finner korteste vei rundt vegger og oppdaterer pathen kontinuerlig.

TODO: Hva betyr A* og enkelt forklart, hvordan fungerer det? Hva er prinsippene i algoritmen?
TODO: Hvordan finner fienden korterste vei når du starter. Altså nå pr idaf? Og hva er forskjellen?

**Hvorfor eget system:**  
Ved å lage pathfinding selv viser jeg at jeg faktisk forstår algoritmen – ikke bare bruker et ferdig verktøy. A* er industristandard for spillpathfinding og gir full kontroll over fiendeatferden.

**Hvorfor ikke NavigationMesh:**  
Godot sitt innebygde system er en black box – jeg kan ikke forklare hva som skjer inni. Et egenutviklet system viser dypere forståelse.
TODO:  Hvorfor er det bedre å bytte til A*?
 
### 2. Fiendeadferd
Koble pathfindingen til fiendeatferd – fienden patruljerer eller jager spilleren basert på posisjon og synsfelt.

### 3. Versjonskontroll med MAZE_Development Workspace
Bruke MAZE_Development Workspace (maze-development.com/workspace) til å administrere prosjektet – Kanban-board for oppgaver, GitHub-integrasjon for commits, og prosjektoversikt.  
Committe kode underveis på eksamensdagen. Viser arbeidsprosess og gir backup.
TODO: Hva er MAZE_Development Workspace?

### 4. MySQL-database på Raspberry Pi *(hvis tid)*
Sette opp MySQL på en Raspberry Pi som kjører som lokal server.  
Lage tabeller for å lagre brukerdata og spillprogress.
TODO: Tabell skal lagre bruker for senere innlogging. Passord skal hashes i database, slik at selv om databasen hackes, kan ikke passord leses. 
TODO: Noen setninger om hashing så du kan forklare hensiketen. Sjekk nettsider på nettet
TODO: Sjekk hvordan du oppretter tabeell.
Eks: CREATE TABLE users (id int auto_increment, username varchar(256), password_hashed var(256), lastlogin timestamp);

**Tabeller:**
- `users` – brukernavn, hashet passord
- `progress` – bruker-ID, nivå, poeng, sist lagret

**Hvorfor Raspberry Pi:**  
En ekte server som kjører en databasetjeneste – dette er reell drift, ikke bare teori.
TODO: Forklare at denne ikke er raskt nok i et ekste produksjonsmiljø
---

## Hva jeg skal si til sensor (stikkord)

### Hva
- 3D snike-spill i Godot 4.6
- Spilleren sniker seg inn i et hus
- AI-fiende med egenutviklet pathfinding
- MAZE_Development Workspace – egenutviklet prosjektplattform med Kanban og GitHub-sync
- MySQL-database på Raspberry Pi

### Hvordan
- A* algoritme – grid over banen, open/closed list, heuristikk
TODO: Hva betyr dette? open/closed list, heuristikk
- Fienden oppdaterer path hvert sekund eller ved bevegelse
- MAZE_Development Workspace med Kanban-board – tracker oppgaver og committer til GitHub underveis
TODO: Hva er Kanban i noen korte ord?
- MySQL tabeller: users, progress
- Godot kobler til databasen via direkte

### Hvorfor
- A* fordi det er raskere enn BFS og gir optimal vei
TODO: Hva er BFS?
- Eget system fordi jeg lærer mer og kan forklare hvert steg
- MAZE_Development Workspace fordi det er en profesjonell arbeidsflyt – Kanban, GitHub-sync, prosjektoversikt
- Raspberry Pi fordi det er en ekte driftsoppgave – ikke bare lokalt

### Alternativer jeg vurderte
- NavigationMesh – for enkel, kan ikke forklare innmaten
TODO: Hvorfor ikke NavigationMesh. 
- Lokal fillagring – ikke skalerbart, fungerer ikke fra annet sted
- SQLite – enklere men ikke en ekte server/tjeneste

### Etikk og sikkerhet
- Passord lagres hashet, ikke i klartekst
- Personvern – kun nødvendig data lagres
- GDPR nevnes kort.
TODO: Hvordan er GDPR relevant. Eks: At en bruker må kunne be om at sin bruker slettes, eller få utlevert alle data lagret som seg, og da kan vi jjo ikke vise passord i klartekst.

---

## Kjerneelementdekning

| Kjerneelement | Hvordan jeg dekker det |
|---|---|
| Løsningsarkitektur og systemutvikling | Spillarkitektur, A* pathfinding, database-tilkobling |
| Utviklingsprosesser og kreativ problemløsning | Egenutviklet A*, MAZE_Development Workspace (Kanban + GitHub), feilsøking underveis |
| IT-støtte og kommunikasjon | Spillet gir spilleren tydelig feedback og brukeropplevelse, kommentere i koden og beskrive hva koden gjør. |
| Driftstøtte | MySQL på Raspberry Pi – setter opp og konfigurerer en databasetjeneste |
| Etikk, lovverk og yrkesutøvelse | Personvern, GDPR, sikker lagring av brukerdata |
| Informasjonssikkerhet | Hashede passord, sikker databasetilkobling |

TODO: IT-støtte og kommunikasjon

---

## Eventuelle forbedringer om tid tillater

- Synsfelt (line of sight) for fienden
- Lydeffekter når fienden oppdager spilleren
- Login-skjerm i spillet koblet til databasen