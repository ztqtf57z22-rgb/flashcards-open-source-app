# Fiszki dla dziecka – instalacja na iPhonie i iPadzie (tylko Windows, bez Maca i bez płatnego konta)

Ta wersja aplikacji (na bazie otwartoźródłowego projektu Nibomo / flashcards-open-source-app) po uruchomieniu
pokazuje **dwa kafelki**:

1. **🎨 Play & Learn Club** – kolorowy moduł dla dziecka. Robisz zdjęcie kartki z zajęć, a **Claude** zamienia ją
   w lekcję: słówka z obrazkami, wymowa po angielsku, quiz obrazkowy, zadania i gramatyka. Na start jest gotowa
   lekcja przykładowa „Unit 2: Art Club”.
2. **🗂️ Fiszki** – standardowa aplikacja z powtórkami (plus „Tryb dla dziecka” w Ustawieniach).

**Wszystko robisz na komputerze z Windows, iPhonie i iPadzie – Mac nie jest potrzebny na żadnym etapie.**
Aplikację kompiluje serwer GitHuba w internecie (to jego maszyna, nie Twoja). Potrzebujesz:

| Co | Po co | Koszt |
|---|---|---|
| Konto **GitHub** | serwer GitHuba w internecie zbuduje plik aplikacji `Fiszki.ipa` (nic nie instalujesz) | darmowe |
| **AltStore** *albo* **SideStore** (do wyboru, krok 2) | instaluje aplikację Twoim Apple ID i co tydzień ją odświeża | darmowe |
| **Apple ID** | podpis aplikacji (to samo konto, co w App Store) | darmowe |
| **iCloud Drive** (na obu urządzeniach) | synchronizacja lekcji i wyników klubu | darmowe (5 GB) |
| Klucz **Claude API** | zamiana zdjęcia kartki w lekcję | kilka–kilkanaście groszy za kartkę |

> **Jedno ograniczenie darmowego Apple ID:** aplikacja jest ważna **7 dni** i trzeba ją odświeżać. Dane i lekcje
> nie znikają, nawet gdy termin minie. Widżety i aplikacja na zegarek są w tej wersji wyłączone.

## Najpierw wybierz: AltStore czy SideStore?

| | **AltStore** (kroki 2A–3A) | **SideStore** (kroki 2B–3B) |
|---|---|---|
| Komputer z Windows | potrzebny **co tydzień** (odświeża przez Wi-Fi w tle) | potrzebny **tylko przy instalacji** |
| Odświeżanie co 7 dni | samo, gdy komputer z AltServerem jest włączony w tej samej sieci Wi-Fi | na iPhonie/iPadzie: włączasz LocalDevVPN i stukasz licznik w SideStore |
| Trudność konfiguracji | łatwiejsza | trochę trudniejsza |
| Koszt | darmowy, open source | darmowy, open source |

**Polecam SideStore**, jeśli komputer nie jest stale włączony w domu. Wybierz jeden wariant (nie instaluj obu): po kroku 1 rób kroki 2A–3A **albo** 2B–3B, a potem krok 4.

---

## Krok 1. Zbuduj plik aplikacji na GitHubie (raz, ok. 45 minut, głównie czekania)

1. Załóż konto na **github.com**.
2. Otwórz **github.com/kirill-markin/flashcards-open-source-app** i kliknij **Fork → Create fork**.
3. Wgraj do forka kod z tymi zmianami. Na komputerze otwórz **Git Bash** w folderze `app` i wpisz kolejno
   (zamień `TWOJ_LOGIN` na swój login z GitHuba). *Możesz też poprosić Claude, żeby zrobił ten krok za Ciebie.*

```bash
git checkout -b dla-dziecka
```

```bash
git add -A && git commit -m "Play & Learn Club i synchronizacja przez folder"
```

```bash
git remote add moj https://github.com/TWOJ_LOGIN/flashcards-open-source-app.git
```

```bash
git push moj dla-dziecka:main --force
```

4. W swoim forku otwórz zakładkę **Actions** → **„I understand my workflows, go ahead and enable them”**.
   Po lewej możesz wyłączyć (⋯ → *Disable workflow*) niepotrzebne workflowy autora: **android-tooling-lint** i **aws-web-release**.
5. Po lewej wybierz **„iOS – zbuduj plik IPA” → Run workflow → Run workflow**.
   (Później budowanie uruchamia się samo po każdej zmianie w kodzie iOS.)
6. Po ok. 30–45 minutach pojawi się zielony ✅. Kliknij przebieg, a na dole w sekcji **Artifacts** pobierz
   **Fiszki-ipa**. Rozpakuj ZIP – w środku jest **`Fiszki.ipa`**.
7. Wrzuć `Fiszki.ipa` do **iCloud Drive** (np. przez icloud.com albo aplikację iCloud na Windows), żeby był widoczny
   na iPhonie i iPadzie w aplikacji **Pliki**.

> Budowanie jest bezpłatne, bo fork jest publiczny. Nie wpisujesz żadnych haseł ani kluczy w GitHubie.

## Krok 2A. AltStore: zainstaluj AltServer na Windows (raz)

Pobieraj programy **tylko z oficjalnych stron** (altstore.io i apple.com).

1. Zainstaluj **iTunes** i **iCloud dla Windows** pobrane **ze strony apple.com** (nie z Microsoft Store – AltServer
   wymaga wersji ze strony Apple; dokładne linki są w FAQ na altstore.io).
2. Pobierz **AltServer dla Windows** ze strony **altstore.io**, zainstaluj i uruchom. Ikonka ◇ pojawi się
   w zasobniku obok zegara.

## Krok 3A. AltStore: zainstaluj AltStore i Fiszki na iPhonie, potem na iPadzie

Zrób to samo najpierw dla iPhone'a, potem dla iPada:

1. Podłącz urządzenie kablem do komputera, odblokuj je i stuknij **Zaufaj**.
2. W iTunes zaznacz dla tego urządzenia **„Synchronizuj z tym urządzeniem przez Wi-Fi”** i kliknij **Zastosuj**
   (dzięki temu AltStore odświeża aplikację bez kabla).
3. Kliknij ikonkę **AltServer** w zasobniku → **Install AltStore** → wybierz urządzenie → wpisz **swoje Apple ID
   i hasło** (wpisujesz je sam(a) w programie AltServer; trafiają tylko do Apple w celu podpisania aplikacji).
4. Na urządzeniu: *Ustawienia → Ogólne → VPN i urządzenia zarządzane* → stuknij swoje Apple ID → **Zaufaj**.
5. Włącz **Tryb dewelopera**: *Ustawienia → Prywatność i ochrona → Tryb dewelopera → włącz*. Urządzenie się
   zrestartuje, potwierdź **Włącz**.
6. Otwórz **AltStore** → zakładka **My Apps** → **➕** → wybierz **`Fiszki.ipa`** z iCloud Drive. Po chwili
   ikona **Fiszki** pojawi się na ekranie głównym.

**Aktualizacja aplikacji:** pobierz nowy `Fiszki.ipa` z GitHuba (krok 1.6) i zainstaluj go tak samo przez AltStore
(**My Apps → ➕**). Lekcje i ustawienia zostają.

---

## Krok 2B. SideStore: przygotuj Windows i urządzenia (raz)

Według oficjalnej dokumentacji **docs.sidestore.io** (pobieraj programy tylko stamtąd i z apple.com):

1. Komputer: **Windows 8 lub nowszy, 64-bitowy** (nie „Windows on Arm”). Sprawdzisz to klawiszami **Windows+R** →
   wpisz `control /name microsoft.system` → *Typ systemu*.
2. Zainstaluj **iTunes** – najlepiej pobrany bezpośrednio ze strony apple.com.
3. Zainstaluj **iloader** – instalator **MSI** ze strony wydań iloader (link w dokumentacji SideStore).
4. Na **iPhonie i iPadzie** zainstaluj z App Store darmową aplikację **LocalDevVPN**, otwórz ją, stuknij **Connect**,
   zezwól na konfigurację VPN (**Allow**) i wpisz kod urządzenia.
5. Urządzenia muszą mieć **iOS/iPadOS 15 lub nowszy**, ustawiony kod blokady i połączenie **Wi-Fi**.

## Krok 3B. SideStore: zainstaluj SideStore i Fiszki na iPhonie, potem na iPadzie

Zrób to samo najpierw dla iPhone'a, potem dla iPada:

1. Podłącz urządzenie **kablem** do komputera, odblokuj je, stuknij **Zaufaj** i wpisz kod.
2. Otwórz **iloader**, zaloguj się **swoim Apple ID** (wielkość liter ma znaczenie), wybierz urządzenie i kliknij
   **Install SideStore (Stable)**.
3. Na urządzeniu: *Ustawienia → Ogólne → VPN i urządzenia zarządzane* → w sekcji **Developer App** stuknij swoje
   Apple ID → **Zaufaj**.
4. Włącz **Tryb dewelopera**: *Ustawienia → Prywatność i ochrona* → na samym dole **Tryb dewelopera** → włącz.
   Urządzenie się zrestartuje.
5. Po restarcie otwórz **LocalDevVPN → Connect**, potem otwórz **SideStore** i zaloguj się **tym samym Apple ID** co w iloader.
6. W SideStore wejdź w **My Apps** i stuknij licznik **7 DAYS** przy SideStore. Jeśli zapyta o certyfikat, stuknij
   **Yes** / **Refresh Now**. Urządzenie na chwilę wróci do ekranu głównego – to normalne.
7. Teraz Fiszki: w SideStore **My Apps → ➕** → wybierz **`Fiszki.ipa`** z iCloud Drive. Po chwili ikona **Fiszki**
   pojawi się na ekranie głównym. Od tej chwili komputer nie jest już potrzebny.

### Odświeżanie co 7 dni (na iPhonie/iPadzie, bez komputera)

1. Otwórz **LocalDevVPN → Connect**.
2. Otwórz **SideStore → My Apps** i stuknij licznik dni przy **Fiszki** (albo przy wszystkich aplikacjach).
3. Gotowe – aplikacja znów jest ważna 7 dni. Warto ustawić sobie przypomnienie, np. co niedzielę.

**Aktualizacja Fiszek:** pobierz nowy `Fiszki.ipa` z GitHuba (krok 1.6) i zainstaluj go tak samo (**My Apps → ➕**,
przy włączonym LocalDevVPN). Lekcje i ustawienia zostają.

> **Plik parowania** (dzięki któremu SideStore działa bez komputera) może czasem wygasnąć – po aktualizacji iOS,
> resecie albo losowo. Objaw: odświeżanie przestaje działać mimo włączonego VPN. Wtedy podłącz urządzenie do
> komputera i wymień plik parowania według poradnika „pairing file” na docs.sidestore.io (iloader to robi).

---

## Krok 4. Lekcje na iPhonie i iPadzie – wybierz sposób

Możesz przenosić lekcje **ręcznie przez AirDrop** (prosto, bez iCloud) **albo** włączyć **automatyczną
synchronizację** przez folder w iCloud Drive. Wystarczy jeden sposób; można też używać obu.

### Sposób 1: AirDrop – bez synchronizacji (najprostszy)

1. Na **iPhonie** zrób zdjęcie kartki – powstanie lekcja.
2. W lekcji stuknij **⋯** (prawy górny róg) → **Wyślij na inne urządzenie (AirDrop)** → wybierz swojego **iPada**.
   (Na iPadzie AirDrop musi być włączony: *Centrum sterowania* → przytrzymaj kafelek Wi-Fi → **AirDrop** →
   *Tylko kontakty* lub *Wszyscy przez 10 minut*.)
3. Na **iPadzie** wybierz **Fiszki** (jeśli iPad zapyta, czym otworzyć plik). Aplikacja sama otworzy klub
   i pokaże „Dodano nową lekcję! 🎉”.
4. Gwiazdki zdobyte na iPadzie zostają na iPadzie. Jeśli chcesz je mieć też na iPhonie, wyślij lekcję tak samo
   z iPada na iPhone – lekcja się nie zdubluje, a lepszy wynik zostanie zachowany.

W **⚙️** klubu (dla rodzica) są też przyciski **Wyślij wszystkie lekcje (AirDrop)** i **Wczytaj lekcje z pliku**
(np. gdy plik `.fiszki` przyszedł mailem albo leży w aplikacji Pliki). Plik możesz też wysłać przez Wiadomości.

> AirDrop działa przez Bluetooth i Wi-Fi bezpośrednio między urządzeniami – bez internetu i bez iCloud.

### Sposób 2: automatyczna synchronizacja przez iCloud Drive (opcjonalnie)

| Co | Jak się synchronizuje |
|---|---|
| **Lekcje klubu, gwiazdki i wyniki** | Wspólny folder w **iCloud Drive** wybrany w aplikacji (na obu urządzeniach ten sam) |
| **Zwykłe fiszki i powtórki** | Bezpłatne konto Nibomo – na obu urządzeniach zaloguj się **tym samym e-mailem** |
| **Klucz Claude** | Wpisz go na każdym urządzeniu (raz) – patrz krok 5 |

#### Ustawienie folderu (raz na każdym urządzeniu)

1. Upewnij się, że iPhone i iPad są zalogowane na **to samo Apple ID** i mają włączony **iCloud Drive**
   (*Ustawienia → [Twoje imię] → iCloud → iCloud Drive*).
2. Na iPhonie otwórz aplikację **Pliki → iCloud Drive** i utwórz folder **`Fiszki-Sync`** (przytrzymaj puste miejsce
   → *Nowy folder*). Na iPadzie już go nie tworzysz – pojawi się sam.
3. W aplikacji **Fiszki** stuknij **🎨 Play & Learn Club → ⚙️** (prawy górny róg) → rozwiąż mnożenie →
   **Wybierz folder synchronizacji** → **iCloud Drive → Fiszki-Sync → Otwórz**.
4. Powtórz punkt 3 na iPadzie, wybierając **ten sam** folder.

Od teraz kartka zeskanowana na iPhonie pojawi się na iPadzie i odwrotnie. To samo dotyczy gwiazdek
(zawsze zostaje lepszy wynik) i usuniętych lekcji. Gdy klub jest otwarty, aplikacja sprawdza zmiany co ok. 30 sekund.
Można też stuknąć **⚙️ → Synchronizuj teraz**. iCloud zwykle przesyła zmiany w kilka sekund, czasem w kilka minut.

#### Zwykłe fiszki (standardowa aplikacja)

W kafelku **🗂️ Fiszki** → *Ustawienia → Konto* zaloguj się **e-mailem** (dostaniesz kod), tym samym adresem na obu
urządzeniach. Logowanie przez Apple/Google w tej wersji najpewniej nie zadziała, więc używaj e-maila.
W *Ustawieniach* znajdziesz też **🧸 Tryb dla dziecka** i **🏠 Ekran wyboru**.

## Krok 5. Klucz Claude

> Jeśli zdjęcia kartek robisz tylko na iPhonie i przesyłasz lekcje przez AirDrop, klucz wpisz **tylko na iPhonie** –
> iPad dostaje gotowe lekcje i klucza nie potrzebuje.

1. Na komputerze wejdź na **platform.claude.com**, załóż konto i w **Billing** dodaj np. 5 USD kredytu.
2. **Settings → API Keys → Create Key** – skopiuj klucz (zaczyna się od `sk-ant-`) i zapisz go np. w Notatkach.
3. Na iPhonie: **Play & Learn Club → ⚙️** → wklej klucz → **Zapisz klucz**. Na iPadzie zrób to samo
   (czasem klucz przejdzie sam przez pęk kluczy iCloud – wtedy zobaczysz „Klucz jest zapisany”).

> Bez klucza klub też działa, ale ze zdjęcia odczyta tylko słówka (bez zadań i gramatyki).

## Krok 6. Jak korzystać z klubu

1. Kafelek **🎨 Play & Learn Club** → **Nowa kartka 📸** → **Zrób zdjęcie kartki** (aparat sam wykryje i wyprostuje
   kartkę) albo **Wybierz z galerii**.
2. Po ok. minucie lekcja otworzy się sama, a po chwili pojawi się też na drugim urządzeniu.
3. W lekcji są cztery zajęcia: **🃏 Słówka** (obrazek + wymowa, stuknięcie = po polsku), **🎯 Zgadnij obrazek**,
   **🧩 Zadania** (gwiazdka za trafienie za pierwszym razem) i **📖 Gramatyka**.
4. **🏠** wraca do ekranu z kafelkami. W **⚙️** rodzic może też przenieść słówka z lekcji do zwykłych fiszek.

**Wskazówki do zdjęcia:** dobre światło, kartka płasko i w całości w kadrze.

---

## Gdy coś nie działa

| Problem | Rozwiązanie |
|---|---|
| GitHub: przebieg długo czeka na start („Queued”) | Serwer z Xcode 27 (`xcode-27`) bywa oblegany – poczekaj albo uruchom ponownie później. |
| GitHub: czerwony ❌ przy budowaniu | Pobierz artefakt **log-budowania** i pokaż go Claude. |
| SideStore: odświeżanie nie działa | Czy **LocalDevVPN** jest połączony (Connect) i jesteś w Wi-Fi? Jeśli tak – wymień plik parowania (krok 3B, ramka na dole). |
| iloader nie widzi urządzenia | Zainstaluj iTunes ze strony apple.com, podłącz kablem, odblokuj urządzenie i stuknij „Zaufaj”. Przy problemach z iloader pomoc jest na serwerze Discord „idevice” (link w dokumentacji SideStore). |
| AltServer nie widzi urządzenia | Zainstaluj iTunes/iCloud ze strony apple.com (nie z Microsoft Store), podłącz kablem, stuknij „Zaufaj”. |
| „Maximum number of apps” | Darmowe Apple ID pozwala na 3 takie aplikacje na urządzeniu (AltStore/SideStore też się liczy) – usuń inne. |
| Aplikacja nie otwiera się po tygodniu | AltStore: uruchom AltServer na komputerze w tej samej sieci Wi-Fi i w AltStore stuknij **Refresh All**. SideStore: **LocalDevVPN → Connect**, potem w SideStore stuknij licznik dni. |
| Po AirDrop iPad nie proponuje „Fiszki” | Stuknij **Więcej…/Otwórz za pomocą** i wybierz Fiszki, albo zapisz plik w aplikacji Pliki i w klubie użyj **⚙️ → Wczytaj lekcje z pliku**. |
| Lekcja nie pojawia się na drugim urządzeniu (synchronizacja) | Ten sam folder wybrany na obu? To samo Apple ID i iCloud Drive włączony? **⚙️ → Synchronizuj teraz**. |
| ⚙️: „Brak dostępu do folderu synchronizacji” | **⚙️ → Zmień folder** i wybierz `Fiszki-Sync` ponownie. |
| Fiszki nie synchronizują się | Na obu urządzeniach zaloguj się tym samym e-mailem w *Ustawienia → Konto*. |
| Klub: „Klucz API Claude jest nieprawidłowy” | Wklej klucz ponownie w ⚙️ (cały, bez spacji); sprawdź kredyt na platform.claude.com. |
| Klub: „Claude jest teraz bardzo zajęty” / „Za dużo zapytań” | Odczekaj minutę i spróbuj ponownie. |
| Klub: „Nie znaleziono słówek ani zadań” | Zrób zdjęcie bliżej, w lepszym świetle, całą kartkę w kadrze. |
