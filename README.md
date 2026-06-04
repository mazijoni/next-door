# Eksamensplan

---

## Prosjektbeskrivelse

Jeg skal lage deler av et 3D spill i Godot 4.6 der spilleren sniker seg inn i et hus.
Hovedfokuset på eksamensdagen er å implementere et egenutviklet pathfinding-system til en AI-fiende, slik at den beveger seg naturlig rundt vegger og hindringer.

- [x] TODO: Forklar hva et pathfinding-system er for noe

Et pathfinding-system er et system som finner veien til et bestemt punkt uten å treffe vegger og andre hindringer.

Jeg har allerede laget grunnleggende spillerbevegelse tidligere og en fiende fra forberedelsestiden.
Prosjektet administreres via MAZE_Development Workspace og koden commites til GitHub underveis. Endringer etter eksamensdagen blir lagt inn som en ny commit.

- [x] TODO: Forklar hva du skal gjøre rundt database

Jeg skal sette opp en MySQL-database på en Raspberry Pi som fungerer som lokal server. Databasen lagrer brukerdata og spillprogress slik at spilleren kan logge inn fra et annet sted og fortsette der de slapp.

---

## Teknologier

- **Godot 4.6** – spillmotor, brukt til å bygge selve spillet, 3D-scener og spillogikk
- **GDScript** – programmeringsspråk innebygd i Godot, brukt til å kode alt fra bevegelse til pathfinding
- **Egenutviklet pathfinding (A\*)** – algoritme kodet fra scratch for å finne korteste vei rundt hindringer, uten å bruke Godots innebygde systemer
- **MAZE_Development Workspace** – egenutviklet prosjektplattform (maze-development.com/workspace) med Kanban-board for oppgavetracking, versjonskontroll og GitHub-integrasjon
- **MySQL** – relasjonsdatabase brukt til å lagre brukerdata og spillprogress, slik at spilleren kan logge inn fra et annet sted og fortsette
- **Raspberry Pi** – en liten fysisk server som hoster MySQL-databasen, dette representerer reell drift av en tjeneste

- [x] TODO: Skriv en hel setning på hver av de som forklarer hva de er eller hvorfor

---

## Hva jeg skal gjøre på eksamensdagen

### 1. Egenutviklet pathfinding til AI-fienden

Implementere A* pathfinding fra scratch i GDScript.
Fienden bruker et grid-basert kart over banen, finner korteste vei rundt vegger og oppdaterer pathen kontinuerlig.

- [x] TODO: Hva betyr A* og enkelt forklart, hvordan fungerer det? Hva er prinsippene i algoritmen?

**Hva er A\* og hvordan fungerer det:**
A* (uttales "A-star") er en algoritme som finner den korteste veien mellom to punkter. Den fungerer ved å dele opp banen i et rutenett (grid), og for hver rute vurderer den to ting: hvor langt den allerede har gått, og et estimat på hvor langt det er igjen til målet. Denne kombinasjonen kalles heuristikk. Algoritmen holder to lister – en open list over ruter den vurderer å utforske, og en closed list over ruter den allerede har sett på. Den velger alltid den mest lovende ruten fra open list, til den når målet.

- [x] TODO: Hvordan finner fienden korteste vei når du starter. Altså nå pr i dag? Og hva er forskjellen?

**Hvordan beveger fienden seg i dag:**
I dag beveger fienden seg rett mot spilleren uten å ta hensyn til vegger – den går gjennom alt i veien. Med A* vil fienden i stedet beregne en faktisk vei rundt hindringer og navigere intelligent gjennom banen.

**Hvorfor eget system:**
Ved å lage pathfinding selv viser jeg at jeg faktisk forstår algoritmen – ikke bare bruker et ferdig verktøy. A* er industristandard for spillpathfinding og gir full kontroll over fiendeatferden.

**Hvorfor ikke NavigationMesh:**
Godots innebygde NavigationMesh er en black box – det fungerer, men jeg kan ikke forklare hva som skjer inni. Et egenutviklet system viser dypere forståelse og at jeg kan løse problemet fra grunnen av.

- [x] TODO: Hvorfor er det bedre å bytte til A*

**Hvorfor A\* er bedre enn den nåværende løsningen:**
Den nåværende løsningen er ikke intelligent – fienden setter seg fast i vegger og finner ikke vei. A* garanterer at fienden alltid finner korteste mulige vei, og gjør det effektivt ved å prioritere de mest lovende rutene fremfor å sjekke alle muligheter blindt.

### 2. Fiendeatferd

Koble pathfindingen til fiendeatferd – fienden patruljerer eller jager spilleren basert på posisjon og synsfelt.

### 3. Versjonskontroll med MAZE_Development Workspace

- [x] TODO: Hva er MAZE_Development Workspace?

MAZE_Development Workspace (maze-development.com/workspace) er en egenutviklet plattform for prosjektstyring. Den inneholder et Kanban-board for å tracke oppgaver, og er integrert med GitHub slik at kode kan commites direkte. Kanban er en metode for oppgavetracking der oppgaver flyttes mellom kolonner som "To Do", "In Progress" og "Done". Det gir oversikt over hva som gjøres til enhver tid.

Kode committes underveis på eksamensdagen – dette viser arbeidsprosessen og gir backup.

### 4. MySQL-database på Raspberry Pi *(hvis tid)*

Sette opp MySQL på en Raspberry Pi som kjører som lokal server.
Lage tabeller for å lagre brukerdata og spillprogress.

- [x] TODO: Tabell skal lagre bruker for senere innlogging. Passord skal hashes i database, slik at selv om databasen hackes, kan ikke passord leses.
- [x] TODO: Noen setninger om hashing så du kan forklare hensikten.

**Om hashing av passord:**
Passord skal aldri lagres i klartekst i en database. Istedenfor brukes en hashing-algoritme som gjør passordet om til en fast streng med tegn som ikke kan reverseres tilbake til det originale passordet. Selv om databasen blir hacket, kan angriperen ikke lese passordene.

Jeg bruker bcrypt – en anerkjent hashing-algoritme designet spesielt for passord. bcrypt legger til en tilfeldig "salt" for hvert passord før hashing, slik at to like passord aldri får samme hash. Dette beskytter mot rainbow table-angrep (forhåndsberegnede lister med vanlige passord og deres hashes).

- [x] TODO: Sjekk hvordan du oppretter tabell.

```sql
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(256),
  password_hashed VARCHAR(256),
  lastlogin TIMESTAMP
);

CREATE TABLE progress (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  level INT,
  score INT,
  saved_at TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

**Tabeller:**
- `users` – brukernavn og hashet passord for innlogging
- `progress` – bruker-ID, nivå, poeng og tidspunkt for siste lagring

**Hvorfor Raspberry Pi:**
En ekte server som kjører en databasetjeneste – dette er reell drift, ikke bare teori.

- [x] TODO: Forklare at denne ikke er rask nok i et ekte produksjonsmiljø

I et ekte produksjonsmiljø ville en Raspberry Pi ikke vært rask nok til mange samtidige brukere, men for demonstrasjon og en enkeltbruker fungerer det fint.

---

## Hva jeg skal si til sensor (stikkord)

### Hva
- 3D snike-spill i Godot 4.6
- Spilleren sniker seg inn i et hus
- AI-fiende med egenutviklet A* pathfinding
- MAZE_Development Workspace – egenutviklet prosjektplattform med Kanban og GitHub-sync
- MySQL-database på Raspberry Pi for brukerlagring og progress

### Hvordan
- A* algoritme – rutenett over banen, open/closed list, heuristikk (estimat på avstand til mål)
- [x] TODO: Hva betyr dette? open/closed list, heuristikk

  - **Open list** – ruter algoritmen ennå ikke har utforsket, men vurderer
  - **Closed list** – ruter algoritmen allerede har sjekket og er ferdig med
  - **Heuristikk** – et estimat på hvor langt det er igjen til målet, brukes til å prioritere hvilken rute som utforskes først

- Fienden oppdaterer path kontinuerlig mot spillerens posisjon
- MAZE_Development Workspace med Kanban-board – tracker oppgaver og committer til GitHub underveis
- [x] TODO: Hva er Kanban i noen korte ord?

  Kanban er en metode der oppgaver flyttes mellom kolonner som "To Do", "In Progress" og "Done" – gir oversikt over arbeidsprosessen.

- MySQL tabeller: users (brukernavn + hashet passord), progress (nivå, poeng)
- Passord hashes med bcrypt før lagring – kan ikke reverseres

### Hvorfor
- A* fordi det er raskere og smartere enn BFS
- [x] TODO: Hva er BFS?

  BFS (Breadth-First Search) er en enklere algoritme som utforsker alle ruter likt i alle retninger uten å prioritere – den finner veien, men er mye tregere enn A* fordi den ikke bruker heuristikk.

- Eget system fordi jeg kan forklare hvert steg og viser dypere forståelse
- MAZE_Development Workspace fordi det er en profesjonell arbeidsflyt – Kanban, GitHub-sync, prosjektoversikt
- Raspberry Pi fordi det er en ekte driftsoppgave – ikke bare lokalt på maskinen

### Alternativer jeg vurderte
- NavigationMesh – Godots innebygde system. Fungerer, men er en black box jeg ikke kan forklare innmaten på
- [x] TODO: Hvorfor ikke NavigationMesh

  NavigationMesh baker en walkable overflate automatisk, men all logikken skjer skjult. Jeg kan ikke forklare hva som skjer steg for steg, noe som gir dårligere grunnlag for å svare på sensorens spørsmål om HVORFOR og HVORDAN.

- Lokal fillagring – ikke skalerbart, fungerer ikke fra annet sted
- SQLite – enklere å sette opp, men ikke en ekte server/tjeneste, og gir ikke reell driftserfaring

### Etikk og sikkerhet
- Passord lagres hashet med bcrypt, ikke i klartekst – selv om databasen hackes kan ikke passord leses
- Personvern – kun nødvendig data lagres (brukernavn, hashet passord, progress)
- [x] TODO: Hvordan er GDPR relevant

  GDPR er relevant fordi brukere har rett til å be om at dataene deres slettes, og rett til å få utlevert all data lagret om dem. Siden passord er hashet kan vi ikke levere ut passordet i klartekst – det er nettopp poenget. Vi lagrer heller ikke mer data enn nødvendig.

---

## Kjerneelementdekning

| Kjerneelement | Hvordan jeg dekker det |
|---|---|
| Løsningsarkitektur og systemutvikling | Spillarkitektur i Godot 4.6, egenutviklet A* pathfinding-system, MySQL database-tilkobling |
| Utviklingsprosesser og kreativ problemløsning | Egenutviklet A* fra scratch, MAZE_Development Workspace (Kanban + GitHub), feilsøking underveis |
| IT-støtte og kommunikasjon | Spillet gir spilleren tydelig feedback og brukeropplevelse. Koden er kommentert med forklaringer på hva hver del gjør, slik at andre kan lese og forstå den |
| Driftstøtte | MySQL på Raspberry Pi – setter opp og konfigurerer en databasetjeneste på en fysisk server |
| Etikk, lovverk og yrkesutøvelse | Personvern, GDPR, sikker lagring av brukerdata med hashing |
| Informasjonssikkerhet | Hashede passord med bcrypt, sikker databasetilkobling |

- [ ] TODO: IT-støtte og kommunikasjon – legg til mer hvis du finner på noe konkret på eksamensdagen

---

## Eventuelle forbedringer om tid tillater

- Synsfelt (line of sight) for fienden
- Lydeffekter når fienden oppdager spilleren
- Login-skjerm i spillet koblet til databasen