-- pgTAP invariants: the core reference tables are seeded, canonical in shape, and mutually
-- consistent. Guard for REF-1 (SPEC-133), which existed because countries, nationalities and
-- languages were FK-referenced tables holding ZERO rows -- so an employee supplying a real country
-- or nationality would have hit a foreign-key error rather than a working dropdown.
--
-- Assertion 4 is the one that keeps the vocabulary decision honest: nationalities deliberately
-- reuse ISO 3166-1 alpha-2 country codes, and that is only a single vocabulary if every nationality
-- actually names a country that exists. It is asserted rather than enforced by FK because the two
-- are peer reference tables and an FK would impose a load order between independent seeds.
create extension if not exists pgtap with schema extensions;

begin;
select plan(7);

select ok((select count(*) from public.countries) >= 60,
  'countries is seeded with a working set, not left empty for the first employee to discover');

select ok((select count(*) from public.nationalities) >= 60,
  'nationalities is seeded');

select ok((select count(*) from public.languages) >= 10,
  'languages is seeded');

select is(
  (select count(*)::int from public.nationalities n
    where not exists (select 1 from public.countries c where c.code = n.code)),
  0,
  'every nationality names a real country -- nationalities and countries are ONE vocabulary');

-- The four FK columns that could previously only ever be null must now accept a real value.
insert into public.tenants (id, name, slug, status)
values ('99990000-0000-0000-0000-00000000000a','Ref Data Tenant','refdata','active');
insert into public.customers (id, tenant_id, customer_type_code, full_name, preferred_language_code)
values ('99990000-0000-0000-0000-0000000000c1','99990000-0000-0000-0000-00000000000a','person','Lang Customer','ar');

select lives_ok(
  $$insert into public.passengers (tenant_id, customer_id, passenger_type_code,
        first_name, family_name, full_name, nationality_code, passport_issuing_country_code)
    values ('99990000-0000-0000-0000-00000000000a','99990000-0000-0000-0000-0000000000c1','adult',
            'Ahmed','Hassan','Ahmed Hassan','EG','EG')$$,
  'a passenger can now be given a real nationality and passport-issuing country');

select is(
  (select preferred_language_code from public.customers where id = '99990000-0000-0000-0000-0000000000c1'),
  'ar',
  'a customer can now be given a real preferred language');

-- The seed must not have smuggled in a casing variant -- the exact failure SPEC-126 guards against
-- at the catalog and which a hand-written seed is the most likely place to reintroduce.
select is(
  (select count(*)::int
     from (select code from public.countries
           union all select code from public.nationalities) x
    where code !~ '^[A-Z]{2}$')
  + (select count(*)::int from public.languages where code !~ '^[a-z]{2}$'),
  0,
  'every seeded reference code is in its canonical ISO shape');

select * from finish();
rollback;
