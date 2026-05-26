# Projekt SQL – Dostupnosť potravín na základe priemerných príjmov

## Popis projektu

Tento projekt skúma dostupnosť základných potravín v Českej republike na základe priemerných miezd za obdobie 2006–2018. Dáta pochádzajú z Portálu otevřených dat ČR.

## Dátové podklady

### Primárna tabuľka: `t_natalia_hlavacova_project_SQL_primary_final`

Obsahuje spojenie dát o priemerných mzdách v jednotlivých odvetviach a priemerných cenách potravín za spoločné porovnateľné obdobie **2006–2018** (6840 riadkov).

**Stĺpce:**
- `year` – rok
- `industry_branch_code` – kód odvetvia
- `industry_name` – názov odvetvia
- `avg_salary` – priemerná hrubá mzda v odvetví (Kč)
- `category_code` – kód kategórie potraviny
- `food_name` – názov potraviny
- `price_value` – množstvo (napr. 1 kg, 1 l)
- `price_unit` – jednotka
- `avg_price` – priemerná cena potraviny (Kč)

**Poznámky k dátam:**
- Mzdy: filtrované na `value_type_code = 5958` (průměrná hrubá mzda) a `calculation_code = 100` (přepočtený)
- Ceny: filtrované na `region_code IS NULL` (priemer za celú ČR)
- Dáta o mzdách sú k dispozícii za roky 2000–2021, o cenách za 2006–2018
- Spoločné porovnateľné obdobie: **2006–2018**

### Sekundárna tabuľka: `t_natalia_hlavacova_project_SQL_secondary_final`

Obsahuje HDP, GINI koeficient a populáciu európskych štátov za rovnaké obdobie (585 riadkov).

**Stĺpce:**
- `country` – krajina
- `year` – rok
- `gdp` – hrubý domáci produkt
- `gini` – GINI koeficient
- `population` – počet obyvateľov

**Poznámky:** GINI koeficient nie je k dispozícii pre všetky krajiny a roky (obsahuje NULL hodnoty).

---

## Výsledky výskumných otázok

### Otázka 1: Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?

Mzdy nerastú kontinuálne vo všetkých odvetviach. Bolo identifikovaných 23 prípadov medziročného poklesu miezd. K poklesom dochádzalo najmä v období ekonomickej krízy (2009–2013). Najvýraznejší pokles zaznamenalo odvetvie Těžba a dobývání v roku 2009 (-4,36 %). Ďalšie výrazné poklesy boli v odvetví Vzdělávání v roku 2010 (-2,03 %) a Veřejná správa v rokoch 2010 a 2011. Dlhodobo však mzdy vo všetkých odvetviach rastú.

### Otázka 2: Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období?

Za priemernú mzdu bolo možné kúpiť:

- **Chléb konzumní kmínový:** v roku 2006 pri mzde 20 342 Kč a cene 16,12 Kč/kg = 1 261 kg; v roku 2018 pri mzde 31 980 Kč a cene 24,24 Kč/kg = 1 319 kg
- **Mléko polotučné pasterované:** v roku 2006 pri mzde 20 342 Kč a cene 14,44 Kč/l = 1 408 l; v roku 2018 pri mzde 31 980 Kč a cene 19,82 Kč/l = 1 613 l

V oboch prípadoch si v roku 2018 bolo možné kúpiť viac ako v roku 2006 – kúpna sila rástla, mzdy rástli rýchlejšie ako ceny týchto potravín.

### Otázka 3: Která kategorie potravin zdražuje nejpomaleji (nejnižší percentuální meziroční nárůst)?

Najpomalšie zdražujúce kategórie potravín (priemerný medziročný percentuálny nárast):

1. Cukr krystalový: -1,92 % (v priemere zlacňoval)
2. Rajská jablka červená kulatá: -0,74 % (v priemere zlacňovali)
3. Banány žluté: +0,81 %
4. Vepřová pečeně s kostí: +0,99 %
5. Přírodní minerální voda uhličitá: +1,03 %

Kategóriou s najnižším medziročným nárastom je teda Cukr krystalový, ktorý v sledovanom období v priemere zlacňoval.

### Otázka 4: Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?

Neexistuje rok, v ktorom by rozdiel medzi medziročným nárastom cien potravín a rastom miezd presiahol 10 %. Najväčší rozdiel bol zaznamenaný v roku 2013 (6,66 percentných bodov), kedy mzdy klesli o 1,56 % a ceny potravín vzrástli o 5,1 %. Odpoveď na otázku je teda nie.

### Otázka 5: Má výška HDP vliv na změny ve mzdách a cenách potravin?

Vplyv HDP na mzdy a ceny potravín nie je jednoznačný, ale určité vzťahy sú pozorovateľné:

- V roku 2009 HDP výrazne kleslo (-4,66 %) a rast miezd v nasledujúcom roku spomalil na 2 %.
- V rokoch silného rastu HDP (2007: +5,57 %, 2015: +5,39 %, 2017: +5,17 %) bol v nasledujúcom roku zaznamenaný výraznejší rast miezd.
- Vzťah medzi HDP a cenami potravín je menej priamočiary – na ceny potravín vplývajú aj ďalšie faktory (globálne ceny surovín, úroda, sezónnosť).

Celkovo možno konštatovať, že výraznejší rast HDP má tendenciu prejaviť sa na raste miezd, a to často s oneskorením jedného roka. Vplyv na ceny potravín je menej výrazný.

---

## Technické poznámky

- Databáza: PostgreSQL (lokálna inštancia s importovaným dumpom z Engeto)
- Pomocné views: `v_payroll_avg` a `v_price_avg` pre prehľadnosť a znovupoužiteľnosť
- V primárnych tabuľkách neboli vykonané žiadne zmeny
