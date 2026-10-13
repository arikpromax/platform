-- Alexon: профіль Google (ALEXON, 17120 86 Ave NW), посилання для відгуків і адреса.
-- Виконати в Supabase → SQL Editor. Якщо спитає про RLS — «Run without RLS» (таблиць тут не створюється).
update public.texts t set value = v.value
from (values
  ('google',    'https://www.google.com/maps/place/?q=place_id:ChIJ1fs41k0hoFMRNJAfr6FTTXo'),
  ('rev_write', 'https://search.google.com/local/writereview?placeid=ChIJ1fs41k0hoFMRNJAfr6FTTXo'),
  ('address',   E'17120 86 Ave NW\nEdmonton, AB T5T 0J2')
) as v(key, value)
where t.site_id = (select id from public.sites where slug = 'alexon') and t.key = v.key;

select key, value from public.texts
where site_id = (select id from public.sites where slug = 'alexon') and key in ('google', 'rev_write', 'address');
