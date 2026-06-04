# Eksamensplan

---

## Prosjektbeskrivelse

Jeg skal lage deler av et 3D spill i Godot 4.6 der spilleren sniker seg inn i et hus.
Hovedfokuset på eksamensdagen er å implementere et egenutviklet pathfinding-system til en AI-fiende, slik at den beveger seg naturlig rundt vegger og hindringer.

Et pathfinding-system er et system som finner veien til et bestemt punkt uten å treffe vegger og andre hindringer.

Jeg har allerede laget grunnleggende spillerbevegelse tidligere og en fiende fra forberedelsestiden.
Prosjektet administreres via MAZE_Development Workspace og koden commites til GitHub underveis. Endringer etter eksamensdagen blir lagt inn som en ny commit.

Jeg skal sette opp en MySQL-database på en Raspberry Pi som fungerer som lokal server. Databasen skal kunne lagre brukerdata og spillprogress slik at spilleren kan logge inn fra et annet sted og fortsette der de slapp. Jeg prioriterer å sette opp databasen med tabeller. Det er sannsynligvis for lite tid til å utvikle inloggingsløsning og lagre spilldata.

---

## Teknologier

- **Godot 4.6** – spillmotor, brukt til å bygge selve spillet, 3D-scener og spillogikk
- **GDScript** – programmeringsspråk innebygd i Godot, brukt til å kode alt fra bevegelse til pathfinding
- **Egenutviklet pathfinding (A\*)** – algoritme kodet fra scratch for å finne korteste vei rundt hindringer, uten å bruke Godots innebygde systemer
- **MAZE_Development Workspace** – egenutviklet prosjektplattform (maze-development.com/workspace) med Kanban-board for oppgavetracking, versjonskontroll og GitHub-integrasjon
- **MySQL** – relasjonsdatabase brukt til å lagre brukerdata og spillprogress, slik at spilleren kan logge inn fra et annet sted og fortsette
- **Raspberry Pi** – en liten fysisk server som hoster MySQL-databasen, dette representerer reell drift av en tjeneste

---

## Hva jeg skal gjøre på eksamensdagen

### 1. Egenutviklet pathfinding til AI-fienden

Implementere A* pathfinding fra scratch i GDScript.
Fienden bruker et grid-basert kart over banen, finner korteste vei rundt vegger og oppdaterer pathen kontinuerlig.

**Hva er A\* og hvordan fungerer det:**
A* (uttales "A-star") er en algoritme som finner den korteste veien mellom to punkter. Den fungerer ved å dele opp banen i et rutenett (grid), og for hver rute vurderer den to ting: hvor langt den allerede har gått, og et estimat på hvor langt det er igjen til målet. Denne kombinasjonen kalles heuristikk. Algoritmen holder to lister – en open list over ruter den vurderer å utforske, og en closed list over ruter den allerede har sett på. Den velger alltid den mest lovende ruten fra open list, til den når målet.

**Hvordan beveger fienden seg i dag:**
I dag beveger fienden seg rett mot spilleren uten å ta hensyn til vegger – den går gjennom alt i veien. Med A* vil fienden i stedet beregne en faktisk vei rundt hindringer og navigere intelligent gjennom banen.

**Hvorfor eget system:**
Ved å lage pathfinding selv viser jeg at jeg faktisk forstår algoritmen – ikke bare bruker et ferdig verktøy. A* er industristandard for spillpathfinding og gir full kontroll over fiendeatferden.

**Hvorfor ikke NavigationMesh:**
Godots innebygde NavigationMesh er en black box – det fungerer, men jeg kan ikke forklare hva som skjer inni. Et egenutviklet system viser dypere forståelse og at jeg kan løse problemet fra grunnen av.

**Hvorfor A\* er bedre enn den nåværende løsningen:**
Den nåværende løsningen er ikke intelligent – fienden setter seg fast i vegger og finner ikke vei. A* garanterer at fienden alltid finner korteste mulige vei, og gjør det effektivt ved å prioritere de mest lovende rutene fremfor å sjekke alle muligheter blindt.

### 2. Fiendeatferd

- [x] TODO: Hva mener du med fiendeadferd? Noen setninger mer utfyllende om logikken som skal brukes.

Fienden vet alltid hvor spilleren er og jager dem kontinuerlig. Hvert sekund henter fienden spillerens posisjon og beregner en ny path via A*. Fienden har ingen synsvinkel eller skjul – den er alltid i jakt-modus. Dette er den enkleste formen for fiendeatferd, og gjør det mulig å fokusere på selve pathfinding-implementasjonen.

### 3. Versjonskontroll med MAZE_Development Workspace

MAZE_Development Workspace (maze-development.com/workspace) er en egenutviklet plattform for prosjektstyring. Den inneholder et Kanban-board for å tracke oppgaver, og er integrert med GitHub slik at kode kan commites direkte. Kanban er en metode for oppgavetracking der oppgaver flyttes mellom kolonner som "To Do", "In Progress" og "Done". Det gir oversikt over hva som gjøres til enhver tid.

Kode committes underveis på eksamensdagen – dette viser arbeidsprosessen og gir backup.

### 4. MySQL-database på Raspberry Pi

- [x] TODO: Du MÅ få tid til å sette opp database, og tabellene. Det er en del av drifts-delen. Integreringen kan du sette på som HVIS TID

Sette opp MySQL på en Raspberry Pi som kjører som lokal server.
Lage tabeller for å lagre brukerdata og spillprogress.

Tabell skal lagre bruker for senere innlogging. Passord skal hashes i database, slik at selv om databasen hackes, kan ikke passord leses.

**Om hashing av passord:**
Passord skal aldri lagres i klartekst i en database. Istedenfor brukes en hashing-algoritme som gjør passordet om til en fast streng med tegn som ikke kan reverseres tilbake til det originale passordet. Selv om databasen blir hacket, kan angriperen ikke lese passordene.

- [x] TODO: Teksten under virker kopiert. Vet du hva SALT er? Isåfall noter et par stikkord på hva det er så du kan svare

**Hva er salt:**
Salt er en tilfeldig streng med tegn som legges til passordet *før* det hashes. Poenget er at to brukere med samme passord får helt forskjellige hashes i databasen, fordi saltet er unikt for hver bruker. Salt beskytter mot rainbow table-angrep – en angriper kan ikke bruke en ferdiglagd liste over vanlige passord fordi saltet gjør hver hash unik. bcrypt håndterer salt automatisk og lagrer det som en del av den ferdige hashen.

**Tabeller:**
- `users` – brukernavn og hashet passord for innlogging
- `progress` – bruker-ID, nivå, poeng og tidspunkt for siste lagring

- [x] TODO: Sjekk hvordan du oppretter tabell. Bør vel ikke stå slik som dette. Kan du ikke slette det hvis du har sjekket det ut, og vet hvordan du gjør det?

Jeg har sett på SQL-syntaksen og vet hvordan tabeller opprettes med CREATE TABLE, AUTO_INCREMENT, PRIMARY KEY og FOREIGN KEY.

**Hvorfor Raspberry Pi:**
En ekte server som kjører en databasetjeneste – dette er reell drift, ikke bare teori.
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
  - **Open list** – ruter algoritmen ennå ikke har utforsket, men vurderer
  - **Closed list** – ruter algoritmen allerede har sjekket og er ferdig med
  - **Heuristikk** – et estimat på hvor langt det er igjen til målet, brukes til å prioritere hvilken rute som utforskes først
- Fienden vet alltid hvor spilleren er og oppdaterer path hvert sekund – alltid i jakt-modus
- MAZE_Development Workspace med Kanban-board – tracker oppgaver og committer til GitHub underveis
  Kanban er en metode der oppgaver flyttes mellom kolonner som "To Do", "In Progress" og "Done" – gir oversikt over arbeidsprosessen.
- MySQL tabeller: users (brukernavn + hashet passord), progress (nivå, poeng)
- Passord hashes med bcrypt + salt før lagring – kan ikke reverseres

### Hvorfor
- A* fordi det er raskere og smartere enn BFS
  BFS (Breadth-First Search) er en enklere algoritme som utforsker alle ruter likt i alle retninger uten å prioritere – den finner veien, men er mye tregere enn A* fordi den ikke bruker heuristikk.
- Eget system fordi jeg kan forklare hvert steg og viser dypere forståelse
- MAZE_Development Workspace fordi det er en profesjonell arbeidsflyt – Kanban, GitHub-sync, prosjektoversikt
- Raspberry Pi fordi det er en ekte driftsoppgave – ikke bare lokalt på maskinen

### Alternativer jeg vurderte
- NavigationMesh – Godots innebygde system. Fungerer, men er en black box jeg ikke kan forklare innmaten på.
  NavigationMesh baker en walkable overflate automatisk, men all logikken skjer skjult. Jeg kan ikke forklare hva som skjer steg for steg.
- Lokal fillagring – ikke skalerbart, fungerer ikke fra annet sted
- SQLite – enklere å sette opp, men ikke en ekte server/tjeneste, og gir ikke reell driftserfaring

### Etikk og sikkerhet
- Passord lagres hashet med bcrypt + salt, ikke i klartekst – selv om databasen hackes kan ikke passord leses
- Personvern – kun nødvendig data lagres (brukernavn, hashet passord, progress)
- GDPR er relevant fordi brukere har rett til å be om at dataene deres slettes, og rett til å få utlevert all data lagret om dem. Siden passord er hashet kan vi ikke levere ut passordet i klartekst – det er nettopp poenget. Vi lagrer heller ikke mer data enn nødvendig.

---

## Kjerneelementdekning

| Kjerneelement | Hvordan jeg dekker det |
|---|---|
| Løsningsarkitektur og systemutvikling | Spillarkitektur i Godot 4.6, egenutviklet A* pathfinding-system, MySQL database-tilkobling |
| Utviklingsprosesser og kreativ problemløsning | Egenutviklet A* fra scratch, MAZE_Development Workspace (Kanban + GitHub), feilsøking underveis |
| IT-støtte og kommunikasjon | Spillet gir spilleren tydelig feedback og brukeropplevelse. Koden er kommentert med forklaringer på hva hver del gjør, slik at andre kan lese og forstå den |
| Driftstøtte | MySQL på Raspberry Pi – setter opp og konfigurerer en databasetjeneste på en fysisk server |
| Etikk, lovverk og yrkesutøvelse | Personvern, GDPR, sikker lagring av brukerdata med hashing |
| Informasjonssikkerhet | Hashede passord med bcrypt + salt, sikker databasetilkobling, tjeneste for å be om alle data og å bli slettet |

---

## Eventuelle forbedringer om tid tillater
- Synsfelt (line of sight) for fienden
- Lydeffekter når fienden oppdager spilleren
- Login-skjerm i spillet koblet til databasen
- Tjeneste for å be om sine egne brukerdata, eller å få slettet alle data som er lagret om seg selv