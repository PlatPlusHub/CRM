-- Migration: seed_geo_reference_data
-- Plan reference: SPEC-133. Resolves REF-1 — countries, nationalities and languages existed as
-- FK-referenced tables holding ZERO rows, so four nullable columns could only ever be null and any
-- employee supplying a real country or nationality would have hit a foreign-key error.
--
-- WHY NOW RATHER THAN "AT THE FIRST UI". The deferral was legitimately governed (migration
-- 202607045300's header: deferred "until a hard requirement earns them"), but the trigger it named
-- is the first UI — which is exactly the moment an employee would discover the gap. The owner's
-- directive is explicit that no employee should be the person who finds a reference-data hole, so
-- the trigger is met now rather than waited for.
--
-- SCOPE FOLLOWS THE ESTABLISHED PRECEDENT, not an exhaustive standard. SPEC-074 seeded 18 curated
-- currencies rather than all 180 of ISO 4217, on the reasoning that a reference table should carry
-- what ORVION actually needs and grow on demand. The same judgement applies here: a curated set
-- covering Egyptian travel-agency reality — the GCC and wider MENA, the Umrah/Hajj corridor, the
-- main European/Asian/American destinations and the usual source markets — rather than 249 rows
-- transcribed by hand, which would carry real transcription risk for rows nothing yet reads.
-- Adding a country later is one INSERT; no schema change and no migration to the existing data.
--
-- THE `nationalities` VOCABULARY DECISION, which REF-1 explicitly left open. Two options existed:
-- reuse ISO 3166-1 alpha-2 country codes with demonym labels, or invent a separate demonym code
-- set. **Reusing the country code is chosen**, on three pieces of evidence:
--   1. `passengers` already carries BOTH `nationality_code` and `passport_issuing_country_code`.
--      With one vocabulary those two are directly comparable — "is this passenger travelling on a
--      passport from their own country?" is a simple equality test rather than a mapping lookup.
--   2. Every travel-industry document that carries nationality (passports, PNRs, visa applications,
--      IATA passenger data) expresses it as the ISO country code, so a second code set would need
--      translating at every integration boundary.
--   3. One vocabulary cannot drift out of sync with itself. A parallel demonym code set is a second
--      place for the same fact, which is what GOVERNANCE.md §6 exists to prevent.
-- The demonym lives in the `name` column, which is what labels are for.
--
-- Codes already satisfy the SPEC-126 shape CHECKs (countries/nationalities `^[A-Z]{2}$`, languages
-- `^[a-z]{2}$`), so this seed is additive and cannot introduce a casing variant.

-- ---------------------------------------------------------------------------------------------
-- Countries (ISO 3166-1 alpha-2)
-- ---------------------------------------------------------------------------------------------
insert into public.countries (code, name) values
    -- Home market and the Gulf / Umrah-Hajj corridor
    ('EG','Egypt'), ('SA','Saudi Arabia'), ('AE','United Arab Emirates'), ('KW','Kuwait'),
    ('QA','Qatar'), ('BH','Bahrain'), ('OM','Oman'), ('JO','Jordan'), ('LB','Lebanon'),
    ('SY','Syria'), ('IQ','Iraq'), ('YE','Yemen'), ('PS','Palestine'),
    -- Wider MENA / North Africa
    ('MA','Morocco'), ('TN','Tunisia'), ('DZ','Algeria'), ('LY','Libya'), ('SD','Sudan'),
    ('TR','Turkey'), ('IL','Israel'),
    -- Europe
    ('GB','United Kingdom'), ('IE','Ireland'), ('FR','France'), ('DE','Germany'), ('IT','Italy'),
    ('ES','Spain'), ('PT','Portugal'), ('NL','Netherlands'), ('BE','Belgium'), ('CH','Switzerland'),
    ('AT','Austria'), ('GR','Greece'), ('CY','Cyprus'), ('SE','Sweden'), ('NO','Norway'),
    ('DK','Denmark'), ('FI','Finland'), ('PL','Poland'), ('CZ','Czechia'), ('HU','Hungary'),
    ('RO','Romania'), ('BG','Bulgaria'), ('RU','Russia'), ('UA','Ukraine'), ('RS','Serbia'),
    -- Asia
    ('CN','China'), ('JP','Japan'), ('KR','South Korea'), ('IN','India'), ('PK','Pakistan'),
    ('BD','Bangladesh'), ('LK','Sri Lanka'), ('NP','Nepal'), ('ID','Indonesia'), ('MY','Malaysia'),
    ('SG','Singapore'), ('TH','Thailand'), ('VN','Vietnam'), ('PH','Philippines'), ('AZ','Azerbaijan'),
    ('GE','Georgia'), ('AM','Armenia'), ('KZ','Kazakhstan'), ('UZ','Uzbekistan'), ('IR','Iran'),
    -- Americas and Oceania
    ('US','United States'), ('CA','Canada'), ('MX','Mexico'), ('BR','Brazil'), ('AR','Argentina'),
    ('AU','Australia'), ('NZ','New Zealand'),
    -- Sub-Saharan Africa
    ('ZA','South Africa'), ('KE','Kenya'), ('NG','Nigeria'), ('ET','Ethiopia'), ('TZ','Tanzania'),
    ('GH','Ghana'), ('SN','Senegal'), ('DJ','Djibouti'), ('SO','Somalia'), ('ER','Eritrea')
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------------------------
-- Nationalities — same ISO 3166-1 alpha-2 codes, demonym in the label. See the decision above.
-- ---------------------------------------------------------------------------------------------
insert into public.nationalities (code, name) values
    ('EG','Egyptian'), ('SA','Saudi'), ('AE','Emirati'), ('KW','Kuwaiti'), ('QA','Qatari'),
    ('BH','Bahraini'), ('OM','Omani'), ('JO','Jordanian'), ('LB','Lebanese'), ('SY','Syrian'),
    ('IQ','Iraqi'), ('YE','Yemeni'), ('PS','Palestinian'),
    ('MA','Moroccan'), ('TN','Tunisian'), ('DZ','Algerian'), ('LY','Libyan'), ('SD','Sudanese'),
    ('TR','Turkish'), ('IL','Israeli'),
    ('GB','British'), ('IE','Irish'), ('FR','French'), ('DE','German'), ('IT','Italian'),
    ('ES','Spanish'), ('PT','Portuguese'), ('NL','Dutch'), ('BE','Belgian'), ('CH','Swiss'),
    ('AT','Austrian'), ('GR','Greek'), ('CY','Cypriot'), ('SE','Swedish'), ('NO','Norwegian'),
    ('DK','Danish'), ('FI','Finnish'), ('PL','Polish'), ('CZ','Czech'), ('HU','Hungarian'),
    ('RO','Romanian'), ('BG','Bulgarian'), ('RU','Russian'), ('UA','Ukrainian'), ('RS','Serbian'),
    ('CN','Chinese'), ('JP','Japanese'), ('KR','South Korean'), ('IN','Indian'), ('PK','Pakistani'),
    ('BD','Bangladeshi'), ('LK','Sri Lankan'), ('NP','Nepali'), ('ID','Indonesian'), ('MY','Malaysian'),
    ('SG','Singaporean'), ('TH','Thai'), ('VN','Vietnamese'), ('PH','Filipino'), ('AZ','Azerbaijani'),
    ('GE','Georgian'), ('AM','Armenian'), ('KZ','Kazakh'), ('UZ','Uzbek'), ('IR','Iranian'),
    ('US','American'), ('CA','Canadian'), ('MX','Mexican'), ('BR','Brazilian'), ('AR','Argentine'),
    ('AU','Australian'), ('NZ','New Zealander'),
    ('ZA','South African'), ('KE','Kenyan'), ('NG','Nigerian'), ('ET','Ethiopian'), ('TZ','Tanzanian'),
    ('GH','Ghanaian'), ('SN','Senegalese'), ('DJ','Djiboutian'), ('SO','Somali'), ('ER','Eritrean')
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------------------------
-- Languages (ISO 639-1). Canon 25 names ar and en as the initial practical values; the rest are
-- the languages an Egyptian agency realistically serves or issues documents in.
-- ---------------------------------------------------------------------------------------------
insert into public.languages (code, name) values
    ('ar','Arabic'), ('en','English'), ('fr','French'), ('de','German'), ('it','Italian'),
    ('es','Spanish'), ('ru','Russian'), ('tr','Turkish'), ('zh','Chinese'), ('ja','Japanese'),
    ('ur','Urdu'), ('hi','Hindi'), ('el','Greek'), ('nl','Dutch'), ('pt','Portuguese'),
    ('fa','Persian'), ('id','Indonesian'), ('ms','Malay'), ('ko','Korean'), ('uk','Ukrainian')
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------------------------
-- Now that the vocabulary decision is made, constrain it. `nationalities.code` was deliberately
-- left unconstrained by SPEC-126 precisely because this choice was open; it no longer is.
-- ---------------------------------------------------------------------------------------------
alter table public.nationalities
    add constraint nationalities_code_format_chk check (code ~ '^[A-Z]{2}$');

-- Every nationality must name a country that exists, which is what makes "one vocabulary" real
-- rather than merely intended. Not a foreign key: `nationalities` is a peer reference table, and an
-- FK would impose a load order between two independent seeds. Asserted permanently by test 18.
